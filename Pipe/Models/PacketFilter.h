//
//  PacketFilter.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "CapturedPacket.h"

NS_ASSUME_NONNULL_BEGIN

/// Filter field types
typedef NS_ENUM(NSInteger, FilterField) {
    FilterFieldProtocol,
    FilterFieldSourceIP,
    FilterFieldDestinationIP,
    FilterFieldSourcePort,
    FilterFieldDestinationPort,
    FilterFieldSize,
    FilterFieldContent
};

/// Filter operators
typedef NS_ENUM(NSInteger, FilterOperator) {
    FilterOperatorEquals,
    FilterOperatorContains,
    FilterOperatorStartsWith,
    FilterOperatorEndsWith,
    FilterOperatorGreaterThan,
    FilterOperatorLessThan,
    FilterOperatorMatchesRegex
};

/// Filter actions
typedef NS_ENUM(NSInteger, FilterAction) {
    FilterActionInclude,
    FilterActionExclude,
    FilterActionHighlight,
    FilterActionAlert
};

/// Filter condition
@interface FilterCondition : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) FilterField field;
@property (nonatomic, assign) FilterOperator operator;
@property (nonatomic, copy) NSString *value;

- (instancetype)initWithField:(FilterField)field
                     operator:(FilterOperator)operator
                        value:(NSString *)value;

/// Evaluate condition against a packet
- (BOOL)evaluateWithPacket:(CapturedPacket *)packet;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

/// Create from dictionary
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

/// Packet filter rule
@interface PacketFilter : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSUUID *filterId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray<FilterCondition *> *conditions;
@property (nonatomic, assign) FilterAction action;
@property (nonatomic, assign) BOOL isEnabled;

- (instancetype)initWithFilterId:(NSUUID *)filterId
                            name:(NSString *)name
                      conditions:(NSArray<FilterCondition *> *)conditions
                          action:(FilterAction)action
                       isEnabled:(BOOL)isEnabled;

/// Convenience initializer
- (instancetype)initWithName:(NSString *)name
                  conditions:(NSArray<FilterCondition *> *)conditions
                      action:(FilterAction)action;

/// Apply filter to array of packets
- (NSArray<CapturedPacket *> *)applyToPackets:(NSArray<CapturedPacket *> *)packets;

/// Check if packet matches filter
- (BOOL)matchesPacket:(CapturedPacket *)packet;

/// Convert to dictionary for JSON serialization
- (NSDictionary *)toDictionary;

/// Create from dictionary (JSON deserialization)
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END