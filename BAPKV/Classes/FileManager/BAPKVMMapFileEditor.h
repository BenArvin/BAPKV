//
//  BAPKVMMapFileEditor.h
//  BAPKV
//
//  Created by benarvin on 2020/10/30.
//

#import <Foundation/Foundation.h>

extern int const kBAPKVMMapFileEditorBaseSize;

@interface BAPKVMMapFileEditor : NSObject

- (BOOL)load:(NSString *)path size:(long long)size error:(NSError **)error;
- (void)unload;

- (BOOL)getSize:(long long *)size error:(NSError **)error;
- (BOOL)resize:(long long)size error:(NSError **)error;

- (BOOL)read:(size_t)location length:(size_t)length data:(NSData **)data error:(NSError **)error;
- (BOOL)write:(NSData *)data location:(size_t)location error:(NSError **)error;
- (BOOL)delete:(size_t)location length:(size_t)length error:(NSError **)error;

@end
