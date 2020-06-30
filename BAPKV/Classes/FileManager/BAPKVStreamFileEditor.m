//
//  BAPKVStreamFileEditor.m
//  BAPKV
//
//  Created by arvinnie on 2020/6/29.
//

#import "BAPKVStreamFileEditor.h"
#import <BAOCxxHash/BAOCxxHash.h>

static const NSUInteger BAPKVStreamFileEditorSliceSize = 1024;

typedef NS_ENUM(NSUInteger, BAPKVStreamFileEditorErrorCode) {
    BAPKVStreamFileEditorErrorCodeReadActionInvalidStatus = 1001,
    BAPKVStreamFileEditorErrorCodeReadActionReadFailed = 1002,
    BAPKVStreamFileEditorErrorCodeReadActionToDataFailed = 1003,
    
    BAPKVStreamFileEditorErrorCodeAppendActionInvalidStatus = 1031,
    BAPKVStreamFileEditorErrorCodeAppendActionNoSpace = 1032,
    BAPKVStreamFileEditorErrorCodeAppendActionWriteFailed = 1033,
    
    BAPKVStreamFileEditorErrorCodeTranscribeActionInvalidStatus = 1011,
    BAPKVStreamFileEditorErrorCodeTranscribeActionReadFailed = 1012,
    BAPKVStreamFileEditorErrorCodeTranscribeActionWriteFailed = 1013,
    BAPKVStreamFileEditorErrorCodeTranscribeActionNoSpace = 1014,
    
    BAPKVStreamFileEditorErrorCodeDeleteActionInvalidStatus = 1021,
    BAPKVStreamFileEditorErrorCodeDeleteActionFirstPartUnknownError = 1022,
    BAPKVStreamFileEditorErrorCodeDeleteActionSecondPartUnknownError = 1023,
    
    BAPKVStreamFileEditorErrorCodeInsertActionInvalidStatus = 1041,
    BAPKVStreamFileEditorErrorCodeInsertActionFirstPartUnknownError = 1042,
    BAPKVStreamFileEditorErrorCodeInsertActionTrulyInsertUnknownError = 1043,
    BAPKVStreamFileEditorErrorCodeInsertActionSecondPartUnknownError = 1044,
};

@interface BAPKVStreamFileEditor () {
}

@property (nonatomic) NSString *originPath;
@property (nonatomic) NSString *tempPath;
@property (nonatomic) NSInputStream *originReadStream;
@property (nonatomic) NSOutputStream *originWriteStream;

@end

@implementation BAPKVStreamFileEditor

