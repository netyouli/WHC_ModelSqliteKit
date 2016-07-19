# WHC_ModelSqliteKit

###咨询qq:712641411
###作者：吴海超

##### 1.专业数据模型存储解决方案(告别直接使用sqlite和coreData)
##### 2.告别繁琐sql语句的编写
##### 3.告别coreData复杂繁琐创建
##### 4.WHC_ModelSqliteKit采用运行时技术动态识别模型属性信息智能创建和编辑数据库
##### 5.目前支持字段存储类型(NSString,Int,double,float,Bool,char,NSNumber)
##### 6.直接淘汰FMDB开源库
### 7.支持模型嵌套模型类存储到数据库，多表嵌套联查
### 8.智能根据模型属性名称类型更新模型数据库表里字段(动态添加字段和删除字段)
### 9.告别数据库字段变更带来的烦恼

###升级更新日志
##### 1.不好意思光专注模型嵌套模型查询解决方案，忘了但模型查询，已经修复了单模型查询不到数据的bug。
##### 2.修复了NSNumber属性查询时的错误bug。

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

####5.修改数据库中模型对象演示(where 条件查询语法和sql where条件查询语法一样) 
```objective-c
[WHC_ModelSqlite update:whc where:@"name = '吴海超2' OR age <= 18"];
```
####6.删除数据库中模型对象演示(where条件查询为空则删除所有)
```objective-c
[WHC_ModelSqlite delete:[Person class] where:@"age = 25 AND name = '吴海超'"];
```

####7.清空指定数据库演示
```objective-c
[WHC_ModelSqlite clear:[Person class]];
```

####8.删除数据库演示
```objective-c
[WHC_ModelSqlite removeModel:[Person class]];
```

####9.删除所有数据库演示
```objective-c
[WHC_ModelSqlite removeAllModel];
```

####10.获取数据库本地路径演示
```objective-c
NSString * path = [WHC_ModelSqlite localPathWithModel:[Person class]];
```
####11.获取数据库本地版本号演示
```objective-c
NSString * path = [WHC_ModelSqlite versionWithModel:[Person class]];
```
