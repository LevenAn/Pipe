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

/// Capture session state (live capture pipeline; distinct from `CaptureSession` in Models).
typedef NS_ENUM(NSInteger, PIPCapSessionState) {
    PIPCapSessionStateStopped,
    PIPCapSessionStateStarting,
    PIPCapSessionStateRunning,
    PIPCapSessionStateStopping,
    PIPCapSessionStateError
};

/// Live capture configuration
@interface PIPCapConfiguration : NSObject <NSCoding, NSCopying>

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
/// When YES, captured data is not written to disk by storage/export helpers.
@property (nonatomic, assign) BOOL privateMode;

- (instancetype)initWithBufferSize:(NSUInteger)bufferSize
                   promiscuousMode:(BOOL)promiscuousMode
                        interfaces:(NSArray<NSString *> *)interfaces
                           filters:(NSArray<PacketFilter *> *)filters
               maxPacketsPerSecond:(NSUInteger)maxPacketsPerSecond
                        captureDNS:(BOOL)captureDNS
                       captureHTTP:(BOOL)captureHTTP
                      captureHTTPS:(BOOL)captureHTTPS
                         captureTCP:(BOOL)captureTCP
                        captureUDP:(BOOL)captureUDP
                        privateMode:(BOOL)privateMode;

/// Default configuration
+ (instancetype)defaultConfiguration;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

/// Create from dictionary
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

/// Live capture session handle
@interface PIPCapSession : NSObject

@property (nonatomic, copy) NSUUID *sessionId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) PIPCapConfiguration *configuration;
@property (nonatomic, assign) PIPCapSessionState state;
@property (nonatomic, assign) NSUInteger packetsCaptured;
@property (nonatomic, assign) NSUInteger packetsFiltered;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSArray<CapturedPacket *> *capturedPackets;

- (instancetype)initWithSessionId:(NSUUID *)sessionId
                             name:(NSString *)name
                    configuration:(PIPCapConfiguration *)configuration;

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
- (void)packetCaptureDidChangeState:(PIPCapSessionState)state;

/// Called when an error occurs
- (void)packetCaptureDidEncounterError:(NSError *)error;

/// Called when statistics are updated
- (void)packetCaptureDidUpdateStatistics:(NSDictionary *)statistics;

@end

/// Packet capture service protocol
@protocol PacketCaptureServiceProtocol <NSObject>

/// Start capture session with configuration
- (BOOL)startCaptureWithConfiguration:(PIPCapConfiguration *)configuration
                                error:(NSError **)error;

/// Stop current capture session
- (BOOL)stopCaptureWithError:(NSError **)error;

/// Pause capture session
- (BOOL)pauseCaptureWithError:(NSError **)error;

/// Resume capture session
- (BOOL)resumeCaptureWithError:(NSError **)error;

/// Get current capture session
- (PIPCapSession * _Nullable)currentSession;

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

@property (nonatomic, assign, readonly, getter=isCapturing) BOOL isCapturing;
@property (nonatomic, assign, readonly, getter=isPaused) BOOL isPaused;

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

/// Snapshot of in-memory packets for UI refresh.
- (NSArray<CapturedPacket *> *)snapshotCapturedPackets;

/// Demo hook: inject a packet into the live capture buffer (requires active capture).
- (void)simulatePacketCapture:(CapturedPacket *)packet;

@end

NS_ASSUME_NONNULL_END