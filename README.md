# WHC_ModelSqliteKit

###咨询qq:712641411
###作者：吴海超

#####VERSION 2.2.1

##### 1.专业数据模型存储解决方案(告别直接使用sqlite和coreData)
##### 2.告别繁琐sql语句的编写
##### 3.告别coreData复杂繁琐创建
##### 4.WHC_ModelSqliteKit采用运行时技术动态识别模型属性信息智能创建和编辑数据库
##### 5.目前支持字段存储类型(NSData,NSString,Int,double,float,Bool,char,NSNumber)
##### 6.直接淘汰FMDB开源库
### 7.支持模型嵌套模型类存储到数据库，多表嵌套联查
### 8.智能根据模型属性名称类型更新模型数据库表里字段(动态添加字段和删除字段)
### 9.告别数据库字段变更带来的烦恼

##### Note1：修改(增加/删除)数据表字段时候请先修改模型类+(NSString *)VERSION方法里版本号
##### Note2：页面最后有详细的Api文档

###升级更新日志
##### 1.不好意思光专注模型嵌套模型查询解决方案，忘了但模型查询，已经修复了单模型查询不到数据的bug。
##### 2.修复了NSNumber属性查询时的错误bug。
##### 3.支持NSData类型存取(可以存图片)
##### 4.修复若干潜在bug，提升稳定性。
##### 5.增加查询排序和限制查询条数功能。
##### 6.重构查询架构
##### 7.修复嵌套存储子模型类对象为nil时崩溃bug
##### 8.修复删除单模型记录失败bug和clear多线程死锁bug
##### 9.增加query系列方法

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

[WHC_ModelSqlite insert:whc];
```

####2.存储批量模型对象到数据库演示
```objective-c
NSArray * persons = [self makeArrayPerson];
[WHC_ModelSqlite insertArray:persons];
```

####3.无条件查询数据库中模型类演示
```objective-c
NSArray * personArray = [WHC_ModelSqlite query:[Person class] where:nil];
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

###14.Api文档
```objective-c
/**
* 说明: 存储模型数组到本地(事务方式)
* @param model_array 模型数组对象(model_array 里对象类型要一致)
*/

+ (void)insertArray:(NSArray *)model_array;

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
