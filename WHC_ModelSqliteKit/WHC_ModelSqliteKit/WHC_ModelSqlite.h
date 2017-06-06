//
//  WHC_ModelSqlite.h
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


#import <Foundation/Foundation.h>

#define WHCSqlite WHC_ModelSqlite

/// 数据库协议信息
@protocol WHC_SqliteInfo <NSObject>
@optional
/// 自定义模型类数据库版本号
/** 注意：
 ***该返回值在改变数据模型属性类型/增加/删除属性时需要更改否则无法自动更新原来模型数据表字段以及类型***
 */
+ (NSString *)whc_SqliteVersion;

/// 自定义数据库加密密码
/** 注意：
 ***该加密功能需要引用SQLCipher三方库才支持***
 /// 引入方式有:
 *** 手动引入 ***
 *** pod 'WHC_ModelSqliteKit/SQLCipher' ***
 */
+ (NSString *)whc_SqlitePasswordKey;

/// 自定义数据表主键名称
/**
 *** 返回自定义主键名称默认主键:_id ***
 */
+ (NSString *)whc_SqliteMainkey;


/**
 忽略属性集合

 @return 返回忽略属性集合
 */
+ (NSArray *)whc_IgnorePropertys;


/**
 引入使用其他方式创建的数据库存储路径比如:FMDB
 来使用WHC_Sqlite进行操作其他方式创建的数据库

 @return 存储路径
 */
+ (NSString *)whc_OtherSqlitePath;


/**
 指定自定义表名

 在指定引入其他方式创建的数据库时，这个时候如果表名不是模型类名需要实现该方法指定表名称
 
 @return 表名
 */
+ (NSString *)whc_TableName;

@end

@interface WHC_ModelSqlite : NSObject

/**
 * 说明: 存储模型数组到本地(事务方式)
 * @param model_array 模型数组对象(model_array 里对象类型要一致)
 */

+ (BOOL)inserts:(NSArray *)model_array;

/**
 * 说明: 存储模型到本地
 * @param model_object 模型对象
 */

+ (BOOL)insert:(id)model_object;


/**
 * 说明: 获取模型类表总条数
 * @param model_class 模型类
 * @return 总条数
 */
+ (NSUInteger)count:(Class)model_class;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @return 查询模型对象数组
 */

+ (NSArray *)query:(Class)model_class;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
 * @return 查询模型对象数组
 */

+ (NSArray *)query:(Class)model_class where:(NSString *)where;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] order:@"by age desc/asc"];
/// 对person数据表查询并且根据age自动降序或者升序排序

+ (NSArray *)query:(Class)model_class order:(NSString *)order;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] limit:@"8"];
/// 对person数据表查询并且并且限制查询数量为8
/// example: [WHCSqlite query:[Person class] limit:@"8 offset 8"];
/// 对person数据表查询并且对查询列表偏移8并且限制查询数量为8

+ (NSArray *)query:(Class)model_class limit:(NSString *)limit;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
 * @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] where:@"age < 30" order:@"by age desc/asc"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
 * @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] where:@"age <= 30" limit:@"8"];
/// 对person数据表查询age小于30岁并且限制查询数量为8
/// example: [WHCSqlite query:[Person class] where:@"age <= 30" limit:@"8 offset 8"];
/// 对person数据表查询age小于30岁并且对查询列表偏移8并且限制查询数量为8

+ (NSArray *)query:(Class)model_class where:(NSString *)where limit:(NSString *)limit;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
 * @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] order:@"by age desc/asc" limit:@"8"];
/// 对person数据表查询并且根据age自动降序或者升序排序并且限制查询的数量为8
/// example: [WHCSqlite query:[Person class] order:@"by age desc/asc" limit:@"8 offset 8"];
/// 对person数据表查询并且根据age自动降序或者升序排序并且限制查询的数量为8偏移为8

+ (NSArray *)query:(Class)model_class order:(NSString *)order limit:(NSString *)limit;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
 * @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
 * @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
 * @return 查询模型对象数组
 */

