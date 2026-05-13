//
//  PipeDashboardViewController.m
//  Pipe
//

#import "PipeDashboardViewController.h"
#import "PacketCaptureService.h"
#import "VPNManagerService.h"
#import "LocalizationManagerService.h"
#import "VPNConfiguration.h"
#import "CapturedPacket.h"

@interface PipeDashboardViewController () <PacketCaptureDelegate>
@property (nonatomic, strong) UILabel *vpnLabel;
@property (nonatomic, strong) UILabel *captureLabel;
@property (nonatomic, strong) UILabel *metricsLabel;
@property (nonatomic, strong) UIButton *vpnButton;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *simulateButton;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UITextField *userField;
@property (nonatomic, strong) UITextField *passField;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation PipeDashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:1];
    self.title = [[LocalizationManagerService sharedService] stringForKey:@"tab.dashboard"];

    PacketCaptureService.sharedService.delegate = self;

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.scroll.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor constant:-32]
    ]];

    self.vpnLabel = [self label];
    self.captureLabel = [self label];
    self.metricsLabel = [self label];
    self.metricsLabel.numberOfLines = 0;

    self.serverField = [self fieldPlaceholder:@"IKEv2 server (hostname)"];
    self.userField = [self fieldPlaceholder:@"Username"];
    self.passField = [self fieldPlaceholder:@"Password"];
    self.passField.secureTextEntry = YES;

    self.vpnButton = [self primaryButtonTitleKey:@"vpn.connect"];
    [self.vpnButton addTarget:self action:@selector(toggleVPN) forControlEvents:UIControlEventTouchUpInside];

    self.captureButton = [self primaryButtonTitleKey:@"capture.start"];
    [self.captureButton addTarget:self action:@selector(toggleCapture) forControlEvents:UIControlEventTouchUpInside];

    self.simulateButton = [self secondaryButtonTitleKey:@"capture.simulate"];
    [self.simulateButton addTarget:self action:@selector(simulate) forControlEvents:UIControlEventTouchUpInside];

    UILabel *hint = [self label];
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = [UIColor secondaryLabelColor];
    hint.text = [[LocalizationManagerService sharedService] stringForKey:@"vpn.configure"];
    hint.numberOfLines = 0;

    for (UIView *v in @[self.vpnLabel, self.captureLabel, self.metricsLabel, self.serverField, self.userField, self.passField, self.vpnButton, self.captureButton, self.simulateButton, hint]) {
        [stack addArrangedSubview:v];
    }

    [self refreshStatus];
    __weak typeof(self) weakSelf = self;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        [weakSelf refreshStatus];
    }];
}

- (void)dealloc {
    [self.refreshTimer invalidate];
}

- (UILabel *)label {
    UILabel *l = [[UILabel alloc] init];
    l.textColor = [UIColor labelColor];
    l.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    l.numberOfLines = 0;
    return l;
}

- (UITextField *)fieldPlaceholder:(NSString *)ph {
    UITextField *f = [[UITextField alloc] init];
    f.placeholder = ph;
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.backgroundColor = [UIColor secondarySystemBackgroundColor];
    f.textColor = [UIColor labelColor];
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    return f;
}

- (UIButton *)primaryButtonTitleKey:(NSString *)key {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:[[LocalizationManagerService sharedService] stringForKey:key] forState:UIControlStateNormal];
    b.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    return b;
}

- (UIButton *)secondaryButtonTitleKey:(NSString *)key {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:[[LocalizationManagerService sharedService] stringForKey:key] forState:UIControlStateNormal];
    b.backgroundColor = [UIColor tertiarySystemFillColor];
    [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    return b;
}

