//
//  SEDownloadModel.h
//  Pods
//
//  Created by Semyon Belokovsky on 18/04/2017.
//
//

@import Foundation;

#import "SEDownloadState.h"

@interface SEDownloadModel : NSObject

@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

@property (nonatomic, strong) NSOutputStream *outputStream; // For write datas to file.

@property (nonatomic, strong) NSURL *URL;

@property (nonatomic, assign) NSInteger totalLength;

@property (nonatomic, copy) void (^state)(SEDownloadState state);

@property (nonatomic, copy) void (^progress)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress);

@property (nonatomic, copy) void (^completion)(BOOL isSuccess, NSString *filePath, NSError *error);

- (void)openOutputStream;

- (void)closeOutputStream;

@end
