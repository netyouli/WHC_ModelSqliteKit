//
//  Person.h
//  WHC_ModelSqliteKit
//
//  Created by WHC on 16/6/21.
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
#import "WHC_ModelSqlite.h"
#import "Car.h"
#import "School.h"
#import "Animal.h"

@interface Person : Animal<WHC_SqliteInfo>
@property (nonatomic, assign) NSInteger whcId;   /// 主键
@property (nonatomic, assign) NSInteger _id;   /// 主键
@property (nonatomic, copy) NSString * name;
@property (nonatomic, assign) long age;
@property (nonatomic, assign) float weight;
@property (nonatomic, assign) double height;
@property (nonatomic, assign) BOOL isDeveloper;
@property (nonatomic, strong) NSString * xx;
@property (nonatomic, strong) NSString * yy;
@property (nonatomic, strong) NSString * ww;
@property (nonatomic, assign) char sex;
@property (nonatomic, strong) NSString * type;
@property (nonatomic, strong) Car * car;
@property (nonatomic, strong) School * school;
@property (nonatomic, strong) NSNumber * zz;
@property (nonatomic, strong) NSData * data;
@property (nonatomic, strong) NSArray * array;
@property (nonatomic, strong) NSArray * carArray;
@property (nonatomic, strong) NSDictionary * dict;
@property (nonatomic, strong) NSDictionary * dictCar;

/// 下面是忽略属性
@property (nonatomic, strong) NSString * ignoreAttr1;
@property (nonatomic, strong) NSString * ignoreAttr2;
@property (nonatomic, strong) NSString * ignoreAttr3;

+ (NSString *)whc_SqliteVersion;
+ (NSArray *)whc_IgnorePropertys;
@end
