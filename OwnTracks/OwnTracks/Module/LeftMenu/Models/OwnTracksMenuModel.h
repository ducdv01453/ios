//
//  OwnTracksMenuModel.h
//  OwnTracks
//
//  Created by duc do viet on 26/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    LeftMenuModelTypeScanQRCode,
    LeftMenuModelTypeImport,
    LeftMenuModelTypeButtonManagement,
} LeftMenuModelType;

@interface OwnTracksMenuModel : NSObject
@property (nonatomic, assign) LeftMenuModelType modelType;
@property (strong, nonatomic) NSString *imageName;
@property (strong, nonatomic) NSString *title;

- (instancetype)initWithType:(LeftMenuModelType)type imageName:(NSString*)imageName title:(NSString*)title;

@end

NS_ASSUME_NONNULL_END
