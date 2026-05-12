//
//  PacketCaptureService.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "PacketCaptureService.h"
#import <NetworkExtension/NetworkExtension.h>

@interface PacketCaptureService ()

@property (nonatomic, strong) CaptureSession *currentSession;
@property (nonatomic, strong) NSMutableArray<CapturedPacket *> *capturedPackets;
@property (nonatomic, strong) NSMutableDictionary *statistics;
@property (nonatomic, assign) BOOL isCapturing;
@property (nonatomic, assign) BOOL isPaused;

@end

@implementation CaptureConfiguration

- (instancetype)initWithBufferSize:(NSUInteger)bufferSize
                   promiscuousMode:(BOOL)promiscuousMode
                        interfaces:(NSArray<NSString *> *)interfaces
                           filters:(NSArray<PacketFilter *> *)filters
               maxPacketsPerSecond:(NSUInteger)maxPacketsPerSecond
                        captureDNS:(BOOL)captureDNS
                       captureHTTP:(BOOL)captureHTTP
                      captureHTTPS:(BOOL)captureHTTPS
                         captureTCP:(BOOL)captureTCP
                        captureUDP:(BOOL)captureUDP {
    self = [super init];
    if (self) {
        _bufferSize = bufferSize;
        _promiscuousMode = promiscuousMode;
        _interfaces = [interfaces copy];
        _filters = [filters copy];
        _maxPacketsPerSecond = maxPacketsPerSecond;
        _captureDNS = captureDNS;
        _captureHTTP = captureHTTP;
        _captureHTTPS = captureHTTPS;
        _captureTCP = captureTCP;
        _captureUDP = captureUDP;
    }
    return self;
}

+ (instancetype)defaultConfiguration {
    return [[CaptureConfiguration alloc] initWithBufferSize:65536
                                            promiscuousMode:NO
                                                 interfaces:@[@"en0", @"pdp_ip0"]
                                                    filters:@[]
                                        maxPacketsPerSecond:1000
                                                 captureDNS:YES
                                                captureHTTP:YES
                                               captureHTTPS:YES
                                                  captureTCP:YES
                                                 captureUDP:YES];
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"bufferSize"] = @(self.bufferSize);
    dict[@"promiscuousMode"] = @(self.promiscuousMode);
    dict[@"interfaces"] = self.interfaces ?: @[];
    
    NSMutableArray *filterDicts = [NSMutableArray array];
    for (PacketFilter *filter in self.filters) {
        [filterDicts addObject:[filter toDictionary]];
    }
    dict[@"filters"] = filterDicts;
    
    dict[@"maxPacketsPerSecond"] = @(self.maxPacketsPerSecond);
    dict[@"captureDNS"] = @(self.captureDNS);
    dict[@"captureHTTP"] = @(self.captureHTTP);
    dict[@"captureHTTPS"] = @(self.captureHTTPS);
    dict[@"captureTCP"] = @(self.captureTCP);
    dict[@"captureUDP"] = @(self.captureUDP);
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return [self defaultConfiguration];
    }
    
    NSUInteger bufferSize = [dictionary[@"bufferSize"] unsignedIntegerValue] ?: 65536;
    BOOL promiscuousMode = [dictionary[@"promiscuousMode"] boolValue];
    NSArray *interfaces = dictionary[@"interfaces"] ?: @[@"en0", @"pdp_ip0"];
    
    NSMutableArray *filters = [NSMutableArray array];
    NSArray *filterDicts = dictionary[@"filters"];
    if ([filterDicts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *filterDict in filterDicts) {
            PacketFilter *filter = [PacketFilter fromDictionary:filterDict];
            if (filter) {
                [filters addObject:filter];
            }
        }
    }
    
    NSUInteger maxPacketsPerSecond = [dictionary[@"maxPacketsPerSecond"] unsignedIntegerValue] ?: 1000;
    BOOL captureDNS = [dictionary[@"captureDNS"] boolValue];
    BOOL captureHTTP = [dictionary[@"captureHTTP"] boolValue];
    BOOL captureHTTPS = [dictionary[@"captureHTTPS"] boolValue];
    BOOL captureTCP = [dictionary[@"captureTCP"] boolValue];
    BOOL captureUDP = [dictionary[@"captureUDP"] boolValue];
    
    return [[CaptureConfiguration alloc] initWithBufferSize:bufferSize
                                            promiscuousMode:promiscuousMode
                                                 interfaces:interfaces
                                                    filters:filters
                                        maxPacketsPerSecond:maxPacketsPerSecond
                                                 captureDNS:captureDNS
                                                captureHTTP:captureHTTP
                                               captureHTTPS:captureHTTPS
                                                  captureTCP:captureTCP
                                                 captureUDP:captureUDP];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _bufferSize = [coder decodeIntegerForKey:@"bufferSize"];
        _promiscuousMode = [coder decodeBoolForKey:@"promiscuousMode"];
        _interfaces = [coder decodeObjectForKey:@"interfaces"];
        _filters = [coder decodeObjectForKey:@"filters"];
        _maxPacketsPerSecond = [coder decodeIntegerForKey:@"maxPacketsPerSecond"];
        _captureDNS = [coder decodeBoolForKey:@"captureDNS"];
        _captureHTTP = [coder decodeBoolForKey:@"captureHTTP"];
        _captureHTTPS = [coder decodeBoolForKey:@"captureHTTPS"];
        _captureTCP = [coder decodeBoolForKey:@"captureTCP"];
        _captureUDP = [coder decodeBoolForKey:@"captureUDP"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.bufferSize forKey:@"bufferSize"];
    [coder encodeBool:self.promiscuousMode forKey:@"promiscuousMode"];
    [coder encodeObject:self.interfaces forKey:@"interfaces"];
    [coder encodeObject:self.filters forKey:@"filters"];
    [coder encodeInteger:self.maxPacketsPerSecond forKey:@"maxPacketsPerSecond"];
    [coder encodeBool:self.captureDNS forKey:@"captureDNS"];
    [coder encodeBool:self.captureHTTP forKey:@"captureHTTP"];
    [coder encodeBool:self.captureHTTPS forKey:@"captureHTTPS"];
    [coder encodeBool:self.captureTCP forKey:@"captureTCP"];
    [coder encodeBool:self.captureUDP forKey:@"captureUDP"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CaptureConfiguration *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_bufferSize = self.bufferSize;
        copy->_promiscuousMode = self.promiscuousMode;
        copy->_interfaces = [self.interfaces copyWithZone:zone];
        copy->_filters = [self.filters copyWithZone:zone];
        copy->_maxPacketsPerSecond = self.maxPacketsPerSecond;
        copy->_captureDNS = self.captureDNS;
        copy->_captureHTTP = self.captureHTTP;
        copy->_captureHTTPS = self.captureHTTPS;
        copy->_captureTCP = self.captureTCP;
        copy->_captureUDP = self.captureUDP;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CaptureConfiguration: bufferSize=%lu, interfaces=%@, filters=%lu>",
            (unsigned long)self.bufferSize, self.interfaces, (unsigned long)self.filters.count];
}

