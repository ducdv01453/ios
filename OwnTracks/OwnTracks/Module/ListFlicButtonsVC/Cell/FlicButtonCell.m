//
//  FlicButtonCell.m
//  OwnTracks
//
//  Created by DucDV on 28/03/2024.
//



#import "FlicButtonCell.h"
@import flic2lib;

@implementation FlicButtonCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    _vStatus.layer.cornerRadius = 8;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(flicButtonStatusChanged:)
                                                     name:@"FlicButtonStatusChanged" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(flicButtonClicked:)
                                                     name:@"FlicButtonClicked" object:nil];
}

- (void) flicButtonStatusChanged:(NSNotification *) notification {
    NSDictionary *userInfo = notification.userInfo;
    FLICButton *button = [userInfo objectForKey:@"FlicButton"];
    [[FLICManager sharedManager] buttons];
    
//    identifier
}

- (void) flicButtonClicked:(NSNotification *) notification {
    NSDictionary *userInfo = notification.userInfo;
    FLICButton *button = [userInfo objectForKey:@"FlicButton"];
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)onRemove:(id)sender {
    [_delegate onRemove: _identifier];
}

@end
