//
//  SEResourceRLMObject.h
//  Pods
//
//  Created by Semyon Belokovsky on 10/04/2017.
//
//

@import Realm;

#import "SEResource.h"

@interface SEResourceRLMObject : RLMObject <SEResource>

+ (instancetype)objectFromResource:(id<SEResource>)resource inRealm:(RLMRealm *)realm;

@end
