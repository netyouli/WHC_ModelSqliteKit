//
//  NSObject+WHC_Model.m
//  WHC_Model<https://github.com/netyouli/WHC_Model>
//
//  Created by WHC on 16/7/13.
//  Copyright © 2016年 whc. All rights reserved.
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


#import "NSObject+WHC_Model.h"
#import <objc/runtime.h>
#import <objc/message.h>

typedef NS_OPTIONS(NSUInteger, WHC_TYPE) {
    _Array = 1 << 0,
    _Dictionary = 1 << 1,
    _String = 1 << 2,
    _Integer = 1 << 3,
    _UInteger = 1 << 4,
    _Float = 1 << 5,
    _Double = 1 << 6,
    _Boolean = 1 << 7,
    _Char = 1 << 8,
    _Number = 1 << 9,
    _Null = 1 << 10,
    _Model = 1 << 11,
    _Data = 1 << 12,
    _Date = 1 << 13,
    _Value = 1 << 14,
    _Url = 1 << 15,
    _Set = 1 << 16,
    _Unknown = 1 << 17
};

@interface WHC_ModelPropertyInfo : NSObject {
@public
    Class class;
    WHC_TYPE type;
    SEL setter;
    SEL getter;
}
@end
@implementation WHC_ModelPropertyInfo

- (void)setClass:(Class)_class valueClass:(Class)valueClass {
    class = _class;
    if (class == nil) {
        type = _Null;
        return;
    }
    if ([class isSubclassOfClass:[NSString class]]) {type = _String;}
    else if ([class isSubclassOfClass:[NSDictionary class]]) {type = _Dictionary;}
    else if ([valueClass isSubclassOfClass:[NSDictionary class]]) {type = _Model;}
    else if ([class isSubclassOfClass:[NSArray class]]) {type = _Array;}
    else if ([class isSubclassOfClass:[NSNumber class]]) {type = _Number;}
    else if ([class isSubclassOfClass:[NSDate class]]) {type = _Date;}
    else if ([class isSubclassOfClass:[NSValue class]]) {type = _Value;}
    else if ([class isSubclassOfClass:[NSData class]]) {type = _Data;}
    else {type = _Unknown;}
}

- (instancetype)init {
    self = [super init];
    if (self) {
        type = _Unknown;
    }
    return self;
}

@end

@implementation NSObject (WHC_Model)

#pragma mark - 枚举类属性列表 -

+ (void)whc_EnumeratePropertyNameUsingBlock:(void (NS_NOESCAPE ^)(NSString * propertyName, NSUInteger index, BOOL * stop))block {
    unsigned int propertyCount = 0;
    BOOL stop = NO;
    objc_property_t * properties = class_copyPropertyList(self, &propertyCount);
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char * name = property_getName(property);
        block([NSString stringWithUTF8String:name],i,&stop);
        if (stop) break;
    }
    free(properties);
}

+ (void)whc_EnumeratePropertyAttributesUsingBlock:(void (NS_NOESCAPE ^)(NSString * propertyName,objc_property_t property, NSUInteger index, BOOL * stop))block {
    unsigned int propertyCount = 0;
    BOOL stop = NO;
    objc_property_t * properties = class_copyPropertyList(self, &propertyCount);
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char * name = property_getName(property);
        block([NSString stringWithUTF8String:name],property,i,&stop);
        if (stop) break;
    }
    free(properties);
}

#pragma mark - 模型对象序列化 Api -

- (void)copySuperObject:(id)newSelf {
    Class superClass = class_getSuperclass(self.class);
    if (superClass != nil &&
        superClass != [NSObject class]) {
        NSObject * superObject = superClass.new;
        [superClass whc_EnumeratePropertyNameUsingBlock:^(NSString *propertyName, NSUInteger index, BOOL *stop) {
            [superObject setValue:[self valueForKey:propertyName] forKey:propertyName];
            [newSelf setValue:[self valueForKey:propertyName] forKey:propertyName];
        }];
        [superObject copySuperObject:newSelf];
    }
}

