//
//  WHC_ModelSqlite.m
//  WHC_ModelSqliteKit
//
//  Created by admin on 16/5/28.
//  Copyright © 2016年 WHC. All rights reserved.
//
// Github <https://github.com/netyouli/WHC_ModelSqliteKit>

//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "WHC_ModelSqlite.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <sqlite3.h>


static const NSString * WHC_String     = @"TEXT";
static const NSString * WHC_Int        = @"INTERGER";
static const NSString * WHC_Boolean    = @"INTERGER";
static const NSString * WHC_Double     = @"DOUBLE";
static const NSString * WHC_Float      = @"DOUBLE";
static const NSString * WHC_Char       = @"NVARCHAR";
static const NSString * WHC_Model      = @"INTERGER";
static const NSString * WHC_Data       = @"BLOB";
static const NSString * WHC_Array      = @"BLOB";
static const NSString * WHC_Dictionary = @"BLOB";
static const NSString * WHC_Date       = @"DOUBLE";

typedef enum : NSUInteger {
    _String,
    _Int,
    _Boolean,
    _Double,
    _Float,
    _Char,
    _Number,
    _Model,
    _Data,
    _Date,
    _Array,
    _Dictionary
} WHC_FieldType;

typedef enum : NSUInteger {
    _Where,
    _Order,
    _Limit,
    _WhereOrder,
    _WhereLimit,
    _OrderLimit,
    _WhereOrderLimit
} WHC_QueryType;


static sqlite3 * _whc_database;

static NSInteger _NO_HANDLE_KEY_ID = -2;

@interface WHC_PropertyInfo : NSObject

@property (nonatomic, assign, readonly) WHC_FieldType type;
@property (nonatomic, copy, readonly) NSString * name;
@property (nonatomic, assign, readonly) SEL setter;
@property (nonatomic, assign, readonly) SEL getter;
@end

@implementation WHC_PropertyInfo

- (WHC_PropertyInfo *)initWithType:(WHC_FieldType)type
                      propertyName:(NSString *)property_name {
    self = [super init];
    if (self) {
        _name = property_name.mutableCopy;
        _type = type;
        _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[property_name substringToIndex:1].uppercaseString,[property_name substringFromIndex:1]]);
        _getter = NSSelectorFromString(property_name);
    }
    return self;
}

@end

@interface WHC_ModelSqlite ()
@property (nonatomic, strong) NSMutableDictionary * sub_model_info;
@property (nonatomic, strong) dispatch_semaphore_t dsema;
@end

@implementation WHC_ModelSqlite

- (WHC_ModelSqlite *)init {
    self = [super init];
    if (self) {
        self.sub_model_info = [NSMutableDictionary dictionary];
        self.dsema = dispatch_semaphore_create(1);
    }
    return self;
}

+ (WHC_ModelSqlite *)shareInstance {
    static WHC_ModelSqlite * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WHC_ModelSqlite new];
    });
    return instance;
}

+ (NSString *)databaseCacheDirectory {
    return [NSString stringWithFormat:@"%@/Library/Caches/WHCSqlite/",NSHomeDirectory()];
}

+ (WHC_FieldType)parserFieldTypeWithAttr:(NSString *)attr {
    NSArray * sub_attrs = [attr componentsSeparatedByString:@","];
    NSString * first_sub_attr = sub_attrs.firstObject;
    first_sub_attr = [first_sub_attr substringFromIndex:1];
    WHC_FieldType field_type = _String;
    const char type = *[first_sub_attr UTF8String];
    switch (type) {
        case 'B':
            field_type = _Boolean;
            break;
        case 'c':
        case 'C':
            field_type = _Char;
            break;
        case 's':
        case 'S':
        case 'i':
        case 'I':
        case 'l':
        case 'L':
        case 'q':
        case 'Q':
            field_type = _Int;
            break;
        case 'f':
            field_type = _Float;
            break;
        case 'd':
        case 'D':
            field_type = _Double;
            break;
        default:
            break;
    }
    return field_type;
}

+ (const NSString *)databaseFieldTypeWithType:(WHC_FieldType)type {
    switch (type) {
        case _String:
            return WHC_String;
        case _Model:
            return WHC_Model;
        case _Int:
            return WHC_Int;
        case _Number:
            return WHC_Double;
        case _Double:
            return WHC_Double;
        case _Float:
            return WHC_Float;
        case _Char:
            return WHC_Char;
        case _Boolean:
            return WHC_Boolean;
        case _Data:
            return WHC_Data;
        case _Date:
            return WHC_Date;
        case _Array:
            return WHC_Array;
        case _Dictionary:
            return WHC_Dictionary;
        default:
            break;
    }
    return WHC_String;
}

+ (NSDictionary *)parserModelObjectFieldsWithModelClass:(Class)model_class {
    NSMutableDictionary * fields = [NSMutableDictionary dictionary];
    Class super_class = class_getSuperclass(model_class);
    if (super_class != nil &&
        super_class != [NSObject class]) {
        [fields setValuesForKeysWithDictionary:[self parserModelObjectFieldsWithModelClass:super_class]];
    }
    unsigned int property_count = 0;
    objc_property_t * propertys = class_copyPropertyList(model_class, &property_count);
    for (int i = 0; i < property_count; i++) {
        objc_property_t property = propertys[i];
        const char * property_name = property_getName(property);
        const char * property_attributes = property_getAttributes(property);
        NSString * property_name_string = [NSString stringWithUTF8String:property_name];
        NSString * property_attributes_string = [NSString stringWithUTF8String:property_attributes];
        NSArray * property_attributes_list = [property_attributes_string componentsSeparatedByString:@"\""];
        if (property_attributes_list.count == 1) {
            // base type
            WHC_FieldType type = [self parserFieldTypeWithAttr:property_attributes_list[0]];
            WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:type propertyName:property_name_string];
            [fields setObject:property_info forKey:property_name_string];
        }else {
            // refernece type
            Class class_type = NSClassFromString(property_attributes_list[1]);
            if (class_type == [NSNumber class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Number propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSString class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_String propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSData class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Data propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSArray class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Array propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSDictionary class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Dictionary propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSDate class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Date propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSSet class] ||
                      class_type == [NSValue class] ||
                      class_type == [NSError class] ||
                      class_type == [NSURL class] ||
                      class_type == [NSStream class] ||
                      class_type == [NSScanner class] ||
                      class_type == [NSException class]) {
                [self log:@"检查模型类异常数据类型"];
            }else {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Model propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }
        }
    }
    free(propertys);
    return fields;
}

