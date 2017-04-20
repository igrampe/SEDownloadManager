//
//  SEResource.h
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

@import Foundation;

#import "SEResourceType.h"

@protocol SEResource

@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, assign) SEResourceType type;
@property (nonatomic, strong) NSDate *expiresAt;

@property (nonatomic, assign) NSInteger totalFileSize;

@end
