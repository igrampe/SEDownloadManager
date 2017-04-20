//
//  SEDownloadManager.m
//  SEDownloadManager
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

#import "SEDownloadManager.h"

#define SEFilePath(URL) [SEDownloadDirectory stringByAppendingPathComponent:SEFileName(URL)]

@import Realm;

#import "SEResourceRLMObject.h"
#import "SEResourceObject.h"
#import "SEDownloadModel.h"

static NSString *SEDownloadManagerDirectory = @"se_download_manager";

NSString *SEDownloadManagerNotificationError = @"SEDownloadManagerNotificationError";
NSString *SEDownloadManagerNotificationCompletion = @"SEDownloadManagerNotificationCompletion";
NSString *SEDownloadManagerNotificationProgress = @"SEDownloadManagerNotificationProgress";

@interface SEDownloadManager () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) NSString *downloadedFilesDirectory;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSMutableDictionary *downloadModelsDict;
@property (nonatomic, strong) NSMutableArray *downloadingModels;
@property (nonatomic, strong) NSMutableArray *waitingModels;

@end

@implementation SEDownloadManager

+ (instancetype)sharedManager {
    static id _sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *downloadDirectory = [self downloadDirectory];
        BOOL isDirectory = NO;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isExists = [fileManager fileExistsAtPath:downloadDirectory isDirectory:&isDirectory];
        if (!isExists || !isDirectory) {
            [fileManager createDirectoryAtPath:downloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        self.maxConcurrentDownloadCount = -1;
        self.waitingQueueMode = SEWaitingQueueFIFO;
    }
    return self;
}

- (NSURLSession *)urlSession {
    if (!_urlSession) {
        _urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                    delegate:self
                                               delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return _urlSession;
}

#pragma mark - Lazy Load

- (NSMutableDictionary *)downloadModelsDict {
    if (!_downloadModelsDict) {
        _downloadModelsDict = [NSMutableDictionary dictionary];
    }
    return _downloadModelsDict;
}

- (NSMutableArray *)downloadingModels {
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
    }
    return _downloadingModels;
}

- (NSMutableArray *)waitingModels {
    if (!_waitingModels) {
        _waitingModels = [NSMutableArray array];
    }
    return _waitingModels;
}

#pragma mark - Helpers

- (RLMRealm *)realm {
    if (_realm) {
        return _realm;
    }
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.fileURL = [NSURL fileURLWithPath:[self realmPath]];
    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    
    return realm;
}

- (NSString *)realmPath {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:SEDownloadManagerDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:nil];
    }
    path = [path stringByAppendingPathComponent:@"resources.realm"];
    return path;
}

- (NSString *)downloadDirectory {
    NSString *path = self.downloadedFilesDirectory;
    if (!path) {
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        path = [path stringByAppendingPathComponent:SEDownloadManagerDirectory];
        path = [path stringByAppendingPathComponent:@"files"];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return path;
}

- (NSString *)fileNameForURL:(NSURL *)url {
    NSString *fileName = [url lastPathComponent];
    return fileName;
}

- (NSString *)filePathForURL:(NSURL *)url {
    NSString *filePath = [self downloadDirectory];
    filePath = [filePath stringByAppendingPathComponent:[self fileNameForURL:url]];
    return filePath;
}

- (NSInteger)totalLength:(NSURL *)URL {
    SEResourceRLMObject *resource = [self resourceRLMObjectForURL:URL];
    return resource.totalFileSize;
}

- (NSInteger)downloadedLengthForURL:(NSURL *)URL {
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self fileFullPathOfURL:URL] error:nil];
    if (!fileAttributes) {
        return 0;
    }
    return [fileAttributes[NSFileSize] integerValue];
}

- (void)resumeNextDowloadModel {
    if (self.maxConcurrentDownloadCount == -1) {
        return;
    }
    if (self.waitingModels.count == 0) {
        return;
    }
    
    SEDownloadModel *downloadModel;
    switch (self.waitingQueueMode) {
            case SEWaitingQueueFIFO:
            downloadModel = self.waitingModels.firstObject;
            break;
            case SEWaitingQueueFILO:
            downloadModel = self.waitingModels.lastObject;
            break;
    }
    [self.waitingModels removeObject:downloadModel];
    
    SEDownloadState downloadState;
    if ([self canResumeDownload]) {
        [self.downloadingModels addObject:downloadModel];
        [downloadModel.dataTask resume];
        downloadState = SEDownloadStateRunning;
    } else {
        [self.waitingModels addObject:downloadModel];
        downloadState = SEDownloadStateWaiting;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (downloadModel.state) {
            downloadModel.state(downloadState);
        }
    });
}