+ (NSDictionary *)scanCommonSubModel:(id)model isClass:(BOOL)is_class {
    Class model_class = is_class ? model : [model class];
    NSMutableDictionary * sub_model_info = [NSMutableDictionary dictionary];
    Class super_class = class_getSuperclass(model_class);
    if (super_class != nil &&
        super_class != [NSObject class]) {
        [sub_model_info setValuesForKeysWithDictionary:[self scanCommonSubModel:is_class ? super_class : super_class.new isClass:is_class]];
    }
    unsigned int property_count = 0;
    objc_property_t * propertys = class_copyPropertyList(model_class, &property_count);
    for (int i = 0; i < property_count; i++) {
        objc_property_t property = propertys[i];
        const char * property_name = property_getName(property);
        const char * property_attributes = property_getAttributes(property);
        NSString * property_name_string = [NSString stringWithUTF8String:property_name];
        NSString * property_attributes_string = [NSString stringWithUTF8String:property_attributes];
        NSArray * property_attributes_list = [property_attributes_string componentsSeparatedByString:@"\""];
        if (property_attributes_list.count > 1) {
            Class class_type = NSClassFromString(property_attributes_list[1]);
            if (class_type != [NSString class] &&
                class_type != [NSNumber class] &&
                class_type != [NSArray class] &&
                class_type != [NSSet class] &&
                class_type != [NSData class] &&
                class_type != [NSDate class] &&
                class_type != [NSDictionary class] &&
                class_type != [NSValue class] &&
                class_type != [NSError class] &&
                class_type != [NSURL class] &&
                class_type != [NSStream class] &&
                class_type != [NSScanner class] &&
                class_type != [NSException class]) {
                if (is_class) {
                    [sub_model_info setObject:property_attributes_list[1] forKey:property_name_string];
                }else {
                    id sub_model = [model valueForKey:property_name_string];
                    if (sub_model) {
                        [sub_model_info setObject:sub_model forKey:property_name_string];
                    }
                }
            }
        }
    }
    free(propertys);
    return sub_model_info;
}

+ (NSDictionary * )scanSubModelClass:(Class)model_class {
    return [self scanCommonSubModel:model_class isClass:YES];
}

+ (NSDictionary * )scanSubModelObject:(NSObject *)model_object {
    return [self scanCommonSubModel:model_object isClass:NO];
}

+ (sqlite_int64)getModelMaxIdWithClass:(Class)model_class {
    sqlite_int64 max_id = 0;
    if (_whc_database) {
        NSString * select_sql = [NSString stringWithFormat:@"SELECT MAX(%@) AS MAXVALUE FROM %@",[self getMainKeyWithClass:model_class],NSStringFromClass(model_class)];
        sqlite3_stmt * pp_stmt = nil;
        if (sqlite3_prepare_v2(_whc_database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
            while (sqlite3_step(pp_stmt) == SQLITE_ROW) {
                max_id = sqlite3_column_int64(pp_stmt, 0);
            }
        }
        sqlite3_finalize(pp_stmt);
    }
    return max_id;
}

+ (NSArray *)getModelFieldNameWithClass:(Class)model_class {
    NSMutableArray * field_name_array = [NSMutableArray array];
    if (_whc_database) {
        NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = %lld",NSStringFromClass(model_class),[self getMainKeyWithClass:model_class],[self getModelMaxIdWithClass:model_class]];
        sqlite3_stmt * pp_stmt = nil;
        if (sqlite3_prepare_v2(_whc_database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
            int colum_count = sqlite3_column_count(pp_stmt);
            for (int column = 1; column < colum_count; column++) {
                NSString * field_name = [NSString stringWithCString:sqlite3_column_name(pp_stmt, column) encoding:NSUTF8StringEncoding];
                [field_name_array addObject:field_name];
            }
        }
        sqlite3_finalize(pp_stmt);
    }
    return field_name_array;
}

+ (void)updateTableFieldWithModel:(Class)model_class
                       newVersion:(NSString *)newVersion
                   localModelName:(NSString *)local_model_name {
    @autoreleasepool {
        NSString * table_name = NSStringFromClass(model_class);
        NSString * cache_directory = [self databaseCacheDirectory];
        NSString * database_cache_path = [NSString stringWithFormat:@"%@%@",cache_directory,local_model_name];
        if (sqlite3_open([database_cache_path UTF8String], &_whc_database) == SQLITE_OK) {
            NSArray * old_model_field_name_array = [self getModelFieldNameWithClass:model_class];
            NSDictionary * new_model_info = [self parserModelObjectFieldsWithModelClass:model_class];
            NSMutableString * delete_field_names = [NSMutableString string];
            NSMutableString * add_field_names = [NSMutableString string];
            [old_model_field_name_array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (new_model_info[obj] == nil) {
                    [delete_field_names appendString:obj];
                    [delete_field_names appendString:@" ,"];
                }
            }];
            [new_model_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, WHC_PropertyInfo * obj, BOOL * _Nonnull stop) {
                if (![old_model_field_name_array containsObject:key]) {
                    [add_field_names appendFormat:@"%@ %@,",key,[self databaseFieldTypeWithType:obj.type]];
                }
            }];
            if (add_field_names.length > 0) {
                NSArray * add_field_name_array = [add_field_names componentsSeparatedByString:@","];
                [add_field_name_array enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (obj.length > 0) {
                        NSString * add_field_name_sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD %@",table_name,obj];
                        [self execSql:add_field_name_sql];
                    }
                }];
            }
            if (delete_field_names.length > 0) {
                [delete_field_names deleteCharactersInRange:NSMakeRange(delete_field_names.length - 1, 1)];
                NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@",table_name];
                NSMutableArray * old_model_data_array = [NSMutableArray array];
                sqlite3_stmt * pp_stmt = nil;
                NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
                NSMutableString * sub_model_name = [NSMutableString string];
                [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [sub_model_name appendString:key];
                    [sub_model_name appendString:@" "];
                }];
                if (sqlite3_prepare_v2(_whc_database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
                    int colum_count = sqlite3_column_count(pp_stmt);
                    while (sqlite3_step(pp_stmt) == SQLITE_ROW) {
                        id new_model_object = [model_class new];
                        for (int column = 1; column < colum_count; column++) {
                            NSString * old_field_name = [NSString stringWithCString:sqlite3_column_name(pp_stmt, column) encoding:NSUTF8StringEncoding];
                            WHC_PropertyInfo * property_info = new_model_info[old_field_name];
                            if (property_info == nil) continue;
                            switch (property_info.type) {
                                case _Number: {
                                    double value = sqlite3_column_double(pp_stmt, column);
                                    [new_model_object setValue:@(value) forKey:old_field_name];
                                }
                                    break;
                                case _Model: {
                                    sqlite3_int64 value = sqlite3_column_int64(pp_stmt, column);
                                    [new_model_object setValue:@(value) forKey:old_field_name];
                                }
                                    break;
                                case _Int: {
                                    sqlite3_int64 value = sqlite3_column_int64(pp_stmt, column);
                                    if (sub_model_name != nil && sub_model_name.length > 0) {
                                        if ([sub_model_name rangeOfString:old_field_name].location == NSNotFound) {
                                            ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)new_model_object, property_info.setter, value);
                                        }else {
                                            [new_model_object setValue:@(value) forKey:old_field_name];
                                        }
                                    }else {
                                        ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)new_model_object, property_info.setter, value);
                                    }
                                }
                                    break;
                                case _String: {
                                    const unsigned char * text = sqlite3_column_text(pp_stmt, column);
                                    if (text != NULL) {
                                        NSString * value = [NSString stringWithCString:(const char *)text encoding:NSUTF8StringEncoding];
                                        [new_model_object setValue:value forKey:old_field_name];
                                    }else {
                                        [new_model_object setValue:@"" forKey:old_field_name];
                                    }
                                }
                                    break;
                                case _Data: {
                                    int length = sqlite3_column_bytes(pp_stmt, column);
                                    const void * blob = sqlite3_column_blob(pp_stmt, column);
                                    if (blob) {
                                        NSData * value = [NSData dataWithBytes:blob length:length];
                                        [new_model_object setValue:value forKey:old_field_name];
                                    }else {
                                        [new_model_object setValue:[NSData data] forKey:old_field_name];
                                    }
                                }
                                    break;
                                case _Date: {
                                    double value = sqlite3_column_double(pp_stmt, column);
                                    if (value > 0) {
                                        NSDate * date_value = [NSDate dateWithTimeIntervalSince1970:value];
                                        if (date_value) {
                                            [new_model_object setValue:date_value forKey:old_field_name];
                                        }
                                    }
                                }
                                    break;
                                case _Dictionary:
                                case _Array: {
                                    int length = sqlite3_column_bytes(pp_stmt, column);
                                    const void * blob = sqlite3_column_blob(pp_stmt, column);
                                    if (blob) {
                                        NSData * value = [NSData dataWithBytes:blob length:length];
                                        @try {
                                            id set_value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
                                            [new_model_object setValue:set_value forKey:old_field_name];
                                        } @catch (NSException *exception) {
                                            [self log:@"update 操作异常 Array/Dictionary 元素没实现NSCoding协议解归档失败"];
                                        }
                                    }else {
                                        [new_model_object setValue:property_info.type == _Dictionary ? [NSDictionary dictionary] : [NSArray array] forKey:old_field_name];
                                    }
                                }
                                    break;
                                case _Char:
                                case _Boolean: {
                                    int value = sqlite3_column_int(pp_stmt, column);
                                    ((void (*)(id, SEL, int))(void *) objc_msgSend)((id)new_model_object, property_info.setter, value);
                                }
                                    break;
                                case _Float:
                                case _Double: {
                                    double value = sqlite3_column_double(pp_stmt, column);
                                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)new_model_object, property_info.setter, value);
                                }
                                    break;
                                default:
                                    break;
                            }
                        }
                        [old_model_data_array addObject:new_model_object];
                    }
                }
                sqlite3_finalize(pp_stmt);
                [self close];
                
                NSFileManager * file_manager = [NSFileManager defaultManager];
                NSString * file_path = [self localPathWithModel:model_class];
                if (file_path) {
                    [file_manager removeItemAtPath:file_path error:nil];
                }
                
                if ([self openTable:model_class]) {
                    [self execSql:@"BEIGIN"];
                    [old_model_data_array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        [self commonInsert:obj index:_NO_HANDLE_KEY_ID];
                    }];
                    [self execSql:@"COMMIT"];
                    [self close];
                    return;
                }
            }
            [self close];
            NSString * new_database_cache_path = [NSString stringWithFormat:@"%@%@_v%@.sqlite",cache_directory,table_name,newVersion];
            NSFileManager * file_manager = [NSFileManager defaultManager];
            [file_manager moveItemAtPath:database_cache_path toPath:new_database_cache_path error:nil];
        }
    }
}


