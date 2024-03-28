//
//  OwnTracksLeftMenuVC.h
//  OwnTracks
//
//  Created by duc do viet on 26/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol OwnTracksLeftMenuVCDelegate <NSObject>
- (void)didPressImport;

@end

NS_ASSUME_NONNULL_BEGIN

@interface OwnTracksLeftMenuVC : UIViewController

@property (weak, nonatomic) id<OwnTracksLeftMenuVCDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