@end

@implementation CaptureSession

- (instancetype)initWithSessionId:(NSUUID *)sessionId
                             name:(NSString *)name
                    configuration:(CaptureConfiguration *)configuration {
    self = [super init];
    if (self) {
        _sessionId = [sessionId copy];
        _name = [name copy];
        _configuration = configuration;
        _state = CaptureSessionStateStopped;
        _packetsCaptured = 0;
        _packetsFiltered = 0;
        _startTime = 0;
        _duration = 0;
        _capturedPackets = @[];
    }
    return self;
}

- (NSString *)startTimeString {
    if (self.startTime == 0) {
        return @"Not started";
    }
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.startTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:date];
}

- (NSString *)durationString {
    if (self.duration == 0) {
        return @"0s";
    }
    
    NSInteger hours = (NSInteger)(self.duration / 3600);
    NSInteger minutes = (NSInteger)((self.duration - hours * 3600) / 60);
    NSInteger seconds = (NSInteger)(self.duration - hours * 3600 - minutes * 60);
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ldh %ldm %lds", (long)hours, (long)minutes, (long)seconds];
    } else if (minutes > 0) {
        return [NSString stringWithFormat:@"%ldm %lds", (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"%lds", (long)seconds];
    }
}

- (double)packetsPerSecond {
    if (self.duration == 0) {
        return 0;
    }
    return (double)self.packetsCaptured / self.duration;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"sessionId"] = [self.sessionId UUIDString];
    dict[@"name"] = self.name ?: @"Unnamed Session";
    dict[@"configuration"] = [self.configuration toDictionary];
    dict[@"state"] = @(self.state);
    dict[@"packetsCaptured"] = @(self.packetsCaptured);
    dict[@"packetsFiltered"] = @(self.packetsFiltered);
    dict[@"startTime"] = @(self.startTime);
    dict[@"duration"] = @(self.duration);
    
    NSMutableArray *packetDicts = [NSMutableArray array];
    for (CapturedPacket *packet in self.capturedPackets) {
        [packetDicts addObject:[packet toDictionary]];
    }
    dict[@"capturedPackets"] = packetDicts;
    
    return [dict copy];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CaptureSession: %@, state=%ld, packets=%lu>",
            self.name, (long)self.state, (unsigned long)self.packetsCaptured];
}

