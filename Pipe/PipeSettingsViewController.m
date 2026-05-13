//
//  PipeSettingsViewController.m
//  Pipe
//

#import "PipeSettingsViewController.h"
#import "PacketCaptureService.h"
#import "PCAPExportService.h"
#import "LocalizationManagerService.h"

static NSString *const kPrivateModeKey = @"PipePrivateCaptureMode";
static NSString *const kAppLanguageKey = @"PipeAppLanguage";

@implementation PipeSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [[LocalizationManagerService sharedService] stringForKey:@"settings.title"];
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? 2 : (section == 1) ? 1 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    if (section == 0) {
        return @"Capture & privacy";
    }
    if (section == 1) {
        return [L stringForKey:@"settings.language"];
    }
    return @"Data";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"s"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"s"];
    }
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.text = nil;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = [L stringForKey:@"settings.vpn_exclusion"];
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [PacketCaptureService isVPNPacketExclusionEnabled];
            [sw addTarget:self action:@selector(vpnExclusionChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        } else {
            cell.textLabel.text = [L stringForKey:@"settings.private_mode"];
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kPrivateModeKey];
            [sw addTarget:self action:@selector(privateChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = [L stringForKey:@"settings.language"];
        cell.detailTextLabel.text = [self currentLanguageTitle];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        if (indexPath.row == 0) {
            cell.textLabel.text = [L stringForKey:@"settings.export_pcap"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = [L stringForKey:@"settings.clear"];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    return cell;
}

- (NSString *)currentLanguageTitle {
    AppLanguage lang = (AppLanguage)[[NSUserDefaults standardUserDefaults] integerForKey:kAppLanguageKey];
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    switch (lang) {
        case AppLanguageChinese: return [L stringForKey:@"language.chinese"];
        case AppLanguageJapanese: return [L stringForKey:@"language.japanese"];
        case AppLanguageSpanish: return [L stringForKey:@"language.spanish"];
        case AppLanguageFrench: return [L stringForKey:@"language.french"];
        default: return [L stringForKey:@"language.english"];
    }
}

- (void)vpnExclusionChanged:(UISwitch *)sw {
    [PacketCaptureService setVPNPacketExclusionEnabled:sw.on error:nil];
}

- (void)privateChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kPrivateModeKey];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    if (indexPath.section == 1) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[L stringForKey:@"settings.language"]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        void (^pick)(AppLanguage) = ^(AppLanguage lang) {
            [[NSUserDefaults standardUserDefaults] setInteger:lang forKey:kAppLanguageKey];
            [LocalizationManagerService sharedService].preferredLanguage = lang;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PipeLanguageDidChange" object:nil];
            [self.tableView reloadData];
        };
        [sheet addAction:[UIAlertAction actionWithTitle:[L stringForKey:@"language.english"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { pick(AppLanguageEnglish); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[L stringForKey:@"language.chinese"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { pick(AppLanguageChinese); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[L stringForKey:@"language.japanese"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { pick(AppLanguageJapanese); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[L stringForKey:@"language.spanish"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { pick(AppLanguageSpanish); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[L stringForKey:@"language.french"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { pick(AppLanguageFrench); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        sheet.popoverPresentationController.sourceView = [tableView cellForRowAtIndexPath:indexPath];
        [self presentViewController:sheet animated:YES completion:nil];
        return;
    }
    if (indexPath.section != 2) {
        return;
    }
    if (indexPath.row == 0) {
        NSArray *packets = [[PacketCaptureService sharedService] snapshotCapturedPackets];
        NSURL *tmp = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Pipe-export.pcap"]];
        NSError *err = nil;
        if (![PCAPExportService exportPackets:packets toURL:tmp error:&err]) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:[L stringForKey:@"export.fail"]
                                                                         message:err.localizedDescription
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
            return;
        }
        UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:@[tmp] applicationActivities:nil];
        if (act.popoverPresentationController) {
            act.popoverPresentationController.sourceView = self.view;
        }
        [self presentViewController:act animated:YES completion:nil];
    } else {
        NSError *e = nil;
        [[PacketCaptureService sharedService] clearCapturedPacketsWithError:&e];
    }
}

@end
