//
//  OwnTracksPermissionManager.m
//  OwnTracks
//
//  Created by duc do viet on 02/04/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "OwnTracksPermissionManager.h"
#import <UserNotifications/UserNotifications.h>
#import "LocationManager.h"

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

@implementation OwnTracksPermissionManager

+ (OwnTracksPermissionManager *)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (void)requestPermissionFor:(OwnTracksPermissionType)type
                  completion:(PermissionCompletionBlock)completion {
    switch (type) {
        case OwnTracksPermissionTypeLocation:
            [self requestLocationPermission:completion];
            break;
        case OwnTracksPermissionTypeNotification:
            [self requestNotificationPermission:completion];
            break;
        default:
            break;
    }
}

// MARK: - Notification
- (void)requestNotificationPermission:(PermissionCompletionBlock) completionBlock {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    UNAuthorizationOptions options =
    UNAuthorizationOptionSound |
    UNAuthorizationOptionAlert |
    UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            completionBlock(OwnTracksPermissionStatusSuccess);
        }else {
            completionBlock(OwnTracksPermissionStatusFail);
        }
        DDLogInfo(@"[OwnTracksAppDelegate] UNUserNotificationCenter requestAuthorizationWithOptions granted:%d error:%@", granted, error);
    }];

}

// MARK: - Location
- (void)requestLocationPermission:(PermissionCompletionBlock) completionBlock {
    __weak OwnTracksPermissionManager* weakSelf = self;
    [LocationManager.sharedInstance authorizeLocationPermission:^(CLAuthorizationStatus status) {
        switch (status) {
            case kCLAuthorizationStatusAuthorizedAlways:
                completionBlock(OwnTracksPermissionStatusSuccess);
                break;
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                completionBlock(OwnTracksPermissionStatusFail);
                break;
            case kCLAuthorizationStatusNotDetermined:
                break;
            case kCLAuthorizationStatusDenied:
                completionBlock(OwnTracksPermissionStatusReject);
                break;
            case kCLAuthorizationStatusRestricted:
                completionBlock(OwnTracksPermissionStatusReject);
                break;
            default:
                break;
        }
    }];
}
@end
