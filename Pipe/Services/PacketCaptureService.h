//
//  PacketCaptureService.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "../Models/CapturedPacket.h"
#import "../Models/PacketFilter.h"

NS_ASSUME_NONNULL_BEGIN

/// Capture session state
typedef NS_ENUM(NSInteger, CaptureSessionState) {
    CaptureSessionStateStopped,
    CaptureSessionStateStarting,
    CaptureSessionStateRunning,
    CaptureSessionStateStopping,
    CaptureSessionStateError
};

/// Capture configuration
@interface CaptureConfiguration : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) NSUInteger bufferSize;
@property (nonatomic, assign) BOOL promiscuousMode;
@property (nonatomic, copy) NSArray<NSString *> *interfaces;
@property (nonatomic, copy) NSArray<PacketFilter *> *filters;
@property (nonatomic, assign) NSUInteger maxPacketsPerSecond;
@property (nonatomic, assign) BOOL captureDNS;
@property (nonatomic, assign) BOOL captureHTTP;
@property (nonatomic, assign) BOOL captureHTTPS;
@property (nonatomic, assign) BOOL captureTCP;
@property (nonatomic, assign) BOOL captureUDP;

- (instancetype)initWithBufferSize:(NSUInteger)bufferSize
                   promiscuousMode:(BOOL)promiscuousMode
                        interfaces:(NSArray<NSString *> *)interfaces
                           filters:(NSArray<PacketFilter *> *)filters
               maxPacketsPerSecond:(NSUInteger)maxPacketsPerSecond
                        captureDNS:(BOOL)captureDNS
                       captureHTTP:(BOOL)captureHTTP
                      captureHTTPS:(BOOL)captureHTTPS
                         captureTCP:(BOOL)captureTCP
                        captureUDP:(BOOL)captureUDP;

/// Default configuration
+ (instancetype)defaultConfiguration;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

/// Create from dictionary
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

/// Capture session
@interface CaptureSession : NSObject

@property (nonatomic, copy) NSUUID *sessionId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) CaptureConfiguration *configuration;
@property (nonatomic, assign) CaptureSessionState state;
@property (nonatomic, assign) NSUInteger packetsCaptured;
@property (nonatomic, assign) NSUInteger packetsFiltered;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSArray<CapturedPacket *> *capturedPackets;

- (instancetype)initWithSessionId:(NSUUID *)sessionId
                             name:(NSString *)name
                    configuration:(CaptureConfiguration *)configuration;

/// Start time as string
- (NSString *)startTimeString;

/// Duration as string
- (NSString *)durationString;

/// Packets per second
- (double)packetsPerSecond;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Packet capture delegate
@protocol PacketCaptureDelegate <NSObject>

@optional
/// Called when a packet is captured
- (void)packetCaptureDidCapturePacket:(CapturedPacket *)packet;

/// Called when capture session state changes
- (void)packetCaptureDidChangeState:(CaptureSessionState)state;

/// Called when an error occurs
- (void)packetCaptureDidEncounterError:(NSError *)error;

/// Called when statistics are updated
- (void)packetCaptureDidUpdateStatistics:(NSDictionary *)statistics;

@end

/// Packet capture service protocol
@protocol PacketCaptureServiceProtocol <NSObject>

/// Start capture session with configuration
- (BOOL)startCaptureWithConfiguration:(CaptureConfiguration *)configuration
                                error:(NSError **)error;

/// Stop current capture session
- (BOOL)stopCaptureWithError:(NSError **)error;

/// Pause capture session
- (BOOL)pauseCaptureWithError:(NSError **)error;

/// Resume capture session
- (BOOL)resumeCaptureWithError:(NSError **)error;

/// Get current capture session
- (CaptureSession * _Nullable)currentSession;

/// Get capture statistics
- (NSDictionary *)captureStatistics;

/// Apply filters to captured packets
- (NSArray<CapturedPacket *> *)applyFilters:(NSArray<PacketFilter *> *)filters
                                   toPackets:(NSArray<CapturedPacket *> *)packets;

/// Clear captured packets
- (BOOL)clearCapturedPacketsWithError:(NSError **)error;

/// Save captured packets to file
- (BOOL)saveCapturedPacketsToURL:(NSURL *)url
                           error:(NSError **)error;

/// Load captured packets from file
- (NSArray<CapturedPacket *> *)loadCapturedPacketsFromURL:(NSURL *)url
                                                    error:(NSError **)error;

@end

/// Packet capture service
@interface PacketCaptureService : NSObject <PacketCaptureServiceProtocol>

/// Shared instance
+ (instancetype)sharedService;

/// Initialize with delegate
- (instancetype)initWithDelegate:(id<PacketCaptureDelegate>)delegate;

/// Capture delegate
@property (nonatomic, weak) id<PacketCaptureDelegate> delegate;

/// Check if packet capture is available on this device
+ (BOOL)isPacketCaptureAvailable;

/// Check if VPN packet exclusion is enabled
+ (BOOL)isVPNPacketExclusionEnabled;

/// Enable/disable VPN packet exclusion
+ (BOOL)setVPNPacketExclusionEnabled:(BOOL)enabled error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END