//
//  CaptureSession.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "CaptureSession.h"

@implementation CaptureConfiguration

- (instancetype)initWithBufferSize:(NSUInteger)bufferSize
                   promiscuousMode:(BOOL)promiscuousMode
                   snapshotLength:(NSUInteger)snapshotLength
                           timeout:(NSTimeInterval)timeout
                     immediateMode:(BOOL)immediateMode {
    self = [super init];
    if (self) {
        _bufferSize = bufferSize;
        _promiscuousMode = promiscuousMode;
        _snapshotLength = snapshotLength;
        _timeout = timeout;
        _immediateMode = immediateMode;
        _privateMode = NO;
    }
    return self;
}

+ (instancetype)defaultConfiguration {
    return [[CaptureConfiguration alloc] initWithBufferSize:65536
                                            promiscuousMode:YES
                                            snapshotLength:65535
                                                    timeout:1000.0
                                              immediateMode:YES];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _bufferSize = [coder decodeIntegerForKey:@"bufferSize"];
        _promiscuousMode = [coder decodeBoolForKey:@"promiscuousMode"];
        _snapshotLength = [coder decodeIntegerForKey:@"snapshotLength"];
        _timeout = [coder decodeDoubleForKey:@"timeout"];
        _immediateMode = [coder decodeBoolForKey:@"immediateMode"];
        _privateMode = [coder decodeBoolForKey:@"privateMode"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.bufferSize forKey:@"bufferSize"];
    [coder encodeBool:self.promiscuousMode forKey:@"promiscuousMode"];
    [coder encodeInteger:self.snapshotLength forKey:@"snapshotLength"];
    [coder encodeDouble:self.timeout forKey:@"timeout"];
    [coder encodeBool:self.immediateMode forKey:@"immediateMode"];
    [coder encodeBool:self.privateMode forKey:@"privateMode"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CaptureConfiguration *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_bufferSize = self.bufferSize;
        copy->_promiscuousMode = self.promiscuousMode;
        copy->_snapshotLength = self.snapshotLength;
        copy->_timeout = self.timeout;
        copy->_immediateMode = self.immediateMode;
        copy->_privateMode = self.privateMode;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CaptureConfiguration: bufferSize=%ld, promiscuous=%d, snapshot=%ld, timeout=%.2f, immediate=%d>",
            (long)self.bufferSize, self.promiscuousMode, (long)self.snapshotLength, self.timeout, self.immediateMode];
}

@end

@implementation CaptureSession {
    NSMutableArray<CapturedPacket *> *_mutablePackets;
}

- (instancetype)initWithSessionId:(NSUUID *)sessionId
                        startTime:(NSDate *)startTime
                          endTime:(NSDate *)endTime
                    configuration:(CaptureConfiguration *)configuration
                      packetCount:(NSUInteger)packetCount
                       totalBytes:(NSUInteger)totalBytes
                      filterRules:(NSArray<NSDictionary *> *)filterRules
                           status:(CaptureSessionStatus)status
                          packets:(NSArray<CapturedPacket *> *)packets {
    self = [super init];
    if (self) {
        _sessionId = [sessionId copy];
        _startTime = startTime;
        _endTime = endTime;
        _configuration = configuration;
        _packetCount = packetCount;
        _totalBytes = totalBytes;
        _filterRules = [filterRules copy];
        _status = status;
        _mutablePackets = [packets mutableCopy];
    }
    return self;
}

- (instancetype)initWithConfiguration:(CaptureConfiguration *)configuration
                          filterRules:(NSArray<NSDictionary *> *)filterRules {
    return [self initWithSessionId:[NSUUID UUID]
                         startTime:[NSDate date]
                           endTime:nil
                     configuration:configuration
                       packetCount:0
                        totalBytes:0
                       filterRules:filterRules
                            status:CaptureSessionStatusActive
                           packets:@[]];
}

#pragma mark - Packet Management

- (NSArray<CapturedPacket *> *)packets {
    return [_mutablePackets copy];
}

