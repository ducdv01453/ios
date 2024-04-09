//
//  OnboardingVC.m
//  OwnTracks
//
//  Created by DucDV on 02/04/2024.
//

#import "OnboardingVC.h"
#import "ViewController.h"
#import "OwnTracksPermissionManager.h"

@interface OnboardingVC ()

@end

@implementation OnboardingVC

- (instancetype)initWithType:(PermissionType)type {
    self = [super init];
    _permissionRequestType = type;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self prepareUI];
}

// MARK: - Private & Support methods
- (void)prepareUI {
    _btnRequest.layer.cornerRadius = 4;
    _btnRequest.layer.borderColor = UIColor.whiteColor.CGColor;
    _btnRequest.layer.borderWidth = 1;
    _btnDone.layer.cornerRadius = 4;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:self.navigationItem.backBarButtonItem.style target:nil action:nil];
    
    switch (_permissionRequestType) {
        case OnboardingLocationType:
            [_btnRequest setHidden:NO];
            [_btnDone setHidden:YES];
            _imgIcon.image = [UIImage imageNamed:@"ic_location"];
            _lblTitle.text = @"Location permissions";
            _lblSubTitle.text = @"In order to receive your current location to send to your b- endpoint, b- needs your permission in order to access to your device's location.";
            break;
//        case     OnboardingBackgroundLocationType:
//            [_btnRequest setHidden:NO];
//            [_btnDone setHidden:YES];
//            _imgIcon.image = [UIImage imageNamed:@"ic_location"];
//            _lblTitle.text = @"Background Location permission";
//            _lblSubTitle.text = @"In order to receive your current location to send to your b- endpoint, b- needs your permission in order to access to your device's location.";
//            break;
        case     OnboardingNotificationType:
            [_btnRequest setHidden:NO];
            [_btnDone setHidden:YES];
            _imgIcon.image = [UIImage imageNamed:@"ic_bell"];
            _lblTitle.text = @"Notification permissions";
            _lblSubTitle.text = @"To funtion fully, b- needs your permission in order to display some notifications.\n\n A permanent notification will be displayed in order to keep the location tracking and connection alive, and you can also choose to enable notifications for contacts transitioning between waypoints.";
            break;
        case     OnboardingDoneType:
            [_btnRequest setHidden:YES];
            [_btnDone setHidden:NO];
            _imgIcon.image = [UIImage imageNamed:@"ic_double_tick"];
            _lblTitle.text = @"Done";
            _lblSubTitle.text = @"Select preferences from the menu(use for the link below) and configure b- for your server before using it";
            break;
    }
}

// MARK: - Actions
- (IBAction)onSelectDone:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"isOnboarding"];
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
    ViewController *_view = [storyboard instantiateViewControllerWithIdentifier:@"ViewController"];
    NavigationController* nav = [[NavigationController alloc] initWithRootViewController:_view];
    [[[UIApplication sharedApplication] keyWindow] setRootViewController: nav];
    [[[UIApplication sharedApplication] keyWindow] makeKeyAndVisible];
}

- (IBAction)onSelectRequest:(id)sender {
    __weak OnboardingVC *weakSelf = self;
    switch (_permissionRequestType) {
        case OnboardingLocationType: {
            [OwnTracksPermissionManager.sharedInstance requestPermissionFor: OwnTracksPermissionTypeLocation completion:^(OwnTracksPermissionStatus status) {
                switch (status) {
                    case OwnTracksPermissionStatusSuccess:
                        // Always allow
                    {
                        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"isOnboarding"];
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                    }
                    case OwnTracksPermissionStatusFail:
                        // Allow once
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                    default:
                        // Don't allow
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                }
            }];
            break;
        }
//        case OnboardingBackgroundLocationType:
//        {
//            [OwnTracksPermissionManager.sharedInstance requestPermissionFor: OwnTracksPermissionTypeLocation completion:^(OwnTracksPermissionStatus status) {
//                switch (status) {
//                    case OwnTracksPermissionStatusSuccess:
//                        // Always allow
//                    {
//                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
//                        break;
//                    }
//                    case OwnTracksPermissionStatusFail:
//                        // Allow once
//                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
//                        break;
//                    default:
//                        // Don't allow
//                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
//                        break;
//                }
//            }];
//            break;
//        }
//            [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
//            break;
            
        case OnboardingNotificationType: {
            [OwnTracksPermissionManager.sharedInstance requestPermissionFor: OwnTracksPermissionTypeNotification completion:^(OwnTracksPermissionStatus status) {
                switch (status) {
                    case OwnTracksPermissionStatusSuccess:
                        // Always allow
                    {
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                    }
                    case OwnTracksPermissionStatusFail:
                        // Allow once
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                    default:
                        // Don't allow
                        [weakSelf.delegate didRequestWithType: weakSelf.permissionRequestType];
                        break;
                }
            }];
            break;
        }
        case OnboardingDoneType:
            break;
    }
}

@end
