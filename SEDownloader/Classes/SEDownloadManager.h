//
//  SEDownloadManager.h
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

#import <Foundation/Foundation.h>

@interface SEDownloadManager : NSObject

+ (instancetype)sharedManager;

- (void)addResourceToQueueWithUrl:(NSString *)urlString;

@end
