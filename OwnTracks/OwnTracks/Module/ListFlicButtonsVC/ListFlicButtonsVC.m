//
//  ListFlicButtons.m
//  OwnTracks
//
//  Created by DucDV on 23/03/2024.
//

#import "ListFlicButtonsVC.h"
#import "FlicButtonCell.h"
@import flic2lib;



@interface ListFlicButtonsVC () <FlicButtonCellDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ListFlicButtonsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self configTableView];
    [self.lbNoFlic setHidden:[[FLICManager sharedManager] buttons].count != 0];
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
    __weak ListFlicButtonsVC *weakSelf = self;
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    CGFloat halfButtonHeight = _btnScan.bounds.size.height / 2;
    CGFloat buttonWidth = _btnScan.bounds.size.width;
    indicator.center = CGPointMake(buttonWidth - halfButtonHeight , halfButtonHeight);
    [_btnScan addSubview:indicator];
    [indicator startAnimating];
    
    [_btnScan setTitle:@"Looking for buttons  " forState:UIControlStateNormal];
    
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
            [indicator stopAnimating];
            NSLog(@"Successfully verified: %@, %@, %@", button.name, button.bluetoothAddress, button.serialNumber);
            [weakSelf.btnScan setTitle:@"Add Flic  " forState:UIControlStateNormal];
            [self.tableView reloadData];
            [self.lbNoFlic setHidden:[[FLICManager sharedManager] buttons].count != 0];
        }
    }];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FlicButtonCell *cell =[tableView dequeueReusableCellWithIdentifier:@"FlicButtonCell"];
    cell.lblContent.text = [[FLICManager sharedManager] buttons][indexPath.row].name;
    cell.identifier = [[FLICManager sharedManager] buttons][indexPath.row].identifier;
    [cell updateView];
    cell.delegate = self;
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[FLICManager sharedManager] buttons] count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FLICButton *button = [[FLICManager sharedManager] buttons][indexPath.row];
    switch(button.state) {
        case FLICButtonStateDisconnected:{
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                           message:@"Do you want to connect this button?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Connect" style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                [button connect];
            }];
            
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * action) {}];
            
            [alert addAction:defaultAction];
            [alert addAction:cancelAction];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
        case FLICButtonStateConnecting:
            break;
        case FLICButtonStateConnected:
        {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                           message:@"Do you want to disconnect this button?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Disconnect" style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                [button disconnect];
            }];
            
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * action) {}];
            
            [alert addAction:defaultAction];
            [alert addAction:cancelAction];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
            break;
        case FLICButtonStateDisconnecting:
            break;
    }
}

// MARK: - FlicButtonCellDelegate
- (void)onRemove:(NSUUID*)identifier {
    // Do stuff here
    __weak ListFlicButtonsVC *weakSelf = self;
    FLICManager *flicManager = [FLICManager sharedManager];
    NSArray<FLICButton *> *buttons = [flicManager buttons];

    for (int i = 0; i < [buttons count]; i++)
    {
        if (buttons[i].identifier == identifier) {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Remove"
                                           message:@"Do you want to remove this button?"
                                           preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDefault
               handler:^(UIAlertAction * action) {
                [flicManager forgetButton:buttons[i] completion:^(NSUUID * _Nonnull uuid, NSError * _Nullable error) {
                    [weakSelf.tableView reloadData];
                    [weakSelf.lbNoFlic setHidden:[[FLICManager sharedManager] buttons].count != 0];
                }];
            }];
            
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
               handler:^(UIAlertAction * action) {}];

            [alert addAction:defaultAction];
            [alert addAction:cancelAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end
