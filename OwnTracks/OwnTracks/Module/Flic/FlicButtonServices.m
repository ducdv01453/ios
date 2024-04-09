//
//  FlicButtonServices.m
//  OwnTracks
//
//  Created by duc do viet on 23/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "FlicButtonServices.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation FlicButtonServices

+ (FlicButtonServices *)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void) startService {
    [FLICManager configureWithDelegate:self buttonDelegate:self background:YES];
}

// MARK: - Executed method
- (void)sendCurrentLocation {
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL validIds = [Settings validIdsInMOC: CoreData.sharedInstance.mainMOC];
    int ignoreInaccurateLocations = [Settings intForKey:@"ignoreinaccuratelocations_preference"
                                                      inMOC:CoreData.sharedInstance.mainMOC];
    CLLocation *location = [[LocationManager sharedInstance] location];

    if (!validIds) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");

        [ad.navigationController alert:@"Settings" message:message];
        return;
    }

    if (!location ||
        !CLLocationCoordinate2DIsValid(location.coordinate) ||
        (location.coordinate.latitude == 0.0 &&
         location.coordinate.longitude == 0.0)
        ) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"No location available",
                           @"Warning displayed if not location available")
         ];
        return;
    }

    if (ignoreInaccurateLocations != 0 && location.horizontalAccuracy > ignoreInaccurateLocations) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"Inaccurate or old location information",
                           @"Warning displayed if location is inaccurate or old")
         ];
        return;
    }

    if ([ad sendNow:location withPOI:nil]) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"publish queued on user request",
                           @"content of an alert message regarding user publish")
                                dismissAfter:1
         ];
    } else {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"publish queued on user request",
                           @"content of an alert message regarding user publish")];
    }
}

// MARK: - FLICManagerDelegate
- (void)button:(nonnull FLICButton *)button didDisconnectWithError:(NSError * _Nullable)error {
    NSLog(@"Did disconnect Flic: %@", button.name);
}

- (void)button:(nonnull FLICButton *)button didFailToConnectWithError:(NSError * _Nullable)error {
    NSLog(@"Did fail to connect Flic: %@", button.name);
}

- (void)buttonDidConnect:(nonnull FLICButton *)button {
    NSLog(@"Did connect Flic: %@", button.name);
}

- (void)buttonIsReady:(nonnull FLICButton *)button {
    NSLog(@"buttonIsReady: %@", button.name);
}

- (void)button:(FLICButton *)button didReceiveButtonClick:(BOOL)queued age:(NSInteger)age {
    [self sendCurrentLocation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self sendCurrentLocation];
    });
    NSLog(@"buttonIsReady: %@", button.name);
}

- (void)manager:(nonnull FLICManager *)manager didUpdateState:(FLICManagerState)state {
    switch (state)
    {
        case FLICManagerStatePoweredOn:
            // Flic buttons can now be scanned and connected.
            NSLog(@"Bluetooth is turned on");
            break;
        case FLICManagerStatePoweredOff:
            // Bluetooth is not powered on.
            NSLog(@"Bluetooth is turned off");
            break;
        case FLICManagerStateUnsupported:
            // The framework can not run on this device.
            NSLog(@"FLICManagerStateUnsupported");
        default:
            break;
    }
}

- (void)managerDidRestoreState:(nonnull FLICManager *)manager {
    // The manager was restored and can now be used.
    for (FLICButton *button in manager.buttons)
    {
        NSLog(@"Did restore Flic: %@", button.name);
    }

}

@end
