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

@interface OwnTracksLeftMenuVC () <UITableViewDelegate,UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation OwnTracksLeftMenuVC
- (NSArray*)datasource {
    return @[
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
    OwnTracksMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OwnTracksMenuCell"];
    
    OwnTracksMenuModel* model = [[self datasource] objectAtIndex:indexPath.row];
    
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
        case LeftMenuModelTypeScanQRCode:
            //
            break;
        case LeftMenuModelTypeImport:
            //
            break;
        case LeftMenuModelTypeButtonManagement:
            //
            break;
        default:
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}
@end
