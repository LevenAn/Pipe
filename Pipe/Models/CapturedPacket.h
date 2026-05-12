//
//  CapturedPacket.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Network protocol types
typedef NS_ENUM(NSInteger, NetworkProtocol) {
    NetworkProtocolTCP,
    NetworkProtocolUDP,
    NetworkProtocolHTTP,
    NetworkProtocolHTTPS,
    NetworkProtocolDNS,
    NetworkProtocolICMP,
    NetworkProtocolARP,
    NetworkProtocolOther
};

/// Packet direction
typedef NS_ENUM(NSInteger, PacketDirection) {
    PacketDirectionIncoming,
    PacketDirectionOutgoing
};

/// Packet flags
typedef NS_OPTIONS(NSUInteger, PacketFlag) {
    PacketFlagSYN = 1 << 0,
    PacketFlagACK = 1 << 1,
    PacketFlagFIN = 1 << 2,
    PacketFlagRST = 1 << 3,
    PacketFlagPSH = 1 << 4,
    PacketFlagURG = 1 << 5
};

/// Packet metadata
@interface PacketMetadata : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSString *interface;
@property (nonatomic, assign) PacketDirection direction;
@property (nonatomic, assign) PacketFlag flags;
@property (nonatomic, assign) NSInteger sequenceNumber;
@property (nonatomic, assign) NSInteger acknowledgementNumber;

- (instancetype)initWithInterface:(NSString *)interface
                        direction:(PacketDirection)direction
                            flags:(PacketFlag)flags
                  sequenceNumber:(NSInteger)sequenceNumber
            acknowledgementNumber:(NSInteger)acknowledgementNumber;

@end

/// Represents a captured network packet
@interface CapturedPacket : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSUUID *packetId;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *sourceIP;
@property (nonatomic, copy) NSString *destinationIP;
@property (nonatomic, assign) NSUInteger sourcePort;
@property (nonatomic, assign) NSUInteger destinationPort;
@property (nonatomic, assign) NetworkProtocol protocol;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy) NSData * _Nullable payload;
@property (nonatomic, strong) PacketMetadata *metadata;

- (instancetype)initWithPacketId:(NSUUID *)packetId
                       timestamp:(NSDate *)timestamp
                        sourceIP:(NSString *)sourceIP
                   destinationIP:(NSString *)destinationIP
                      sourcePort:(NSUInteger)sourcePort
                 destinationPort:(NSUInteger)destinationPort
                        protocol:(NetworkProtocol)protocol
                            size:(NSUInteger)size
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         payload:(NSData * _Nullable)payload
                        metadata:(PacketMetadata *)metadata;

/// Convenience initializer
- (instancetype)initWithSourceIP:(NSString *)sourceIP
                   destinationIP:(NSString *)destinationIP
                      sourcePort:(NSUInteger)sourcePort
                 destinationPort:(NSUInteger)destinationPort
                        protocol:(NetworkProtocol)protocol
                            size:(NSUInteger)size
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         payload:(NSData * _Nullable)payload;

/// Convert to dictionary for JSON serialization
- (NSDictionary *)toDictionary;

/// Create from dictionary (JSON deserialization)
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END