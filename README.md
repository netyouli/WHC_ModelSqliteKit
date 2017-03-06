WHC_ModelSqliteKit
==============
![Build Status](https://api.travis-ci.org/netyouli/WHC_ModelSqliteKit.svg?branch=master)
[![Pod Version](http://img.shields.io/cocoapods/v/WHC_ModelSqliteKit.svg?style=flat)](http://cocoadocs.org/docsets/WHC_ModelSqliteKit/)
[![Pod Platform](http://img.shields.io/cocoapods/p/WHC_ModelSqliteKit.svg?style=flat)](http://cocoadocs.org/docsets/WHC_ModelSqliteKit/)
[![Pod License](http://img.shields.io/cocoapods/l/WHC_ModelSqliteKit.svg?style=flat)](https://opensource.org/licenses/MIT)

架构图
==============
<div align=center><img src="https://github.com/netyouli/WHC_ModelSqliteKit/blob/master/architecture.png"/></div></br>

简介
==============
- **架构**: 采用runtime和Sqlite完美结合打造的强大数据库操作引擎开源库
- **安全**: 支持数据库级别加密
- **易用**: 真正实现一行代码操作数据库
- **目标**: 替代直接使用Sqlite和CoreData以及FMDB低效率方式
- **支持**: (NSArray,NSDictionary,NSDate,NSData,NSString,NSNumber,Int,double,float,Bool,char)类型
- **强大**: 支持模型嵌套继承模型类存储到数据库和多表嵌套联查
- **智能**: 根据数据库模型类实现的WHC_SqliteInfo协议返回的版本号来智能更新数据库字段(动态删除/添加)
- **咨询**: 712641411
- **作者**: 吴海超

要求
==============
* iOS 5.0 or later
* Xcode 8.0 or later


集成
==============
* 使用CocoaPods:
-  pod 'WHC_ModelSqlite', '~> 1.1.5'
* 需要加密数据库使用CocoaPods:
-  pod 'WHC_ModelSqlite/SQLCipher'
* 手工集成:
-  导入文件夹WHC_ModelSqliteKit

注意
==============
* 在需要对数据表自定义信息需要model类实现WHC_SqliteInfo协议
- 当模型类有新增/删除属性的时候需要在模型类里定义类方法whc_SqliteVersion方法修改模型类(数据库)版本号来表明有字段更新操作，库会根据这个VERSION变更智能检查并自动更新数据库字段，无需手动更新数据库字段
```objective-c
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
*** CocoaPods: pod 'WHC_ModelSqliteKit/SQLCipher' ***
*/
+ (NSString *)whc_SqlitePasswordKey;

/// 自定义数据表主键名称
/**
*** 返回自定义主键名称默认主键:_id ***
*/
+ (NSString *)whc_SqliteMainkey;

@end
```

用法
==============
####1.存储嵌套模型对象到数据库演示
```objective-c
Person * whc = [Person new];
whc.name = @"吴海超";
whc.age = 25;
whc.height = 180.0;
whc.weight = 140.0;
whc.isDeveloper = YES;
whc.sex = 'm';

// 嵌套car对象
whc.car = [Car new];
whc.car.name = @"撼路者";
whc.car.brand = @"大路虎";

// 嵌套school对象
whc.school = [School new];
whc.school.name = @"北京大学";
whc.school.personCount = 5000;

// school对象嵌套city对象
whc.school.city = [City new];
whc.school.city.name = @"北京";
whc.school.city.personCount = 1000;

/// 测试NSArray属性存储
Car * tempCar = [Car new];
tempCar.name = @"宝马";
tempCar.brand = @"林肯";
person.array = @[@"1",@"2"];
person.carArray = @[tempCar];

/// 测试NSDictionary属性存储
person.dict = @{@"1":@"2"};
person.dictCar = @{@"car": tempCar};

[WHC_ModelSqlite insert:whc];
```

####2.存储批量模型对象到数据库演示
```objective-c
NSArray * persons = [self makeArrayPerson];
[WHC_ModelSqlite insertArray:persons];
```

####3.无条件查询(查询所有记录)数据库中模型类演示
```objective-c
NSArray * personArray = [WHC_ModelSqlite query:[Person class]];
```

####4.条件查询数据库中模型类演示(where 条件查询语法和sql where条件查询语法一样)
```objective-c
NSArray * personArray = [WHC_ModelSqlite query:[Person class] where:@"name = '吴海超2' OR age <= 18"];
```

####5.查询数据库并对结果排序
```objective-c
///对person数据表查询并且根据age自动降序或者升序排序
[WHC_ModelSqlite query:[Person class] order:@"by age desc/asc"];
```

####6.查询数据库并对结果限制查询条数
```objective-c
/// 对person数据表查询并且并且限制查询数量为8
[WHC_ModelSqlite query:[Person class] limit:@"8"];

/// 对person数据表查询并且对查询列表偏移8并且限制查询数量为8
[WHC_ModelSqlite query:[Person class] limit:@"8 offset 8"];

```

####7.修改数据库中模型对象演示(where 条件查询语法和sql where条件查询语法一样) 
```objective-c
[WHC_ModelSqlite update:whc where:@"name = '吴海超2' OR age <= 18"];
```
####8.删除数据库中模型对象演示(where条件查询为空则删除所有)
```objective-c
[WHC_ModelSqlite delete:[Person class] where:@"age = 25 AND name = '吴海超'"];
```

####9.清空指定数据库演示
```objective-c
[WHC_ModelSqlite clear:[Person class]];
```

####10.删除数据库演示
```objective-c
[WHC_ModelSqlite removeModel:[Person class]];
```

####11.删除所有数据库演示
```objective-c
[WHC_ModelSqlite removeAllModel];
```

####12.获取数据库本地路径演示
```objective-c
NSString * path = [WHC_ModelSqlite localPathWithModel:[Person class]];
```
####13.获取数据库本地版本号演示
```objective-c
NSString * path = [WHC_ModelSqlite versionWithModel:[Person class]];
```

## <a id="期待"></a>期待

- 如果您在使用过程中有任何问题，欢迎issue me! 很乐意为您解答任何相关问题!
- 与其给我点star，不如向我狠狠地抛来一个BUG！
- 如果您想要更多的接口来自定义或者建议/意见，欢迎issue me！我会根据大家的需求提供更多的接口！

Api文档
==============
```objective-c
/**
* 说明: 存储模型数组到本地(事务方式)
* @param model_array 模型数组对象(model_array 里对象类型要一致)
*/

+ (void)inserts:(NSArray *)model_array;

/**
* 说明: 存储模型到本地
* @param model_object 模型对象
*/

+ (void)insert:(id)model_object;

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

/// example: [WHC_ModelSqlite query:[Person class] order:@"by age desc/asc"];
/// 对person数据表查询并且根据age自动降序或者升序排序

+ (NSArray *)query:(Class)model_class order:(NSString *)order;

/**
* 说明: 查询本地模型对象
* @param model_class 模型类
* @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
* @return 查询模型对象数组
*/

/// example: [WHC_ModelSqlite query:[Person class] limit:@"8"];
/// 对person数据表查询并且并且限制查询数量为8
/// example: [WHC_ModelSqlite query:[Person class] limit:@"8 offset 8"];
/// 对person数据表查询并且对查询列表偏移8并且限制查询数量为8

+ (NSArray *)query:(Class)model_class limit:(NSString *)limit;

/**
* 说明: 查询本地模型对象
* @param model_class 模型类
* @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
* @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
* @return 查询模型对象数组
*/

/// example: [WHC_ModelSqlite query:[Person class] where:@"age < 30" order:@"by age desc/asc"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order;

/**
* 说明: 查询本地模型对象
* @param model_class 模型类
* @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则查询所有)
* @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
* @return 查询模型对象数组
*/

/// example: [WHC_ModelSqlite query:[Person class] where:@"age <= 30" limit:@"8"];
/// 对person数据表查询age小于30岁并且限制查询数量为8
/// example: [WHC_ModelSqlite query:[Person class] where:@"age <= 30" limit:@"8 offset 8"];
/// 对person数据表查询age小于30岁并且对查询列表偏移8并且限制查询数量为8

+ (NSArray *)query:(Class)model_class where:(NSString *)where limit:(NSString *)limit;

/**
* 说明: 查询本地模型对象
* @param model_class 模型类
* @param order 排序条件(排序语法和SQL order 查询语法一样，order为空则不排序)
* @param limit 限制条件(限制语法和SQL limit 查询语法一样，limit为空则不限制查询)
* @return 查询模型对象数组
*/

/// example: [WHC_ModelSqlite query:[Person class] order:@"by age desc/asc" limit:@"8"];
/// 对person数据表查询并且根据age自动降序或者升序排序并且限制查询的数量为8
/// example: [WHC_ModelSqlite query:[Person class] order:@"by age desc/asc" limit:@"8 offset 8"];
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

/// example: [WHC_ModelSqlite query:[Person class] where:@"age <= 30" order:@"by age desc/asc" limit:@"8"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序并且限制查询的数量为8
/// example: [WHC_ModelSqlite query:[Person class] where:@"age <= 30" order:@"by age desc/asc" limit:@"8 offset 8"];
/// 对person数据表查询age小于30岁并且根据age自动降序或者升序排序并且限制查询的数量为8偏移为8

+ (NSArray *)query:(Class)model_class where:(NSString *)where order:(NSString *)order limit:(NSString *)limit;

/**
* 说明: 更新本地模型对象
* @param model_class 模型类
* @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则更新所有)
*/

+ (void)update:(id)model_object where:(NSString *)where;

/**
* 说明: 清空本地模型对象
* @param model_class 模型类
*/

+ (void)clear:(Class)model_class;


/**
* 说明: 删除本地模型对象
* @param model_class 模型类
* @param where 查询条件(查询语法和SQL where 查询语法一样，where为空则删除所有)
*/

+ (void)delete:(Class)model_class where:(NSString *)where;

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

```
## Licenses
All source code is licensed under the MIT License.
