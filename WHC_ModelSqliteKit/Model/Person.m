//
//  Person.m
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

#import "Person.h"

@implementation Person

+ (NSArray *)whc_IgnorePropertys {
    return @[@"ignoreAttr1",
             @"ignoreAttr2",
             @"ignoreAttr3"];
}

+ (NSString *)whc_SqliteVersion {
    return @"1.0.0";
}

+ (NSString *)whc_OtherSqlitePath {
    return [NSString stringWithFormat:@"%@/Library/per.db",NSHomeDirectory()];
}
@end
