//
//  WHC_ModelSqlite.m
//  WHC_ModelSqliteKit
//
//  Created by admin on 16/5/28.
//  Copyright © 2016年 WHC. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.

// github<>

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

static sqlite3 * database;


@interface WHC_PropertyInfo : NSObject

@property (nonatomic, assign, readonly)WHC_FieldType type;
@property (nonatomic, assign, readonly)SEL setter;
@property (nonatomic, assign, readonly)SEL getter;

@end

@implementation WHC_PropertyInfo

- (WHC_PropertyInfo *)initWithType:(WHC_FieldType)type propertyName:(NSString *)property_name {
    self = [super init];
    if (self) {
        _type = type;
        _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[property_name substringToIndex:1].uppercaseString,[property_name substringFromIndex:1]]);
        _getter = NSSelectorFromString(property_name);
    }
    return self;
}

@end

@implementation WHC_ModelSqlite

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
            // inner type
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
            }else {
                NSLog(@"异常数据类型");
            }
        }
    }
    free(propertys);
    return fields;
}

+ (BOOL)openTable:(Class)modelClass {
    NSFileManager * file_manager = [NSFileManager defaultManager];
    NSString * cache_directory = [self databaseCacheDirectory];
    BOOL is_directory = YES;
    if (![file_manager fileExistsAtPath:cache_directory isDirectory:&is_directory]) {
        [file_manager createDirectoryAtPath:cache_directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString * database_cache_path = [NSString stringWithFormat:@"%@%@.sqlite",cache_directory,NSStringFromClass(modelClass)];
    if (sqlite3_open([database_cache_path UTF8String], &database) == SQLITE_OK) {
        return [self createTable:modelClass];
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
    return sqlite3_exec(database, [sql UTF8String], nil, nil, nil) == SQLITE_OK;
}

+ (void)commonInsert:(id)model_object {
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
        if (value) {
            [value_array addObject:value];
        }else {
            switch (property_info.type) {
                case _String:
                    [value_array addObject:@""];
                    break;
                case _Int: {
                    NSNumber * value = @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter));
                    [value_array addObject:value];
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
    int error = sqlite3_prepare_v2(database, [insert_sql UTF8String], -1, &pp_stmt, nil);
    if (error == SQLITE_OK) {
        if (sqlite3_step(pp_stmt) != SQLITE_DONE) {
            sqlite3_finalize(pp_stmt);
        }
    }else {
        NSLog(@"存储数据失败");
    }
}

+ (BOOL)insertArray:(NSArray *)model_array {
    if (!(model_array != nil && model_array.count > 0)) {
        return NO;
    }
    if (![self openTable:[model_array.firstObject class]]) return NO;
    [self execSql:@"BEIGIN"];
    for (id model_object in model_array) {
        [self commonInsert:model_object];
    }
    int result = [self execSql:@"COMMIT"];
    [self close];
    return result == SQLITE_OK;
}

+ (BOOL)insert:(id)model_object {
    if (![self openTable:[model_object class]]) return NO;
    [self execSql:@"BEIGIN"];
    [self commonInsert:model_object];
    int result = [self execSql:@"COMMIT"];
    [self close];
    return result == SQLITE_OK;
}

+ (NSArray *)query:(Class)model_class where:(NSString *)where {
    if (![self openTable:model_class]) return @[];
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:model_class];
    NSString * table_name = NSStringFromClass(model_class);
    NSString * select_sql = [NSString stringWithFormat:@"SELECT * FROM %@",table_name];
    if (where != nil && where.length > 0) {
        select_sql = [select_sql stringByAppendingFormat:@" WHERE %@",where];
    }
    NSMutableArray * model_object_array = [NSMutableArray array];
    sqlite3_stmt * pp_stmt = nil;
    if (sqlite3_prepare_v2(database, [select_sql UTF8String], -1, &pp_stmt, nil) == SQLITE_OK) {
        while (sqlite3_step(pp_stmt) == SQLITE_ROW) {
            id model_object = [model_class new];
            int colum_count = sqlite3_column_count(pp_stmt);
            for (int column = 1; column < colum_count; column++) {
                NSString * field_name = [NSString stringWithCString:sqlite3_column_name(pp_stmt, column) encoding:NSUTF8StringEncoding];
                WHC_PropertyInfo * property_info = field_dictionary[field_name];
                switch (property_info.type) {
                    case _String: {
                        NSString * value = [NSString stringWithCString:(const char *)sqlite3_column_text(pp_stmt, column) encoding:NSUTF8StringEncoding];
                        [model_object setValue:value forKey:field_name];
                    }
                        break;
                    case _Int: {
                        sqlite3_int64 value = sqlite3_column_int64(pp_stmt, column);
                        ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model_object, property_info.setter, value);
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

+ (BOOL)update:(id)model_object where:(NSString *)where {
    if (model_object == nil) return NO;
    if (![self openTable:[model_object class]]) return NO;
    NSDictionary * field_dictionary = [self parserModelObjectFieldsWithModelClass:[model_object class]];
    NSString * table_name = NSStringFromClass([model_object class]);
    __block NSString * update_sql = [NSString stringWithFormat:@"UPDATE %@ SET ",table_name];
    
    NSArray * field_array = field_dictionary.allKeys;
    [field_array enumerateObjectsUsingBlock:^(id  _Nonnull field, NSUInteger idx, BOOL * _Nonnull stop) {
        WHC_PropertyInfo * property_info = field_dictionary[field];
        switch (property_info.type) {
            case _String: {
                NSString * value = [model_object valueForKey:field];
                if (value == nil) {
                    value = @"";
                }
                update_sql = [update_sql stringByAppendingFormat:@"%@ = '%@',",field,value];
            }
                break;
            case _Int: {
                int64_t value = ((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %lld,",field,value];
            }
                break;
            case _Char: {
                char value = ((char (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %c,",field,value];
            }
                break;
            case _Float: {
                float value = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %f,",field,value];
            }
                break;
            case _Double: {
                double value = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter);
                update_sql = [update_sql stringByAppendingFormat:@"%@ = %f,",field,value];
            }
                break;
            case _Boolean: {
                BOOL value = ((BOOL (*)(id, SEL))(void *) objc_msgSend)((id)model_object, property_info.getter);
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
    int result = [self execSql:update_sql];
    [self close];
    return result == SQLITE_OK;
}

+ (BOOL)clear:(Class)model_class {
    return [self delete:model_class where:nil];
}

+ (BOOL)delete:(Class)model_class where:(NSString *)where {
    if (![self openTable:model_class]) return NO;
    NSString * table_name = NSStringFromClass(model_class);
    NSString * delete_sql = [NSString stringWithFormat:@"DELETE FROM %@",table_name];
    if (where != nil && where.length > 0) {
        delete_sql = [delete_sql stringByAppendingFormat:@" WHERE %@",where];
    }
    int result = [self execSql:delete_sql];
    [self close];
    return result == SQLITE_OK;
}

+ (void)close {
    if (database) {
        sqlite3_close(database);
        database = nil;
    }
}

+ (void)removeAllModel {
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

+ (void)removeModel:(Class)model_class {
    @autoreleasepool {
        NSFileManager * file_manager = [NSFileManager defaultManager];
        NSString * file_path = [self localPathWithModel:model_class];
        if ([file_manager fileExistsAtPath:file_path]) {
            [file_manager removeItemAtPath:file_path error:nil];
        }
    }
}

+ (NSString *)localPathWithModel:(Class)model_class {
    return [NSString stringWithFormat:@"%@%@.sqlite",[self databaseCacheDirectory],NSStringFromClass(model_class)];
}

@end