- (void)addPacket:(CapturedPacket *)packet {
    if (!_mutablePackets) {
        _mutablePackets = [NSMutableArray array];
    }
    
    [_mutablePackets addObject:packet];
    _packetCount++;
    _totalBytes += packet.size;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _sessionId = [coder decodeObjectForKey:@"sessionId"];
        _startTime = [coder decodeObjectForKey:@"startTime"];
        _endTime = [coder decodeObjectForKey:@"endTime"];
        _configuration = [coder decodeObjectForKey:@"configuration"];
        _packetCount = [coder decodeIntegerForKey:@"packetCount"];
        _totalBytes = [coder decodeIntegerForKey:@"totalBytes"];
        _filterRules = [coder decodeObjectForKey:@"filterRules"];
        _status = [coder decodeIntegerForKey:@"status"];
        _mutablePackets = [[coder decodeObjectForKey:@"packets"] mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.sessionId forKey:@"sessionId"];
    [coder encodeObject:self.startTime forKey:@"startTime"];
    [coder encodeObject:self.endTime forKey:@"endTime"];
    [coder encodeObject:self.configuration forKey:@"configuration"];
    [coder encodeInteger:self.packetCount forKey:@"packetCount"];
    [coder encodeInteger:self.totalBytes forKey:@"totalBytes"];
    [coder encodeObject:self.filterRules forKey:@"filterRules"];
    [coder encodeInteger:self.status forKey:@"status"];
    [coder encodeObject:self.packets forKey:@"packets"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CaptureSession *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_sessionId = [self.sessionId copyWithZone:zone];
        copy->_startTime = [self.startTime copyWithZone:zone];
        copy->_endTime = [self.endTime copyWithZone:zone];
        copy->_configuration = [self.configuration copyWithZone:zone];
        copy->_packetCount = self.packetCount;
        copy->_totalBytes = self.totalBytes;
        copy->_filterRules = [self.filterRules copyWithZone:zone];
        copy->_status = self.status;
        copy->_mutablePackets = [self.packets mutableCopy];
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"id"] = [self.sessionId UUIDString];
    dict[@"startTime"] = @([self.startTime timeIntervalSince1970]);
    
    if (self.endTime) {
        dict[@"endTime"] = @([self.endTime timeIntervalSince1970]);
    }
    
    if (self.configuration) {
        NSMutableDictionary *configDict = [NSMutableDictionary dictionary];
        configDict[@"bufferSize"] = @(self.configuration.bufferSize);
        configDict[@"promiscuousMode"] = @(self.configuration.promiscuousMode);
        configDict[@"snapshotLength"] = @(self.configuration.snapshotLength);
        configDict[@"timeout"] = @(self.configuration.timeout);
        configDict[@"immediateMode"] = @(self.configuration.immediateMode);
        dict[@"configuration"] = configDict;
    }
    
    dict[@"packetCount"] = @(self.packetCount);
    dict[@"totalBytes"] = @(self.totalBytes);
    dict[@"filterRules"] = self.filterRules ?: @[];
    dict[@"status"] = [self statusString];
    
    NSMutableArray *packetsArray = [NSMutableArray array];
    for (CapturedPacket *packet in self.packets) {
        [packetsArray addObject:[packet toDictionary]];
    }
    dict[@"packets"] = packetsArray;
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSUUID *sessionId = [[NSUUID alloc] initWithUUIDString:dictionary[@"id"]] ?: [NSUUID UUID];
    NSDate *startTime = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"startTime"] doubleValue]];
    
    NSDate *endTime = nil;
    NSNumber *endTimeNumber = dictionary[@"endTime"];
    if ([endTimeNumber isKindOfClass:[NSNumber class]]) {
        endTime = [NSDate dateWithTimeIntervalSince1970:[endTimeNumber doubleValue]];
    }
    
    CaptureConfiguration *configuration = nil;
    NSDictionary *configDict = dictionary[@"configuration"];
    if ([configDict isKindOfClass:[NSDictionary class]]) {
        configuration = [[CaptureConfiguration alloc] initWithBufferSize:[configDict[@"bufferSize"] unsignedIntegerValue]
                                                         promiscuousMode:[configDict[@"promiscuousMode"] boolValue]
                                                         snapshotLength:[configDict[@"snapshotLength"] unsignedIntegerValue]
                                                                 timeout:[configDict[@"timeout"] doubleValue]
                                                           immediateMode:[configDict[@"immediateMode"] boolValue]];
    } else {
        configuration = [CaptureConfiguration defaultConfiguration];
    }
    
    NSUInteger packetCount = [dictionary[@"packetCount"] unsignedIntegerValue];
    NSUInteger totalBytes = [dictionary[@"totalBytes"] unsignedIntegerValue];
    NSArray *filterRules = dictionary[@"filterRules"] ?: @[];
    CaptureSessionStatus status = [self statusFromString:dictionary[@"status"]];
    
    NSMutableArray<CapturedPacket *> *packets = [NSMutableArray array];
    NSArray *packetsArray = dictionary[@"packets"];
    if ([packetsArray isKindOfClass:[NSArray class]]) {
        for (NSDictionary *packetDict in packetsArray) {
            CapturedPacket *packet = [CapturedPacket fromDictionary:packetDict];
            if (packet) {
                [packets addObject:packet];
            }
        }
    }
    
    return [[CaptureSession alloc] initWithSessionId:sessionId
                                           startTime:startTime
                                             endTime:endTime
                                       configuration:configuration
                                         packetCount:packetCount
                                          totalBytes:totalBytes
                                         filterRules:filterRules
                                              status:status
                                             packets:packets];
}

#pragma mark - Status Helpers

- (NSString *)statusString {
    switch (self.status) {
        case CaptureSessionStatusActive: return @"active";
        case CaptureSessionStatusStopped: return @"stopped";
        case CaptureSessionStatusExporting: return @"exporting";
        case CaptureSessionStatusError: return @"error";
        default: return @"unknown";
    }
}

+ (CaptureSessionStatus)statusFromString:(NSString *)string {
    if ([string isEqualToString:@"active"]) return CaptureSessionStatusActive;
    if ([string isEqualToString:@"stopped"]) return CaptureSessionStatusStopped;
    if ([string isEqualToString:@"exporting"]) return CaptureSessionStatusExporting;
    if ([string isEqualToString:@"error"]) return CaptureSessionStatusError;
    return CaptureSessionStatusStopped;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CaptureSession: id=%@, start=%@, packets=%ld, bytes=%ld, status=%ld>",
            self.sessionId, self.startTime, (long)self.packetCount, (long)self.totalBytes, (long)self.status];
}

@end