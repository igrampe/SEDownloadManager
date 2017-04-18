//
//  SEDownloadManager.h
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

#import <Foundation/Foundation.h>

@protocol SEResource;

@interface SEDownloadManager : NSObject

+ (instancetype)sharedManager;

- (void)addResourceToQueueWithUrl:(NSString *)urlString;
- (id<SEResource>)resourceForUrl:(NSString *)urlString downloadIfNotExist:(BOOL)shouldDownload;

@end
