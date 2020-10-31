//
//  BAPKVMMapFileEditor.m
//  BAPKV
//
//  Created by benarvin on 2020/10/30.
//

#import "BAPKVMMapFileEditor.h"
#import <BAError/NSError+BAError.h>
#import <sys/mman.h>
#import <sys/stat.h>

typedef NS_ENUM(NSUInteger, BAPKVMMapFileEditorErrorCode) {
    BAPKVMMapFileEditorErrorCodeLoadActionFailed = 1000,
    BAPKVMMapFileEditorErrorCodeWriteActionFailed = 1001,
    BAPKVMMapFileEditorErrorCodeReadActionFailed = 1002,
    BAPKVMMapFileEditorErrorCodeDeleteActionFailed = 1003,
    BAPKVMMapFileEditorErrorCodeGetSizeActionFailed = 1004,
    BAPKVMMapFileEditorErrorCodeResizeActionFailed = 1005,
    
    BAPKVMMapFileEditorErrorCodeOpenFileFailed = 1900,
    BAPKVMMapFileEditorErrorCodeReadStatFailed = 1901,
    BAPKVMMapFileEditorErrorCodeResizeFailed = 1902,
};

int const kBAPKVMMapFileEditorBaseSize = 16 * 1024;

@interface BAPKVMMapFileEditor() {
}

@property (atomic) BOOL loaded;
@property (nonatomic) NSString *path;
@property (nonatomic) long long size;
@property (nonatomic) int fd;
@property (nonatomic) void *m_ptr;

@end

@implementation BAPKVMMapFileEditor

- (void)dealloc {
    [self unload];
}

#pragma mark - public methods
- (BOOL)load:(NSString *)path size:(long long)size error:(NSError **)error {
    if (self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:@"File already loaded, please unload first" cause:nil];
        }
        return NO;
    }
    if (!path || path.length == 0) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:[NSString stringWithFormat:@"Invalid path: %@", path] cause:nil];
        }
        [self unload];
        return NO;
    }
    BOOL isDirectory;
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exist || isDirectory) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:[NSString stringWithFormat:@"Invalid path: %@", path] cause:nil];
        }
        [self unload];
        return NO;
    }
    
    NSError *openFileError;
    BOOL openFileSuccessed = [self openFile:path fd:&_fd mode:O_RDWR error:&openFileError];
    if (!openFileSuccessed) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:@"Open file failed!" cause:openFileError];
        }
        [self unload];
        return NO;
    }
    
    struct stat statInfo;
    NSError *readStatError;
    BOOL readStatSuccessed = [self readFileStatInfo:_fd statInfo:&statInfo error:&readStatError];
    if (!readStatSuccessed) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:@"Read file stat info failed!" cause:readStatError];
        }
        [self unload];
        return NO;
    }
    
    self.size = [self floorSize:size];
    if (statInfo.st_size < self.size) {
        NSError *resizeError;
        BOOL resizeSuccessed = [self resize:_fd size:self.size error:&resizeError];
        if (!resizeSuccessed) {
            if (error) {
                *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:@"Resize file failed!" cause:resizeError];
            }
            [self unload];
            return NO;
        }
    } else {
        self.size = statInfo.st_size;
    }
    
    self.m_ptr = mmap(NULL, self.size, PROT_READ | PROT_WRITE, MAP_SHARED, _fd, 0);
    
    if (self.m_ptr == MAP_FAILED) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeLoadActionFailed description:@"mmap action failed!" cause:nil];
        }
        [self unload];
        return NO;
    }
    self.path = path;
    self.loaded = YES;
    return YES;
}

- (void)unload {
    if (self.fd != -1) {
        close(self.fd);
        self.fd = -1;
    }
    if (self.m_ptr != MAP_FAILED) {
        munmap(self.m_ptr, self.size);
        self.m_ptr = MAP_FAILED;
    }
    self.loaded = NO;
}

- (BOOL)getSize:(long long *)size error:(NSError **)error {
    if (!self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeGetSizeActionFailed description:@"File unloaded" cause:nil];
        }
        return NO;
    }
    struct stat statInfo;
    BOOL getSizeSuccessed = [self readFileStatInfo:self.fd statInfo:&statInfo error:error];
    if (!getSizeSuccessed) {
        return NO;
    }
    self.size = statInfo.st_size;
    if (size) {
        *size = statInfo.st_size;
    }
    return YES;
}