- (id)whc_Copy {
    id newSelf = self.class.new;
    [self copySuperObject:newSelf];
    [self.class whc_EnumeratePropertyAttributesUsingBlock:^(NSString *propertyName, objc_property_t property, NSUInteger index, BOOL *stop) {
        NSDictionary <NSString *, WHC_ModelPropertyInfo *> * propertyInfoMap = [self.class getModelPropertyDictionary];
        WHC_ModelPropertyInfo * propertyInfo = nil;
        if (propertyInfoMap != nil) {
            propertyInfo = propertyInfoMap[propertyName];
        }
        if (propertyInfo == nil) {
            propertyInfo = [WHC_ModelPropertyInfo new];
            const char * attributes = property_getAttributes(property);
            propertyInfo->type = [self.class parserTypeWithAttr:[NSString stringWithUTF8String:attributes]];
            propertyInfo->setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[propertyName substringToIndex:1].uppercaseString, [propertyName substringFromIndex:1]]);
        }
        if ([newSelf respondsToSelector:propertyInfo->setter]) {
            id value = [self valueForKey:propertyName];
            switch (propertyInfo->type) {
                case _Char: {
                    ((void (*)(id, SEL, char))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value charValue]);
                }
                    break;
                case _Float: {
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value floatValue]);
                }
                    break;
                case _Double: {
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value doubleValue]);
                }
                    break;
                case _Boolean:{
                    ((void (*)(id, SEL, BOOL))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value boolValue]);
                }
                    break;
                case _Integer:{
                    ((void (*)(id, SEL, NSInteger))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value integerValue]);
                }
                    break;
                case _UInteger:{
                    ((void (*)(id, SEL, NSUInteger))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value unsignedIntegerValue]);
                }
                    break;
                default: {
                    if (value) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)newSelf, propertyInfo->setter, [value copy]);
                    }
                }
                    break;
            }
        }
    }];
    return newSelf;
}

- (void)whc_Encode:(NSCoder *)aCoder {
    Class superClass = class_getSuperclass(self.class);
    if (superClass != nil &&
        superClass != [NSObject class]) {
        NSObject * superObject = superClass.new;
        [superClass whc_EnumeratePropertyNameUsingBlock:^(NSString *propertyName, NSUInteger index, BOOL *stop) {
            [superObject setValue:[self valueForKey:propertyName] forKey:propertyName];
        }];
        [superObject whc_Encode:aCoder];
    }
    [self.class whc_EnumeratePropertyNameUsingBlock:^(NSString *propertyName, NSUInteger index, BOOL *stop) {
        id value = [self valueForKey:propertyName];
        if (value != nil) {
            [aCoder encodeObject:value forKey:propertyName];
        }
    }];
}

- (void)whc_Decode:(NSCoder *)aDecoder {
    Class superClass = class_getSuperclass(self.class);
    if (superClass != nil &&
        superClass != [NSObject class]) {
        NSObject * superObject = superClass.new;
        [superObject whc_Decode:aDecoder];
        [superClass whc_EnumeratePropertyNameUsingBlock:^(NSString *propertyName, NSUInteger index, BOOL *stop) {
            [self setValue:[superObject valueForKey:propertyName] forKey:propertyName];
        }];
    }
    [self.class whc_EnumeratePropertyAttributesUsingBlock:^(NSString *propertyName, objc_property_t property, NSUInteger index, BOOL *stop) {
        id value = [aDecoder decodeObjectForKey:propertyName];
        if (value != nil) {
            NSDictionary <NSString *, WHC_ModelPropertyInfo *> * propertyInfoMap = [self.class getModelPropertyDictionary];
            WHC_ModelPropertyInfo * propertyInfo = nil;
            if (propertyInfoMap != nil) {
                propertyInfo = propertyInfoMap[propertyName];
            }
            if ([value isKindOfClass:[NSNumber class]]) {
                if (propertyInfo == nil) {
                    propertyInfo = [WHC_ModelPropertyInfo new];
                    const char * attributes = property_getAttributes(property);
                    NSArray * attributesArray = [[NSString stringWithUTF8String:attributes] componentsSeparatedByString:@"\""];
                    if (attributesArray.count != 1) {
                        propertyInfo->type = _Number;
                    }else {
                        propertyInfo->type = [self.class parserTypeWithAttr:[NSString stringWithUTF8String:attributes]];
                    }
                    propertyInfo->setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[propertyName substringToIndex:1].uppercaseString, [propertyName substringFromIndex:1]]);
                }
                if ([self respondsToSelector:propertyInfo->setter]) {
                    switch (propertyInfo->type) {
                        case _Char:
                            ((void (*)(id, SEL, char))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value charValue]);
                            break;
                        case _Float:
                            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value floatValue]);
                            break;
                        case _Double:
                            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value doubleValue]);
                            break;
                        case _Boolean:
                            ((void (*)(id, SEL, BOOL))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value boolValue]);
                            break;
                        case _Integer:
                            ((void (*)(id, SEL, NSInteger))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value integerValue]);
                            break;
                        case _UInteger:
                            ((void (*)(id, SEL, NSUInteger))(void *) objc_msgSend)((id)self, propertyInfo->setter, [value unsignedIntegerValue]);
                            break;
                        case _Number:
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyInfo->setter, value);
                            break;
                        default:
                            break;
                    }
                }
            }else {
                if (propertyInfo != nil) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyInfo->setter, value);
                }else {
                    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[propertyName substringToIndex:1].uppercaseString, [propertyName substringFromIndex:1]]);
                    if ([self respondsToSelector:setter]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, setter, value);
                    }
                }
            }
        }
    }];
}

