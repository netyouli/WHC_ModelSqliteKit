//
//  ViewController.m
//  WHC_ModelSqliteKit
//
//  Created by admin on 16/5/29.
//  Copyright © 2016年 WHC. All rights reserved.
//



#import "ViewController.h"
#import "WHC_ModelSqlite.h"

@interface Person : NSObject
@property (nonatomic, copy) NSString * name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) CGFloat weight;
@property (nonatomic, assign) double height;
@property (nonatomic, assign) BOOL isDeveloper;
@property (nonatomic, assign) char sex;
@end

@implementation Person
@end


@interface ViewController ()
@property (nonatomic, weak)IBOutlet UILabel * detailLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _detailLabel.text = @"开发者:WHC(吴海超)\n\n专业的数据存储解决方案\n\n由于本开源库主要针对数据存储解决方案所以没有UI演示\n\n测试者可以通过ViewController里测试用例进行断点查看\n\n觉得不错请给予star支持,谢谢";
    
    [WHC_ModelSqlite removeAllModel];
    
    /// 1.存储单个模型对象到数据库演示代码
    Person * whc = [Person new];
    whc.name = @"吴海超";
    whc.age = 25;
    whc.height = 180.0;
    whc.weight = 140.0;
    whc.isDeveloper = YES;
    whc.sex = 'm';
    
    if ([WHC_ModelSqlite insert:whc]) {
        NSLog(@"1.存储单个模型对象到数据库演示代码");
    }
    
    /// 1.1查询上面存储的模型对象
        // where 参数为空查询所有, 查询语法和sql 语句一样
    NSArray * personArray = [WHC_ModelSqlite query:[Person class] where:nil];
    [personArray enumerateObjectsUsingBlock:^(Person *  _Nonnull person, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"第%lu条数据",(unsigned long)idx);
        NSLog(@"name = %@",person.name);
        NSLog(@"age = %lu",person.age);
        NSLog(@"height = %f",person.height);
        NSLog(@"weight = %f",person.weight);
        NSLog(@"isDeveloper = %d",person.isDeveloper);
        NSLog(@"sex = %c",person.sex);
        NSLog(@"---------------------------------");
    }];
    
    /// 2.批量存储模型对象到数据库演示代码
    
    NSArray * persons = [self makeArrayPerson];
    if ([WHC_ModelSqlite insertArray:persons]) {
        NSLog(@"2.批量存储模型对象到数据库演示代码");
    }
    
    /// 2.1 查询上面存储的模型对象演示代码
    
    personArray = [WHC_ModelSqlite query:[Person class] where:nil];
    [personArray enumerateObjectsUsingBlock:^(Person *  _Nonnull person, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"第%lu条数据",(unsigned long)idx);
        NSLog(@"name = %@",person.name);
        NSLog(@"age = %lu",person.age);
        NSLog(@"height = %f",person.height);
        NSLog(@"weight = %f",person.weight);
        NSLog(@"isDeveloper = %d",person.isDeveloper);
        NSLog(@"sex = %c",person.sex);
        NSLog(@"---------------------------------");
    }];
    
    /// 2.2 条件查询存储的模型对象演示代码
    
    personArray = [WHC_ModelSqlite query:[Person class] where:@"age > 20"];
    [personArray enumerateObjectsUsingBlock:^(Person *  _Nonnull person, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"第%lu条数据",(unsigned long)idx);
        NSLog(@"name = %@",person.name);
        NSLog(@"age = %lu",person.age);
        NSLog(@"height = %f",person.height);
        NSLog(@"weight = %f",person.weight);
        NSLog(@"isDeveloper = %d",person.isDeveloper);
        NSLog(@"sex = %c",person.sex);
        NSLog(@"---------------------------------");
    }];
    
    /// 3.修改存储模型对象演示代码
    
    if ([WHC_ModelSqlite update:whc where:@"name = '吴海超2' OR age <= 18"]) {
        NSLog(@"修改批量模型对象成功");
    }
    
    /// 3.1 查询刚刚修改是否成功示例代码
    
    personArray = [WHC_ModelSqlite query:[Person class] where:@"age = 25 AND name = '吴海超'"];
    [personArray enumerateObjectsUsingBlock:^(Person *  _Nonnull person, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"第%lu条数据",(unsigned long)idx);
        NSLog(@"name = %@",person.name);
        NSLog(@"age = %lu",person.age);
        NSLog(@"height = %f",person.height);
        NSLog(@"weight = %f",person.weight);
        NSLog(@"isDeveloper = %d",person.isDeveloper);
        NSLog(@"sex = %c",person.sex);
        NSLog(@"---------------------------------");
    }];
    
    /// 4.删除存储模型对象演示代码
        /*注 where 为空时则表示清空数据库*/
    if ([WHC_ModelSqlite delete:[Person class] where:@"age = 25 AND name = '吴海超'"]) {
        NSLog(@"删除批量模型对象成功");
    }
    
    /// 4.1 查询刚刚删除是否成功示例代码
    personArray = [WHC_ModelSqlite query:[Person class] where:nil];
    [personArray enumerateObjectsUsingBlock:^(Person *  _Nonnull person, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"第%lu条数据",(unsigned long)idx);
        NSLog(@"name = %@",person.name);
        NSLog(@"age = %lu",person.age);
        NSLog(@"height = %f",person.height);
        NSLog(@"weight = %f",person.weight);
        NSLog(@"isDeveloper = %d",person.isDeveloper);
        NSLog(@"sex = %c",person.sex);
        NSLog(@"---------------------------------");
    }];
    
    /// 5.1 清空数据库
    [WHC_ModelSqlite clear:[Person class]];
    
    /// 6.1 删除数据库
    [WHC_ModelSqlite removeModel:[Person class]];
    
    /// 7.1删除本地所有数据库
    [WHC_ModelSqlite removeAllModel];
    
    /// 8.1 获取数据库本地路径
    NSString * path = [WHC_ModelSqlite localPathWithModel:[Person class]];
    NSLog(@"localPath = %@",path);
    
}

- (NSArray *)makeArrayPerson {
    NSMutableArray * personArray = [NSMutableArray array];
    for (int i = 0; i < 10; i++) {
        Person * person = [Person new];
        person.name = [NSString stringWithFormat:@"吴海超%d",i];
        person.age = 15 + i;
        person.height = 170.0 + i;
        person.weight = 140.0;
        person.isDeveloper = YES;
        person.sex = 'm';
        [personArray addObject:person];
    }
    return personArray;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
