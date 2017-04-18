//
//  SEResourceObject.m
//  Pods
//
//  Created by Semyon Belokovsky on 12/04/2017.
//
//

#import "SEResourceObject.h"

@implementation SEResourceObject

@synthesize url;
@synthesize localPath;
@synthesize type;
@synthesize expiresAt;

+ (instancetype)objectFromResource:(id<SEResource>)resource {
    SEResourceObject *object = [SEResourceObject new];
    object.url = resource.url;
    object.localPath = resource.localPath;
    object.type = resource.type;
    object.expiresAt = resource.expiresAt;
    
    return object;
}

@end
