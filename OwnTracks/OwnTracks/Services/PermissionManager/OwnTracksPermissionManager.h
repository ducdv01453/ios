//
//  OwnTracksPermissionManager.h
//  OwnTracks
//
//  Created by duc do viet on 02/04/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

NS_ASSUME_NONNULL_BEGIN


typedef enum : NSUInteger {
    OwnTracksPermissionStatusSuccess,
    OwnTracksPermissionStatusFail,
    OwnTracksPermissionStatusReject,
} OwnTracksPermissionStatus;

typedef enum : NSUInteger {
    OwnTracksPermissionTypeLocation,
    OwnTracksPermissionTypeNotification,
} OwnTracksPermissionType;

typedef void (^PermissionCompletionBlock)(OwnTracksPermissionStatus status);

@interface OwnTracksPermissionManager : NSObject
+ (OwnTracksPermissionManager *)sharedInstance;

- (void)requestPermissionFor:(OwnTracksPermissionType)type
                  completion:(PermissionCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
