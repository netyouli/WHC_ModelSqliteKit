//
//  WHC_ModelSqlite.h
//  WHC_ModelSqliteKit
//
//  Created by admin on 16/5/28.
//  Copyright © 2016年 WHC. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.

#import <Foundation/Foundation.h>

@interface WHC_ModelSqlite : NSObject

/**
 * 说明: 存储模型数组到本地(事务方式)
 * @param model_array 模型数组对象(model_array 里对象类型要一致)
 * @return 成功 YES or NO
 */

+ (BOOL)insertArray:(NSArray *)model_array;

/**
 * 说明: 存储模型到本地
 * @param model_object 模型对象
 * @return 成功 YES or NO
 */

+ (BOOL)insert:(id)model_object;

/**
 * 说明: 查询本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
 * @return 查询模型对象数组
 */

+ (NSArray *)query:(Class)model_class where:(NSString *)where;

/**
 * 说明: 更新本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则更新所有)
 * @return 成功 YES or NO
 */

+ (BOOL)update:(id)model_object where:(NSString *)where;

/**
 * 说明: 清空本地模型对象
 * @param model_class 模型类
 * @return 成功 YES or NO
 */

+ (BOOL)clear:(Class)model_class;


/**
 * 说明: 删除本地模型对象
 * @param model_class 模型类
 * @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则删除所有)
 * @return 成功 YES or NO
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

@end
