//
//  NSObject+WHC_Model.h
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

#import <Foundation/Foundation.h>

///模型对象归档解归档实现
#define WHC_CodingImplementation \
- (id)initWithCoder:(NSCoder *)decoder \
{ \
if (self = [super init]) { \
[self whc_Decode:decoder]; \
} \
return self; \
} \
\
- (void)encodeWithCoder:(NSCoder *)encoder \
{ \
[self whc_Encode:encoder]; \
}\
- (id)copyWithZone:(NSZone *)zone { return [self whc_Copy]; }

@protocol WHC_ModelKeyValue <NSObject>
@optional
/// 模型类可自定义属性名称<json key名, 替换实际属性名>
+ (NSDictionary <NSString *, NSString *> *)whc_ModelReplacePropertyMapper;
/// 模型数组/字典元素对象可自定义类<替换实际属性名,实际类>
+ (NSDictionary <NSString *, Class> *)whc_ModelReplaceContainerElementClassMapper;
/// 模型类可自定义属性类型<替换实际属性名,实际类>
+ (NSDictionary <NSString *, Class> *)whc_ModelReplacePropertyClassMapper;

@end

@interface NSObject (WHC_Model) <WHC_ModelKeyValue>

#pragma mark - json转模型对象 Api -

/** 说明:把json解析为模型对象
 *@param json :json数据对象
 *@return 模型对象
 */
+ (id)whc_ModelWithJson:(id)json;

/** 说明:把json解析为模型对象
 *@param json :json数据对象
 *@param keyPath :json key的路径
 *@return 模型对象
 */

+ (id)whc_ModelWithJson:(id)json keyPath:(NSString *)keyPath;


#pragma mark - 模型对象转json Api -

/** 说明:把模型对象转换为字典
 *@return 字典对象
 */

- (NSDictionary *)whc_Dictionary;

/** 说明:把模型对象转换为json字符串
 *@return json字符串
 */

- (NSString *)whc_Json;

#pragma mark - 模型对象序列化 Api -

/// 复制模型对象
- (id)whc_Copy;

/// 序列化模型对象
- (void)whc_Encode:(NSCoder *)aCoder;

/// 反序列化模型对象
- (void)whc_Decode:(NSCoder *)aDecoder;
@end
