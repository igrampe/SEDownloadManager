//
//  SEDownloadState.h
//  Pods
//
//  Created by Semyon Belokovsky on 18/04/2017.
//
//

@import Foundation;

typedef NS_ENUM(NSInteger, SEDownloadState) {
    SEDownloadStateWaiting,
    SEDownloadStateRunning,
    SEDownloadStateSuspended,
    SEDownloadStateCanceled,
    SEDownloadStateCompleted,
    SEDownloadStateFailed
};