- (BOOL)resize:(long long)size error:(NSError **)error {
    if (!self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeResizeActionFailed description:@"File unloaded" cause:nil];
        }
        return NO;
    }
    [self unload];
    NSError *errorTmp;
    BOOL reloadSuccessed = [self load:self.path size:size error:&errorTmp];
    if (!reloadSuccessed) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeResizeActionFailed description:@"Reload file failed" cause:errorTmp];
        }
        return NO;
    }
    return YES;
}

- (BOOL)read:(size_t)location length:(size_t)length data:(NSData **)data error:(NSError **)error {
    if (!self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeReadActionFailed description:@"File unloaded" cause:nil];
        }
        return NO;
    }
    if (location + length > self.size) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeReadActionFailed description:@"Out of range" cause:nil];
        }
        return NO;
    }
    BOOL readFailed = NO;
    NSMutableData *result = nil;
    void *ptr_tmp = self.m_ptr + location;
    size_t leftedLength = length;
    while (leftedLength > 0) {
        size_t lengthTmp = leftedLength;
        if (leftedLength > 1024) {
            lengthTmp = 1024;
        }
        uint8_t buffer[lengthTmp];
        memcpy(buffer, ptr_tmp, lengthTmp);
        NSData *dataTmp = [NSData dataWithBytes:buffer length:lengthTmp];
        if (!dataTmp) {
            readFailed = YES;
            break;
        }
        if (!result) {
            result = [[NSMutableData alloc]init];
        }
        [result appendData:dataTmp];
        leftedLength = leftedLength - lengthTmp;
        ptr_tmp = ptr_tmp + lengthTmp;
    }
    if (readFailed) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeReadActionFailed description:@"Read data from ptr failed" cause:nil];
        }
        return NO;
    }
    if (data) {
        *data = result;
    }
    return YES;
}

- (BOOL)write:(NSData *)data location:(size_t)location error:(NSError **)error {
    if (!data || data.length == 0) {
        return YES;
    }
    if (!self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeWriteActionFailed description:@"File unloaded" cause:nil];
        }
        return NO;
    }
    if (location + data.length > self.size) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeWriteActionFailed description:@"Out of range" cause:nil];
        }
        return NO;
    }
    memcpy(self.m_ptr + location, data.bytes, data.length);
//    msync(self.m_ptr + location, data.length, MS_SYNC);
    msync(self.m_ptr, self.size, MS_SYNC);
    return YES;
}

- (BOOL)delete:(size_t)location length:(size_t)length error:(NSError **)error {
    if (!self.loaded) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeDeleteActionFailed description:@"File unloaded" cause:nil];
        }
        return NO;
    }
    if (location + length > self.size) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeDeleteActionFailed description:@"Out of range" cause:nil];
        }
        return NO;
    }
    memset(self.m_ptr + location, 0, length);
//    msync(self.m_ptr + location, length, MS_SYNC);
    msync(self.m_ptr, self.size, MS_SYNC);
    return YES;
}

#pragma mark - private methods
- (long long)floorSize:(long long)size {
    return floor(size / kBAPKVMMapFileEditorBaseSize) * kBAPKVMMapFileEditorBaseSize;
}

- (NSError *)simpleError:(NSUInteger)code description:(NSString *)description cause:(NSError *)cause {
    return [NSError bae_errorWith:NSStringFromClass([self class]) code:code description:description causes: cause, nil];
}

- (BOOL)openFile:(NSString *)path fd:(int *)fd mode:(int)mode error:(NSError **)error {
    errno = 0;
    *fd = open(path.UTF8String, mode);
    if (*fd == -1) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeOpenFileFailed description:[NSString stringWithFormat:@"Open file failed: %d, %s", errno, strerror(errno)] cause:nil];
        }
        return NO;
    }
    return YES;
}

- (BOOL)readFileStatInfo:(int)fd statInfo:(struct stat *)statInfo error:(NSError **)error {
    errno = 0;
    int getStatResult = fstat(fd, statInfo);
    if (getStatResult == -1) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeReadStatFailed description:[NSString stringWithFormat:@"Read file stat info failed: %d, %s", errno, strerror(errno)] cause:nil];
        }
        return NO;
    }
    return YES;
}

- (BOOL)resize:(int)fd size:(long long)size error:(NSError **)error {
    errno = 0;
    int resizeSuccessed = ftruncate(fd, size);
    fsync(fd);
    if (resizeSuccessed == -1) {
        if (error) {
            *error = [self simpleError:BAPKVMMapFileEditorErrorCodeResizeFailed description:[NSString stringWithFormat:@"Resize file failed: %d, %s", errno, strerror(errno)] cause:nil];
        }
        return NO;
    }
    return YES;
}

@end
