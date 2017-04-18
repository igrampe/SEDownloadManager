//
//  SEDownloadManager.m
//  SEDownloadManager
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

#import "SEDownloadManager.h"

@import Realm;
@import REDownloadTasksQueue;

#import "SEResourceRLMObject.h"
#import "SEResourceObject.h"
#import "SEDownloadTasksQueue.h"

@interface SEDownloadManager () <REDownloadTasksQueueDelegate>

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) NSMutableDictionary *queuesDict;
@property (nonatomic, strong) NSMutableArray *queuesKeys;

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
        self.queuesDict = [NSMutableDictionary new];
        self.queuesKeys = [NSMutableArray new];
    }
    return self;
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
    path = [path stringByAppendingPathComponent:@"se_downloader"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:nil];
    }
    path = [path stringByAppendingPathComponent:@"resources.realm"];
    return path;
}

- (SEDownloadTasksQueue *)getQueue {
    SEDownloadTasksQueue *queue = nil;
    NSNumber *key = [self.queuesKeys lastObject];
    if (key) {
        queue = [self.queuesDict objectForKey:key];
    } else {
        key = @([self.queuesKeys count]);
        [self.queuesKeys addObject:key];
    }
    if (!queue) {
        queue = [SEDownloadTasksQueue new];
        [self.queuesDict setObject:queue forKey:key];
    }
    
    queue.delegate = self;
    queue.userObject = key;
    return queue;
}

- (void)removeQueueForKey:(NSNumber *)key {
    if (!key) {
        return;
    }
    [self.queuesDict removeObjectForKey:key];
    [self.queuesKeys removeObject:key];
}

- (NSString *)storePathForResourceWithUrl:(NSString *)url {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"se_downloader"];
    path = [path stringByAppendingPathComponent:@"files"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:nil];
    }
    NSString *fileName = [[url pathComponents] lastObject];
    path = [path stringByAppendingPathComponent:fileName];
    return path;
}

- (void)saveResourceWithURL:(NSURL *)url localPath:(NSURL *)localPath {
    SEResourceRLMObject *object = [SEResourceRLMObject new];
    object.url = url.absoluteString;
    object.localPath = localPath.absoluteString;
    BOOL needCommitTransaction = YES;
    if (self.realm.inWriteTransaction) {
        needCommitTransaction = NO;
        [self.realm beginWriteTransaction];
    }
    [self.realm addObject:object];
    if (needCommitTransaction) {
        [self.realm commitWriteTransaction];
    }
}

#pragma mark - Public

- (void)addResourceToQueueWithUrl:(NSString *)urlString {
    NSLog(@"SE_add: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }
    SEDownloadTasksQueue *queue = [self getQueue];
    [queue addURL:url withStorePath:[self storePathForResourceWithUrl:urlString]];
    if (!queue.started) {
        queue.started = YES;
        [queue start];
    }
}

- (id<SEResource>)resourceForUrl:(NSString *)urlString downloadIfNotExist:(BOOL)shouldDownload {
    SEResourceObject *resource = nil;
    RLMResults *objects = [SEResourceRLMObject objectsInRealm:self.realm where:@"url == %@", urlString];
    SEResourceRLMObject *object = [objects firstObject];
    if (object) {
        resource = [SEResourceObject objectFromResource:object];
    } else if (shouldDownload) {
        [self addResourceToQueueWithUrl:urlString];
    }
    return resource;
}

#pragma mark - REDownloadTasksQueueDelegate

- (void)onREDownloadTasksQueueFinished:(REDownloadTasksQueue *)queue {
    NSLog(@"RE_finished: %@", queue.userObject);
    if (queue.tasksCount < 1) {
        NSNumber *key = (NSNumber *)queue.userObject;
        [self removeQueueForKey:key];
    }
}

- (void)onREDownloadTasksQueue:(REDownloadTasksQueue *)queue
                      progress:(float)progress {
    NSLog(@"RE_progress: %@ %f", queue.userObject, progress);
}

- (void)onREDownloadTasksQueue:(REDownloadTasksQueue *)queue
                didDownloadURL:(NSURL *)downloadURL
                andStoredToURL:(NSURL *)storeURL
                  withProgress:(float) progress {
    NSLog(@"RE_downloaded: %@ %f", queue.userObject, progress);
    [self saveResourceWithURL:downloadURL localPath:storeURL];
}

- (void)onREDownloadTasksQueue:(REDownloadTasksQueue *)queue
                         error:(NSError *)error
                   downloadURL:(NSURL *)downloadURL
                      storeURL:(NSURL *)storeURL {
    NSLog(@"RE_error: %@ %@", queue.userObject, error.localizedDescription);
}

@end
