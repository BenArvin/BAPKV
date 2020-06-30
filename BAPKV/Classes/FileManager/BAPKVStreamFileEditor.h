//
//  BAPKVStreamFileEditor.h
//  BAPKV
//
//  Created by arvinnie on 2020/6/29.
//

#import <Foundation/Foundation.h>

@interface BAPKVStreamFileEditor : NSObject

- (instancetype)initWith:(NSString *)path;

- (NSData *)read:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error;
- (BOOL)append:(NSData *)content error:(NSError **)error;
- (BOOL)delete:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error;
- (BOOL)insert:(NSUInteger)location content:(NSData *)content error:(NSError **)error;

@end
