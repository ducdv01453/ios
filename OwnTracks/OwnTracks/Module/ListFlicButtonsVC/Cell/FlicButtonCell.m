//
//  FlicButtonCell.m
//  OwnTracks
//
//  Created by DucDV on 28/03/2024.
//



#import "FlicButtonCell.h"

@implementation FlicButtonCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)onRemove:(id)sender {
    [_delegate onRemove: _identifier];
}

@end