- (SEResourceRLMObject *)resourceRLMObjectForURL:(NSURL *)url {
    RLMResults *results = [SEResourceRLMObject objectsInRealm:self.realm where:@"url == %@", url.absoluteString];
    SEResourceRLMObject *object = results.firstObject;
    if (!object) {
        object = [SEResourceRLMObject new];
        object.url = url.absoluteString;
    }
    BOOL needCommitTransaction = NO;
    if (!self.realm.inWriteTransaction) {
        [self.realm beginWriteTransaction];
        needCommitTransaction = YES;
    }
    [self.realm addObject:object];
    if (needCommitTransaction) {
        [self.realm commitWriteTransaction];
    }
    return object;
}

- (void)deleteResourceForURL:(NSURL *)URL {
    RLMResults *results = [SEResourceRLMObject objectsInRealm:self.realm where:@"url == %@", URL.absoluteString];
    BOOL needCommitTransaction = NO;
    if (!self.realm.inWriteTransaction) {
        [self.realm beginWriteTransaction];
        needCommitTransaction = YES;
    }
    [self.realm deleteObjects:results];
    
    if (needCommitTransaction) {
        [self.realm commitWriteTransaction];
    }
}

#pragma mark - Public

- (BOOL)isDownloadCompletedOfURL:(NSURL *)URL {
    NSInteger totalLength = [self totalLength:URL];
    if (totalLength != 0) {
        if (totalLength == [self downloadedLengthForURL:URL]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)fileFullPathOfURL:(NSURL *)URL {
    return [self filePathForURL:URL];
}

- (CGFloat)downloadedProgressOfURL:(NSURL *)URL {
    if ([self isDownloadCompletedOfURL:URL]) {
        return 1.0;
    }
    if ([self totalLength:URL] == 0) {
        return 0.0;
    }
    return 1.0 * [self downloadedLengthForURL:URL] / [self totalLength:URL];
}

- (void)deleteFileOfURL:(NSURL *)URL {
    [self cancelDownloadOfURL:URL];
    
    [self deleteResourceForURL:URL];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self fileFullPathOfURL:URL];
    if (![fileManager fileExistsAtPath:filePath]) {
        return;
    }
    if ([fileManager removeItemAtPath:filePath error:nil]) {
        return;
    }
    NSLog(@"removeItemAtPath Failed: %@", filePath);
}

- (void)deleteAllFiles {
    [self cancelAllDownloads];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *fileNames = [fileManager contentsOfDirectoryAtPath:[self downloadDirectory] error:nil];
    for (NSString *fileName in fileNames) {
        NSString *filePath = [[self downloadDirectory] stringByAppendingPathComponent:fileName];
        if ([fileManager removeItemAtPath:filePath error:nil]) {
            continue;
        }
        NSLog(@"removeItemAtPath Failed: %@", filePath);
    }
}

- (void)setDownloadedFilesDirectory:(NSString *)downloadedFilesDirectory {
    _downloadedFilesDirectory = downloadedFilesDirectory;
    
    if (!downloadedFilesDirectory) {
        return;
    }
    BOOL isDirectory = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isExists = [fileManager fileExistsAtPath:downloadedFilesDirectory isDirectory:&isDirectory];
    if (!isExists || !isDirectory) {
        [fileManager createDirectoryAtPath:downloadedFilesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark -- Download Actions

- (void)downloadFileOfURL:(NSURL *)URL
                    state:(void(^)(SEDownloadState state))state
                 progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress))progress
               completion:(void(^)(BOOL success, NSString *filePath, NSError *error))completion {
    if (!URL) {
        return;
    }
    
    if ([self isDownloadCompletedOfURL:URL]) {
        if (state) {
            state(SEDownloadStateCompleted);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SEDownloadManagerNotificationCompletion
                                                            object:URL];
        if (completion) {
            completion(YES, [self fileFullPathOfURL:URL], nil);
        }
        return;
    }
    
    SEDownloadModel *downloadModel = self.downloadModelsDict[[self fileNameForURL:URL]];
    if (downloadModel) {
        return;
    }
    
    // bytes=x-y  x byte ~ y byte
    // bytes=x-   x byte ~ end
    // bytes=-y   head ~ y byte
    NSMutableURLRequest *requestM = [NSMutableURLRequest requestWithURL:URL];
    [requestM setValue:[NSString stringWithFormat:@"bytes=%lld-", (long long int)[self downloadedLengthForURL:URL]] forHTTPHeaderField:@"Range"];
    NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithRequest:requestM];
    dataTask.taskDescription = [self fileNameForURL:URL];
    
    downloadModel = [[SEDownloadModel alloc] init];
    downloadModel.dataTask = dataTask;
    downloadModel.outputStream = [NSOutputStream outputStreamToFileAtPath:[self fileFullPathOfURL:URL] append:YES];
    downloadModel.URL = URL;
    downloadModel.state = state;
    downloadModel.progress = progress;
    downloadModel.completion = completion;
    self.downloadModelsDict[dataTask.taskDescription] = downloadModel;
    
    SEResourceRLMObject *resource = [self resourceRLMObjectForURL:downloadModel.URL];
    BOOL needCommitTransaction = NO;
    if (!self.realm.inWriteTransaction) {
        [self.realm beginWriteTransaction];
        needCommitTransaction = YES;
    }
    resource.localPath = [self fileFullPathOfURL:URL];
    if (needCommitTransaction) {
        [self.realm commitWriteTransaction];
    }
    
    SEDownloadState downloadState;
    if ([self canResumeDownload]) {
        [self.downloadingModels addObject:downloadModel];
        [dataTask resume];
        downloadState = SEDownloadStateRunning;
    } else {
        [self.waitingModels addObject:downloadModel];
        downloadState = SEDownloadStateWaiting;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (downloadModel.state) {
            downloadModel.state(downloadState);
        }
    });
}