@end

@implementation PacketCaptureService

#pragma mark - Singleton

+ (instancetype)sharedService {
    static PacketCaptureService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<PacketCaptureDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _capturedPackets = [NSMutableArray array];
        _statistics = [NSMutableDictionary dictionary];
        _isCapturing = NO;
        _isPaused = NO;
        
        // Initialize statistics
        _statistics[@"totalPackets"] = @0;
        _statistics[@"filteredPackets"] = @0;
        _statistics[@"droppedPackets"] = @0;
        _statistics[@"startTime"] = @0;
        _statistics[@"currentTime"] = @0;
    }
    return self;
}

#pragma mark - PacketCaptureServiceProtocol

- (BOOL)startCaptureWithConfiguration:(CaptureConfiguration *)configuration
                                error:(NSError **)error {
    if (self.isCapturing) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Capture is already running"}];
        }
        return NO;
    }
    
    // Create new session
    self.currentSession = [[CaptureSession alloc] initWithSessionId:[NSUUID UUID]
                                                               name:[NSString stringWithFormat:@"Session %@", [NSDate date]]
                                                      configuration:configuration];
    
    self.currentSession.state = CaptureSessionStateStarting;
    self.currentSession.startTime = [[NSDate date] timeIntervalSince1970];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
        [self.delegate packetCaptureDidChangeState:CaptureSessionStateStarting];
    }
    
    // In a real implementation, this would start the Network Extension packet capture
    // For now, we'll simulate starting after a delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isCapturing = YES;
        self.currentSession.state = CaptureSessionStateRunning;
        
        // Update statistics
        self.statistics[@"startTime"] = @(self.currentSession.startTime);
        self.statistics[@"currentTime"] = @([[NSDate date] timeIntervalSince1970]);
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
            [self.delegate packetCaptureDidChangeState:CaptureSessionStateRunning];
        }
        
        if ([self.delegate respondsToSelector:@selector(packetCaptureDidUpdateStatistics:)]) {
            [self.delegate packetCaptureDidUpdateStatistics:self.statistics];
        }
        
        NSLog(@"Packet capture started with configuration: %@", configuration);
    });
    
    return YES;
}

- (BOOL)stopCaptureWithError:(NSError **)error {
    if (!self.isCapturing) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"No capture session is running"}];
        }
        return NO;
    }
    
    self.currentSession.state = CaptureSessionStateStopping;
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
        [self.delegate packetCaptureDidChangeState:CaptureSessionStateStopping];
    }
    
    // In a real implementation, this would stop the Network Extension packet capture
    // For now, we'll simulate stopping after a delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isCapturing = NO;
        self.isPaused = NO;
        
        // Update session duration
        self.currentSession.duration = [[NSDate date] timeIntervalSince1970] - self.currentSession.startTime;
        self.currentSession.state = CaptureSessionStateStopped;
        
        // Clear captured packets if configured
        if (self.currentSession.configuration) {
            // Check if we should clear on stop
            // This would be based on configuration
        }
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
            [self.delegate packetCaptureDidChangeState:CaptureSessionStateStopped];
        }
        
        NSLog(@"Packet capture stopped. Captured %lu packets.", (unsigned long)self.capturedPackets.count);
    });
    
    return YES;
}

- (BOOL)pauseCaptureWithError:(NSError **)error {
    if (!self.isCapturing) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"No capture session is running"}];
        }
        return NO;
    }
    
    if (self.isPaused) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Capture is already paused"}];
        }
        return NO;
    }
    
    self.isPaused = YES;
    self.currentSession.state = CaptureSessionStateStopping; // Using Stopping as "paused" state
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
        [self.delegate packetCaptureDidChangeState:CaptureSessionStateStopping];
    }
    
    NSLog(@"Packet capture paused.");
    
    return YES;
}

