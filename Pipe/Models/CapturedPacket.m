//
//  CapturedPacket.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "CapturedPacket.h"

@implementation PacketMetadata

- (instancetype)initWithInterface:(NSString *)interface
                        direction:(PacketDirection)direction
                            flags:(PacketFlag)flags
                  sequenceNumber:(NSInteger)sequenceNumber
            acknowledgementNumber:(NSInteger)acknowledgementNumber {
    self = [super init];
    if (self) {
        _interface = [interface copy];
        _direction = direction;
        _flags = flags;
        _sequenceNumber = sequenceNumber;
        _acknowledgementNumber = acknowledgementNumber;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _interface = [coder decodeObjectForKey:@"interface"];
        _direction = [coder decodeIntegerForKey:@"direction"];
        _flags = [coder decodeIntegerForKey:@"flags"];
        _sequenceNumber = [coder decodeIntegerForKey:@"sequenceNumber"];
        _acknowledgementNumber = [coder decodeIntegerForKey:@"acknowledgementNumber"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.interface forKey:@"interface"];
    [coder encodeInteger:self.direction forKey:@"direction"];
    [coder encodeInteger:self.flags forKey:@"flags"];
    [coder encodeInteger:self.sequenceNumber forKey:@"sequenceNumber"];
    [coder encodeInteger:self.acknowledgementNumber forKey:@"acknowledgementNumber"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PacketMetadata *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_interface = [self.interface copyWithZone:zone];
        copy->_direction = self.direction;
        copy->_flags = self.flags;
        copy->_sequenceNumber = self.sequenceNumber;
        copy->_acknowledgementNumber = self.acknowledgementNumber;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<PacketMetadata: interface=%@, direction=%ld, flags=%lu, seq=%ld, ack=%ld>",
            self.interface, (long)self.direction, (unsigned long)self.flags,
            (long)self.sequenceNumber, (long)self.acknowledgementNumber];
}

@end

@implementation CapturedPacket

- (instancetype)initWithPacketId:(NSUUID *)packetId
                       timestamp:(NSDate *)timestamp
                        sourceIP:(NSString *)sourceIP
                   destinationIP:(NSString *)destinationIP
                      sourcePort:(NSUInteger)sourcePort
                 destinationPort:(NSUInteger)destinationPort
                        protocol:(NetworkProtocol)protocol
                            size:(NSUInteger)size
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         payload:(NSData *)payload
                        metadata:(PacketMetadata *)metadata {
    self = [super init];
    if (self) {
        _packetId = [packetId copy];
        _timestamp = timestamp;
        _sourceIP = [sourceIP copy];
        _destinationIP = [destinationIP copy];
        _sourcePort = sourcePort;
        _destinationPort = destinationPort;
        _protocol = protocol;
        _size = size;
        _headers = [headers copy];
        _payload = [payload copy];
        _metadata = metadata;
    }
    return self;
}

- (instancetype)initWithSourceIP:(NSString *)sourceIP
                   destinationIP:(NSString *)destinationIP
                      sourcePort:(NSUInteger)sourcePort
                 destinationPort:(NSUInteger)destinationPort
                        protocol:(NetworkProtocol)protocol
                            size:(NSUInteger)size
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         payload:(NSData *)payload {
    return [self initWithPacketId:[NSUUID UUID]
                        timestamp:[NSDate date]
                         sourceIP:sourceIP
                    destinationIP:destinationIP
                       sourcePort:sourcePort
                  destinationPort:destinationPort
                         protocol:protocol
                             size:size
                          headers:headers
                          payload:payload
                         metadata:[[PacketMetadata alloc] initWithInterface:@"en0"
                                                                  direction:PacketDirectionIncoming
                                                                      flags:0
                                                            sequenceNumber:0
                                                      acknowledgementNumber:0]];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _packetId = [coder decodeObjectForKey:@"packetId"];
        _timestamp = [coder decodeObjectForKey:@"timestamp"];
        _sourceIP = [coder decodeObjectForKey:@"sourceIP"];
        _destinationIP = [coder decodeObjectForKey:@"destinationIP"];
        _sourcePort = [coder decodeIntegerForKey:@"sourcePort"];
        _destinationPort = [coder decodeIntegerForKey:@"destinationPort"];
        _protocol = [coder decodeIntegerForKey:@"protocol"];
        _size = [coder decodeIntegerForKey:@"size"];
        _headers = [coder decodeObjectForKey:@"headers"];
        _payload = [coder decodeObjectForKey:@"payload"];
        _metadata = [coder decodeObjectForKey:@"metadata"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.packetId forKey:@"packetId"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeObject:self.sourceIP forKey:@"sourceIP"];
    [coder encodeObject:self.destinationIP forKey:@"destinationIP"];
    [coder encodeInteger:self.sourcePort forKey:@"sourcePort"];
    [coder encodeInteger:self.destinationPort forKey:@"destinationPort"];
    [coder encodeInteger:self.protocol forKey:@"protocol"];
    [coder encodeInteger:self.size forKey:@"size"];
    [coder encodeObject:self.headers forKey:@"headers"];
    [coder encodeObject:self.payload forKey:@"payload"];
    [coder encodeObject:self.metadata forKey:@"metadata"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CapturedPacket *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_packetId = [self.packetId copyWithZone:zone];
        copy->_timestamp = [self.timestamp copyWithZone:zone];
        copy->_sourceIP = [self.sourceIP copyWithZone:zone];
        copy->_destinationIP = [self.destinationIP copyWithZone:zone];
        copy->_sourcePort = self.sourcePort;
        copy->_destinationPort = self.destinationPort;
        copy->_protocol = self.protocol;
        copy->_size = self.size;
        copy->_headers = [self.headers copyWithZone:zone];
        copy->_payload = [self.payload copyWithZone:zone];
        copy->_metadata = [self.metadata copyWithZone:zone];
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"id"] = [self.packetId UUIDString];
    dict[@"timestamp"] = @([self.timestamp timeIntervalSince1970]);
    dict[@"sourceIP"] = self.sourceIP ?: @"";
    dict[@"destinationIP"] = self.destinationIP ?: @"";
    dict[@"sourcePort"] = @(self.sourcePort);
    dict[@"destinationPort"] = @(self.destinationPort);
    dict[@"protocol"] = [self protocolString];
    dict[@"size"] = @(self.size);
    dict[@"headers"] = self.headers ?: @{};
    
    if (self.payload) {
        dict[@"payload"] = [self.payload base64EncodedStringWithOptions:0];
    }
    
    if (self.metadata) {
        NSMutableDictionary *metadataDict = [NSMutableDictionary dictionary];
        metadataDict[@"interface"] = self.metadata.interface ?: @"";
        metadataDict[@"direction"] = @(self.metadata.direction);
        metadataDict[@"flags"] = @(self.metadata.flags);
        metadataDict[@"sequenceNumber"] = @(self.metadata.sequenceNumber);
        metadataDict[@"acknowledgementNumber"] = @(self.metadata.acknowledgementNumber);
        dict[@"metadata"] = metadataDict;
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSUUID *packetId = [[NSUUID alloc] initWithUUIDString:dictionary[@"id"]] ?: [NSUUID UUID];
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"timestamp"] doubleValue]];
    NSString *sourceIP = dictionary[@"sourceIP"] ?: @"";
    NSString *destinationIP = dictionary[@"destinationIP"] ?: @"";
    NSUInteger sourcePort = [dictionary[@"sourcePort"] unsignedIntegerValue];
    NSUInteger destinationPort = [dictionary[@"destinationPort"] unsignedIntegerValue];
    NetworkProtocol protocol = [self protocolFromString:dictionary[@"protocol"]];
    NSUInteger size = [dictionary[@"size"] unsignedIntegerValue];
    NSDictionary *headers = dictionary[@"headers"] ?: @{};
    
    NSData *payload = nil;
    NSString *payloadString = dictionary[@"payload"];
    if ([payloadString isKindOfClass:[NSString class]]) {
        payload = [[NSData alloc] initWithBase64EncodedString:payloadString options:0];
    }
    
    PacketMetadata *metadata = nil;
    NSDictionary *metadataDict = dictionary[@"metadata"];
    if ([metadataDict isKindOfClass:[NSDictionary class]]) {
        metadata = [[PacketMetadata alloc] initWithInterface:metadataDict[@"interface"] ?: @""
                                                   direction:[metadataDict[@"direction"] integerValue]
                                                       flags:[metadataDict[@"flags"] unsignedIntegerValue]
                                             sequenceNumber:[metadataDict[@"sequenceNumber"] integerValue]
                                       acknowledgementNumber:[metadataDict[@"acknowledgementNumber"] integerValue]];
    }
    
    return [[CapturedPacket alloc] initWithPacketId:packetId
                                          timestamp:timestamp
                                           sourceIP:sourceIP
                                      destinationIP:destinationIP
                                         sourcePort:sourcePort
                                    destinationPort:destinationPort
                                           protocol:protocol
                                               size:size
                                            headers:headers
                                            payload:payload
                                           metadata:metadata];
}

