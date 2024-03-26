//
//  OwnTracksMenuModel.m
//  OwnTracks
//
//  Created by duc do viet on 26/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "OwnTracksMenuModel.h"
@interface OwnTracksMenuModel()
@end

@implementation OwnTracksMenuModel

- (instancetype)initWithType:(LeftMenuModelType)type imageName:(NSString*)imageName title:(NSString*)title {
    self = [super init];
    self.modelType = type;
    self.imageName = imageName;
    self.title = title;
    
    return self;
}

@end
