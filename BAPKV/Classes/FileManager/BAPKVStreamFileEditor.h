//
//  BAPKVStreamFileEditor.h
//  BAPKV
//
//  Created by benarvin on 2020/6/29.
//

#import <Foundation/Foundation.h>

@interface BAPKVStreamFileEditor : NSObject

- (instancetype)initWith:(NSString *)path;

- (NSData *)read:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error;
- (BOOL)append:(NSData *)content error:(NSError **)error;
- (BOOL)delete:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error;
- (BOOL)insert:(NSUInteger)location content:(NSData *)content error:(NSError **)error;

/// Get file size, it's slow. Return -1if path invalid.
/// @param path target file path
+ (NSInteger)getSize:(NSString *)path;

@end