+ (BOOL)setKey:(NSString*)key {
    NSData *keyData = [NSData dataWithBytes:[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
    
    return [self setKeyWithData:keyData];
}

+ (BOOL)setKeyWithData:(NSData *)keyData {
#ifdef SQLITE_HAS_CODEC
    if (!keyData) {
        return NO;
    }
    
    int rc = sqlite3_key(_whc_database, [keyData bytes], (int)[keyData length]);
    
    return (rc == SQLITE_OK);
#else
    return NO;
#endif
}

+ (NSString *)exceSelector:(SEL)selector modelClass:(Class)model_class {
    if ([model_class respondsToSelector:selector]) {
        IMP sqlite_info_func = [model_class methodForSelector:selector];
        NSString * (*func)(id, SEL) = (void *)sqlite_info_func;
        return func(model_class, selector);
    }
    return nil;
}

+ (NSString *)getMainKeyWithClass:(Class)model_class {
    NSString * main_key = [self exceSelector:@selector(whc_SqliteMainkey) modelClass:model_class];
    if (!main_key || main_key.length == 0) {
        main_key = @"_id";
    }
    return main_key;
}

+ (BOOL)openTable:(Class)model_class {
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSString * cache_directory = [self databaseCacheDirectory];
    BOOL is_directory = YES;
    if (![file_manager fileExistsAtPath:cache_directory isDirectory:&is_directory]) {
        [file_manager createDirectoryAtPath:cache_directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    SEL VERSION = @selector(whc_SqliteVersion);
    NSString * version = @"1.0";
    if ([model_class respondsToSelector:VERSION]) {
        version = [self exceSelector:VERSION modelClass:model_class];
        if (!version || version.length == 0) {version = @"1.0";}
        NSString * local_model_name = [self localNameWithModel:model_class];
        if (local_model_name != nil &&
            [local_model_name rangeOfString:version].location == NSNotFound) {
            [self updateTableFieldWithModel:model_class
                                 newVersion:version
                             localModelName:local_model_name];
        }
    }
    NSString * database_cache_path = [NSString stringWithFormat:@"%@%@_v%@.sqlite",cache_directory,NSStringFromClass(model_class),version];
    if (sqlite3_open([database_cache_path UTF8String], &_whc_database) == SQLITE_OK) {
        NSString * psw_key = [self exceSelector:@selector(whc_SqlitePasswordKey) modelClass:model_class];
        if (psw_key && psw_key.length > 0) {
            [self setKey:psw_key];
        }
        return [self createTable:model_class];
    }
    return NO;
}

+ (BOOL)createTable:(Class)model_class {
    NSString * table_name = NSStringFromClass(model_class);
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:model_class];
    if (field_dictionary.count > 0) {
        NSString * main_key = [self getMainKeyWithClass:model_class];
        NSString * create_table_sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,",table_name,main_key];
        NSArray * field_array = field_dictionary.allKeys;
        for (NSString * field in field_array) {
            WHC_PropertyInfo * property_info = field_dictionary[field];
            create_table_sql = [create_table_sql stringByAppendingFormat:@"%@ %@ DEFAULT ",field, [self databaseFieldTypeWithType:property_info.type]];
            switch (property_info.type) {
                case _Data:
                case _String:
                case _Char:
                case _Dictionary:
                case _Array:
                    create_table_sql = [create_table_sql stringByAppendingString:@"NULL,"];
                    break;
                case _Boolean:
                case _Int:
                case _Model:
                    create_table_sql = [create_table_sql stringByAppendingString:@"0,"];
                    break;
                case _Float:
                case _Double:
                case _Number:
                case _Date:
                    create_table_sql = [create_table_sql stringByAppendingString:@"0.0,"];
                    break;
                default:
                    break;
            }
        }
        create_table_sql = [create_table_sql substringWithRange:NSMakeRange(0, create_table_sql.length - 1)];
        create_table_sql = [create_table_sql stringByAppendingString:@")"];
        return [self execSql:create_table_sql];
    }
    return NO;
}

+ (BOOL)execSql:(NSString *)sql {
    return sqlite3_exec(_whc_database, [sql UTF8String], nil, nil, nil) == SQLITE_OK;
}

+ (void)commonInsert:(id)model_object index:(NSInteger)index {
    sqlite3_stmt * pp_stmt = nil;
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:[model_object class]];
    NSString * table_name = NSStringFromClass([model_object class]);
    __block NSString * insert_sql = [NSString stringWithFormat:@"INSERT INTO %@ (",table_name];
    NSArray * field_array = field_dictionary.allKeys;
    NSMutableArray * value_array = [NSMutableArray array];
    NSMutableArray * insert_field_array = [NSMutableArray array];
    [field_array enumerateObjectsUsingBlock:^(NSString *  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        [insert_field_array addObject:field];
        insert_sql = [insert_sql stringByAppendingFormat:@"%@,",field];
        id value = [model_object valueForKey:field];
        id subModelKeyId = [self shareInstance].sub_model_info[property_info.name];
        if ((value && subModelKeyId == nil) || index == _NO_HANDLE_KEY_ID) {
            [value_array addObject:value];
        }else {
            switch (property_info.type) {
                case _Array: {
                    NSData * array_value = [NSKeyedArchiver archivedDataWithRootObject:[NSArray array]];
                    [value_array addObject:array_value];
                }
                    break;
                case _Dictionary: {
                    NSData * dictionary_value = [NSKeyedArchiver archivedDataWithRootObject:[NSDictionary dictionary]];
                    [value_array addObject:dictionary_value];
                }
                    break;
                case _Data: {
                    [value_array addObject:[NSData data]];
                }
                    break;
                case _String: {
                    [value_array addObject:@""];
                }
                    break;
                case _Date:
                case _Number: {
                    [value_array addObject:@(0.0)];
                }
                    break;
                case _Model: {
                    if ([subModelKeyId isKindOfClass:[NSArray class]]) {
                        [value_array addObject:subModelKeyId[index]];
                    }else {
                        if (subModelKeyId) {
                            [value_array addObject:subModelKeyId];
                        }else {
                            [value_array addObject:@(_NO_HANDLE_KEY_ID)];
                        }
                    }
                }
                    break;
                case _Int: {
                    id sub_model_main_key_object = [self shareInstance].sub_model_info[property_info.name];
                    if (sub_model_main_key_object != nil) {
                        if (index != -1) {
                            [value_array addObject:sub_model_main_key_object[index]];
                        }else {
                            [value_array addObject:sub_model_main_key_object];
                        }
                    }else {
                        NSNumber * value = @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                        [value_array addObject:value];
                    }
                }
                    break;
                case _Boolean: {
                    NSNumber * value = @(((Boolean (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                    [value_array addObject:value];
                }
                    break;
                case _Char: {
                    NSNumber * value = @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                    [value_array addObject:value];
                }
                    break;
                case _Double: {
                    NSNumber * value = @(((double (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                    [value_array addObject:value];
                }
                    break;
                case _Float: {
                    NSNumber * value = @(((float (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                    [value_array addObject:value];
                }
                    break;
                default:
                    break;
            }
        }
    }];
   
    insert_sql = [insert_sql substringWithRange:NSMakeRange(0, insert_sql.length - 1)];
    insert_sql = [insert_sql stringByAppendingString:@") VALUES ("];
    
    [field_array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        insert_sql = [insert_sql stringByAppendingString:@"?,"];
    }];
    insert_sql = [insert_sql substringWithRange:NSMakeRange(0, insert_sql.length - 1)];
    insert_sql = [insert_sql stringByAppendingString:@")"];
    
    if (sqlite3_prepare_v2(_whc_database, [insert_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
        [field_array enumerateObjectsUsingBlock:^(NSString *  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
            WHC_PropertyInfo * property_info = field_dictionary[field];
            id value = value_array[idx];
            int index = (int)[insert_field_array indexOfObject:field] + 1;
            switch (property_info.type) {
                case _Dictionary:
                case _Array: {
                    @try {
                        if ([value isKindOfClass:[NSArray class]] ||
                            [value isKindOfClass:[NSDictionary class]]) {
                            NSData * data = [NSKeyedArchiver archivedDataWithRootObject:value];
                            sqlite3_bind_blob(pp_stmt, index, [data bytes], (int)[data length], SQLITE_TRANSIENT);
                        }else {
                            sqlite3_bind_blob(pp_stmt, index, [value bytes], (int)[value length], SQLITE_TRANSIENT);
                        }
                    } @catch (NSException *exception) {
                        [self log:[NSString stringWithFormat:@"insert 异常 Array/Dictionary类型元素未实现NSCoding协议归档失败"]];
                    }
                }
                    break;
                case _Data:
                    sqlite3_bind_blob(pp_stmt, index, [value bytes], (int)[value length], SQLITE_TRANSIENT);
                    break;
                case _String:
                    if ([value respondsToSelector:@selector(UTF8String)]) {
                        sqlite3_bind_text(pp_stmt, index, [value UTF8String], -1, SQLITE_TRANSIENT);
                    }else {
                        sqlite3_bind_text(pp_stmt, index, [[NSString stringWithFormat:@"%@",value] UTF8String], -1, SQLITE_TRANSIENT);
                    }
                    break;
                case _Number:
                    sqlite3_bind_double(pp_stmt, index, [value doubleValue]);
                    break;
                case _Model:
                    sqlite3_bind_int64(pp_stmt, index, (sqlite3_int64)[value integerValue]);
                    break;
                case _Int:
                    sqlite3_bind_int64(pp_stmt, index, (sqlite3_int64)[value longLongValue]);
                    break;
                case _Boolean:
                    sqlite3_bind_int(pp_stmt, index, [value boolValue]);
                    break;
                case _Char:
                    sqlite3_bind_int(pp_stmt, index, [value intValue]);
                    break;
                case _Float:
                    sqlite3_bind_double(pp_stmt, index, [value floatValue]);
                    break;
                case _Double:
                    sqlite3_bind_double(pp_stmt, index, [value doubleValue]);
                    break;
                case _Date: {
                    if ([value isKindOfClass:[NSDate class]]) {
                        sqlite3_bind_double(pp_stmt, index, [(NSDate *)value timeIntervalSince1970]);
                    }else {
                        sqlite3_bind_double(pp_stmt, index, [value doubleValue]);
                    }
                }
                    break;
                default:
                    break;
            }
        }];
        if (sqlite3_step(pp_stmt) != SQLITE_DONE) {
            sqlite3_finalize(pp_stmt);
        }
    }else {
        [self log:@"Sorry存储数据失败,建议检查模型类属性类型是否符合规范"];
    }
}

+ (NSArray *)commonInsertSubArrayModelObject:(NSArray *)sub_array_model_object {
    NSMutableArray * id_array = [NSMutableArray array];
    __block sqlite_int64 _id = -1;
    Class first_sub_model_class = [sub_array_model_object.firstObject class];
    if (sub_array_model_object.count > 0 &&
        [self openTable:first_sub_model_class]) {
        _id = [self getModelMaxIdWithClass:first_sub_model_class];
        [self execSql:@"BEIGIN"];
        [sub_array_model_object enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            _id++;
            [self commonInsert:obj index:idx];
            [id_array addObject:@(_id)];
        }];
        [self execSql:@"COMMIT"];
        [self close];
    }
    return id_array;
}

+ (NSArray *)inserSubModelArray:(NSArray *)model_array {
    id first_model_object = model_array.firstObject;
    NSDictionary * sub_model_object_info = [self scanSubModelObject:first_model_object];
    if (sub_model_object_info.count > 0) {
        NSMutableDictionary * sub_model_object_info = [NSMutableDictionary dictionary];
        [model_array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary * temp_sub_model_object_info = [self scanSubModelObject:obj];
            [temp_sub_model_object_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if (sub_model_object_info[key] != nil) {
                    NSMutableArray * temp_sub_array = [sub_model_object_info[key] mutableCopy];
                    [temp_sub_array addObject:obj];
                    sub_model_object_info[key] = temp_sub_array;
                }else {
                    NSMutableArray * temp_sub_array = [NSMutableArray array];
                    [temp_sub_array addObject:obj];
                    sub_model_object_info[key] = temp_sub_array;
                }
            }];
        }];
        if (sub_model_object_info.count > 0) {
            [sub_model_object_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSArray * subArray, BOOL * _Nonnull stop) {
                NSArray * sub_id_array = [self inserSubModelArray:subArray];
                [self shareInstance].sub_model_info[key] = sub_id_array;
            }];
        }
    }
    return [self commonInsertSubArrayModelObject:model_array];
}

+ (void)inserts:(NSArray *)model_array {
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        [[self shareInstance].sub_model_info removeAllObjects];
        if (model_array != nil && model_array.count > 0) {
            [self inserSubModelArray:model_array];
        }
    }
    dispatch_semaphore_signal([self shareInstance].dsema);
}

+ (sqlite_int64)commonInsertSubModelObject:(id)sub_model_object {
    sqlite_int64 _id = -1;
    if ([self openTable:[sub_model_object class]]) {
        [self execSql:@"BEIGIN"];
        [self commonInsert:sub_model_object index:-1];
        [self execSql:@"COMMIT"];
        _id = [self getModelMaxIdWithClass:[sub_model_object class]];
        [self close];
    }
    return _id;
}

+ (sqlite_int64)insertModelObject:(id)model_object {
    NSDictionary * sub_model_objects_info = [self scanSubModelObject:model_object];
    if (sub_model_objects_info.count > 0) {
        [sub_model_objects_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            sqlite_int64 _id = [self insertModelObject:obj];
            [[self shareInstance].sub_model_info setObject:@(_id) forKey:key];
        }];
    }
    return [self commonInsertSubModelObject:model_object];
}

+ (void)insert:(id)model_object {
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        [[self shareInstance].sub_model_info removeAllObjects];
        [self insertModelObject:model_object];
    }
    dispatch_semaphore_signal([self shareInstance].dsema);
}

+ (NSArray *)commonQuery:(Class)model_class conditions:(NSArray *)conditions subModelName:(NSString *)sub_model_name queryType:(WHC_QueryType)query_type {
    if (![self openTable:model_class]) return @[];
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:model_class];
    NSString * table_name = NSStringFromClass(model_class);
    NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@",table_name];
    NSString * where = nil;
    NSString * order = nil;
    NSString * limit = nil;
    if (conditions != nil && conditions.count > 0) {
        switch (query_type) {
            case _Where: {
                where = conditions.firstObject;
                if (where.length > 0) {
                    select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
                }
            }
                break;
            case _Order: {
                order = conditions.firstObject;
                if (order.length > 0) {
                    select_sql = [select_sql stringByAppendingFormat:@" ORDER %@",order];
                }
            }
                break;
            case _Limit:
                limit = conditions.firstObject;
                if (limit.length > 0) {
                    select_sql = [select_sql stringByAppendingFormat:@" LIMIT %@",limit];
                }
                break;
            case _WhereOrder: {
                if (conditions.count > 0) {
                    where = conditions.firstObject;
                    if (where.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
                    }
                }
                if (conditions.count > 1) {
                    order = conditions.lastObject;
                    if (order.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" ORDER %@",order];
                    }
                }
            }
                break;
            case _WhereLimit: {
                if (conditions.count > 0) {
                    where = conditions.firstObject;
                    if (where.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
                    }
                }
                if (conditions.count > 1) {
                    limit = conditions.lastObject;
                    if (limit.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" LIMIT %@",limit];
                    }
                }
            }
                break;
            case _OrderLimit: {
                if (conditions.count > 0) {
                    order = conditions.firstObject;
                    if (order.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" ORDER %@",order];
                    }
                }
                if (conditions.count > 1) {
                    limit = conditions.lastObject;
                    if (limit.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" LIMIT %@",limit];
                    }
                }
            }
                break;
            case _WhereOrderLimit: {
                if (conditions.count > 0) {
                    where = conditions.firstObject;
                    if (where.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
                    }
                }
                if (conditions.count > 1) {
                    order = conditions[1];
                    if (order.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" ORDER %@",order];
                    }
                }
                if (conditions.count > 2) {
                    limit = conditions.lastObject;
                    if (limit.length > 0) {
                        select_sql = [select_sql stringByAppendingFormat:@" LIMIT %@",limit];
                    }
                }
            }
                break;
            default:
                break;
        }
    }
    NSMutableArray * model_object_array = [NSMutableArray array];
    sqlite3_stmt * pp_stmt = nil;
    if (sqlite3_prepare_v2(_whc_database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
        int colum_count = sqlite3_column_count(pp_stmt);
        while (sqlite3_step(pp_stmt) == SQLITE_ROW) {
            id model_object = [model_class new];
            for (int column = 1; column < colum_count; column++) {
                NSString * field_name = [NSString stringWithCString:sqlite3_column_name(pp_stmt, column) encoding:NSUTF8StringEncoding];
                WHC_PropertyInfo * property_info = field_dictionary[field_name];
                if (property_info == nil) continue;
                switch (property_info.type) {
                    case _Dictionary:
                    case _Array: {
                        int length = sqlite3_column_bytes(pp_stmt, column);
                        const void * blob = sqlite3_column_blob(pp_stmt, column);
                        if (blob != NULL) {
                            NSData * value = [NSData dataWithBytes:blob length:length];
                            @try {
                                id set_value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
                                if (set_value) {
                                    [model_object setValue:set_value forKey:field_name];
                                }
                            } @catch (NSException *exception) {
                                [self log:@"query 查询异常 Array/Dictionary 元素没实现NSCoding协议解归档失败"];
                            }
                        }
                    }
                        break;
                    case _Date: {
                        double value = sqlite3_column_double(pp_stmt, column);
                        if (value > 0) {
                            NSDate * date_value = [NSDate dateWithTimeIntervalSince1970:value];
                            if (date_value) {
                                [model_object setValue:date_value forKey:field_name];
                            }
                        }
                    }
                        break;
                    case _Data: {
                        int length = sqlite3_column_bytes(pp_stmt, column);
                        const void * blob = sqlite3_column_blob(pp_stmt, column);
                        if (blob != NULL) {
                            NSData * value = [NSData dataWithBytes:blob length:length];
                            [model_object setValue:value forKey:field_name];
                        }
                    }
                        break;
                    case _String: {
                        const unsigned char * text = sqlite3_column_text(pp_stmt, column);
                        if (text != NULL) {
                            NSString * value = [NSString stringWithCString:(const char *)text encoding:NSUTF8StringEncoding];
                            [model_object setValue:value forKey:field_name];
                        }
                    }
                        break;
                    case _Number: {
                        double value = sqlite3_column_double(pp_stmt, column);
                        [model_object setValue:@(value) forKey:field_name];
                    }
                        break;
                    case _Model: {
                        sqlite3_int64 value = sqlite3_column_int64(pp_stmt, column);
                        [model_object setValue:@(value) forKey:field_name];
                    }
                        break;
                    case _Int: {
                        sqlite3_int64 value = sqlite3_column_int64(pp_stmt, column);
                        if (sub_model_name != nil && sub_model_name.length > 0) {
                            if ([sub_model_name rangeOfString:field_name].location == NSNotFound) {
                                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                            }else {
                                [model_object setValue:@(value) forKey:field_name];
                            }
                        }else {
                            ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                        }
                    }
                        break;
                    case _Float: {
                        double value = sqlite3_column_double(pp_stmt, column);
                        ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                    }
                        break;
                    case _Double: {
                        double value = sqlite3_column_double(pp_stmt, column);
                        ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                    }
                        break;
                    case _Char: {
                        int value = sqlite3_column_int(pp_stmt, column);
                        ((void (*)(id, SEL, int))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                    }
                        break;
                    case _Boolean: {
                        int value = sqlite3_column_int(pp_stmt, column);
                        ((void (*)(id, SEL, int))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
                    }
                        break;
                    default:
                        break;
                }
            }
            [model_object_array addObject:model_object];
        }
    }else {
        [self log:@"Sorry查询语句异常,建议检查查询条件Sql语句语法是否正确"];
    }
    sqlite3_finalize(pp_stmt);
    [self close];
    return model_object_array;
}

+ (NSDictionary *)modifyAssistQuery:(Class)model_class where:(NSString *)where {
    if ([self openTable:model_class]) {
        NSString * table_name = NSStringFromClass(model_class);
        NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@",table_name];
        if (where != nil && where.length > 0) {
            select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
        }
        NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
        NSMutableString * sub_model_name = [NSMutableString new];
        [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [sub_model_name appendString:key];
            [sub_model_name appendString:@" "];
        }];
        if (sub_model_name.length > 0) {
            [sub_model_name deleteCharactersInRange:NSMakeRange(sub_model_name.length - 1, 1)];
            NSMutableArray * model_object_array = [NSMutableArray array];
            sqlite3_stmt * pp_stmt = nil;
            if (sqlite3_prepare_v2(_whc_database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
                while (sqlite3_step(pp_stmt) == SQLITE_ROW) {
                    int colum_count = sqlite3_column_count(pp_stmt);
                    NSMutableDictionary * sub_model_id_info = [NSMutableDictionary dictionary];
                    for (int column = 1; column < colum_count; column++) {
                        NSString * field_name = [NSString stringWithCString:sqlite3_column_name(pp_stmt, column) encoding:NSUTF8StringEncoding];
                        if ([sub_model_name rangeOfString:field_name].location != NSNotFound) {
                            sqlite3_int64 sub_id = sqlite3_column_int64(pp_stmt, column);
                            [sub_model_id_info setObject:@(sub_id) forKey:field_name];
                        }
                    }
                    [model_object_array addObject:sub_model_id_info];
                }
            }else {
                [self log:@"Sorry查询语句异常,建议先检查Where条件sql语句语法是否正确"];
            }
            sqlite3_finalize(pp_stmt);
            [self close];
            return @{sub_model_name: model_object_array};
        }
    }
    return @{};
}

+ (id)querySubModel:(Class)model_class conditions:(NSArray *)conditions queryType:(WHC_QueryType)query_type {
    NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
    NSMutableString * sub_model_name = [NSMutableString new];
    [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [sub_model_name appendString:key];
        [sub_model_name appendString:@" "];
    }];
    if (sub_model_name.length > 0) {
        [sub_model_name deleteCharactersInRange:NSMakeRange(sub_model_name.length - 1, 1)];
    }
    NSArray * model_array = [self commonQuery:model_class conditions:conditions subModelName:sub_model_name queryType:query_type];
    NSObject * model = nil;
    if (model_array.count > 0) {
        model = model_array.lastObject;
    }
    if (model != nil) {
        [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * obj, BOOL * _Nonnull stop) {
            Class sub_model_class = NSClassFromString(obj);
            id sub_model = [self querySubModel:sub_model_class conditions:@[[NSString stringWithFormat:@"%@ = %d",[self getMainKeyWithClass:sub_model_class],[[model valueForKey:name] intValue]]] queryType:_Where];
            [model setValue:sub_model forKey:name];
        }];
    }
    return model;
}

+ (NSArray *)queryModel:(Class)model_class conditions:(NSArray *)conditions queryType:(WHC_QueryType)query_type {
    if (![self localNameWithModel:model_class]) {return @[];}
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    [[self shareInstance].sub_model_info removeAllObjects];
    NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
    NSMutableString * sub_model_name = [NSMutableString new];
    [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [sub_model_name appendString:key];
        [sub_model_name appendString:@" "];
    }];
    if (sub_model_name.length > 0) {
        [sub_model_name deleteCharactersInRange:NSMakeRange(sub_model_name.length - 1, 1)];
    }
    NSArray * model_array = [self commonQuery:model_class conditions:conditions subModelName:sub_model_name queryType:query_type];
    [model_array enumerateObjectsUsingBlock:^(NSObject * model, NSUInteger idx, BOOL * _Nonnull stop) {
        [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * obj, BOOL * _Nonnull stop) {
            Class sub_model_class = NSClassFromString(obj);
            id sub_model = [self querySubModel:sub_model_class conditions:@[[NSString stringWithFormat:@"%@ = %d",[self getMainKeyWithClass:sub_model_class],[[model valueForKey:name] intValue]]] queryType:_Where];
            [model setValue:sub_model forKey:name];
        }];
    }];
    dispatch_semaphore_signal([self shareInstance].dsema);
    return model_array;
}

+ (NSArray *)query:(Class)model_class {
    return [self query:model_class where:nil];
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where {
    return [self queryModel:model_class conditions:@[where == nil ? @"" : where] queryType:_Where];
}

+ (NSArray *)query:(Class)model_class order:(NSString *)order {
    return [self queryModel:model_class conditions:@[order == nil ? @"" : order] queryType:_Order];
}


+ (NSArray *)query:(Class)model_class limit:(NSString *)limit {
    return [self queryModel:model_class conditions:@[limit == nil ? @"" : limit] queryType:_Limit];
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order {
    return [self queryModel:model_class conditions:@[where == nil ? @"" : where,
                                                     order == nil ? @"" : order] queryType:_WhereOrder];
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where limit:(NSString *)limit {
    return [self queryModel:model_class conditions:@[where == nil ? @"" : where,
                                                     limit == nil ? @"" : limit] queryType:_WhereLimit];
}

+ (NSArray *)query:(Class)model_class order:(NSString *)order limit:(NSString *)limit {
    return [self queryModel:model_class conditions:@[order == nil ? @"" : order,
                                                     limit == nil ? @"" : limit] queryType:_OrderLimit];
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order limit:(NSString *)limit {
    return [self queryModel:model_class conditions:@[where == nil ? @"" : where,
                                                     order == nil ? @"" : order,
                                                     limit == nil ? @"" : limit] queryType:_WhereOrderLimit];
}

+ (void)updateSubModel:(id)sub_model_object where:(NSString *)where subModelName:(NSString *)sub_model_name {
    if (sub_model_object == nil) return;
    Class sum_model_class = [sub_model_object class];
    if (![self openTable:sum_model_class]) return;
    sqlite3_stmt * pp_stmt = nil;
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:sum_model_class];
    NSString * table_name = NSStringFromClass(sum_model_class);
    __block NSString * update_sql = [NSString stringWithFormat:@"UPDATE %@ SET ",table_name];
    
    NSArray * field_array = field_dictionary.allKeys;
    NSMutableArray * update_field_array = [NSMutableArray array];
    [field_array enumerateObjectsUsingBlock:^(id  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        if (property_info.type != _Model) {
            update_sql = [update_sql stringByAppendingFormat:@"%@ = ?,",field];
            [update_field_array addObject:field];
        }
    }];
    update_sql = [update_sql substringWithRange:NSMakeRange(0, update_sql.length - 1)];
    if (where != nil && where.length > 0) {
        update_sql = [update_sql stringByAppendingFormat:@" WHERE %@", where];
    }
    if (sqlite3_prepare_v2(_whc_database, [update_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
        [field_array enumerateObjectsUsingBlock:^(id  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
            WHC_PropertyInfo * property_info = field_dictionary[field];
            int index = (int)[update_field_array indexOfObject:field] + 1;
            switch (property_info.type) {
                case _Dictionary:
                case _Array: {
                    id value = [sub_model_object valueForKey:field];
                    if (value == nil) {
                        value = property_info.type == _Dictionary ? [NSDictionary dictionary] : [NSArray array];
                    }
                    @try {
                        NSData * set_value = [NSKeyedArchiver archivedDataWithRootObject:value];
                        sqlite3_bind_blob(pp_stmt, index, [set_value bytes], (int)[set_value length], SQLITE_TRANSIENT);
                    } @catch (NSException *exception) {
                        [self log:@"update 操作异常 Array/Dictionary 元素没实现NSCoding协议归档失败"];
                    }
                }
                    break;
                case _Date: {
                    NSDate * value = [sub_model_object valueForKey:field];
                    if (value == nil) {
                        sqlite3_bind_double(pp_stmt, index, 0.0);
                    }else {
                        sqlite3_bind_double(pp_stmt, index, [value timeIntervalSince1970]);
                    }
                }
                    break;
                case _Data: {
                    NSData * value = [sub_model_object valueForKey:field];
                    if (value == nil) {
                        value = [NSData data];
                    }
                    sqlite3_bind_blob(pp_stmt, index, [value bytes], (int)[value length], SQLITE_TRANSIENT);
                }
                    break;
                case _String: {
                    NSString * value = [sub_model_object valueForKey:field];
                    if (value == nil) {
                        value = @"";
                    }
                    if ([value respondsToSelector:@selector(UTF8String)]) {
                        sqlite3_bind_text(pp_stmt, index, [value UTF8String], -1, SQLITE_TRANSIENT);
                    }else {
                        sqlite3_bind_text(pp_stmt, index, [[NSString stringWithFormat:@"%@",value] UTF8String], -1, SQLITE_TRANSIENT);
                    }
                }
                    break;
                case _Number: {
                    NSNumber * value = [sub_model_object valueForKey:field];
                    if (value == nil) {
                        value = @(0.0);
                    }
                    if (property_info.type != _Model) {
                        sqlite3_bind_double(pp_stmt, index, [value doubleValue]);
                    }
                }
                    break;
                case _Int: {
                    if (sub_model_name &&
                        [sub_model_name rangeOfString:field].location != NSNotFound){} else {
                        /* 32bit os type issue
                         long value = ((long (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);*/
                        NSNumber * value = [sub_model_object valueForKey:field];
                        sqlite3_bind_int64(pp_stmt, index, (sqlite3_int64)[value longLongValue]);
                    }
                }
                    break;
                case _Char: {
                    char value = ((char (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                    sqlite3_bind_int(pp_stmt, index, value);
                }
                    break;
                case _Float: {
                    float value = ((float (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                    sqlite3_bind_double(pp_stmt, index, value);
                }
                    break;
                case _Double: {
                    double value = ((double (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                    sqlite3_bind_double(pp_stmt, index, value);
                }
                    break;
                case _Boolean: {
                    BOOL value = ((BOOL (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                    sqlite3_bind_int(pp_stmt, index, value);
                }
                    break;
                default:
                    break;
            }
        }];
        sqlite3_step(pp_stmt);
        sqlite3_finalize(pp_stmt);
    }else {
        [self log:@"更新失败"];
    }
    [self close];
}

+ (void)updateModel:(id)model_object where:(NSString *)where {
    [self updateSubModel:model_object where:where subModelName:nil];
    NSDictionary * queryDictionary = [self modifyAssistQuery:[model_object class] where:where];
    if (queryDictionary.count > 0) {
        NSArray * model_object_array = queryDictionary.allValues.lastObject;
        [model_object_array enumerateObjectsUsingBlock:^(NSDictionary * sub_model_id_info, NSUInteger idx, BOOL * _Nonnull stop) {
            [sub_model_id_info.allKeys enumerateObjectsUsingBlock:^(NSString * field_name, NSUInteger idx, BOOL * _Nonnull stop) {
                id sub_model = [model_object valueForKey:field_name];
                if (sub_model) {
                    [self updateModel:sub_model where:[NSString stringWithFormat:@"%@ = %@",[self getMainKeyWithClass:[sub_model class]],sub_model_id_info[field_name]]];
                }
            }];
        }];
    }
}

+ (void)update:(id)model_object where:(NSString *)where {
    if ([self localNameWithModel:[model_object class]]) {
        dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
        @autoreleasepool {
            [[self shareInstance].sub_model_info removeAllObjects];
            [self updateModel:model_object where:where];
        }
        dispatch_semaphore_signal([self shareInstance].dsema);
    }
}

+ (void)clear:(Class)model_class {
    [self delete:model_class where:nil];
}

+ (BOOL)commonDeleteModel:(Class)model_class where:(NSString *)where {
    BOOL result = NO;
    if ([self localNameWithModel:model_class]) {
        if ([self openTable:model_class]) {
            NSString * table_name = NSStringFromClass(model_class);
            NSString * delete_sql = [NSString stringWithFormat:@"DELETE FROM %@",table_name];
            if (where != nil && where.length > 0) {
                delete_sql = [delete_sql stringByAppendingFormat:@" WHERE %@",where];
            }
            result = [self execSql:delete_sql];
            [self close];
        }
    }
    return result;
}

+ (void)deleteModel:(Class)model_class where:(NSString *)where {
    if (where != nil && where.length > 0) {
        NSDictionary * queryDictionary = [self modifyAssistQuery:model_class where:where];
        NSDictionary * subModelInfo = [self scanSubModelClass:model_class];
        if (queryDictionary.count > 0) {
            NSArray * model_object_array = queryDictionary.allValues.lastObject;
            if ([self commonDeleteModel:model_class where:where]) {
                [model_object_array enumerateObjectsUsingBlock:^(NSDictionary * sub_model_id_info, NSUInteger idx, BOOL * _Nonnull stop) {
                    [sub_model_id_info.allKeys enumerateObjectsUsingBlock:^(NSString * field_name, NSUInteger idx, BOOL * _Nonnull stop) {
                        Class sub_model_class = NSClassFromString(subModelInfo[field_name]);
                        [self deleteModel:sub_model_class where:[NSString stringWithFormat:@"%@ = %@",[self getMainKeyWithClass:sub_model_class],sub_model_id_info[field_name]]];
                    }];
                }];
            }
        }else {
            goto DELETE;
        }
    }else {
    DELETE:
        if ([self commonDeleteModel:model_class where:where]) {
            NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
            [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [self deleteModel:NSClassFromString(obj) where:where];
            }];
        }
    }
}

+ (void)delete:(Class)model_class where:(NSString *)where {
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        [[self shareInstance].sub_model_info removeAllObjects];
        [self deleteModel:model_class where:where];
    }
    dispatch_semaphore_signal([self shareInstance].dsema);
}

+ (void)close {
    if (_whc_database) {
        sqlite3_close(_whc_database);
        _whc_database = nil;
    }
}

+ (void)removeAllModel {
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        NSFileManager * file_manager = [NSFileManager defaultManager];
        NSString * cache_path = [self databaseCacheDirectory];
        BOOL is_directory = YES;
        if ([file_manager fileExistsAtPath:cache_path isDirectory:&is_directory]) {
            NSArray * file_array = [file_manager contentsOfDirectoryAtPath:cache_path error:nil];
            [file_array enumerateObjectsUsingBlock:^(id  _Nonnull file, NSUInteger idx, BOOL * _Nonnull stop) {
                if (![file isEqualToString:@".DS_Store"]) {
                    NSString * file_path = [NSString stringWithFormat:@"%@%@",cache_path,file];
                    [file_manager removeItemAtPath:file_path error:nil];
                    [self log:[NSString stringWithFormat:@"已经删除了数据库 ->%@",file_path]];
                }
            }];
        }
    }
    dispatch_semaphore_signal([self shareInstance].dsema);
}

+ (void)removeSubModel:(Class)model_class {
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
    [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        Class sub_model_calss = NSClassFromString(obj);
        [self removeSubModel:sub_model_calss];
        NSString * file_path = [self localPathWithModel:sub_model_calss];
        if (file_path) {
            [file_manager removeItemAtPath:file_path error:nil];
        }
    }];
}

+ (void)removeModel:(Class)model_class {
    dispatch_semaphore_wait([self shareInstance].dsema, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        NSFileManager * file_manager = [NSFileManager defaultManager];
        NSString * file_path = [self localPathWithModel:model_class];
        if (file_path) {
            [self removeSubModel:model_class];
            [file_manager removeItemAtPath:file_path error:nil];
        }
    }
    dispatch_semaphore_signal([self shareInstance].dsema);
}

+ (NSString *)commonLocalPathWithModel:(Class)model_class isPath:(BOOL)isPath {
    NSString * class_name = NSStringFromClass(model_class);
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSString * file_directory = [self databaseCacheDirectory];
    BOOL isDirectory = YES;
    __block NSString * file_path = nil;
    if ([file_manager fileExistsAtPath:file_directory isDirectory:&isDirectory]) {
        NSArray <NSString *> * file_name_array = [file_manager contentsOfDirectoryAtPath:file_directory error:nil];
        if (file_name_array != nil && file_name_array.count > 0) {
            [file_name_array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj rangeOfString:class_name].location != NSNotFound) {
                    if (isPath) {
                        file_path = [NSString stringWithFormat:@"%@%@",file_directory,obj];
                    }else {
                        file_path = [obj mutableCopy];
                    }
                    *stop = YES;
                }
            }];
        }
    }
    return file_path;
}

+ (NSString *)localNameWithModel:(Class)model_class {
    return [self commonLocalPathWithModel:model_class isPath:NO];
}

+ (NSString *)localPathWithModel:(Class)model_class {
    return [self commonLocalPathWithModel:model_class isPath:YES];
}

+ (NSString *)versionWithModel:(Class)model_class {
    NSString * model_version = nil;
    NSString * model_name = [self localNameWithModel:model_class];
    if (model_name) {
        NSRange end_range = [model_name rangeOfString:@"." options:NSBackwardsSearch];
        NSRange start_range = [model_name rangeOfString:@"v" options:NSBackwardsSearch];
        if (end_range.location != NSNotFound &&
            start_range.location != NSNotFound) {
            model_version = [model_name substringWithRange:NSMakeRange(start_range.length + start_range.location, end_range.location - (start_range.length + start_range.location))];
        }
    }
    return model_version;
}

+ (void)log:(NSString *)msg {
    NSLog(@"WHC_ModelSqlite:[%@]",msg);
}

@end
