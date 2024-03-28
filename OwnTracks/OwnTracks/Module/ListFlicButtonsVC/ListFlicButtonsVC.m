//
//  ListFlicButtons.m
//  OwnTracks
//
//  Created by DucDV on 23/03/2024.
//

#import "ListFlicButtonsVC.h"
#import "FlicButtonCell.h"
@import flic2lib;

@interface ListFlicButtonsVC ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ListFlicButtonsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self configTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Get list Flic buttons
    
}

- (void)configTableView {
    self.tableView.delegate   = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[UINib nibWithNibName:@"FlicButtonCell" bundle:nil] forCellReuseIdentifier:@"FlicButtonCell"];
}

- (IBAction)onScan:(id)sender {
    [[FLICManager sharedManager] scanForButtonsWithStateChangeHandler:^(FLICButtonScannerStatusEvent event) {
        // You can use these events to update your UI.
        switch (event)
        {
            case FLICButtonScannerStatusEventDiscovered:
                NSLog(@"A Flic was discovered.");
                break;
            case FLICButtonScannerStatusEventConnected:
                NSLog(@"A Flic is being verified.");
                break;
            case FLICButtonScannerStatusEventVerified:
                NSLog(@"The Flic was verified successfully.");
                break;
            case FLICButtonScannerStatusEventVerificationFailed:
                NSLog(@"The Flic verification failed.");
                break;
            default:
                break;
        }
    } completion:^(FLICButton *button, NSError *error) {
        NSLog(@"Scanner completed with error: %@", error);
        if (!error)
        {
            NSLog(@"Successfully verified: %@, %@, %@", button.name, button.bluetoothAddress, button.serialNumber);
            // Listen to single click only.
//            button.triggerMode = FLICButtonTriggerModeClick;
//            [button connect];
            [self.tableView reloadData];
        }
    }];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FlicButtonCell *cell =[tableView dequeueReusableCellWithIdentifier:@"FlicButtonCell"];
    cell.lblContent.text = [[FLICManager sharedManager] buttons][indexPath.row].name;
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[FLICManager sharedManager] buttons] count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[[FLICManager sharedManager] buttons][indexPath.row] connect];
}

@end
