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

// VERSION:(2.0)

#import "WHC_ModelSqlite.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <sqlite3.h>


#define  WHC_String    (@"TEXT")
#define  WHC_Int       (@"INTERGER")
#define  WHC_Boolean   (@"INTERGER")
#define  WHC_Double    (@"DOUBLE")
#define  WHC_Float     (@"DOUBLE")
#define  WHC_Char      (@"NVARCHAR")

typedef NS_OPTIONS(NSInteger, WHC_FieldType) {
    _String     =      1 << 0,
    _Int        =      1 << 1,
    _Boolean    =      1 << 2,
    _Double     =      1 << 3,
    _Float      =      1 << 4,
    _Char       =      1 << 5
};

static sqlite3 * _whc_database;

static NSInteger _NO_HANDLE_KEY_ID = -2;

@interface WHC_PropertyInfo : NSObject

@property (nonatomic, assign, readonly)WHC_FieldType type;
@property (nonatomic, copy, readonly) NSString * name;
@property (nonatomic, assign, readonly)SEL setter;
@property (nonatomic, assign, readonly)SEL getter;

@end

@implementation WHC_PropertyInfo

- (WHC_PropertyInfo *)initWithType:(WHC_FieldType)type propertyName:(NSString *)property_name {
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
@end

@implementation WHC_ModelSqlite

- (WHC_ModelSqlite *)init {
    self = [super init];
    if (self) {
        self.sub_model_info = [NSMutableDictionary dictionary];
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

+ (NSString *)databaseFieldTypeWithType:(WHC_FieldType)type {
    switch (type) {
        case _String:
            return WHC_String;
        case _Int:
            return WHC_Int;
        case _Double:
            return WHC_Double;
        case _Float:
            return WHC_Float;
        case _Char:
            return WHC_Char;
        case _Boolean:
            return WHC_Boolean;
        default:
            break;
    }
    return WHC_String;
}

+ (NSDictionary *)parserModelObjectFieldsWithModelClass:(Class)modelClass {
    NSMutableDictionary * fields = [NSMutableDictionary dictionary];
    unsigned int property_count = 0;
    objc_property_t * propertys = class_copyPropertyList(modelClass, &property_count);
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
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Int propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSString class]) {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_String propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }else if (class_type == [NSArray class] ||
                      class_type == [NSDictionary class] ||
                      class_type == [NSData class] ||
                      class_type == [NSDate class] ||
                      class_type == [NSSet class] ){
                NSLog(@"异常数据类型");
            }else {
                WHC_PropertyInfo * property_info = [[WHC_PropertyInfo alloc] initWithType:_Int propertyName:property_name_string];
                [fields setObject:property_info forKey:property_name_string];
            }
        }
    }
    free(propertys);
    return fields;
}