- (instancetype)initWith:(NSString *)path {
    self = [self init];
    if (self) {
        _originPath = path;
        _tempPath = [self tempPathFor:_originPath];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:[self rootFolderPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

#pragma mark - public methods
- (NSData *)read:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error {
    if (length == 0 || location == NSUIntegerMax) {
        return nil;
    }
    if (!self.originReadStream || [self.originReadStream streamStatus] == NSStreamStatusClosed || [self.originReadStream streamStatus] == NSStreamStatusAtEnd) {
        [self.originReadStream close];
        self.originReadStream = [[NSInputStream alloc] initWithFileAtPath:self.originPath];
    }
    NSStreamStatus status = [self.originReadStream streamStatus];
    if (status == NSStreamStatusNotOpen) {
        [self.originReadStream open];
        status = [self.originReadStream streamStatus];
    }
    if (status == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeReadActionInvalidStatus description:[NSString stringWithFormat:@"Invalid status: %ld, details: %@", status, [[self.originReadStream streamError] localizedDescription]]];
        }
        return nil;
    }
    
    NSMutableData *result = nil;
    NSUInteger remainedLength = length;
    NSUInteger lastLocation = location;
    BOOL readFailed = NO;
    NSError *tmpError = nil;
    while (remainedLength > 0) {
        @autoreleasepool {
            NSUInteger lenTmp = remainedLength > BAPKVStreamFileEditorSliceSize ? BAPKVStreamFileEditorSliceSize : remainedLength;
            
            uint8_t buffer[lenTmp];
            [self.originReadStream setProperty:@(lastLocation) forKey:NSStreamFileCurrentOffsetKey];
            NSInteger count = [self.originReadStream read:buffer maxLength:lenTmp];
            if (count == -1 || [self.originReadStream streamStatus] == NSStreamStatusError) {
                readFailed = YES;
                tmpError = [self simpleError:BAPKVStreamFileEditorErrorCodeReadActionReadFailed description:[NSString stringWithFormat:@"Read failed(location=%ld, length=%ld), status=%ld, details:%@", lastLocation, lenTmp, [self.originReadStream streamStatus], [[self.originReadStream streamError] localizedDescription]]];
                break;
            }
            if (count == 0 && [self.originReadStream streamStatus] == NSStreamStatusAtEnd) {
                break;
            }
            NSData *dataTmp = [NSData dataWithBytes:buffer length:count];
            if (!dataTmp) {
                readFailed = YES;
                tmpError = [self simpleError:BAPKVStreamFileEditorErrorCodeReadActionToDataFailed description:[NSString stringWithFormat:@"To data failed, count=%ld", count]];
                break;
            }
            if(!result) {
                result = [[NSMutableData alloc] init];
            }
            [result appendData:dataTmp];
            remainedLength = remainedLength - count;
            lastLocation = lastLocation + count;
        }
    }
    if (readFailed) {
        if (error) {
            *error = tmpError;
        }
        return nil;
    } else {
        return result;
    }
}

- (BOOL)append:(NSData *)content error:(NSError **)error {
    if (!content || content.length == 0) {
        return YES;
    }
    if (!self.originWriteStream || [self.originWriteStream streamStatus] == NSStreamStatusClosed || [self.originWriteStream streamStatus] == NSStreamStatusAtEnd) {
        [self.originWriteStream close];
        self.originWriteStream = [[NSOutputStream alloc] initToFileAtPath:self.originPath append:YES];
    }
    NSStreamStatus status = [self.originWriteStream streamStatus];
    if (status == NSStreamStatusNotOpen) {
        [self.originWriteStream open];
        status = [self.originWriteStream streamStatus];
    }
    return [self append:self.originWriteStream content:content error:error];
}

- (BOOL)delete:(NSUInteger)location length:(NSUInteger)length error:(NSError **)error {
    if (length == 0 || location == NSUIntegerMax) {
        return YES;
    }
    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
    [self closeStream:self.originWriteStream];
    
    if (!self.originReadStream || [self.originReadStream streamStatus] == NSStreamStatusClosed || [self.originReadStream streamStatus] == NSStreamStatusAtEnd) {
        [self.originReadStream close];
        self.originReadStream = [[NSInputStream alloc] initWithFileAtPath:self.originPath];
    }
    NSStreamStatus status = [self.originReadStream streamStatus];
    if (status == NSStreamStatusNotOpen) {
        [self.originReadStream open];
        status = [self.originReadStream streamStatus];
    }
    if (status == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeDeleteActionInvalidStatus description:[NSString stringWithFormat:@"Invalid source stream status: %ld, details: %@", status, [[self.originReadStream streamError] localizedDescription]]];
        }
        return NO;
    }
    
    NSOutputStream *tempOutputStream = [[NSOutputStream alloc] initToFileAtPath:self.tempPath append:YES];
    [tempOutputStream open];
    if ([tempOutputStream streamStatus] == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeDeleteActionInvalidStatus description:[NSString stringWithFormat:@"Invalid output stream status: %ld, details: %@", [tempOutputStream streamStatus], [[tempOutputStream streamError] localizedDescription]]];
        }
        return NO;
    }
    
    NSError *firstPartError;
    BOOL firstPartSuccessed = [self transcribeFrom:self.originReadStream to:tempOutputStream withLocation:0 andLength:location error:&firstPartError];
    if (!firstPartSuccessed || firstPartError) {
        if (error) {
            *error = firstPartError?:[self simpleError:BAPKVStreamFileEditorErrorCodeDeleteActionFirstPartUnknownError description:@"First part failed, unknown reason"];
        }
        [self closeStream:tempOutputStream];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        return NO;
    }
    
    NSUInteger secondPartLocation = (location == NSUIntegerMax || length == NSUIntegerMax) ? NSUIntegerMax : (location + length);
    NSError *secondPartError;
    BOOL secondPartSuccessed = [self transcribeFrom:self.originReadStream to:tempOutputStream withLocation:secondPartLocation andLength:NSUIntegerMax error:&secondPartError];
    if (!secondPartSuccessed || secondPartError) {
        if (error) {
            *error = secondPartError?:[self simpleError:BAPKVStreamFileEditorErrorCodeDeleteActionSecondPartUnknownError description:@"Second part failed, unknown reason"];
        }
        [self closeStream:tempOutputStream];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        return NO;
    }
    
    [self closeStream:tempOutputStream];
    [self closeStream:self.originReadStream];
    
    [[NSFileManager defaultManager] removeItemAtPath:self.originPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:self.tempPath toPath:self.originPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
    return YES;
}

