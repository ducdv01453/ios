//
//  FlicVC.m
//  OwnTracks
//
//  Created by duc do viet on 22/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "FlicVC.h"

@interface FlicVC ()

@end

@implementation FlicVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [FLICManager configureWithDelegate:self buttonDelegate:self background:YES];
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
        }
    }];
}

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
