//
//  VPNConfiguration.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// VPN protocol types
typedef NS_ENUM(NSInteger, VPNProtocol) {
    VPNProtocolWireGuard,
    VPNProtocolOpenVPN,
    VPNProtocolIKEv2
};

/// Authentication methods
typedef NS_ENUM(NSInteger, AuthenticationMethod) {
    AuthenticationMethodPassword,
    AuthenticationMethodCertificate,
    AuthenticationMethodToken
};

/// VPN authentication
@interface VPNAuthentication : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) AuthenticationMethod method;
@property (nonatomic, copy) NSString * _Nullable username;
@property (nonatomic, copy) NSString * _Nullable password;
@property (nonatomic, copy) NSData * _Nullable certificate;
@property (nonatomic, copy) NSData * _Nullable privateKey;

- (instancetype)initWithMethod:(AuthenticationMethod)method
                      username:(NSString * _Nullable)username
                      password:(NSString * _Nullable)password
                   certificate:(NSData * _Nullable)certificate
                    privateKey:(NSData * _Nullable)privateKey;

/// Password authentication
+ (instancetype)passwordAuthenticationWithUsername:(NSString *)username
                                          password:(NSString *)password;

/// Certificate authentication
+ (instancetype)certificateAuthenticationWithCertificate:(NSData *)certificate
                                              privateKey:(NSData * _Nullable)privateKey;

@end

/// VPN routing configuration
@interface VPNRouting : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) BOOL splitTunnel;
@property (nonatomic, copy) NSArray<NSString *> *allowedIPs;
@property (nonatomic, copy) NSArray<NSString *> *disallowedIPs;

- (instancetype)initWithSplitTunnel:(BOOL)splitTunnel
                         allowedIPs:(NSArray<NSString *> *)allowedIPs
                      disallowedIPs:(NSArray<NSString *> *)disallowedIPs;

/// Full tunnel (all traffic through VPN)
+ (instancetype)fullTunnel;

/// Split tunnel with specific IP ranges
+ (instancetype)splitTunnelWithAllowedIPs:(NSArray<NSString *> *)allowedIPs
                           disallowedIPs:(NSArray<NSString *> *)disallowedIPs;

@end

/// VPN configuration
@interface VPNConfiguration : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSUUID *configId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign) VPNProtocol protocol;
@property (nonatomic, strong) VPNAuthentication *authentication;
@property (nonatomic, strong) VPNRouting *routing;
@property (nonatomic, copy) NSArray<NSString *> *dnsServers;
@property (nonatomic, assign) NSUInteger mtu;
@property (nonatomic, assign) BOOL isEnabled;

- (instancetype)initWithConfigId:(NSUUID *)configId
                            name:(NSString *)name
                   serverAddress:(NSString *)serverAddress
                            port:(NSUInteger)port
                        protocol:(VPNProtocol)protocol
                  authentication:(VPNAuthentication *)authentication
                         routing:(VPNRouting *)routing
                      dnsServers:(NSArray<NSString *> *)dnsServers
                             mtu:(NSUInteger)mtu
                       isEnabled:(BOOL)isEnabled;

/// Convenience initializer
- (instancetype)initWithName:(NSString *)name
               serverAddress:(NSString *)serverAddress
                        port:(NSUInteger)port
                    protocol:(VPNProtocol)protocol
              authentication:(VPNAuthentication *)authentication
                     routing:(VPNRouting *)routing
                  dnsServers:(NSArray<NSString *> *)dnsServers
                         mtu:(NSUInteger)mtu;

/// Convert to dictionary for JSON serialization
- (NSDictionary *)toDictionary;

/// Create from dictionary (JSON deserialization)
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END