- (BOOL)insert:(NSUInteger)location content:(NSData *)content error:(NSError **)error {
    if (!content || content.length == 0) {
        return YES;
    }
    if (location == NSUIntegerMax) {
        return [self append:content error:error];
    }
    
    // prepare files
    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
    [self closeStream:self.originWriteStream];

    // prepare streams
    if (!self.originReadStream || [self.originReadStream streamStatus] == NSStreamStatusClosed || [self.originReadStream streamStatus] == NSStreamStatusAtEnd) {
        [self.originReadStream close];
        self.originReadStream = [[NSInputStream alloc] initWithFileAtPath:self.originPath];
    }
    NSStreamStatus status = [self.originReadStream streamStatus];
    if (status == NSStreamStatusNotOpen) {
        [self.originReadStream open];
        status = [self.originReadStream streamStatus];
    }
    if (status == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeInsertActionInvalidStatus description:[NSString stringWithFormat:@"Invalid source stream status: %ld, details: %@", status, [[self.originReadStream streamError] localizedDescription]]];
        }
        return NO;
    }
    
    NSOutputStream *tempOutputStream = [[NSOutputStream alloc] initToFileAtPath:self.tempPath append:YES];
    [tempOutputStream open];
    if ([tempOutputStream streamStatus] == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeInsertActionInvalidStatus description:[NSString stringWithFormat:@"Invalid output stream status: %ld, details: %@", [tempOutputStream streamStatus], [[tempOutputStream streamError] localizedDescription]]];
        }
        return NO;
    }
    
    // first part
    NSError *firstPartError;
    BOOL firstPartSuccessed = [self transcribeFrom:self.originReadStream to:tempOutputStream withLocation:0 andLength:location error:&firstPartError];
    if (!firstPartSuccessed || firstPartError) {
        if (error) {
            *error = firstPartError?:[self simpleError:BAPKVStreamFileEditorErrorCodeInsertActionFirstPartUnknownError description:@"First part failed, unknown reason"];
        }
        [self closeStream:tempOutputStream];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        return NO;
    }
    
    // truly insert
    NSError *trulyInsertError;
    BOOL trulyInsertSuccessed = [self append:tempOutputStream content:content error:&trulyInsertError];
    if (!trulyInsertSuccessed || trulyInsertError) {
        if (error) {
            *error = trulyInsertError?:[self simpleError:BAPKVStreamFileEditorErrorCodeInsertActionTrulyInsertUnknownError description:@"Truly insert failed, unknown reason"];
        }
        [self closeStream:tempOutputStream];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        return NO;
    }
    
    // second part
    NSError *secondPartError;
    BOOL secondPartSuccessed = [self transcribeFrom:self.originReadStream to:tempOutputStream withLocation:location andLength:NSUIntegerMax error:&secondPartError];
    if (!secondPartSuccessed || secondPartError) {
        if (error) {
            *error = secondPartError?:[self simpleError:BAPKVStreamFileEditorErrorCodeInsertActionSecondPartUnknownError description:@"Second part failed, unknown reason"];
        }
        [self closeStream:tempOutputStream];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        return NO;
    }
    
    // finished
    [self closeStream:tempOutputStream];
    [self closeStream:self.originReadStream];
    
    [[NSFileManager defaultManager] removeItemAtPath:self.originPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:self.tempPath toPath:self.originPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
    return YES;
}

#pragma mark - private methods
#pragma mark path methods
- (NSString *)rootFolderPath {
    NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *result = [document stringByAppendingPathComponent:@"BAPKVStreamFileEditor"];
    return result;
}

- (NSString *)tempPathFor:(NSString *)originPath {
    NSString *newFileName = [NSString stringWithFormat:@"%llx", [originPath BAXH_hash64]];
    return [[self rootFolderPath] stringByAppendingPathComponent:newFileName];
}

#pragma mark stream methods
- (void)closeStream:(NSStream *)stream {
    if (stream) {
        [stream close];
        stream = nil;
    }
}

