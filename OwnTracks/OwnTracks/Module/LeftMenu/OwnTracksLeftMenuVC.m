//
//  OwnTracksLeftMenuVC.m
//  OwnTracks
//
//  Created by duc do viet on 26/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "OwnTracksLeftMenuVC.h"
#import <UIKit/UIKit.h>
#import "OwnTracksMenuCell.h"
#import "OwnTracksMenuModel.h"
#import "ScanQRCodeVC.h"
#import "ImportFileService.h"
#import "ListFlicButtonsVC.h"
#import "RegionsTVC.h"
#import "StatusTVC.h"

@interface OwnTracksLeftMenuVC () <UITableViewDelegate,UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation OwnTracksLeftMenuVC
- (NSArray*)datasource {
    return @[
        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeStatus
         imageName:@"checkmark.shield"
         title:@"Status"],

        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeWaypoint
         imageName:@"location"
         title:@"Waypoints"],

        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeSpace
         imageName:@""
         title:@""],

        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeScanQRCode
         imageName:@"qrcode.viewfinder"
         title:@"Scan QR code"],
        
        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeImport
         imageName:@"square.and.arrow.down"
         title:@"Import configuration"],
        
        [[OwnTracksMenuModel alloc]
         initWithType: LeftMenuModelTypeButtonManagement
         imageName:@"button.programmable"
         title:@"Button management"],
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self configTableView];
}

- (void)configTableView {
    self.tableView.delegate   = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[UINib nibWithNibName:@"OwnTracksMenuCell" bundle:nil] forCellReuseIdentifier:@"OwnTracksMenuCell"];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    OwnTracksMenuModel* model = [[self datasource] objectAtIndex:indexPath.row];
    if (model.modelType == LeftMenuModelTypeSpace) {
        return [UITableViewCell new];
    }

    OwnTracksMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OwnTracksMenuCell"];
    [cell configure:model.imageName title:model.title];
    
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self datasource].count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OwnTracksMenuModel* model = [[self datasource] objectAtIndex:indexPath.row];
    /// Use model.type to navigate
    switch (model.modelType) {
        case LeftMenuModelTypeStatus: {
            UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
            StatusTVC *_view = [storyboard instantiateViewControllerWithIdentifier:@"StatusTVC"];
            [self.navigationController pushViewController: _view animated:true];
            break;
        }
        case LeftMenuModelTypeWaypoint: {
            UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
            RegionsTVC *_view = [storyboard instantiateViewControllerWithIdentifier:@"RegionsTVC"];
            [self.navigationController pushViewController: _view animated:true];
            break;
        }
        case LeftMenuModelTypeScanQRCode:
            [self.navigationController pushViewController: [[ScanQRCodeVC alloc] init] animated:true];
            break;
        case LeftMenuModelTypeImport: {
            __weak OwnTracksLeftMenuVC *weakSelf = self;
            [self dismissViewControllerAnimated:YES completion:^{
                [weakSelf.delegate didPressImport];
            }];
            break;
        }
        case LeftMenuModelTypeButtonManagement:
            [self.navigationController pushViewController: [[ListFlicButtonsVC alloc] init] animated:true];
            break;
        default:
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    OwnTracksMenuModel* model = [[self datasource] objectAtIndex:indexPath.row];
    if (model.modelType == LeftMenuModelTypeSpace) {
        CGFloat height = tableView.bounds.size.height - 60*(self.datasource.count-1);
        return height;
    }else {
        return 60;
    }
}
@end
