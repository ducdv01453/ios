//
//  OwnTracksMenuCell.m
//  OwnTracks
//
//  Created by duc do viet on 26/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "OwnTracksMenuCell.h"

@interface OwnTracksMenuCell ()
@property (weak, nonatomic) IBOutlet UIButton *iconImageButton;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end

@implementation OwnTracksMenuCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)configure:(nonnull NSString *)systemImageName title:(nonnull NSString *)title {
    [self.iconImageButton setImage:[UIImage systemImageNamed:systemImageName] forState:UIControlStateNormal];
    [self.titleLabel setText:title];
}

@end
