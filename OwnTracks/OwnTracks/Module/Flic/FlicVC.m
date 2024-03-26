//
//  FlicVC.m
//  OwnTracks
//
//  Created by duc do viet on 22/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "FlicVC.h"
#import "StatusTVC.h"
#import "FriendAnnotationV.h"
#import "FriendsTVC.h"
#import "RegionsTVC.h"
#import "WaypointTVC.h"
#import "CoreData.h"
#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "LocationManager.h"
#import "OwnTracking.h"
#import <Foundation/Foundation.h>

#import "OwnTracksChangeMonitoringIntent.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface FlicVC ()

@end

@implementation FlicVC

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startScan:(id)sender;
{
    [[FLICManager sharedManager] scanForButtonsWithStateChangeHandler:^(FLICButtonScannerStatusEvent event) {
        // You can use these events to update your UI.
        switch (event)
        {
            case FLICButtonScannerStatusEventDiscovered:
                NSLog(@"A Flic was discovered.");
                break;
            case FLICButtonScannerStatusEventConnected:
                NSLog(@"A Flic is being verified.");
                break;
            case FLICButtonScannerStatusEventVerified:
                NSLog(@"The Flic was verified successfully.");
                break;
            case FLICButtonScannerStatusEventVerificationFailed:
                NSLog(@"The Flic verification failed.");
                break;
            default:
                break;
        }
    } completion:^(FLICButton *button, NSError *error) {
        NSLog(@"Scanner completed with error: %@", error);
        if (!error)
        {
            NSLog(@"Successfully verified: %@, %@, %@", button.name, button.bluetoothAddress, button.serialNumber);
            // Listen to single click only.
            button.triggerMode = FLICButtonTriggerModeClick;
            [button connect];
        }
    }];
}

- (IBAction)sendNow:(id)sender;
{
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

@end
