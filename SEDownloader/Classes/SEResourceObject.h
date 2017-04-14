//
//  SEResourceObject.h
//  Pods
//
//  Created by Semyon Belokovsky on 12/04/2017.
//
//

#import "SEResource.h"

@interface SEResourceObject : NSObject <SEResource>

+ (instancetype)objectFromResource:(id<SEResource>)resource;

@end
