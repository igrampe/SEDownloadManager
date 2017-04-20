//
//  SEDownloadManager.h
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

@import Foundation;

#import "SEDownloadState.h"

typedef NS_ENUM(NSInteger, SEWaitingQueueMode) {
    SEWaitingQueueFIFO,
    SEWaitingQueueFILO
};

extern NSString *SEDownloadManagerNotificationError;
extern NSString *SEDownloadManagerNotificationCompletion;
extern NSString *SEDownloadManagerNotificationProgress;

@protocol SEResource;

@interface SEDownloadManager : NSObject

@property (nonatomic, assign) NSInteger maxConcurrentDownloadCount;
@property (nonatomic, assign) SEWaitingQueueMode waitingQueueMode;

+ (instancetype)sharedManager;

- (void)downloadFileOfURL:(NSURL *)URL
                    state:(void (^)(SEDownloadState state))state
                 progress:(void (^)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress))progress
               completion:(void (^)(BOOL success, NSString *filePath, NSError *error))completion;

- (BOOL)isDownloadCompletedOfURL:(NSURL *)URL;

- (NSString *)fileFullPathOfURL:(NSURL *)URL;

- (CGFloat)downloadedProgressOfURL:(NSURL *)URL;

- (void)deleteFileOfURL:(NSURL *)URL;
- (void)deleteAllFiles;

- (void)suspendDownloadOfURL:(NSURL *)URL;
- (void)suspendAllDownloads;

- (void)resumeDownloadOfURL:(NSURL *)URL;
- (void)resumeAllDownloads;

- (void)cancelDownloadOfURL:(NSURL *)URL;
- (void)cancelAllDownloads;

@end
