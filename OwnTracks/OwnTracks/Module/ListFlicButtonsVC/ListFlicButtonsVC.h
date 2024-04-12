//
//  ListFlicButtons.h
//  OwnTracks
//
//  Created by DucDV on 23/03/2024.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ListFlicButtonsVC : UIViewController<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *lbNoFlic;
@property (weak, nonatomic) IBOutlet UIButton *btnScan;

@end

NS_ASSUME_NONNULL_END
