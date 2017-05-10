WHC_ModelSqliteKit
==============
![Build Status](https://api.travis-ci.org/netyouli/WHC_ModelSqliteKit.svg?branch=master)
[![Pod Version](http://img.shields.io/cocoapods/v/WHC_ModelSqliteKit.svg?style=flat)](http://cocoadocs.org/docsets/WHC_ModelSqliteKit/)
[![Pod Platform](http://img.shields.io/cocoapods/p/WHC_ModelSqliteKit.svg?style=flat)](http://cocoadocs.org/docsets/WHC_ModelSqliteKit/)
[![Pod License](http://img.shields.io/cocoapods/l/WHC_ModelSqliteKit.svg?style=flat)](https://opensource.org/licenses/MIT)

架构图
==============
<div align=center><img src="https://github.com/netyouli/WHC_ModelSqliteKit/blob/master/architecture.png"/></div></br>

- Professional database storage solutions, thread safe, high-performance model object storage Sqlite open source library, realize one line of code database operation, simple database storage
- 专业的数据库存储解决方案，线程安全，高性能模型对象存储Sqlite开源库，真正实现一行代码操作数据库，让数据库存储变得简单

简介
==============
- **架构**: 采用runtime和Sqlite完美结合打造的强大数据库操作引擎开源库
- **安全**: 支持数据库级别加密
- **易用**: 真正实现一行代码操作数据库
- **目标**: 替代直接使用Sqlite和CoreData以及FMDB低效率方式
- **支持**: (NSArray,NSDictionary,NSDate,NSData,NSString,NSNumber,Int,double,float,Bool,char)类型
- **灵活**: 支持使用Sqlite函数进行查询,支持忽略模型类属性存储数据表中
- **强大**: 支持模型嵌套继承模型类存储到数据库和多表嵌套复杂查询
- **智能**: 根据数据库模型类实现的WHC_SqliteInfo协议返回的版本号来智能更新数据库字段(动态删除/添加)
- **咨询**: 712641411
- **作者**: 吴海超

多表嵌套复杂查询
==============
```objective-c
/// 查询person名称为吴海超，并且person的汽车对象的名称为宝马或者person对象学校对象的所在城市对象的名称为北京
NSArray * result = [WHCSqlite query:[Person class] 
        where:@"name = '吴海超' and car.name = '宝马' or school.city.name = '北京'"];
```

自定义sql查询
==============
```objective-c
persons = [WHCSqlite query:Person.self sql:@"select * from Person"];

/// 来个复杂的例如：
[WHCSqlite query:Model.self sql:@"select cc.* from 
     ( select tt.*,(select count(*)+1 from Chapter where chapter_id =tt.chapter_id and updateTime<tt.updateTime ) as group_id from Chapter tt)
     cc where cc.group_id<=7 order by updateTime desc"];
```

要求
==============
* iOS 5.0 or later
* Xcode 8.0 or later


集成
==============
* 使用CocoaPods:
-  pod 'WHC_ModelSqliteKit'
* 需要加密数据库使用CocoaPods:
-  pod 'WHC_ModelSqliteKit/SQLCipher'
* 手工集成:
-  导入文件夹WHC_ModelSqliteKit

注意
==============
* 在需要对数据表自定义信息需要model类实现WHC_SqliteInfo协议
- 当模型类有新增/删除属性的时候需要在模型类里定义类方法whc_SqliteVersion方法修改模型类(数据库)版本号来表明有字段更新操作，库会根据这个VERSION变更智能检查并自动更新数据库字段，无需手动更新数据库字段
- 当存储NSArray/NSDictionary属性并且里面是自定义模型对象时，模型对象必须实现NSCoding协议，可以使用[WHC_Model](https://github.com/netyouli/WHC_Model)库一行代码实现NSCoding相关代码
- 当需要模型类忽略属性存储数据表时实现whc_IgnorePropertys协议方法即可return要忽略属性名称数组
- 好用的Mac开源工具：[Json生成Class](https://github.com/netyouli/WHC_DataModelFactory),[扫描无用图片](https://github.com/netyouli/WHC_ScanUnreferenceImageTool),[扫描无用类](https://github.com/netyouli/WHC_Scan),[keyborad](https://github.com/netyouli/WHC_KeyboardManager)
- 如果要获取主键id需要在model里声明属性：@property (nonatomic, assign) NSInteger whcId; 

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
*** CocoaPods: pod 'WHC_ModelSqlite/SQLCipher' ***
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

@end
```

用法
==============
#### 1.存储嵌套模型对象到数据库演示
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
whc.array = @[@"1",@"2"];
whc.carArray = @[tempCar];

/// 测试NSDictionary属性存储
whc.dict = @{@"1":@"2"};
whc.dictCar = @{@"car": tempCar};

[WHCSqlite insert:whc];
```

#### 2.存储批量模型对象到数据库演示
```objective-c
NSArray * persons = [self makeArrayPerson];
[WHCSqlite inserts:persons];
```

#### 3.无条件查询(查询所有记录)数据库中模型类演示
```objective-c
NSArray * personArray = [WHCSqlite query:[Person class]];

```

#### 3.1.使用Sqlite函数查询数据库演示
```objective-c
/// 获取Person表所有name和name长度
NSArray * nameArray = [WHCSqlite query:[Person class] func:@"name, length(name)"];
NSLog(@"nameArray = %@",nameArray);

/// 获取Person表最大age值
NSNumber * maxAge = [WHCSqlite query:[Person class] func:@"max(age)"];
NSLog(@"maxAge = %@",maxAge);

/// 获取Person表总记录数
NSNumber * sumCount = [WHCSqlite query:[Person class] func:@"count(*)"];
NSLog(@"sumCount = %@",sumCount);

/// 获取Person表字段school.city.name = 北京--0,总记录数
sumCount = [WHCSqlite query:[Person class] func:@"count(*)" condition:@"where school.city.name = '北京--0'"];
NSLog(@"sumCount = %@",sumCount);

```

#### 4.条件查询数据库中模型类演示(where 条件查询语法和sql where条件查询语法一样)
```objective-c
NSArray * personArray = [WHCSqlite query:[Person class] where:@"name = '吴海超2' OR age <= 18"];
```

#### 5.查询数据库并对结果排序
```objective-c
///对person数据表查询并且根据age自动降序或者升序排序
[WHCSqlite query:[Person class] order:@"by age desc/asc"];
```

#### 6.查询数据库并对结果限制查询条数
```objective-c
/// 对person数据表查询并且并且限制查询数量为8
[WHCSqlite query:[Person class] limit:@"8"];

/// 对person数据表查询并且对查询列表偏移8并且限制查询数量为8
[WHCSqlite query:[Person class] limit:@"8 offset 8"];

```

#### 7.修改数据库中模型对象演示(where 条件查询语法和sql where条件查询语法一样) 
```objective-c
/// 更新整条记录
[WHCSqlite update:whc where:@"name = '吴海超2' OR age <= 18"];
/// 更新整条记录中的指定字段（更新Person表在age字段大于25岁时name值为whc，age为100岁）
[WHCSqlite update:Person.self value:@"name = 'whc', age = 100" where:@"age > 25"];
```
#### 8.删除数据库中模型对象演示(where条件查询为空则删除所有)
```objective-c
[WHCSqlite delete:[Person class] where:@"age = 25 AND name = '吴海超'"];
```

#### 9.清空指定数据库演示
```objective-c
[WHCSqlite clear:[Person class]];
```

#### 10.删除数据库演示
```objective-c
[WHCSqlite removeModel:[Person class]];
```

#### 11.删除所有数据库演示
```objective-c
[WHCSqlite removeAllModel];
```

#### 12.获取数据库本地路径演示
```objective-c
NSString * path = [WHCSqlite localPathWithModel:[Person class]];
```
#### 13.获取数据库本地版本号演示
```objective-c
NSString * path = [WHCSqlite versionWithModel:[Person class]];
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

```
## Licenses
All source code is licensed under the MIT License.
