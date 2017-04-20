//
//  SEDownloadModel.m
//  Pods
//
//  Created by Semyon Belokovsky on 18/04/2017.
//
//

#import "SEDownloadModel.h"

@implementation SEDownloadModel

- (void)openOutputStream {
    if (self.outputStream) {
        [self.outputStream open];
    }
}

- (void)closeOutputStream {
    
    if (self.outputStream) {
        if (self.outputStream.streamStatus > NSStreamStatusNotOpen && self.outputStream.streamStatus < NSStreamStatusClosed) {
            [self.outputStream close];
        }
        self.outputStream = nil;
    }
}

@end
