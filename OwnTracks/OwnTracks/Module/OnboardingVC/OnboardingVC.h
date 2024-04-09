//
//  OnboardingVC.h
//  OwnTracks
//
//  Created by DucDV on 02/04/2024.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum: NSUInteger {
    OnboardingLocationType,
//    OnboardingBackgroundLocationType,
    OnboardingNotificationType,
    OnboardingDoneType
} PermissionType;

@protocol OnboardingVCDelegate <NSObject>
- (void)didRequestWithType: (PermissionType)type;

@end

@interface OnboardingVC : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *imgIcon;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblSubTitle;
@property (weak, nonatomic) IBOutlet UIButton *btnRequest;
@property (weak, nonatomic) IBOutlet UIButton *btnDone;

@property (nonatomic, assign) PermissionType permissionRequestType;
@property (nonatomic, assign) int identifier;

@property (weak, nonatomic) id<OnboardingVCDelegate> delegate;

- (instancetype)initWithType:(PermissionType)type;

@end

NS_ASSUME_NONNULL_END