#pragma mark - Protocol Helpers

- (NSString *)protocolString {
    switch (self.protocol) {
        case NetworkProtocolTCP: return @"TCP";
        case NetworkProtocolUDP: return @"UDP";
        case NetworkProtocolHTTP: return @"HTTP";
        case NetworkProtocolHTTPS: return @"HTTPS";
        case NetworkProtocolDNS: return @"DNS";
        case NetworkProtocolICMP: return @"ICMP";
        case NetworkProtocolARP: return @"ARP";
        default: return @"Other";
    }
}

+ (NetworkProtocol)protocolFromString:(NSString *)string {
    if ([string isEqualToString:@"TCP"]) return NetworkProtocolTCP;
    if ([string isEqualToString:@"UDP"]) return NetworkProtocolUDP;
    if ([string isEqualToString:@"HTTP"]) return NetworkProtocolHTTP;
    if ([string isEqualToString:@"HTTPS"]) return NetworkProtocolHTTPS;
    if ([string isEqualToString:@"DNS"]) return NetworkProtocolDNS;
    if ([string isEqualToString:@"ICMP"]) return NetworkProtocolICMP;
    if ([string isEqualToString:@"ARP"]) return NetworkProtocolARP;
    return NetworkProtocolOther;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CapturedPacket: id=%@, timestamp=%@, %@:%ld -> %@:%ld, protocol=%ld, size=%ld>",
            self.packetId, self.timestamp, self.sourceIP, (long)self.sourcePort,
            self.destinationIP, (long)self.destinationPort, (long)self.protocol, (long)self.size];
}

@end