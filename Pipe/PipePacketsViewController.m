//
//  PipePacketsViewController.m
//  Pipe
//

#import "PipePacketsViewController.h"
#import "PacketCaptureService.h"
#import "PacketAnalyzerService.h"
#import "LocalizationManagerService.h"
#import "CapturedPacket.h"

@interface PipePacketsViewController () <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<CapturedPacket *> *displayed;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PipePacketsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:1];
    self.title = [[LocalizationManagerService sharedService] stringForKey:@"tab.packets"];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"c"];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        [weakSelf reloadFromService];
    }];
    [self reloadFromService];
}

- (void)dealloc {
    [self.timer invalidate];
}

- (void)reloadFromService {
    NSArray *all = [[PacketCaptureService sharedService] snapshotCapturedPackets];
    NSString *q = self.searchController.searchBar.text ?: @"";
    if (q.length) {
        SearchOptions *opt = [[SearchOptions alloc] initWithQuery:q
                                                    caseSensitive:NO
                                                  searchSourceIP:YES
                                             searchDestinationIP:YES
                                                  searchProtocol:YES
                                                   searchPayload:YES
                                                        startDate:nil
                                                          endDate:nil
                                                          minSize:0
                                                          maxSize:NSUIntegerMax];
        NSArray *hits = [[PacketAnalyzerService sharedService] searchPackets:all withOptions:opt];
        NSMutableArray *packets = [NSMutableArray array];
        for (SearchResult *sr in hits) {
            if (sr.analysisResult.packet) {
                [packets addObject:sr.analysisResult.packet];
            }
        }
        self.displayed = [packets copy];
    } else {
        self.displayed = all;
    }
    [self.tableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self reloadFromService];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayed.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c" forIndexPath:indexPath];
    if (self.displayed.count == 0) {
        cell.textLabel.text = [[LocalizationManagerService sharedService] stringForKey:@"packets.empty"];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.text = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    CapturedPacket *p = self.displayed[indexPath.row];
    cell.textLabel.text = [[PacketAnalyzerService sharedService] formatPacketForDisplay:p];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    cell.detailTextLabel.text = nil;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.displayed.count == 0) {
        return;
    }
    CapturedPacket *p = self.displayed[indexPath.row];
    NSString *body = [[PacketAnalyzerService sharedService] formatPacketWithDetails:p];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[[LocalizationManagerService sharedService] stringForKey:@"packets.detail"]
                                                               message:body
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
