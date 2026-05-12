//
//  PacketFilter.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "PacketFilter.h"

@implementation FilterCondition

- (instancetype)initWithField:(FilterField)field
                     operator:(FilterOperator)operator
                        value:(NSString *)value {
    self = [super init];
    if (self) {
        _field = field;
        _operator = operator;
        _value = [value copy];
    }
    return self;
}

#pragma mark - Evaluation

- (BOOL)evaluateWithPacket:(CapturedPacket *)packet {
    if (!packet) {
        return NO;
    }
    
    NSString *packetValue = [self packetValueForField:self.field packet:packet];
    if (!packetValue) {
        return NO;
    }
    
    switch (self.operator) {
        case FilterOperatorEquals:
            return [packetValue isEqualToString:self.value];
            
        case FilterOperatorContains:
            return [packetValue rangeOfString:self.value].location != NSNotFound;
            
        case FilterOperatorStartsWith:
            return [packetValue hasPrefix:self.value];
            
        case FilterOperatorEndsWith:
            return [packetValue hasSuffix:self.value];
            
        case FilterOperatorGreaterThan: {
            NSInteger packetInt = [packetValue integerValue];
            NSInteger valueInt = [self.value integerValue];
            return packetInt > valueInt;
        }
            
        case FilterOperatorLessThan: {
            NSInteger packetInt = [packetValue integerValue];
            NSInteger valueInt = [self.value integerValue];
            return packetInt < valueInt;
        }
            
        case FilterOperatorMatchesRegex: {
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:self.value
                                                                                   options:0
                                                                                     error:&error];
            if (error) {
                return NO;
            }
            NSUInteger matches = [regex numberOfMatchesInString:packetValue
                                                        options:0
                                                          range:NSMakeRange(0, packetValue.length)];
            return matches > 0;
        }
            
        default:
            return NO;
    }
}

- (NSString *)packetValueForField:(FilterField)field packet:(CapturedPacket *)packet {
    switch (field) {
        case FilterFieldProtocol:
            return [packet protocolString];
            
        case FilterFieldSourceIP:
            return packet.sourceIP;
            
        case FilterFieldDestinationIP:
            return packet.destinationIP;
            
        case FilterFieldSourcePort:
            return [NSString stringWithFormat:@"%ld", (long)packet.sourcePort];
            
        case FilterFieldDestinationPort:
            return [NSString stringWithFormat:@"%ld", (long)packet.destinationPort];
            
        case FilterFieldSize:
            return [NSString stringWithFormat:@"%ld", (long)packet.size];
            
        case FilterFieldContent: {
            if (!packet.payload) {
                return @"";
            }
            NSString *payloadString = [[NSString alloc] initWithData:packet.payload encoding:NSUTF8StringEncoding];
            return payloadString ?: @"";
        }
            
        default:
            return @"";
    }
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _field = [coder decodeIntegerForKey:@"field"];
        _operator = [coder decodeIntegerForKey:@"operator"];
        _value = [coder decodeObjectForKey:@"value"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.field forKey:@"field"];
    [coder encodeInteger:self.operator forKey:@"operator"];
    [coder encodeObject:self.value forKey:@"value"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    FilterCondition *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_field = self.field;
        copy->_operator = self.operator;
        copy->_value = [self.value copyWithZone:zone];
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"field"] = [self fieldString];
    dict[@"operator"] = [self operatorString];
    dict[@"value"] = self.value ?: @"";
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    FilterField field = [self fieldFromString:dictionary[@"field"]];
    FilterOperator operator = [self operatorFromString:dictionary[@"operator"]];
    NSString *value = dictionary[@"value"] ?: @"";
    
    return [[FilterCondition alloc] initWithField:field
                                         operator:operator
                                            value:value];
}

#pragma mark - String Conversion Helpers

- (NSString *)fieldString {
    switch (self.field) {
        case FilterFieldProtocol: return @"protocol";
        case FilterFieldSourceIP: return @"sourceIP";
        case FilterFieldDestinationIP: return @"destinationIP";
        case FilterFieldSourcePort: return @"sourcePort";
        case FilterFieldDestinationPort: return @"destinationPort";
        case FilterFieldSize: return @"size";
        case FilterFieldContent: return @"content";
        default: return @"unknown";
    }
}

+ (FilterField)fieldFromString:(NSString *)string {
    if ([string isEqualToString:@"protocol"]) return FilterFieldProtocol;
    if ([string isEqualToString:@"sourceIP"]) return FilterFieldSourceIP;
    if ([string isEqualToString:@"destinationIP"]) return FilterFieldDestinationIP;
    if ([string isEqualToString:@"sourcePort"]) return FilterFieldSourcePort;
    if ([string isEqualToString:@"destinationPort"]) return FilterFieldDestinationPort;
    if ([string isEqualToString:@"size"]) return FilterFieldSize;
    if ([string isEqualToString:@"content"]) return FilterFieldContent;
    return FilterFieldProtocol;
}

- (NSString *)operatorString {
    switch (self.operator) {
        case FilterOperatorEquals: return @"equals";
        case FilterOperatorContains: return @"contains";
        case FilterOperatorStartsWith: return @"startsWith";
        case FilterOperatorEndsWith: return @"endsWith";
        case FilterOperatorGreaterThan: return @"greaterThan";
        case FilterOperatorLessThan: return @"lessThan";
        case FilterOperatorMatchesRegex: return @"matchesRegex";
        default: return @"equals";
    }
}

