//
//  VPNManagerService.m
//  Pipe
//

#import "VPNManagerService.h"
#import <NetworkExtension/NetworkExtension.h>
#import <Security/Security.h>

static NSString *const kVPNKeychainService = @"tube.Pipe.vpn.password";

static NSData *VPNPasswordReferenceForAccount(NSString *account, NSString *password) {
    if (!account.length || !password.length) {
        return nil;
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kVPNKeychainService,
        (__bridge id)kSecAttrAccount: account
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
    NSData *pwData = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *add = [query mutableCopy];
    add[(__bridge id)kSecValueData] = pwData;
    add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    add[(__bridge id)kSecReturnPersistentRef] = @YES;
    CFTypeRef out = NULL;
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)add, &out);
    if (st != errSecSuccess || out == NULL) {
        return nil;
    }
    return CFBridgingRelease(out);
}

@interface VPNManagerService ()

@property (nonatomic, strong) VPNConfiguration *lastConfiguration;
@property (nonatomic, assign) BOOL reconnecting;
@property (nonatomic, assign) NSUInteger reconnectAttempt;
@property (nonatomic, strong) id observerToken;

@end

@implementation VPNManagerService

+ (VPNManagerService *)sharedService {
    static VPNManagerService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoReconnectEnabled = YES;
        _reconnectBaseDelay = 2.0;
        __weak typeof(self) weakSelf = self;
        _observerToken = [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification
                                                                             object:nil
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
            [weakSelf handleStatusChange];
        }];
    }
    return self;
}

- (void)dealloc {
    if (self.observerToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.observerToken];
    }
}

- (void)refreshVPNAuthorizationWithCompletion:(void (^)(BOOL))completion {
    [NEVPNManager.sharedManager loadFromPreferencesWithCompletionHandler:^(NSError *error) {
        if (completion) {
            completion(error == nil);
        }
    }];
}

- (void)applyVPNConfiguration:(VPNConfiguration *)configuration
                   completion:(void (^)(NSError *))completion {
    if (!configuration) {
        if (completion) {
            completion([NSError errorWithDomain:@"VPNManagerService" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing configuration"}]);
        }
        return;
    }
    self.lastConfiguration = configuration;

    if (configuration.protocol == VPNProtocolWireGuard || configuration.protocol == VPNProtocolOpenVPN) {
        if (completion) {
            completion([NSError errorWithDomain:@"VPNManagerService" code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"WireGuard / OpenVPN 需在 Xcode 中增加 Packet Tunnel Extension 与相应二进制（如 WireGuardKit / OpenVPN3）。当前版本仅实现 IKEv2（NEVPNProtocolIKEv2）。"}]);
        }
        return;
    }

    NEVPNManager *mgr = [NEVPNManager sharedManager];
    [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
        if (loadError) {
            if (completion) {
                completion(loadError);
            }
            return;
        }

        NEVPNProtocolIKEv2 *ike = [[NEVPNProtocolIKEv2 alloc] init];
        ike.serverAddress = configuration.serverAddress;
        ike.remoteIdentifier = configuration.serverAddress;
        NSString *user = configuration.authentication.username ?: @"";
        ike.username = user;
        if (configuration.authentication.password.length) {
            NSString *acct = [NSString stringWithFormat:@"%@::%@", configuration.serverAddress, configuration.configId.UUIDString];
            ike.passwordReference = VPNPasswordReferenceForAccount(acct, configuration.authentication.password);
        }
        ike.authenticationMethod = NEVPNIKEAuthenticationMethodNone;
        ike.useExtendedAuthentication = YES;

        mgr.protocolConfiguration = ike;
        mgr.localizedDescription = configuration.name.length ? configuration.name : @"Pipe";
        mgr.enabled = YES;

        [mgr saveToPreferencesWithCompletionHandler:^(NSError *saveError) {
            if (completion) {
                completion(saveError);
            }
        }];
    }];
}

- (void)connectLastSavedConfigurationWithCompletion:(void (^)(NSError *))completion {
    NEVPNManager *mgr = [NEVPNManager sharedManager];
    [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
        if (loadError) {
            if (completion) {
                completion(loadError);
            }
            return;
        }
        NSError *startErr = nil;
        BOOL ok = [[mgr connection] startVPNTunnelAndReturnError:&startErr];
        if (!ok && completion) {
            completion(startErr);
            return;
        }
        self.reconnectAttempt = 0;
        if (completion) {
            completion(nil);
        }
    }];
}

- (void)disconnect {
    [[NEVPNManager.sharedManager connection] stopVPNTunnel];
    self.reconnecting = NO;
    self.reconnectAttempt = 0;
    self.lastConfiguration = nil;
}

- (BOOL)isVPNActive {
    return NEVPNManager.sharedManager.connection.status == NEVPNStatusConnected;
}

- (NSString *)statusDescription {
    switch (NEVPNManager.sharedManager.connection.status) {
        case NEVPNStatusInvalid: return @"Invalid";
        case NEVPNStatusDisconnected: return @"Disconnected";
        case NEVPNStatusConnecting: return @"Connecting";
        case NEVPNStatusConnected: return @"Connected";
        case NEVPNStatusReasserting: return @"Reasserting";
        case NEVPNStatusDisconnecting: return @"Disconnecting";
    }
}

- (void)handleStatusChange {
    NEVPNStatus st = NEVPNManager.sharedManager.connection.status;
    if ([self.delegate respondsToSelector:@selector(vpnManager:statusDidChange:)]) {
        [self.delegate vpnManager:self statusDidChange:(NSInteger)st];
    }
    if (st == NEVPNStatusDisconnected && self.autoReconnectEnabled && self.lastConfiguration &&
        self.lastConfiguration.protocol == VPNProtocolIKEv2) {
        [self scheduleReconnectIfNeeded];
    }
    if (st != NEVPNStatusDisconnected) {
        self.reconnecting = NO;
    }
}

- (void)scheduleReconnectIfNeeded {
    if (self.reconnectAttempt >= 6) {
        if ([self.delegate respondsToSelector:@selector(vpnManager:didFailWithError:)]) {
            NSError *e = [NSError errorWithDomain:@"VPNManagerService" code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"多次重连失败，已停止自动重连"}];
            [self.delegate vpnManager:self didFailWithError:e];
        }
        return;
    }
    self.reconnecting = YES;
    self.reconnectAttempt++;
    NSTimeInterval delay = self.reconnectBaseDelay * pow(2.0, (double)(self.reconnectAttempt - 1));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self connectLastSavedConfigurationWithCompletion:^(NSError *error) {
            if (error && [self.delegate respondsToSelector:@selector(vpnManager:didFailWithError:)]) {
                [self.delegate vpnManager:self didFailWithError:error];
            }
        }];
    });
}

@end