#pragma mark edit methods
- (BOOL)append:(NSOutputStream *)stream content:(NSData *)content error:(NSError **)error {
    if (!content || content.length == 0) {
        return YES;
    }
    if ([stream streamStatus] == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeAppendActionInvalidStatus description:[NSString stringWithFormat:@"Invalid status: %ld, details: %@", [stream streamStatus], [[stream streamError] localizedDescription]]];
        }
        return nil;
    }
    
    if (![stream hasSpaceAvailable]) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeAppendActionNoSpace description:@"Append failed, there is no space available"];
        }
        return NO;
    }
    
    const void *bytes = [content bytes];
    NSUInteger length = [content length];
    uint8_t *crypto_data = (uint8_t *)bytes;
    NSInteger count = [stream write:crypto_data maxLength:length];
    if (count == -1 || [stream streamStatus] == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeAppendActionWriteFailed description:[NSString stringWithFormat:@"Append failed(length=%ld), status=%ld, details:%@", length, [stream streamStatus], [[stream streamError] localizedDescription]]];
        }
        return NO;
    }
    return YES;
}

- (BOOL)transcribeFrom:(NSInputStream *)sourceStream to:(NSOutputStream *)targetStream withLocation:(NSUInteger)location andLength:(NSUInteger)length error:(NSError **)error {
    if (location == NSUIntegerMax) {
        return YES;
    }
    NSStreamStatus sourceStreamStatus = [sourceStream streamStatus];
    NSStreamStatus targetStreamStatus = [targetStream streamStatus];
    if (sourceStreamStatus == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeTranscribeActionInvalidStatus description:[NSString stringWithFormat:@"Invalid source stream status: %ld, details: %@", sourceStreamStatus, [[sourceStream streamError] localizedDescription]]];
        }
        return NO;
    } else if (targetStreamStatus == NSStreamStatusError) {
        if (error) {
            *error = [self simpleError:BAPKVStreamFileEditorErrorCodeTranscribeActionInvalidStatus description:[NSString stringWithFormat:@"Invalid target stream status: %ld, details: %@", targetStreamStatus, [[targetStream streamError] localizedDescription]]];
        }
        return NO;
    }
    
    BOOL successed = YES;
    NSError *tmpError = nil;
    NSUInteger remainedLength = length;
    NSUInteger lastLocation = location;
    while (remainedLength > 0) {
        @autoreleasepool {
            NSUInteger lenTmp = remainedLength > BAPKVStreamFileEditorSliceSize ? BAPKVStreamFileEditorSliceSize : remainedLength;
            
            uint8_t buffer[lenTmp];
            [sourceStream setProperty:@(lastLocation) forKey:NSStreamFileCurrentOffsetKey];
            NSInteger readCount = [sourceStream read:buffer maxLength:lenTmp];
            if (readCount == -1 || [sourceStream streamStatus] == NSStreamStatusError) {
                tmpError = [self simpleError:BAPKVStreamFileEditorErrorCodeTranscribeActionReadFailed description:[NSString stringWithFormat:@"Read failed(location=%ld, length=%ld), status=%ld, details:%@", lastLocation, lenTmp, [sourceStream streamStatus], [[sourceStream streamError] localizedDescription]]];
                successed = NO;
                break;
            }
            if (readCount == 0 && [sourceStream streamStatus] == NSStreamStatusAtEnd) {
                break;
            }
            if (![targetStream hasSpaceAvailable]) {
                tmpError = [self simpleError:BAPKVStreamFileEditorErrorCodeTranscribeActionNoSpace description:[NSString stringWithFormat:@"Write failed(location=%ld, length=%ld), status=%ld, there is no space available", lastLocation, readCount, [targetStream streamStatus]]];
                successed = NO;
                break;
            }
            NSInteger writeCount = [targetStream write:buffer maxLength:readCount];
            if (writeCount == -1 || [targetStream streamStatus] == NSStreamStatusError) {
                tmpError = [self simpleError:BAPKVStreamFileEditorErrorCodeTranscribeActionWriteFailed description:[NSString stringWithFormat:@"Write failed(location=%ld, length=%ld), status=%ld, details:%@", lastLocation, readCount, [targetStream streamStatus], [[targetStream streamError] localizedDescription]]];
                successed = NO;
                break;
            }
            remainedLength = remainedLength - readCount;
            lastLocation = lastLocation + readCount;
        }
    }
    return YES;
}

#pragma mark others
- (NSError *)simpleError:(NSUInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{NSLocalizedDescriptionKey: description?:@"unknown"}];
}

- (void)removeFile:(NSString *)path {
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (exists && !isDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

@end