#pragma mark - json转模型对象 Api -

+ (id)whc_ModelWithJson:(id)json {
    if (json) {
        if ([json isKindOfClass:[NSData class]]) {
            id jsonObject = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
            return [self whc_ModelWithJson:jsonObject];
        }else if ([json isKindOfClass:[NSDictionary class]]) {
            return [self handleDataModelEngine:json class:self];
        }else if ([json isKindOfClass:[NSArray class]]) {
            return [self handleDataModelEngine:json class:self];
        }else if ([json isKindOfClass:[NSString class]]) {
            id  jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
            return [self whc_ModelWithJson:jsonData];
        }
    }
    return nil;
}

+ (id)whc_ModelWithJson:(id)json keyPath:(NSString *)keyPath {
    if (json) {
        if (keyPath != nil && keyPath.length > 0) {
            __block id jsonObject = nil;
            if ([json isKindOfClass:[NSData class]]) {
                jsonObject = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
            }else if ([json isKindOfClass:[NSDictionary class]]) {
                jsonObject = json;
            }else if ([json isKindOfClass:[NSArray class]]) {
                jsonObject = json;
            }else if ([json isKindOfClass:[NSString class]]) {
                id  jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
                jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:nil];
            }else {
                return nil;
            }
            NSArray<NSString *> * keyPathArray = [keyPath componentsSeparatedByString:@"."];
            [keyPathArray enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
                NSRange range = [key rangeOfString:@"["];
                if (range.location != NSNotFound) {
                    NSString * realKey = [key substringToIndex:range.location];
                    NSString * indexString = key;
                    if (realKey.length > 0) {
                        jsonObject = jsonObject[realKey];
                        indexString = [key substringFromIndex:range.location];
                    }
                    NSString * handleIndexString = [indexString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]];
                    NSInteger indexLength = handleIndexString.length;
                    for (NSUInteger i = 0; i < indexLength; i++) {
                        NSInteger index = [[handleIndexString substringWithRange:NSMakeRange(i, 1)] integerValue];
                        jsonObject = jsonObject[index];
                    }
                }else {
                    jsonObject = jsonObject[key];
                }
            }];
            if (jsonObject) {
                if ([jsonObject isKindOfClass:[NSDictionary class]] || [jsonObject isKindOfClass:[NSArray class]]) {
                    return [self whc_ModelWithJson:jsonObject];
                }else {
                    return jsonObject;
                }
            }
            return nil;
        }else {
            return [self whc_ModelWithJson:json];
        }
    }
    return nil;
}

#pragma mark - 模型对象转json Api -