- (BOOL)canResumeDownload {
    if (self.maxConcurrentDownloadCount == -1) {
        return YES;
    }
    if (self.downloadingModels.count >= self.maxConcurrentDownloadCount) {
        return NO;
    }
    return YES;
}

- (void)suspendDownloadOfURL:(NSURL *)URL {
    SEDownloadModel *downloadModel = self.downloadModelsDict[[self fileNameForURL:URL]];
    if (!downloadModel) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (downloadModel.state) {
            downloadModel.state(SEDownloadStateSuspended);
        }
    });
    if ([self.waitingModels containsObject:downloadModel]) {
        [self.waitingModels removeObject:downloadModel];
    } else {
        [downloadModel.dataTask suspend];
        [self.downloadingModels removeObject:downloadModel];
    }
    
    [self resumeNextDowloadModel];
}

- (void)suspendAllDownloads {
    if (self.downloadModelsDict.count == 0) {
        return;
    }
    
    if (self.waitingModels.count > 0) {
        for (NSInteger i = 0; i < self.waitingModels.count; i++) {
            SEDownloadModel *downloadModel = self.waitingModels[i];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (downloadModel.state) {
                    downloadModel.state(SEDownloadStateSuspended);
                }
            });
        }
        [self.waitingModels removeAllObjects];
    }
    
    if (self.downloadingModels.count > 0) {
        for (NSInteger i = 0; i < self.downloadingModels.count; i++) {
            SEDownloadModel *downloadModel = self.downloadingModels[i];
            [downloadModel.dataTask suspend];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (downloadModel.state) {
                    downloadModel.state(SEDownloadStateSuspended);
                }
            });
        }
        [self.downloadingModels removeAllObjects];
    }
}

- (void)resumeDownloadOfURL:(NSURL *)URL {
    SEDownloadModel *downloadModel = self.downloadModelsDict[[self fileNameForURL:URL]];
    if (!downloadModel) {
        return;
    }
    
    SEDownloadState downloadState;
    if ([self canResumeDownload]) {
        [self.downloadingModels addObject:downloadModel];
        [downloadModel.dataTask resume];
        downloadState = SEDownloadStateRunning;
    } else {
        [self.waitingModels addObject:downloadModel];
        downloadState = SEDownloadStateWaiting;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (downloadModel.state) {
            downloadModel.state(downloadState);
        }
    });
}

