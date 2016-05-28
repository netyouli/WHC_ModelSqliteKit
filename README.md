# WHC_ModelSqliteKit

##### 联系QQ: 712641411
##### 开发作者: 吴海超
##### iOS技术交流群: 302157745

##### 1.专业数据模型存储解决方案(告别直接使用sqlite和coreData)
##### 2.告别繁琐sql语句的编写
##### 3.告别coreData复杂繁琐创建
##### 4.WHC_ModelSqliteKit采用运行时技术动态识别模型属性信息智能创建和编辑数据库
##### 5.目前支持字段存储类型(NSString,Int,double,float,Bool,char,NSNuber)不支持模型类嵌套

####1.存储单个模型对象到数据库演示
```objective-c
Person * whc = [Person new];
whc.name = @"吴海超";
whc.age = 25;
whc.height = 180.0;
whc.weight = 140.0;
whc.isDeveloper = YES;
whc.sex = 'm';

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
NSArray * personArray = [WHC_ModelSqlite update:whc where:@"name = '吴海超2' OR age <= 18"];
```

####5.删除数据库中模型对象演示(where条件查询为空则删除所有)
```objective-c
[WHC_ModelSqlite delete:[Person class] where:@"age = 25 AND name = '吴海超'"];
```

####6.清空指定数据库演示
```objective-c
[WHC_ModelSqlite clear:[Person class]];
```

####7.删除数据库演示
```objective-c
[WHC_ModelSqlite removeModel:[Person class]];
```

####8.删除所有数据库演示
```objective-c
[WHC_ModelSqlite removeAllModel];
```

####9.获取数据库本地路径演示
```objective-c
NSString * path = [WHC_ModelSqlite localPathWithModel:[Person class]];
```

