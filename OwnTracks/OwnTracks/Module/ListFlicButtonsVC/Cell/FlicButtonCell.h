//
//  FlicButtonCell.h
//  OwnTracks
//
//  Created by DucDV on 28/03/2024.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FlicButtonCellDelegate <NSObject>
- (void)onRemove: (NSUUID*)identifier;
@end

@interface FlicButtonCell: UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *lblContent;
@property (weak, nonatomic) IBOutlet UIView *vStatus;

@property (weak, nonatomic) id<FlicButtonCellDelegate> delegate;
@property(nonatomic, strong) NSUUID *identifier;

- (void)updateView;
@end

NS_ASSUME_NONNULL_END