+ (NSDictionary *)scanCommonSubModel:(id)model isClass:(BOOL)isClass {
    Class model_class = isClass ? model : [model class];
    NSMutableDictionary * sub_model_info = [NSMutableDictionary dictionary];
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
                class_type != [NSDictionary class]) {
                if (isClass) {
                    [sub_model_info setObject:property_name_string forKey:property_attributes_list[1]];
                }else {
                    [sub_model_info setObject:[model valueForKey:property_name_string] forKey:property_name_string];
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
        NSString * select_sql = [NSString stringWithFormat:@"SELECT MAX(_id) AS MAXVALUE FROM %@",NSStringFromClass(model_class)];
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
        NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE _id = %lld",NSStringFromClass(model_class),[self getModelMaxIdWithClass:model_class]];
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
                    [sub_model_name appendString:obj];
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
                                    NSString * value = [NSString stringWithCString:(const char *)sqlite3_column_text(pp_stmt, column) encoding:NSUTF8StringEncoding];
                                    [new_model_object setValue:value forKey:old_field_name];
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

+ (BOOL)openTable:(Class)model_class {
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSString * cache_directory = [self databaseCacheDirectory];
    BOOL is_directory = YES;
    if (![file_manager fileExistsAtPath:cache_directory isDirectory:&is_directory]) {
        [file_manager createDirectoryAtPath:cache_directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    SEL VERSION = NSSelectorFromString(@"VERSION");
    NSString * version = @"1.0";
    if ([model_class respondsToSelector:VERSION]) {
        IMP version_func = [model_class methodForSelector:VERSION];
        NSString * (*func)(id, SEL) = (void *)version_func;
        version = func(model_class, VERSION);
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
        return [self createTable:model_class];
    }
    return NO;
}

+ (BOOL)createTable:(Class)modelClass {
    NSString * table_name = NSStringFromClass(modelClass);
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:modelClass];
    if (field_dictionary.count > 0) {
        NSString * create_table_sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,",table_name];
        NSArray * field_array = field_dictionary.allKeys;
        for (NSString * field in field_array) {
            WHC_PropertyInfo * property_info = field_dictionary[field];
            create_table_sql = [create_table_sql stringByAppendingFormat:@"%@ %@ DEFAULT ",field, [self databaseFieldTypeWithType:property_info.type]];
            switch (property_info.type) {
                case _String:
                case _Char:
                    create_table_sql = [create_table_sql stringByAppendingString:@"NULL,"];
                    break;
                case _Boolean:
                case _Int:
                    create_table_sql = [create_table_sql stringByAppendingString:@"0,"];
                    break;
                case _Float:
                case _Double:
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
    for (NSString * field in field_array) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        insert_sql = [insert_sql stringByAppendingFormat:@"%@,",field];
        id value = [model_object valueForKey:field];
        if ((value && [self shareInstance].sub_model_info[property_info.name] == nil) || index == _NO_HANDLE_KEY_ID) {
            [value_array addObject:value];
        }else {
            switch (property_info.type) {
                case _String:
                    [value_array addObject:@""];
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
    }
    insert_sql = [insert_sql substringWithRange:NSMakeRange(0, insert_sql.length - 1)];
    insert_sql = [insert_sql stringByAppendingString:@") VALUES ("];
    [field_array enumerateObjectsUsingBlock:^(id  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        id value = value_array[idx];
        switch (property_info.type) {
            case _String:
                insert_sql = [insert_sql stringByAppendingFormat:@"'%@',",value];
                break;
            case _Int:
                insert_sql = [insert_sql stringByAppendingFormat:@"%ld,",(long)[value integerValue]];
                break;
            case _Boolean:
                insert_sql = [insert_sql stringByAppendingFormat:@"%d,",[value boolValue]];
                break;
            case _Char:
                insert_sql = [insert_sql stringByAppendingFormat:@"%d,",[value intValue]];
                break;
            case _Float:
                insert_sql = [insert_sql stringByAppendingFormat:@"%f,",[value floatValue]];
                break;
            case _Double:
                insert_sql = [insert_sql stringByAppendingFormat:@"%f,",[value doubleValue]];
                break;
            default:
                break;
        }
    }];
    insert_sql = [insert_sql substringWithRange:NSMakeRange(0, insert_sql.length - 1)];
    insert_sql = [insert_sql stringByAppendingString:@")"];
    int error = sqlite3_prepare_v2(_whc_database, [insert_sql UTF8String], -1, &pp_stmt, nil);
    if (error == SQLITE_OK) {
        if (sqlite3_step(pp_stmt) != SQLITE_DONE) {
            sqlite3_finalize(pp_stmt);
        }
    }else {
        NSLog(@"存储数据失败");
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

+ (void)insertArray:(NSArray *)model_array {
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            [[self shareInstance].sub_model_info removeAllObjects];
            if (!(model_array != nil && model_array.count > 0)) {
                return;
            }
            [self inserSubModelArray:model_array];
        }
    }
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
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            [[self shareInstance].sub_model_info removeAllObjects];
            [self insertModelObject:model_object];
        }
    }
}

+ (NSArray *)commonQuery:(Class)model_class where:(NSString *)where subModelName:(NSString *)sub_model_name {
    if (![self openTable:model_class]) return @[];
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:model_class];
    NSString * table_name = NSStringFromClass(model_class);
    NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@",table_name];
    if (where != nil && where.length > 0) {
        select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
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
                    case _String: {
                        NSString * value = [NSString stringWithCString:(const char *)sqlite3_column_text(pp_stmt, column) encoding:NSUTF8StringEncoding];
                        [model_object setValue:value forKey:field_name];
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
        NSLog(@"查询语句异常");
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
            [sub_model_name appendString:obj];
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
                NSLog(@"查询语句异常");
            }
            sqlite3_finalize(pp_stmt);
            [self close];
            return @{sub_model_name: model_object_array};
        }
    }
    return @{};
}

+ (id)querySubModel:(Class)model_class where:(NSString *)where {
    NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
    NSMutableString * sub_model_name = [NSMutableString new];
    [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [sub_model_name appendString:obj];
        [sub_model_name appendString:@" "];
    }];
    if (sub_model_name.length > 0) {
        [sub_model_name deleteCharactersInRange:NSMakeRange(sub_model_name.length - 1, 1)];
    }
    NSArray * model_array = [self commonQuery:model_class where:where subModelName:sub_model_name];
    NSObject * model = nil;
    if (model_array.count > 0) {
        model = model_array.lastObject;
    }
    if (model != nil) {
        NSArray * sub_model_name_array = sub_model_class_info.allValues;
        NSArray * sub_model_class_array = sub_model_class_info.allKeys;
        [sub_model_name_array enumerateObjectsUsingBlock:^(NSString * name, NSUInteger idx, BOOL * _Nonnull stop) {
            Class sub_model_class = NSClassFromString(sub_model_class_array[[sub_model_name_array indexOfObject:name]]);
            id sub_model = [self querySubModel:sub_model_class where:[NSString stringWithFormat:@"_id = %ld",[[model valueForKey:name] integerValue]]];
            [model setValue:sub_model forKey:name];
        }];
    }
    return model;
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where {
    @synchronized ([self shareInstance]) {
        [[self shareInstance].sub_model_info removeAllObjects];
        NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
        NSMutableString * sub_model_name = [NSMutableString new];
        [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [sub_model_name appendString:obj];
            [sub_model_name appendString:@" "];
        }];
        if (sub_model_name.length > 0) {
            [sub_model_name deleteCharactersInRange:NSMakeRange(sub_model_name.length - 1, 1)];
        }
        NSArray * model_array = [self commonQuery:model_class where:where subModelName:sub_model_name];
        NSArray * sub_model_name_array = sub_model_class_info.allValues;
        NSArray * sub_model_class_array = sub_model_class_info.allKeys;
        if (sub_model_name_array.count > 0) {
            [model_array enumerateObjectsUsingBlock:^(NSObject * model, NSUInteger idx, BOOL * _Nonnull stop) {
                [sub_model_name_array enumerateObjectsUsingBlock:^(NSString * name, NSUInteger idx, BOOL * _Nonnull stop) {
                    Class sub_model_class = NSClassFromString(sub_model_class_array[[sub_model_name_array indexOfObject:name]]);
                    id sub_model = [self querySubModel:sub_model_class where:[NSString stringWithFormat:@"_id = %ld",[[model valueForKey:name] integerValue]]];
                    [model setValue:sub_model forKey:name];
                }];
            }];
        }
        return model_array;
    }
}

+ (void)updateSubModel:(id)sub_model_object where:(NSString *)where subModelName:(NSString *)sub_model_name {
    if (sub_model_object == nil) return;
    Class sum_model_class = [sub_model_object class];
    if (![self openTable:sum_model_class]) return;
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:sum_model_class];
    NSString * table_name = NSStringFromClass(sum_model_class);
    __block NSString * update_sql = [NSString stringWithFormat:@"UPDATE %@ SET ",table_name];
    
    NSArray * field_array = field_dictionary.allKeys;
    [field_array enumerateObjectsUsingBlock:^(id  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        switch (property_info.type) {
            case _String: {
                NSString * value = [sub_model_object valueForKey:field];
                if (value == nil) {
                    value = @"";
                }
                update_sql = [update_sql stringByAppendingFormat:@"%@ = '%@',",field,value];
            }
                break;
            case _Int: {
                if (sub_model_name &&
                    [sub_model_name rangeOfString:field].location == NSNotFound) {
                    int64_t value = ((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                    update_sql = [update_sql stringByAppendingFormat:@"%@ = %lld,",field,value];
                }
            }
                break;
            case _Char: {
                char value = ((char (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = '%d',",field,value];
            }
                break;
            case _Float: {
                float value = ((float (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %f,",field,value];
            }
                break;
            case _Double: {
                double value = ((double (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %f,",field,value];
            }
                break;
            case _Boolean: {
                BOOL value = ((BOOL (*)(id, SEL))(void *) objc_msgSend)((id)sub_model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %d,",field,value];
            }
                break;
            default:
                break;
        }
    }];
    
    update_sql = [update_sql substringWithRange:NSMakeRange(0, update_sql.length - 1)];
    if (where != nil && where.length > 0) {
        update_sql = [update_sql stringByAppendingFormat:@" WHERE %@", where];
    }
    [self execSql:update_sql];
    [self close];
}

+ (void)updateModel:(id)model_object where:(NSString *)where {
    [self updateSubModel:model_object where:where subModelName:nil];
    NSDictionary * queryDictionary = [self modifyAssistQuery:[model_object class] where:where];
    if (queryDictionary.count > 0) {
        NSArray * model_object_array = queryDictionary.allValues.lastObject;
        [model_object_array enumerateObjectsUsingBlock:^(NSDictionary * sub_model_id_info, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString * field_name = sub_model_id_info.allKeys.lastObject;
            [self updateModel:[model_object valueForKey:field_name] where:[NSString stringWithFormat:@"_id = %@",sub_model_id_info[field_name]]];
        }];
    }
}

+ (void)update:(id)model_object where:(NSString *)where {
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            [[self shareInstance].sub_model_info removeAllObjects];
            [self updateModel:model_object where:where];
        }
    }
}

+ (void)clear:(Class)model_class {
    @synchronized ([self shareInstance]) {
        [self delete:model_class where:nil];
    }
}

+ (BOOL)commonDeleteModel:(Class)model_class where:(NSString *)where {
    BOOL result = NO;
    if ([self openTable:model_class]) {
        NSString * table_name = NSStringFromClass(model_class);
        NSString * delete_sql = [NSString stringWithFormat:@"DELETE FROM %@",table_name];
        if (where != nil && where.length > 0) {
            delete_sql = [delete_sql stringByAppendingFormat:@" WHERE %@",where];
        }
        result = [self execSql:delete_sql] == SQLITE_OK;
        [self close];
    }
    return result;
}

+ (void)deleteModel:(Class)model_class where:(NSString *)where {
    if (where != nil && where.length > 0) {
        NSDictionary * queryDictionary = [self modifyAssistQuery:model_class where:where];
        if (queryDictionary.count > 0) {
            NSArray * model_object_array = queryDictionary.allValues.lastObject;
            if ([self commonDeleteModel:model_class where:where]) {
                [model_object_array enumerateObjectsUsingBlock:^(NSDictionary * sub_model_id_info, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSString * field_name = sub_model_id_info.allKeys.lastObject;
                    [self deleteModel:[sub_model_id_info.allValues.lastObject class] where:[NSString stringWithFormat:@"_id = %@",sub_model_id_info[field_name]]];
                }];
            }
        }
    }else {
        if ([self commonDeleteModel:model_class where:where]) {
            NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
            [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [self deleteModel:NSClassFromString(key) where:where];
            }];
        }
    }
}

+ (void)delete:(Class)model_class where:(NSString *)where {
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            [[self shareInstance].sub_model_info removeAllObjects];
            [self deleteModel:model_class where:where];
        }
    }
}

+ (void)close {
    if (_whc_database) {
        sqlite3_close(_whc_database);
        _whc_database = nil;
    }
}

+ (void)removeAllModel {
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            NSFileManager * file_manager = [NSFileManager defaultManager];
            NSString * cache_path = [self databaseCacheDirectory];
            BOOL is_directory = YES;
            if ([file_manager fileExistsAtPath:cache_path isDirectory:&is_directory]) {
                NSArray * file_array = [file_manager contentsOfDirectoryAtPath:cache_path error:nil];
                [file_array enumerateObjectsUsingBlock:^(id  _Nonnull file, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (![file isEqualToString:@".DS_Store"]) {
                        NSString * file_path = [NSString stringWithFormat:@"%@,%@",cache_path,file];
                        [file_manager removeItemAtPath:file_path error:nil];
                    }
                }];
            }
        }
    }
}

+ (void)removeSubModel:(Class)model_class {
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSDictionary * sub_model_class_info = [self scanSubModelClass:model_class];
    [sub_model_class_info enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        Class sub_model_calss = NSClassFromString(key);
        [self removeSubModel:sub_model_calss];
        NSString * file_path = [self localPathWithModel:sub_model_calss];
        if (file_path) {
            [file_manager removeItemAtPath:file_path error:nil];
        }
    }];
}

+ (void)removeModel:(Class)model_class {
    @synchronized ([self shareInstance]) {
        @autoreleasepool {
            NSFileManager * file_manager = [NSFileManager defaultManager];
            NSString * file_path = [self localPathWithModel:model_class];
            if (file_path) {
                [self removeSubModel:model_class];
                [file_manager removeItemAtPath:file_path error:nil];
            }
        }
    }
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


@end
