//
//  VPNManagerService.h
//  Pipe
//

#import <Foundation/Foundation.h>
#import "../Models/VPNConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@class VPNManagerService;

@protocol VPNManagerDelegate <NSObject>
@optional
- (void)vpnManager:(VPNManagerService *)manager statusDidChange:(NSInteger)status;
- (void)vpnManager:(VPNManagerService *)manager didFailWithError:(NSError *)error;
@end

@interface VPNManagerService : NSObject

+ (instancetype)sharedService;
@property (nonatomic, weak) id<VPNManagerDelegate> delegate;

@property (nonatomic, assign, readonly, getter=isReconnecting) BOOL reconnecting;
@property (nonatomic, assign) BOOL autoReconnectEnabled;
@property (nonatomic, assign) NSTimeInterval reconnectBaseDelay;

- (void)refreshVPNAuthorizationWithCompletion:(void (^)(BOOL granted))completion;

/// Applies and saves VPN configuration. IKEv2 is fully supported; WireGuard/OpenVPN require a Packet Tunnel provider extension (not included).
- (void)applyVPNConfiguration:(VPNConfiguration *)configuration
                   completion:(void (^)(NSError * _Nullable error))completion;

- (void)connectLastSavedConfigurationWithCompletion:(void (^)(NSError * _Nullable error))completion;

- (void)disconnect;

- (BOOL)isVPNActive;

/// Human-readable status for UI.
- (NSString *)statusDescription;

@end

NS_ASSUME_NONNULL_END
