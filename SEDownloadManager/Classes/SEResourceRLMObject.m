//
//  SEResourceRLMObject.m
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

#import "SEResourceRLMObject.h"

@implementation SEResourceRLMObject

@synthesize url;
@synthesize localPath;
@synthesize type;
@synthesize expiresAt;
@synthesize totalFileSize;

+ (instancetype)objectFromResource:(id<SEResource>)resource inRealm:(RLMRealm *)realm {
    BOOL needCommitTransaction = YES;
    if (realm.inWriteTransaction) {
        needCommitTransaction = NO;
    } else {
        [realm beginWriteTransaction];
    }
    
    SEResourceRLMObject *object = [SEResourceRLMObject new];
    object.url = resource.url;
    object.localPath = resource.localPath;
    object.type = resource.type;
    object.expiresAt = resource.expiresAt;
    object.totalFileSize = resource.totalFileSize;
    
    [realm addObject:object];
    
    if (needCommitTransaction) {
        [realm commitWriteTransaction];
    }
    
    return object;
}

@end
