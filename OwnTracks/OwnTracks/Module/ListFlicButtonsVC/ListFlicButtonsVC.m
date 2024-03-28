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