- (BOOL)resumeCaptureWithError:(NSError **)error {
    if (!self.isCapturing) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"No capture session is running"}];
        }
        return NO;
    }
    
    if (!self.isPaused) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Capture is not paused"}];
        }
        return NO;
    }
    
    self.isPaused = NO;
    self.currentSession.state = CaptureSessionStateRunning;
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidChangeState:)]) {
        [self.delegate packetCaptureDidChangeState:CaptureSessionStateRunning];
    }
    
    NSLog(@"Packet capture resumed.");
    
    return YES;
}

- (CaptureSession *)currentSession {
    return _currentSession;
}

- (NSDictionary *)captureStatistics {
    // Update current time
    self.statistics[@"currentTime"] = @([[NSDate date] timeIntervalSince1970]);
    
    // Calculate duration
    NSTimeInterval startTime = [self.statistics[@"startTime"] doubleValue];
    NSTimeInterval currentTime = [self.statistics[@"currentTime"] doubleValue];
    NSTimeInterval duration = currentTime - startTime;
    
    // Add calculated statistics
    NSMutableDictionary *stats = [self.statistics mutableCopy];
    stats[@"duration"] = @(duration);
    stats[@"packetsPerSecond"] = @(duration > 0 ? [self.statistics[@"totalPackets"] doubleValue] / duration : 0);
    stats[@"memoryUsage"] = @(self.capturedPackets.count * 1024); // Rough estimate: 1KB per packet
    
    return [stats copy];
}

- (NSArray<CapturedPacket *> *)applyFilters:(NSArray<PacketFilter *> *)filters
                                   toPackets:(NSArray<CapturedPacket *> *)packets {
    if (filters.count == 0 || packets.count == 0) {
        return packets;
    }
    
    NSMutableArray<CapturedPacket *> *filteredPackets = [NSMutableArray array];
    
    for (CapturedPacket *packet in packets) {
        BOOL shouldInclude = YES;
        
        for (PacketFilter *filter in filters) {
            if (!filter.isEnabled) {
                continue;
            }
            
            BOOL matches = [filter matchesPacket:packet];
            
            switch (filter.action) {
                case FilterActionInclude:
                    if (!matches) {
                        shouldInclude = NO;
                    }
                    break;
                    
                case FilterActionExclude:
                    if (matches) {
                        shouldInclude = NO;
                    }
                    break;
                    
                case FilterActionHighlight:
                    // For highlighting, we still include the packet
                    // but might mark it differently in UI
                    break;
                    
                case FilterActionAlert:
                    // For alerts, we still include the packet
                    // but might trigger a notification
                    break;
            }
            
            if (!shouldInclude) {
                break;
            }
        }
        
        if (shouldInclude) {
            [filteredPackets addObject:packet];
        }
    }
    
    return [filteredPackets copy];
}

- (BOOL)clearCapturedPacketsWithError:(NSError **)error {
    [self.capturedPackets removeAllObjects];
    
    // Update statistics
    self.statistics[@"totalPackets"] = @0;
    self.statistics[@"filteredPackets"] = @0;
    
    // Update session
    if (self.currentSession) {
        self.currentSession.packetsCaptured = 0;
        self.currentSession.packetsFiltered = 0;
        self.currentSession.capturedPackets = @[];
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidUpdateStatistics:)]) {
        [self.delegate packetCaptureDidUpdateStatistics:self.statistics];
    }
    
    NSLog(@"Cleared all captured packets.");
    
    return YES;
}

- (BOOL)saveCapturedPacketsToURL:(NSURL *)url
                           error:(NSError **)error {
    if (self.capturedPackets.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"No packets to save"}];
        }
        return NO;
    }
    
    // Convert packets to dictionary array
    NSMutableArray *packetDicts = [NSMutableArray array];
    for (CapturedPacket *packet in self.capturedPackets) {
        [packetDicts addObject:[packet toDictionary]];
    }
    
    // Create full export dictionary
    NSMutableDictionary *exportDict = [NSMutableDictionary dictionary];
    exportDict[@"version"] = @"1.0.0";
    exportDict[@"exportDate"] = @([[NSDate date] timeIntervalSince1970]);
    exportDict[@"packetCount"] = @(self.capturedPackets.count);
    exportDict[@"packets"] = packetDicts;
    
    if (self.currentSession) {
        exportDict[@"session"] = [self.currentSession toDictionary];
    }
    
    // Convert to JSON
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportDict
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to serialize packets to JSON",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return NO;
    }
    
    // Write to file
    NSError *writeError = nil;
    BOOL success = [jsonData writeToURL:url options:NSDataWritingAtomic error:&writeError];
    
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to write packets to file",
                                          NSUnderlyingErrorKey: writeError
                                      }];
        }
        return NO;
    }
    
    NSLog(@"Saved %lu packets to %@", (unsigned long)self.capturedPackets.count, url.path);
    
    return YES;
}