- (void)refreshStatus {
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    self.vpnLabel.text = [L stringForKey:@"vpn.status" arguments:@[[VPNManagerService.sharedService statusDescription]]];
    PacketCaptureService *cap = [PacketCaptureService sharedService];
    NSString *capState = cap.isCapturing ? [L stringForKey:@"capture.running"] : [L stringForKey:@"capture.stopped"];
    self.captureLabel.text = [L stringForKey:@"capture.status" arguments:@[capState]];
    NSDictionary *st = [cap captureStatistics];
    self.metricsLabel.text = [NSString stringWithFormat:@"%@\n%@",
                            [L stringForKey:@"metrics.packets" arguments:@[st[@"totalPackets"] ?: @0]],
                            [L stringForKey:@"metrics.filtered" arguments:@[st[@"filteredPackets"] ?: @0]]];

    BOOL vpnOn = [VPNManagerService.sharedService isVPNActive];
    [self.vpnButton setTitle:[L stringForKey:(vpnOn ? @"vpn.disconnect" : @"vpn.connect")] forState:UIControlStateNormal];

    BOOL capOn = cap.isCapturing;
    [self.captureButton setTitle:[L stringForKey:(capOn ? @"capture.stop" : @"capture.start")] forState:UIControlStateNormal];
}

- (void)toggleVPN {
    if ([VPNManagerService.sharedService isVPNActive]) {
        [VPNManagerService.sharedService disconnect];
        [self refreshStatus];
        return;
    }
    NSString *host = self.serverField.text ?: @"";
    if (!host.length) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Pipe" message:@"请输入 IKEv2 服务器地址" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    VPNAuthentication *auth = [VPNAuthentication passwordAuthenticationWithUsername:self.userField.text ?: @""
                                                                        password:self.passField.text ?: @""];
    VPNRouting *route = [VPNRouting fullTunnel];
    VPNConfiguration *cfg = [[VPNConfiguration alloc] initWithName:@"Pipe IKEv2"
                                                     serverAddress:host
                                                              port:500
                                                          protocol:VPNProtocolIKEv2
                                                    authentication:auth
                                                           routing:route
                                                        dnsServers:@[@"1.1.1.1"]
                                                               mtu:1400];
    [VPNManagerService.sharedService applyVPNConfiguration:cfg completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"VPN" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:a animated:YES completion:nil];
                return;
            }
            [VPNManagerService.sharedService connectLastSavedConfigurationWithCompletion:^(NSError *e2) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (e2) {
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"VPN" message:e2.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [self presentViewController:a animated:YES completion:nil];
                    }
                    [self refreshStatus];
                });
            }];
        });
    }];
}

- (void)toggleCapture {
    PacketCaptureService *cap = [PacketCaptureService sharedService];
    NSError *err = nil;
    if (cap.isCapturing) {
        [cap stopCaptureWithError:&err];
    } else {
        PIPCapConfiguration *cfg = [PIPCapConfiguration defaultConfiguration];
        [cap startCaptureWithConfiguration:cfg error:&err];
    }
    if (err) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Capture" message:err.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
    [self refreshStatus];
}

- (void)simulate {
    NSData *http = [@"GET / HTTP/1.1\r\nHost: example.com\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    CapturedPacket *p = [[CapturedPacket alloc] initWithSourceIP:@"192.168.1.20"
                                                  destinationIP:@"93.184.216.34"
                                                     sourcePort:52431
                                                destinationPort:80
                                                       protocol:NetworkProtocolHTTP
                                                           size:http.length
                                                        headers:@{@"User-Agent": @"Pipe/1.0"}
                                                        payload:http];
    [[PacketCaptureService sharedService] simulatePacketCapture:p];

    NSData *dns = [NSData dataWithBytes:(uint8_t[]){0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00} length:12];
    CapturedPacket *d = [[CapturedPacket alloc] initWithSourceIP:@"192.168.1.20"
                                                 destinationIP:@"8.8.8.8"
                                                    sourcePort:55555
                                               destinationPort:53
                                                      protocol:NetworkProtocolDNS
                                                          size:dns.length
                                                       headers:@{}
                                                       payload:dns];
    [[PacketCaptureService sharedService] simulatePacketCapture:d];
    [self refreshStatus];
}

#pragma mark - PacketCaptureDelegate

- (void)packetCaptureDidUpdateStatistics:(NSDictionary *)statistics {
    dispatch_async(dispatch_get_main_queue(), ^{ [self refreshStatus]; });
}

@end
