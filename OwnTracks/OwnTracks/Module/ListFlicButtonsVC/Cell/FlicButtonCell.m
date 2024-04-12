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
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];
}

- (void) flicButtonStatusChanged:(NSNotification *) notification {
    NSDictionary *userInfo = notification.userInfo;
    FLICButton *button = [userInfo objectForKey:@"FlicButton"];
    FLICManager *flicManager = [FLICManager sharedManager];
    NSArray<FLICButton *> *buttons = [flicManager buttons];
    
    for (int i = 0; i < [buttons count]; i++)
    {
        if (buttons[i].identifier == _identifier) {
        
            switch(buttons[i].state) {
                    
                case FLICButtonStateDisconnected:
                    _vStatus.backgroundColor = UIColor.redColor;
                    break;
                case FLICButtonStateConnecting:
                    _vStatus.backgroundColor = UIColor.yellowColor;
                    break;
                case FLICButtonStateConnected:
                    _vStatus.backgroundColor = UIColor.greenColor;
                    break;
                case FLICButtonStateDisconnecting:
                    _vStatus.backgroundColor = UIColor.yellowColor;
                    break;
            }
        }
    }
}

- (void) updateView {
    FLICManager *flicManager = [FLICManager sharedManager];
    NSArray<FLICButton *> *buttons = [flicManager buttons];
    
    for (int i = 0; i < [buttons count]; i++)
    {
        if (buttons[i].identifier == _identifier) {
        
            switch(buttons[i].state) {
                    
                case FLICButtonStateDisconnected:
                    _vStatus.backgroundColor = UIColor.redColor;
                    break;
                case FLICButtonStateConnecting:
                    _vStatus.backgroundColor = UIColor.yellowColor;
                    break;
                case FLICButtonStateConnected:
                    _vStatus.backgroundColor = UIColor.greenColor;
                    break;
                case FLICButtonStateDisconnecting:
                    _vStatus.backgroundColor = UIColor.yellowColor;
                    break;
            }
        }
    }
}

- (void) flicButtonClicked:(NSNotification *) notification {
    NSDictionary *userInfo = notification.userInfo;
    FLICManager *flicManager = [FLICManager sharedManager];
    NSArray<FLICButton *> *buttons = [flicManager buttons];
    for (int i = 0; i < [buttons count]; i++)
    {
        if (buttons[i].identifier == _identifier) {
            [self.vStatus setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.5]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.vStatus setBackgroundColor:[UIColor greenColor]];
            });
        }
    }
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}




- (IBAction)onRemove:(id)sender {
    [_delegate onRemove: _identifier];
}

@end