- (NSString *)whc_Json {
    id jsonSet = nil;
    if ([self isKindOfClass:[NSDictionary class]]) {
        jsonSet = [self parserDictionaryEngine:(NSDictionary *)self];
    }else if ([self isKindOfClass:[NSArray class]]) {
        jsonSet = [self parserArrayEngine:(NSArray *)self];
    }else {
        jsonSet = [self whc_Dictionary];
    }
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:jsonSet options:kNilOptions error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)whc_Dictionary {
    NSMutableDictionary * jsonDictionary = [NSMutableDictionary new];
    Class superClass = class_getSuperclass(self.class);
    if (superClass != nil &&
        superClass != [NSObject class]) {
        NSObject * superObject = superClass.new;
        [superClass whc_EnumeratePropertyNameUsingBlock:^(NSString *propertyName, NSUInteger index, BOOL *stop) {
            [superObject setValue:[self valueForKey:propertyName] forKey:propertyName];
        }];
        [jsonDictionary setDictionary:[superObject whc_Dictionary]];
    }
    NSDictionary <NSString *, WHC_ModelPropertyInfo *> * propertyInfoMap = [self.class getModelPropertyDictionary];
    [self.class whc_EnumeratePropertyAttributesUsingBlock:^(NSString *propertyName, objc_property_t property, NSUInteger index, BOOL *stop) {
        WHC_ModelPropertyInfo * propertyInfo = nil;
        if (propertyInfoMap != nil) {
            propertyInfo = propertyInfoMap[propertyName];
        }
        if (propertyInfo) {
            if (propertyInfo->getter == nil) {
                propertyInfo->getter = NSSelectorFromString(propertyName);
            }
            switch (propertyInfo->type) {
                case _Data: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    if (value) {
                        if ([value isKindOfClass:[NSData class]]) {
                            [jsonDictionary setObject:[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] forKey:propertyName];
                        }else {
                            [jsonDictionary setObject:value forKey:propertyName];
                        }
                    }else {
                        [jsonDictionary setObject:[NSNull new] forKey:propertyName];
                    }
                }
                    break;
                case _Date: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    if (value) {
                        if ([value isKindOfClass:[NSString class]]) {
                            [jsonDictionary setObject:value forKey:propertyName];
                        }else {
                            NSDateFormatter * formatter = [NSDateFormatter new];
                            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                            [jsonDictionary setObject:[formatter stringFromDate:value] forKey:propertyName];
                        }
                    }else {
                        [jsonDictionary setObject:[NSNull new] forKey:propertyName];
                    }
                }
                    break;
                case _Value:
                    break;
                case _String:
                case _Number: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    if (value != nil) {
                        [jsonDictionary setObject:value forKey:propertyName];
                    }else {
                        [jsonDictionary setObject:[NSNull new] forKey:propertyName];
                    }
                }
                    break;
                case _Model: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[value whc_Dictionary] forKey:propertyName];
                }
                    break;
                case _Array: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[self parserArrayEngine:value] forKey:propertyName];
                }
                    break;
                case _Dictionary: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[self parserDictionaryEngine:value] forKey:propertyName];
                }
                    break;
                case _Char: {
                    char value = ((char (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithChar:value] forKey:propertyName];
                }
                    break;
                case _Float: {
                    Float64 value = ((Float64 (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithFloat:value] forKey:propertyName];
                }
                    break;
                case _Double: {
                    double value = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithDouble:value] forKey:propertyName];
                }
                    break;
                case _Boolean: {
                    BOOL value = ((BOOL (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithBool:value] forKey:propertyName];
                }
                    break;
                case _Integer: {
                    NSInteger value = ((NSInteger (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithInteger:value] forKey:propertyName];
                }
                    break;
                case _UInteger: {
                    NSUInteger value = ((NSUInteger (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyInfo->getter);
                    [jsonDictionary setObject:[NSNumber numberWithUnsignedInteger:value] forKey:propertyName];
                }
                    break;
                case _Null: {
                    [jsonDictionary setObject:[NSNull new] forKey:propertyName];
                }
                    break;
                default:
                    break;
            }
        }else {
            const char * attributes = property_getAttributes(property);
            NSArray * attributesArray = [[NSString stringWithUTF8String:attributes] componentsSeparatedByString:@"\""];
            if (attributesArray.count == 1) {
                id value = [self valueForKey:propertyName];
                [jsonDictionary setObject:value forKey:propertyName];
            }else {
                id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, NSSelectorFromString(propertyName));
                if (value != nil) {
                    Class classType = NSClassFromString(attributesArray[1]);
                    if ([classType isSubclassOfClass:[NSString class]]) {
                        [jsonDictionary setObject:value forKey:propertyName];
                    }else if ([classType isSubclassOfClass:[NSNumber class]]) {
                        [jsonDictionary setObject:value forKey:propertyName];
                    }else if ([classType isSubclassOfClass:[NSDictionary class]]) {
                        [jsonDictionary setObject:[self parserDictionaryEngine:value] forKey:propertyName];
                    }else if ([classType isSubclassOfClass:[NSArray class]]) {
                        [jsonDictionary setObject:[self parserArrayEngine:value] forKey:propertyName];
                    }else if ([classType isSubclassOfClass:[NSDate class]]) {
                        if ([value isKindOfClass:[NSString class]]) {
                            [jsonDictionary setObject:value forKey:propertyName];
                        }else {
                            NSDateFormatter * formatter = [NSDateFormatter new];
                            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                            [jsonDictionary setObject:[formatter stringFromDate:value] forKey:propertyName];
                        }
                    }else if ([classType isSubclassOfClass:[NSData class]]) {
                        if ([value isKindOfClass:[NSData class]]) {
                            [jsonDictionary setObject:[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] forKey:propertyName];
                        }else {
                            [jsonDictionary setObject:value forKey:propertyName];
                        }
                    }else if ([classType isSubclassOfClass:[NSValue class]] || [classType isSubclassOfClass:[NSSet class]] || [classType isSubclassOfClass:[NSURL class]] || [classType isSubclassOfClass:[NSError class]]) {
                    }else {
                        [jsonDictionary setObject:[value whc_Dictionary] forKey:propertyName];
                    }
                }else {
                    [jsonDictionary setObject:[NSNull new] forKey:propertyName];
                }
            }
        }
    }];
    return jsonDictionary;
}