/// example: [WHCSqlite query:[Person class] where:@"age <= 30" order:@"by age desc/asc" limit:@"8"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序并且限制查询的数量为8
/// example: [WHCSqlite query:[Person class] where:@"age <= 30" order:@"by age desc/asc" limit:@"8 offset 8"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序并且限制查询的数量为8偏移为8

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order limit:(NSString *)limit;


/**
 说明: 自定义sql查询

 @param model_class 接收model类
 @param sql sql语句
 @return 查询模型对象数组
 
 /// example: [WHCSqlite query:Model.self sql:@"select cc.* from ( select tt.*,(select count(*)+1 from Chapter where chapter_id =tt.chapter_id and updateTime<tt.updateTime ) as group_id from Chapter tt) cc where cc.group_id<=7 order by updateTime desc"];
 */
+ (NSArray *)query:(Class)model_class sql:(NSString *)sql;

/**
 * 说明: 利用sqlite 函数进行查询
 
 * @param model_class 要查询模型类
 * @param sqliteFunc sqlite函数例如：（MAX(age),MIN(age),COUNT(*)....）
 * @return 返回查询结果(如果结果条数 > 1返回Array , = 1返回单个值 , = 0返回nil)
 * /// example: [WHCSqlite query:[Person class] sqliteFunc:@"max(age)"];  /// 获取Person表的最大age值
 * /// example: [WHCSqlite query:[Person class] sqliteFunc:@"count(*)"];  /// 获取Person表的总记录条数
 */
+ (id)query:(Class)model_class func:(NSString *)func;

/**
 * 说明: 利用sqlite 函数进行查询
 
 * @param model_class 要查询模型类
 * @param sqliteFunc sqlite函数例如：（MAX(age),MIN(age),COUNT(*)....）
 * @param condition 其他查询条件例如：(where age > 20 order by age desc ....)
 * @return 返回查询结果(如果结果条数 > 1返回Array , = 1返回单个值 , = 0返回nil)
 * /// example: [WHCSqlite query:[Person class] sqliteFunc:@"max(age)" condition:@"where name = '北京'"];  /// 获取Person表name=北京集合中的的最大age值
 * /// example: [WHCSqlite query:[Person class] sqliteFunc:@"count(*)" condition:@"where name = '北京'"];  /// 获取Person表name=北京集合中的总记录条数
 */
+ (id)query:(Class)model_class func:(NSString *)func condition:(NSString *)condition;

/**
 * 说明: 更新本地模型对象
 * @param model_object 模型对象
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则更新所有)
 */

+ (BOOL)update:(id)model_object where:(NSString *)where;


/**
 说明: 更新数据表字段

 @param model_class 模型类
 @param value 更新的值
 @param where 更新条件
 @return 是否成功
 /// 更新Person表在age字段大于25岁是的name值为whc，age为100岁
 /// example: [WHCSqlite update:Person.self value:@"name = 'whc', age = 100" where:@"age > 25"];
 */
+ (BOOL)update:(Class)model_class value:(NSString *)value where:(NSString *)where;

/**
 * 说明: 清空本地模型对象
 * @param model_class 模型类
 */

+ (BOOL)clear:(Class)model_class;


/**
 * 说明: 删除本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则删除所有)
 */

+ (BOOL)delete:(Class)model_class where:(NSString *)where;

/**
 * 说明: 清空所有本地模型数据库
 */

+ (void)removeAllModel;

/**
 * 说明: 清空指定本地模型数据库
 * @param model_class 模型类
 */

+ (void)removeModel:(Class)model_class;

/**
 * 说明: 返回本地模型数据库路径
 * @param model_class 模型类
 * @return 路径
 */

+ (NSString *)localPathWithModel:(Class)model_class;

/**
 * 说明: 返回本地模型数据库版本号
 * @param model_class 模型类
 * @return 版本号
 */
+ (NSString *)versionWithModel:(Class)model_class;

@end
