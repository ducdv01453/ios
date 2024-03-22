//
//  FlicButtonServices.h
//  OwnTracks
//
//  Created by duc do viet on 23/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
@import flic2lib;

NS_ASSUME_NONNULL_BEGIN

@interface FlicButtonServices : NSObject <FLICButtonDelegate, FLICManagerDelegate>
+ (FlicButtonServices *)sharedInstance;

- (void) startService;

@end

NS_ASSUME_NONNULL_END
