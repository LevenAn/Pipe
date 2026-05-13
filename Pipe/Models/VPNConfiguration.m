//
//  VPNConfiguration.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "VPNConfiguration.h"

@implementation VPNAuthentication

- (instancetype)initWithMethod:(AuthenticationMethod)method
                      username:(NSString *)username
                      password:(NSString *)password
                   certificate:(NSData *)certificate
                    privateKey:(NSData *)privateKey {
    self = [super init];
    if (self) {
        _method = method;
        _username = [username copy];
        _password = [password copy];
        _certificate = [certificate copy];
        _privateKey = [privateKey copy];
    }
    return self;
}

+ (instancetype)passwordAuthenticationWithUsername:(NSString *)username
                                          password:(NSString *)password {
    return [[VPNAuthentication alloc] initWithMethod:AuthenticationMethodPassword
                                            username:username
                                            password:password
                                         certificate:nil
                                          privateKey:nil];
}

+ (instancetype)certificateAuthenticationWithCertificate:(NSData *)certificate
                                              privateKey:(NSData *)privateKey {
    return [[VPNAuthentication alloc] initWithMethod:AuthenticationMethodCertificate
                                            username:nil
                                            password:nil
                                         certificate:certificate
                                          privateKey:privateKey];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _method = [coder decodeIntegerForKey:@"method"];
        _username = [coder decodeObjectForKey:@"username"];
        _password = [coder decodeObjectForKey:@"password"];
        _certificate = [coder decodeObjectForKey:@"certificate"];
        _privateKey = [coder decodeObjectForKey:@"privateKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.method forKey:@"method"];
    [coder encodeObject:self.username forKey:@"username"];
    [coder encodeObject:self.password forKey:@"password"];
    [coder encodeObject:self.certificate forKey:@"certificate"];
    [coder encodeObject:self.privateKey forKey:@"privateKey"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    VPNAuthentication *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_method = self.method;
        copy->_username = [self.username copyWithZone:zone];
        copy->_password = [self.password copyWithZone:zone];
        copy->_certificate = [self.certificate copyWithZone:zone];
        copy->_privateKey = [self.privateKey copyWithZone:zone];
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<VPNAuthentication: method=%ld, username=%@>",
            (long)self.method, self.username];
}

@end

@implementation VPNRouting

- (instancetype)initWithSplitTunnel:(BOOL)splitTunnel
                         allowedIPs:(NSArray<NSString *> *)allowedIPs
                      disallowedIPs:(NSArray<NSString *> *)disallowedIPs {
    self = [super init];
    if (self) {
        _splitTunnel = splitTunnel;
        _allowedIPs = [allowedIPs copy];
        _disallowedIPs = [disallowedIPs copy];
    }
    return self;
}

+ (instancetype)fullTunnel {
    return [[VPNRouting alloc] initWithSplitTunnel:NO
                                        allowedIPs:@[@"0.0.0.0/0", @"::/0"]
                                     disallowedIPs:@[]];
}

+ (instancetype)splitTunnelWithAllowedIPs:(NSArray<NSString *> *)allowedIPs
                           disallowedIPs:(NSArray<NSString *> *)disallowedIPs {
    return [[VPNRouting alloc] initWithSplitTunnel:YES
                                        allowedIPs:allowedIPs
                                     disallowedIPs:disallowedIPs];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _splitTunnel = [coder decodeBoolForKey:@"splitTunnel"];
        _allowedIPs = [coder decodeObjectForKey:@"allowedIPs"];
        _disallowedIPs = [coder decodeObjectForKey:@"disallowedIPs"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.splitTunnel forKey:@"splitTunnel"];
    [coder encodeObject:self.allowedIPs forKey:@"allowedIPs"];
    [coder encodeObject:self.disallowedIPs forKey:@"disallowedIPs"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    VPNRouting *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_splitTunnel = self.splitTunnel;
        copy->_allowedIPs = [self.allowedIPs copyWithZone:zone];
        copy->_disallowedIPs = [self.disallowedIPs copyWithZone:zone];
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<VPNRouting: splitTunnel=%d, allowedIPs=%@>",
            self.splitTunnel, self.allowedIPs];
}

@end

@implementation VPNConfiguration

- (instancetype)initWithConfigId:(NSUUID *)configId
                            name:(NSString *)name
                   serverAddress:(NSString *)serverAddress
                            port:(NSUInteger)port
                        protocol:(VPNProtocol)protocol
                  authentication:(VPNAuthentication *)authentication
                         routing:(VPNRouting *)routing
                      dnsServers:(NSArray<NSString *> *)dnsServers
                             mtu:(NSUInteger)mtu
                       isEnabled:(BOOL)isEnabled {
    self = [super init];
    if (self) {
        _configId = [configId copy];
        _name = [name copy];
        _serverAddress = [serverAddress copy];
        _port = port;
        _protocol = protocol;
        _authentication = authentication;
        _routing = routing;
        _dnsServers = [dnsServers copy];
        _mtu = mtu;
        _isEnabled = isEnabled;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
               serverAddress:(NSString *)serverAddress
                        port:(NSUInteger)port
                    protocol:(VPNProtocol)protocol
              authentication:(VPNAuthentication *)authentication
                     routing:(VPNRouting *)routing
                  dnsServers:(NSArray<NSString *> *)dnsServers
                         mtu:(NSUInteger)mtu {
    return [self initWithConfigId:[NSUUID UUID]
                             name:name
                    serverAddress:serverAddress
                             port:port
                         protocol:protocol
                   authentication:authentication
                          routing:routing
                       dnsServers:dnsServers
                              mtu:mtu
                        isEnabled:YES];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _configId = [coder decodeObjectForKey:@"configId"];
        _name = [coder decodeObjectForKey:@"name"];
        _serverAddress = [coder decodeObjectForKey:@"serverAddress"];
        _port = [coder decodeIntegerForKey:@"port"];
        _protocol = [coder decodeIntegerForKey:@"protocol"];
        _authentication = [coder decodeObjectForKey:@"authentication"];
        _routing = [coder decodeObjectForKey:@"routing"];
        _dnsServers = [coder decodeObjectForKey:@"dnsServers"];
        _mtu = [coder decodeIntegerForKey:@"mtu"];
        _isEnabled = [coder decodeBoolForKey:@"isEnabled"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.configId forKey:@"configId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.serverAddress forKey:@"serverAddress"];
    [coder encodeInteger:self.port forKey:@"port"];
    [coder encodeInteger:self.protocol forKey:@"protocol"];
    [coder encodeObject:self.authentication forKey:@"authentication"];
    [coder encodeObject:self.routing forKey:@"routing"];
    [coder encodeObject:self.dnsServers forKey:@"dnsServers"];
    [coder encodeInteger:self.mtu forKey:@"mtu"];
    [coder encodeBool:self.isEnabled forKey:@"isEnabled"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    VPNConfiguration *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_configId = [self.configId copyWithZone:zone];
        copy->_name = [self.name copyWithZone:zone];
        copy->_serverAddress = [self.serverAddress copyWithZone:zone];
        copy->_port = self.port;
        copy->_protocol = self.protocol;
        copy->_authentication = [self.authentication copyWithZone:zone];
        copy->_routing = [self.routing copyWithZone:zone];
        copy->_dnsServers = [self.dnsServers copyWithZone:zone];
        copy->_mtu = self.mtu;
        copy->_isEnabled = self.isEnabled;
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"id"] = [self.configId UUIDString];
    dict[@"name"] = self.name ?: @"";
    dict[@"serverAddress"] = self.serverAddress ?: @"";
    dict[@"port"] = @(self.port);
    dict[@"protocol"] = [self protocolString];
    dict[@"isEnabled"] = @(self.isEnabled);
    
    if (self.authentication) {
        NSMutableDictionary *authDict = [NSMutableDictionary dictionary];
        authDict[@"method"] = [self authenticationMethodString];
        
        if (self.authentication.username) {
            authDict[@"username"] = self.authentication.username;
        }
        
        if (self.authentication.password) {
            authDict[@"password"] = self.authentication.password;
        }
        
        if (self.authentication.certificate) {
            authDict[@"certificate"] = [self.authentication.certificate base64EncodedStringWithOptions:0];
        }
        
        if (self.authentication.privateKey) {
            authDict[@"privateKey"] = [self.authentication.privateKey base64EncodedStringWithOptions:0];
        }
        
        dict[@"authentication"] = authDict;
    }
    
    if (self.routing) {
        NSMutableDictionary *routingDict = [NSMutableDictionary dictionary];
        routingDict[@"splitTunnel"] = @(self.routing.splitTunnel);
        routingDict[@"allowedIPs"] = self.routing.allowedIPs ?: @[];
        routingDict[@"disallowedIPs"] = self.routing.disallowedIPs ?: @[];
        dict[@"routing"] = routingDict;
    }
    
    dict[@"dnsServers"] = self.dnsServers ?: @[];
    
    if (self.mtu > 0) {
        dict[@"mtu"] = @(self.mtu);
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSUUID *configId = [[NSUUID alloc] initWithUUIDString:dictionary[@"id"]] ?: [NSUUID UUID];
    NSString *name = dictionary[@"name"] ?: @"";
    NSString *serverAddress = dictionary[@"serverAddress"] ?: @"";
    NSUInteger port = [dictionary[@"port"] unsignedIntegerValue];
    VPNProtocol protocol = [self protocolFromString:dictionary[@"protocol"]];
    BOOL isEnabled = [dictionary[@"isEnabled"] boolValue];
    
    VPNAuthentication *authentication = nil;
    NSDictionary *authDict = dictionary[@"authentication"];
    if ([authDict isKindOfClass:[NSDictionary class]]) {
        AuthenticationMethod method = [self authenticationMethodFromString:authDict[@"method"]];
        NSString *username = authDict[@"username"];
        NSString *password = authDict[@"password"];
        
        NSData *certificate = nil;
        NSString *certString = authDict[@"certificate"];
        if ([certString isKindOfClass:[NSString class]]) {
            certificate = [[NSData alloc] initWithBase64EncodedString:certString options:0];
        }
        
        NSData *privateKey = nil;
        NSString *keyString = authDict[@"privateKey"];
        if ([keyString isKindOfClass:[NSString class]]) {
            privateKey = [[NSData alloc] initWithBase64EncodedString:keyString options:0];
        }
        
        authentication = [[VPNAuthentication alloc] initWithMethod:method
                                                          username:username
                                                          password:password
                                                       certificate:certificate
                                                        privateKey:privateKey];
    }
    
    VPNRouting *routing = nil;
    NSDictionary *routingDict = dictionary[@"routing"];
    if ([routingDict isKindOfClass:[NSDictionary class]]) {
        BOOL splitTunnel = [routingDict[@"splitTunnel"] boolValue];
        NSArray *allowedIPs = routingDict[@"allowedIPs"] ?: @[];
        NSArray *disallowedIPs = routingDict[@"disallowedIPs"] ?: @[];
        routing = [[VPNRouting alloc] initWithSplitTunnel:splitTunnel
                                               allowedIPs:allowedIPs
                                            disallowedIPs:disallowedIPs];
    } else {
        routing = [VPNRouting fullTunnel];
    }
    
    NSArray *dnsServers = dictionary[@"dnsServers"] ?: @[];
    NSUInteger mtu = [dictionary[@"mtu"] unsignedIntegerValue];
    
    return [[VPNConfiguration alloc] initWithConfigId:configId
                                                 name:name
                                        serverAddress:serverAddress
                                                 port:port
                                             protocol:protocol
                                       authentication:authentication
                                              routing:routing
                                           dnsServers:dnsServers
                                                  mtu:mtu
                                            isEnabled:isEnabled];
}

#pragma mark - Protocol Helpers

- (NSString *)protocolString {
    switch (self.protocol) {
        case VPNProtocolWireGuard: return @"WireGuard";
        case VPNProtocolOpenVPN: return @"OpenVPN";
        case VPNProtocolIKEv2: return @"IKEv2";
        default: return @"Unknown";
    }
}

+ (VPNProtocol)protocolFromString:(NSString *)string {
    if ([string isEqualToString:@"WireGuard"]) return VPNProtocolWireGuard;
    if ([string isEqualToString:@"OpenVPN"]) return VPNProtocolOpenVPN;
    if ([string isEqualToString:@"IKEv2"]) return VPNProtocolIKEv2;
    return VPNProtocolWireGuard;
}

#pragma mark - Authentication Method Helpers

- (NSString *)authenticationMethodString {
    switch (self.authentication.method) {
        case AuthenticationMethodPassword: return @"password";
        case AuthenticationMethodCertificate: return @"certificate";
        case AuthenticationMethodToken: return @"token";
        default: return @"unknown";
    }
}

+ (AuthenticationMethod)authenticationMethodFromString:(NSString *)string {
    if ([string isEqualToString:@"password"]) return AuthenticationMethodPassword;
    if ([string isEqualToString:@"certificate"]) return AuthenticationMethodCertificate;
    if ([string isEqualToString:@"token"]) return AuthenticationMethodToken;
    return AuthenticationMethodPassword;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<VPNConfiguration: id=%@, name=%@, server=%@:%ld, protocol=%ld, enabled=%d>",
            self.configId, self.name, self.serverAddress, (long)self.port, (long)self.protocol, self.isEnabled];
}

@end