- (NSArray<CapturedPacket *> *)loadCapturedPacketsFromURL:(NSURL *)url
                                                    error:(NSError **)error {
    // Read file
    NSError *readError = nil;
    NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    
    if (readError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:404
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to read file",
                                          NSUnderlyingErrorKey: readError
                                      }];
        }
        return nil;
    }
    
    // Parse JSON
    NSError *jsonError = nil;
    NSDictionary *exportDict = [NSJSONSerialization JSONObjectWithData:fileData
                                                                options:0
                                                                  error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Invalid JSON format",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return nil;
    }
    
    // Extract packets
    NSArray *packetDicts = exportDict[@"packets"];
    if (![packetDicts isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketCaptureService"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid packet data format"}];
        }
        return nil;
    }
    
    // Convert dictionaries to CapturedPacket objects
    NSMutableArray<CapturedPacket *> *packets = [NSMutableArray array];
    for (NSDictionary *packetDict in packetDicts) {
        CapturedPacket *packet = [CapturedPacket fromDictionary:packetDict];
        if (packet) {
            [packets addObject:packet];
        }
    }
    
    NSLog(@"Loaded %lu packets from %@", (unsigned long)packets.count, url.path);
    
    return [packets copy];
}

#pragma mark - Utility Methods

+ (BOOL)isPacketCaptureAvailable {
    // Check if Network Extension framework is available
    // and if app has necessary entitlements
    // This is a simplified check
    return YES;
}

+ (BOOL)isVPNPacketExclusionEnabled {
    // Check if VPN packet exclusion is enabled
    // This would check system settings or stored configuration
    return NO;
}

+ (BOOL)setVPNPacketExclusionEnabled:(BOOL)enabled error:(NSError **)error {
    // Enable/disable VPN packet exclusion
    // This would require Network Extension configuration
    NSLog(@"VPN packet exclusion %@", enabled ? @"enabled" : @"disabled");
    return YES;
}

#pragma mark - Simulated Packet Capture (for testing)

/// Simulate capturing a packet (for testing without Network Extension)
- (void)simulatePacketCapture:(CapturedPacket *)packet {
    if (!self.isCapturing || self.isPaused) {
        return;
    }
    
    // Apply filters
    NSArray<PacketFilter *> *filters = self.currentSession.configuration.filters;
    BOOL shouldCapture = YES;
    
    for (PacketFilter *filter in filters) {
        if (!filter.isEnabled) {
            continue;
        }
        
        BOOL matches = [filter matchesPacket:packet];
        
        switch (filter.action) {
            case FilterActionInclude:
                if (!matches) {
                    shouldCapture = NO;
                }
                break;
                
            case FilterActionExclude:
                if (matches) {
                    shouldCapture = NO;
                }
                break;
                
            case FilterActionHighlight:
            case FilterActionAlert:
                // Still capture, but might mark differently
                break;
        }
        
        if (!shouldCapture) {
            self.statistics[@"filteredPackets"] = @([self.statistics[@"filteredPackets"] unsignedIntegerValue] + 1);
            self.currentSession.packetsFiltered++;
            return;
        }
    }
    
    // Add to captured packets
    [self.capturedPackets addObject:packet];
    
    // Update statistics
    self.statistics[@"totalPackets"] = @([self.statistics[@"totalPackets"] unsignedIntegerValue] + 1);
    self.currentSession.packetsCaptured++;
    self.currentSession.capturedPackets = [self.capturedPackets copy];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(packetCaptureDidCapturePacket:)]) {
        [self.delegate packetCaptureDidCapturePacket:packet];
    }
    
    // Update statistics periodically
    static NSUInteger updateCounter = 0;
    updateCounter++;
    if (updateCounter % 10 == 0) {
        if ([self.delegate respondsToSelector:@selector(packetCaptureDidUpdateStatistics:)]) {
            [self.delegate packetCaptureDidUpdateStatistics:self.statistics];
        }
        updateCounter = 0;
    }
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<PacketCaptureService: capturing=%d, paused=%d, packets=%lu>",
            self.isCapturing, self.isPaused, (unsigned long)self.capturedPackets.count];
}

@end