#pragma mark - 模型对象转json解析引擎(private) -

- (id)parserDictionaryEngine:(NSDictionary *)value {
    if (value == nil) return [NSNull new];
    NSMutableDictionary * subJsonDictionary = [NSMutableDictionary new];
    NSArray * allKey = value.allKeys;
    for (NSString * key in allKey) {
        id subValue = value[key];
        if ([subValue isKindOfClass:[NSString class]] ||
            [subValue isKindOfClass:[NSNumber class]]) {
            [subJsonDictionary setObject:subValue forKey:key];
        }else if ([subValue isKindOfClass:[NSDictionary class]]){
            [subJsonDictionary setObject:[self parserDictionaryEngine:subValue] forKey:key];
        }else if ([subValue isKindOfClass:[NSArray class]]) {
            [subJsonDictionary setObject:[self parserArrayEngine:subValue] forKey:key];
        }else {
            [subJsonDictionary setObject:[subValue whc_Dictionary] forKey:key];
        }
    }
    return subJsonDictionary;
}

- (id)parserArrayEngine:(NSArray *)value {
    if (value == nil) return [NSNull new];
    NSMutableArray * subJsonArray = [NSMutableArray new];
    for (id subValue in value) {
        if ([subValue isKindOfClass:[NSString class]] ||
            [subValue isKindOfClass:[NSNumber class]]) {
            [subJsonArray addObject:subValue];
        }else if ([subValue isKindOfClass:[NSDictionary class]]){
            [subJsonArray addObject:[self parserDictionaryEngine:subValue]];
        }else if ([subValue isKindOfClass:[NSArray class]]) {
            [subJsonArray addObject:[self parserArrayEngine:subValue]];
        }else {
            [subJsonArray addObject:[subValue whc_Dictionary]];
        }
    }
    return subJsonArray;
}

#pragma mark - json转模型对象解析引擎(private) -

static const char  WHC_ModelPropertyInfokey = '\0';
static const char  WHC_ReplaceKeyValue = '\0';
static const char  WHC_ReplacePropertyClass = '\0';
static const char  WHC_ReplaceContainerElementClass = '\0';

+ (NSDictionary <NSString *, Class> *)getContainerElementClassMapper {
    return objc_getAssociatedObject(self, &WHC_ReplaceContainerElementClass);
}

