//
//  ListFlicButtons.m
//  OwnTracks
//
//  Created by DucDV on 23/03/2024.
//

#import "ListFlicButtons.h"
@import flic2lib;

@interface ListFlicButtons ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ListFlicButtons

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Get list Flic buttons
    
}

- (void)configTableView {
    self.tableView.delegate   = self;
    self.tableView.dataSource = self;
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell =[tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.text = [[FLICManager sharedManager] buttons][indexPath.row].name;
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[FLICManager sharedManager] buttons] count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[[FLICManager sharedManager] buttons][indexPath.row] connect];
}

@end