- (void)resumeAllDownloads {
    if (self.downloadModelsDict.count == 0) {
        return;
    }
    
    NSArray *downloadModels = self.downloadModelsDict.allValues;
    for (SEDownloadModel *downloadModel in downloadModels) {
        SEDownloadState downloadState;
        if ([self canResumeDownload]) {
            [self.downloadingModels addObject:downloadModel];
            [downloadModel.dataTask resume];
            downloadState = SEDownloadStateRunning;
        } else {
            [self.waitingModels addObject:downloadModel];
            downloadState = SEDownloadStateWaiting;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (downloadModel.state) {
                downloadModel.state(downloadState);
            }
        });
    }
}

- (void)cancelDownloadOfURL:(NSURL *)URL {
    SEDownloadModel *downloadModel = self.downloadModelsDict[[self fileNameForURL:URL]];
    if (!downloadModel) {
        return;
    }
    
    [downloadModel closeOutputStream];
    [downloadModel.dataTask cancel];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (downloadModel.state) {
            downloadModel.state(SEDownloadStateCanceled);
        }
    });
    if ([self.waitingModels containsObject:downloadModel]) {
        [self.waitingModels removeObject:downloadModel];
    } else {
        [self.downloadingModels removeObject:downloadModel];
    }
    [self.downloadModelsDict removeObjectForKey:[self fileNameForURL:URL]];
    
    [self deleteResourceForURL:URL];
    
    [self resumeNextDowloadModel];
}

- (void)cancelAllDownloads {
    if (self.downloadModelsDict.count == 0) {
        return;
    }
    NSArray *downloadModels = self.downloadModelsDict.allValues;
    for (SEDownloadModel *downloadModel in downloadModels) {
        [downloadModel closeOutputStream];
        [downloadModel.dataTask cancel];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (downloadModel.state) {
                downloadModel.state(SEDownloadStateCanceled);
            }
        });
    }
    [self.waitingModels removeAllObjects];
    [self.downloadingModels removeAllObjects];
    [self.downloadModelsDict removeAllObjects];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSHTTPURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    SEDownloadModel *downloadModel = self.downloadModelsDict[dataTask.taskDescription];
    if (!downloadModel) {
        return;
    }
    
    [downloadModel openOutputStream];
    
    NSInteger thisTotalLength = response.expectedContentLength; // Equal to [response.allHeaderFields[@"Content-Length"] integerValue]
    NSInteger totalLength = thisTotalLength + [self downloadedLengthForURL:downloadModel.URL];
    downloadModel.totalLength = totalLength;
    SEResourceRLMObject *resource = [self resourceRLMObjectForURL:downloadModel.URL];
    BOOL needCommitTransaction = NO;
    if (!self.realm.inWriteTransaction) {
        [self.realm beginWriteTransaction];
        needCommitTransaction = YES;
    }
    resource.totalFileSize = totalLength;
    if (needCommitTransaction) {
        [self.realm commitWriteTransaction];
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    SEDownloadModel *downloadModel = self.downloadModelsDict[dataTask.taskDescription];
    if (!downloadModel) {
        return;
    }
    
    [downloadModel.outputStream write:data.bytes maxLength:data.length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SEDownloadManagerNotificationProgress
                                                            object:downloadModel.URL];
        
        if (downloadModel.progress) {
            NSUInteger receivedSize = [self downloadedLengthForURL:downloadModel.URL];
            NSUInteger expectedSize = downloadModel.totalLength;
            CGFloat progress = 1.0 * receivedSize / expectedSize;
            downloadModel.progress(receivedSize, expectedSize, progress);
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {    
    if (error && error.code == -999) { // cancelled
        return;
    }
    
    SEDownloadModel *downloadModel = self.downloadModelsDict[task.taskDescription];
    if (!downloadModel) {
        return;
    }
    
    [downloadModel closeOutputStream];
    [self.downloadModelsDict removeObjectForKey:task.taskDescription];
    [self.downloadingModels removeObject:downloadModel];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self isDownloadCompletedOfURL:downloadModel.URL]) {
            if (downloadModel.state) {
                downloadModel.state(SEDownloadStateCompleted);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SEDownloadManagerNotificationCompletion
                                                                object:downloadModel.URL];
            if (downloadModel.completion) {
                downloadModel.completion(YES, [self fileFullPathOfURL:downloadModel.URL], error);
            }
        } else {
            if (downloadModel.state) {
                downloadModel.state(SEDownloadStateFailed);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SEDownloadManagerNotificationError
                                                                object:downloadModel.URL];
            if (downloadModel.completion) {
                downloadModel.completion(NO, nil, error);
            }
        }
    });
    
    [self resumeNextDowloadModel];
}

@end