+ (void)setContainerElementClassMapper:(NSDictionary <NSString *, Class> *)mapper {
    objc_setAssociatedObject(self, &WHC_ReplaceContainerElementClass, mapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSDictionary <NSString *, Class> *)getModelPropertyClassMapper {
    return objc_getAssociatedObject(self, &WHC_ReplacePropertyClass);
}

+ (void)setModelPropertyClassMapper:(NSDictionary <NSString *, Class> *)mapper {
    objc_setAssociatedObject(self, &WHC_ReplacePropertyClass, mapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSDictionary <NSString *, NSString *> *)getModelReplacePropertyMapper {
    return objc_getAssociatedObject(self, &WHC_ReplaceKeyValue);
}

+ (void)setModelReplacePropertyMapper:(NSDictionary *)mapper {
    objc_setAssociatedObject(self, &WHC_ReplaceKeyValue, mapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSDictionary <NSString *, WHC_ModelPropertyInfo *>*)getModelPropertyDictionary {
    return objc_getAssociatedObject(self, &WHC_ModelPropertyInfokey);
}

+ (WHC_ModelPropertyInfo *)getPropertyInfo:(NSString *)property {
    NSDictionary * propertyInfo = objc_getAssociatedObject(self, &WHC_ModelPropertyInfokey);
    return propertyInfo != nil ? propertyInfo[property] : nil;
}

+ (void)setModelInfo:(WHC_ModelPropertyInfo *)modelInfo property:(NSString *)property {
    NSMutableDictionary * propertyInfo = objc_getAssociatedObject(self, &WHC_ModelPropertyInfokey);
    if (propertyInfo == nil) {
        propertyInfo = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &WHC_ModelPropertyInfokey, propertyInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [propertyInfo setObject:modelInfo forKey:property];
}

+ (NSString *)existproperty:(NSString *)property withObject:(NSObject *)object {
    objc_property_t property_t = class_getProperty(object.class, [property UTF8String]);
    if (property_t != NULL) {
        const char * name = property_getName(property_t);
        NSString * nameString = [NSString stringWithUTF8String:name];
        return nameString;
    }else {
        unsigned int  propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList([object class], &propertyCount);
        for (unsigned int i = 0; i < propertyCount; ++i) {
            objc_property_t property_t = properties[i];
            const char * name = property_getName(property_t);
            NSString * nameString = [NSString stringWithUTF8String:name];
            if ([nameString.lowercaseString isEqualToString:property.lowercaseString]) {
                free(properties);
                return nameString;
            }
        }
        free(properties);
        Class superClass = class_getSuperclass(object.class);
        if (superClass && superClass != [NSObject class]) {
            NSString * name =  [self existproperty:property withObject:superClass.new];
            if (name != nil && name.length > 0) {
                return name;
            }
        }
        return nil;
    }
}

+ (WHC_TYPE)parserTypeWithAttr:(NSString *)attr {
    NSArray * sub_attrs = [attr componentsSeparatedByString:@","];
    NSString * first_sub_attr = sub_attrs.firstObject;
    first_sub_attr = [first_sub_attr substringFromIndex:1];
    WHC_TYPE attr_type = _Null;
    const char type = *[first_sub_attr UTF8String];
    switch (type) {
        case 'B':
            attr_type = _Boolean;
            break;
        case 'c':
        case 'C':
            attr_type = _Char;
            break;
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            attr_type = _UInteger;
        case 'l':
        case 'q':
        case 'i':
        case 's':
            attr_type = _Integer;
            break;
        case 'f':
            attr_type = _Float;
            break;
        case 'd':
        case 'D':
            attr_type = _Double;
            break;
        default:
            break;
    }
    return attr_type;
}

+ (WHC_ModelPropertyInfo *)classExistProperty:(NSString *)property withObject:(NSObject *)object valueClass:(Class)valueClass {
    WHC_ModelPropertyInfo * propertyInfo = nil;
    objc_property_t property_t = class_getProperty(object.class, [property UTF8String]);
    if (property_t != NULL) {
        const char * attributes = property_getAttributes(property_t);
        NSString * attr = [NSString stringWithUTF8String:attributes];
        NSArray * arrayString = [attr componentsSeparatedByString:@"\""];
        propertyInfo = [WHC_ModelPropertyInfo new];
        if (arrayString.count == 1) {
            propertyInfo->type = [self parserTypeWithAttr:arrayString[0]];
        }else {
            [propertyInfo setClass: NSClassFromString(arrayString[1]) valueClass:valueClass];
        }
        return propertyInfo;
    }else {
        unsigned int  propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList([object class], &propertyCount);
        for (unsigned int i = 0; i < propertyCount; ++i) {
            objc_property_t property_t = properties[i];
            const char * name = property_getName(property_t);
            NSString * nameStr = [NSString stringWithUTF8String:name];
            if ([nameStr.lowercaseString isEqualToString:property.lowercaseString]) {
                const char * attributes = property_getAttributes(property_t);
                NSString * attr = [NSString stringWithUTF8String:attributes];
                NSArray * arrayString = [attr componentsSeparatedByString:@"\""];
                free(properties);
                propertyInfo = [WHC_ModelPropertyInfo new];
                if (arrayString.count == 1) {
                    propertyInfo->type = [self parserTypeWithAttr:arrayString[0]];
                }else {
                    [propertyInfo setClass: NSClassFromString(arrayString[1]) valueClass:valueClass];
                }
                return propertyInfo;
            }
        }
        free(properties);
        Class superClass = class_getSuperclass(object.class);
        if (superClass && superClass != [NSObject class]) {
            propertyInfo = [self classExistProperty:property withObject:superClass.new valueClass:valueClass];
            if (propertyInfo != nil) {
                return propertyInfo;
            }
        }
    }
    return propertyInfo;
}

+ (id)handleDataModelEngine:(id)object class:(Class)class {
    if(object) {
        if([object isKindOfClass:[NSDictionary class]]) {
            __block NSObject *  modelObject = nil;
            NSDictionary  * dictionary = object;
            __block NSDictionary <NSString *, NSString *> * replacePropertyNameMap = [class getModelReplacePropertyMapper];
            __block NSDictionary <NSString *, Class> * replacePropertyClassMap = [class getModelPropertyClassMapper];
            __block NSDictionary <NSString *, Class> * replaceContainerElementClassMap = [class getContainerElementClassMapper];
            if (replacePropertyNameMap == nil &&
                [class respondsToSelector:@selector(whc_ModelReplacePropertyMapper)]) {
                replacePropertyNameMap = [class whc_ModelReplacePropertyMapper];
                [class setModelReplacePropertyMapper:replacePropertyNameMap];
            }
            if ([class isSubclassOfClass:[NSDictionary class]]) {
                modelObject = [NSMutableDictionary dictionary];
                [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString * key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    if ([obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]]) {
                        Class subModelClass = NSClassFromString(key);
                        if (subModelClass == nil) {
                            subModelClass = NSClassFromString([NSString stringWithFormat:@"%@%@:",[key substringToIndex:1].uppercaseString, [key substringFromIndex:1]]);
                            if (subModelClass == nil) {
                                subModelClass = [obj class];
                            }
                        }
                        [(NSMutableDictionary *)modelObject setObject:[self handleDataModelEngine:obj class:subModelClass] forKey:key];
                    }else {
                        [(NSMutableDictionary *)modelObject setObject:obj forKey:key];
                    }
                }];
            }else {
                modelObject = [class new];
                [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString * key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    NSString * actualProperty = key;
                    id subObject = obj;
                    if (replacePropertyNameMap != nil) {
                        NSString * replaceName =  replacePropertyNameMap[actualProperty];
                        if (replaceName) {
                            actualProperty = replaceName;
                        }
                    }
                    WHC_ModelPropertyInfo * propertyInfo = [class getPropertyInfo:actualProperty];
                    if (propertyInfo == nil || (propertyInfo != nil && propertyInfo->type == _Unknown)) {
                        if (replacePropertyClassMap) {
                            propertyInfo = [WHC_ModelPropertyInfo new];
                            [propertyInfo setClass:replacePropertyClassMap[actualProperty] valueClass:[obj class]];
                        }else {
                            if ([class respondsToSelector:@selector(whc_ModelReplacePropertyClassMapper)]) {
                                [class setModelPropertyClassMapper:[class whc_ModelReplacePropertyClassMapper]];
                            }
                            propertyInfo = [self classExistProperty:actualProperty withObject:modelObject valueClass:[obj class]];
                        }
                        if (propertyInfo) {
                            [class setModelInfo:propertyInfo property:actualProperty];
                        }else {
                            return;
                        }
                        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[actualProperty substringToIndex:1].uppercaseString, [actualProperty substringFromIndex:1]]);
                        if (![modelObject respondsToSelector:setter]) {
                            actualProperty = [self existproperty:actualProperty withObject:modelObject];
                            if (actualProperty == nil) {
                                return;
                            }
                            setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[actualProperty substringToIndex:1].uppercaseString, [actualProperty substringFromIndex:1]]);
                        }
                        propertyInfo->setter = setter;
                    }
                    switch (propertyInfo->type) {
                        case _Array:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                Class subModelClass = NULL;
                                if (replaceContainerElementClassMap) {
                                    subModelClass = replaceContainerElementClassMap[actualProperty];
                                }else if ([class respondsToSelector:@selector(whc_ModelReplaceContainerElementClassMapper)]) {
                                    replaceContainerElementClassMap = [class whc_ModelReplaceContainerElementClassMapper];
                                    subModelClass = replaceContainerElementClassMap[actualProperty];
                                    [class setContainerElementClassMapper:replaceContainerElementClassMap];
                                }
                                if (subModelClass == NULL) {
                                    subModelClass = NSClassFromString(actualProperty);
                                    if (subModelClass == nil) {
                                        NSString * first = [actualProperty substringToIndex:1];
                                        NSString * other = [actualProperty substringFromIndex:1];
                                        subModelClass = NSClassFromString([NSString stringWithFormat:@"%@%@",[first uppercaseString],other]);
                                    }
                                }
                                if (subModelClass) {
                                    ((void (*)(id, SEL, NSArray *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [self handleDataModelEngine:subObject class:subModelClass]);
                                }else {
                                    ((void (*)(id, SEL, NSArray *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                                }
                                
                            }else{
                                ((void (*)(id, SEL, NSArray *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, @[]);
                            }
                            break;
                        case _Dictionary:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                Class subModelClass = NULL;
                                if (replaceContainerElementClassMap) {
                                    subModelClass = replaceContainerElementClassMap[actualProperty];
                                }else if ([class respondsToSelector:@selector(whc_ModelReplaceContainerElementClassMapper)]) {
                                    replaceContainerElementClassMap = [class whc_ModelReplaceContainerElementClassMapper];
                                    if (replaceContainerElementClassMap) {
                                        subModelClass = replaceContainerElementClassMap[actualProperty];
                                        [class setContainerElementClassMapper:replaceContainerElementClassMap];
                                    }
                                }
                                if (subModelClass == NULL) {
                                    subModelClass = NSClassFromString(actualProperty);
                                    if (subModelClass == nil) {
                                        NSString * first = [actualProperty substringToIndex:1];
                                        NSString * other = [actualProperty substringFromIndex:1];
                                        subModelClass = NSClassFromString([NSString stringWithFormat:@"%@%@",[first uppercaseString],other]);
                                    }
                                }
                                if (subModelClass) {
                                    NSMutableDictionary * subObjectDictionary = [NSMutableDictionary dictionary];
                                    [subObject enumerateKeysAndObjectsUsingBlock:^(NSString * key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                                        [subObjectDictionary setObject:[self handleDataModelEngine:obj class:subModelClass] forKey:key];
                                    }];
                                    ((void (*)(id, SEL, NSDictionary *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObjectDictionary);
                                }else {
                                    ((void (*)(id, SEL, NSArray *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                                }
                                
                            }else{
                                ((void (*)(id, SEL, NSDictionary *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, @{});
                            }
                            break;
                        case _String:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                ((void (*)(id, SEL, NSString *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                            }else{
                                ((void (*)(id, SEL, NSString *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, @"");
                            }
                            break;
                        case _Number:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                ((void (*)(id, SEL, NSNumber *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                            }else{
                                ((void (*)(id, SEL, NSNumber *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, @(0));
                            }
                            break;
                        case _Integer:
                            ((void (*)(id, SEL, NSInteger))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject integerValue]);
                            break;
                        case _UInteger:
                            ((void (*)(id, SEL, NSUInteger))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject unsignedIntegerValue]);
                            break;
                        case _Boolean:
                            ((void (*)(id, SEL, BOOL))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject boolValue]);
                            break;
                        case _Float:
                            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject floatValue]);
                            break;
                        case _Double:
                            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject doubleValue]);
                            break;
                        case _Char:
                            ((void (*)(id, SEL, char))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [subObject charValue]);
                            break;
                        case _Model:
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, [self handleDataModelEngine:subObject class:propertyInfo->class]);
                            break;
                        case _Date:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                ((void (*)(id, SEL, NSDate *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                            }
                            break;
                        case _Value:
                            if(![subObject isKindOfClass:[NSNull class]]){
                                ((void (*)(id, SEL, NSValue *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                            }
                            break;
                        case _Data: {
                            if(![subObject isKindOfClass:[NSNull class]]){
                                ((void (*)(id, SEL, NSData *))(void *) objc_msgSend)((id)modelObject, propertyInfo->setter, subObject);
                            }
                            break;
                        }
                        default:
                            
                            break;
                    }
                }];
            }
            return modelObject;
        }else if ([object isKindOfClass:[NSArray class]]){
            NSMutableArray  * modelObjectArr = [NSMutableArray new];
            [object enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                id subModelObject = [self handleDataModelEngine:obj class:class];
                if(subModelObject){
                    [modelObjectArr addObject:subModelObject];
                }
            }];
            return modelObjectArr;
        }else {
            return object;
        }
    }
    return nil;
}

@end
