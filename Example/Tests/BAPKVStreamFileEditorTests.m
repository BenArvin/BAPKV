//
//  BAPKVTests.m
//  BAPKVTests
//
//  Created by benarvin on 06/29/2020.
//  Copyright (c) 2020 benarvin. All rights reserved.
//
#import <BAPKV/BAPKVStreamFileEditor.h>

@import XCTest;

@interface BAPKVStreamFileEditorTests : XCTestCase

@end

@implementation BAPKVStreamFileEditorTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRead {
    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *targetPath = [document stringByAppendingPathComponent:@"testFile"];
    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    [[@"abcdefghijkl" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:targetPath atomically:YES];
    
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijkl"]);
    
    BAPKVStreamFileEditor *editor = [[BAPKVStreamFileEditor alloc] initWith:targetPath];
    
    NSError *e1;
    NSData *data1 = [editor read:0 length:NSUIntegerMax error:&e1];
    
    XCTAssert(e1 == nil);
    XCTAssert(data1 != nil);
    
    NSString *str1 = [[NSString alloc] initWithData:data1 encoding:NSUTF8StringEncoding];
    XCTAssert([str1 isEqualToString:@"abcdefghijkl"]);
    
    
    NSError *e2;
    NSData *data2 = [editor read:2 length:2 error:&e2];
    
    XCTAssert(e2 == nil);
    XCTAssert(data2 != nil);
    
    NSString *str2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
    XCTAssert([str2 isEqualToString:@"cd"]);
    
    NSError *e3;
    NSData *data3 = [editor read:NSUIntegerMax length:2 error:&e3];
    
    XCTAssert(e3 == nil);
    XCTAssert(data3 == nil);
    
    NSError *e4;
    NSData *data4 = [editor read:2 length:0 error:&e4];
    
    XCTAssert(e4 == nil);
    XCTAssert(data4 == nil);
}

- (void)testAppend {
    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *targetPath = [document stringByAppendingPathComponent:@"testFile"];
    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    [[@"abcdefghijkl" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:targetPath atomically:YES];
    
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijkl"]);
    
    BAPKVStreamFileEditor *editor = [[BAPKVStreamFileEditor alloc] initWith:targetPath];
    
    NSError *e1;
    BOOL s1 = [editor append:[@"mn" dataUsingEncoding:NSUTF8StringEncoding] error:&e1];
    XCTAssert(s1 == YES);
    XCTAssert(e1 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijklmn"]);
    
    NSError *e2;
    BOOL s2 = [editor append:nil error:&e2];
    XCTAssert(s2 == YES);
    XCTAssert(e2 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijklmn"]);
    
    NSError *e3;
    BOOL s3 = [editor append:[[NSData alloc] init] error:&e3];
    XCTAssert(s3 == YES);
    XCTAssert(e3 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijklmn"]);
}

- (void)testDelete {
    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *targetPath = [document stringByAppendingPathComponent:@"testFile"];
    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    [[@"abcdefghijkl" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:targetPath atomically:YES];
    
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijkl"]);
    
    BAPKVStreamFileEditor *editor = [[BAPKVStreamFileEditor alloc] initWith:targetPath];
    
    NSError *e1;
    BOOL s1 = [editor delete:2 length:2 error:&e1];
    XCTAssert(s1 == YES);
    XCTAssert(e1 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"abefghijkl"]);
    
    NSError *e2;
    BOOL s2 = [editor delete:2 length:NSUIntegerMax error:&e2];
    XCTAssert(s2 == YES);
    XCTAssert(e2 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"ab"]);
    
    NSError *e3;
    BOOL s3 = [editor delete:NSUIntegerMax length:NSUIntegerMax error:&e3];
    XCTAssert(s3 == YES);
    XCTAssert(e3 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"ab"]);
    
    NSError *e4;
    BOOL s4 = [editor delete:0 length:NSUIntegerMax error:&e4];
    XCTAssert(s4 == YES);
    XCTAssert(e4 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:nil]);
}

- (void)testInsert {
    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *targetPath = [document stringByAppendingPathComponent:@"testFile"];
    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    [[@"abcdefghijkl" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:targetPath atomically:YES];
    
    XCTAssert([self checkFileContent:targetPath compareWith:@"abcdefghijkl"]);
    
    BAPKVStreamFileEditor *editor = [[BAPKVStreamFileEditor alloc] initWith:targetPath];
    
    NSError *e1;
    BOOL s1 = [editor insert:0 content:[@"12" dataUsingEncoding:NSUTF8StringEncoding] error:&e1];
    XCTAssert(s1 == YES);
    XCTAssert(e1 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"12abcdefghijkl"]);
    
    NSError *e2;
    BOOL s2 = [editor insert:NSUIntegerMax content:[@"34" dataUsingEncoding:NSUTF8StringEncoding] error:&e2];
    XCTAssert(s2 == YES);
    XCTAssert(e2 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"12abcdefghijkl34"]);
    
    NSError *e3;
    BOOL s3 = [editor insert:0 content:nil error:&e3];
    XCTAssert(s3 == YES);
    XCTAssert(e3 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"12abcdefghijkl34"]);
    
    NSError *e4;
    BOOL s4 = [editor insert:0 content:[[NSData alloc] init] error:&e4];
    XCTAssert(s4 == YES);
    XCTAssert(e4 == nil);
    XCTAssert([self checkFileContent:targetPath compareWith:@"12abcdefghijkl34"]);
}

#pragma mark - utils methods
- (BOOL)checkFileContent:(NSString *)path compareWith:(NSString *)baseStr {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || data.length == 0) {
        if (!baseStr) {
            return YES;
        } else {
            return NO;
        }
    } else if (!baseStr) {
        return NO;
    }
    NSString *strTmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [strTmp isEqualToString:baseStr];
}

@end