+ (FilterOperator)operatorFromString:(NSString *)string {
    if ([string isEqualToString:@"equals"]) return FilterOperatorEquals;
    if ([string isEqualToString:@"contains"]) return FilterOperatorContains;
    if ([string isEqualToString:@"startsWith"]) return FilterOperatorStartsWith;
    if ([string isEqualToString:@"endsWith"]) return FilterOperatorEndsWith;
    if ([string isEqualToString:@"greaterThan"]) return FilterOperatorGreaterThan;
    if ([string isEqualToString:@"lessThan"]) return FilterOperatorLessThan;
    if ([string isEqualToString:@"matchesRegex"]) return FilterOperatorMatchesRegex;
    return FilterOperatorEquals;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<FilterCondition: field=%ld, operator=%ld, value=%@>",
            (long)self.field, (long)self.operator, self.value];
}

@end

@implementation PacketFilter

- (instancetype)initWithFilterId:(NSUUID *)filterId
                            name:(NSString *)name
                      conditions:(NSArray<FilterCondition *> *)conditions
                          action:(FilterAction)action
                       isEnabled:(BOOL)isEnabled {
    self = [super init];
    if (self) {
        _filterId = [filterId copy];
        _name = [name copy];
        _conditions = [conditions copy];
        _action = action;
        _isEnabled = isEnabled;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                  conditions:(NSArray<FilterCondition *> *)conditions
                      action:(FilterAction)action {
    return [self initWithFilterId:[NSUUID UUID]
                             name:name
                       conditions:conditions
                           action:action
                        isEnabled:YES];
}

#pragma mark - Filter Application

- (NSArray<CapturedPacket *> *)applyToPackets:(NSArray<CapturedPacket *> *)packets {
    if (!self.isEnabled || self.conditions.count == 0) {
        return packets;
    }
    
    NSMutableArray<CapturedPacket *> *filteredPackets = [NSMutableArray array];
    
    for (CapturedPacket *packet in packets) {
        if ([self matchesPacket:packet]) {
            if (self.action == FilterActionInclude || self.action == FilterActionHighlight) {
                [filteredPackets addObject:packet];
            }
            // For FilterActionExclude, we skip adding the packet
            // For FilterActionAlert, we still include it but might mark it for alert
        } else {
            if (self.action == FilterActionExclude) {
                [filteredPackets addObject:packet];
            }
        }
    }
    
    return [filteredPackets copy];
}

- (BOOL)matchesPacket:(CapturedPacket *)packet {
    if (!self.isEnabled || self.conditions.count == 0) {
        return NO;
    }
    
    // All conditions must be satisfied (AND logic)
    for (FilterCondition *condition in self.conditions) {
        if (![condition evaluateWithPacket:packet]) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _filterId = [coder decodeObjectForKey:@"filterId"];
        _name = [coder decodeObjectForKey:@"name"];
        _conditions = [coder decodeObjectForKey:@"conditions"];
        _action = [coder decodeIntegerForKey:@"action"];
        _isEnabled = [coder decodeBoolForKey:@"isEnabled"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.filterId forKey:@"filterId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.conditions forKey:@"conditions"];
    [coder encodeInteger:self.action forKey:@"action"];
    [coder encodeBool:self.isEnabled forKey:@"isEnabled"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PacketFilter *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_filterId = [self.filterId copyWithZone:zone];
        copy->_name = [self.name copyWithZone:zone];
        copy->_conditions = [self.conditions copyWithZone:zone];
        copy->_action = self.action;
        copy->_isEnabled = self.isEnabled;
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"id"] = [self.filterId UUIDString];
    dict[@"name"] = self.name ?: @"";
    dict[@"action"] = [self actionString];
    dict[@"isEnabled"] = @(self.isEnabled);
    
    NSMutableArray *conditionsArray = [NSMutableArray array];
    for (FilterCondition *condition in self.conditions) {
        [conditionsArray addObject:[condition toDictionary]];
    }
    dict[@"conditions"] = conditionsArray;
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSUUID *filterId = [[NSUUID alloc] initWithUUIDString:dictionary[@"id"]] ?: [NSUUID UUID];
    NSString *name = dictionary[@"name"] ?: @"";
    FilterAction action = [self actionFromString:dictionary[@"action"]];
    BOOL isEnabled = [dictionary[@"isEnabled"] boolValue];
    
    NSMutableArray<FilterCondition *> *conditions = [NSMutableArray array];
    NSArray *conditionsArray = dictionary[@"conditions"];
    if ([conditionsArray isKindOfClass:[NSArray class]]) {
        for (NSDictionary *conditionDict in conditionsArray) {
            FilterCondition *condition = [FilterCondition fromDictionary:conditionDict];
            if (condition) {
                [conditions addObject:condition];
            }
        }
    }
    
    return [[PacketFilter alloc] initWithFilterId:filterId
                                             name:name
                                       conditions:conditions
                                           action:action
                                        isEnabled:isEnabled];
}

#pragma mark - Action Helpers

- (NSString *)actionString {
    switch (self.action) {
        case FilterActionInclude: return @"include";
        case FilterActionExclude: return @"exclude";
        case FilterActionHighlight: return @"highlight";
        case FilterActionAlert: return @"alert";
        default: return @"include";
    }
}

+ (FilterAction)actionFromString:(NSString *)string {
    if ([string isEqualToString:@"include"]) return FilterActionInclude;
    if ([string isEqualToString:@"exclude"]) return FilterActionExclude;
    if ([string isEqualToString:@"highlight"]) return FilterActionHighlight;
    if ([string isEqualToString:@"alert"]) return FilterActionAlert;
    return FilterActionInclude;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<PacketFilter: id=%@, name=%@, conditions=%ld, action=%ld, enabled=%d>",
            self.filterId, self.name, (long)self.conditions.count, (long)self.action, self.isEnabled];
}

@end