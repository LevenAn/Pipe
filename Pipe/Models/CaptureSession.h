//
//  CaptureSession.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "CapturedPacket.h"

NS_ASSUME_NONNULL_BEGIN

/// Capture session status
typedef NS_ENUM(NSInteger, CaptureSessionStatus) {
    CaptureSessionStatusActive,
    CaptureSessionStatusStopped,
    CaptureSessionStatusExporting,
    CaptureSessionStatusError
};

/// Capture configuration
@interface CaptureConfiguration : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) NSUInteger bufferSize;
@property (nonatomic, assign) BOOL promiscuousMode;
@property (nonatomic, assign) NSUInteger snapshotLength;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) BOOL immediateMode;
@property (nonatomic, assign) BOOL privateMode;

- (instancetype)initWithBufferSize:(NSUInteger)bufferSize
                   promiscuousMode:(BOOL)promiscuousMode
                   snapshotLength:(NSUInteger)snapshotLength
                           timeout:(NSTimeInterval)timeout
                     immediateMode:(BOOL)immediateMode;

/// Default configuration
+ (instancetype)defaultConfiguration;

@end

/// Represents a packet capture session
@interface CaptureSession : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSUUID *sessionId;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate * _Nullable endTime;
@property (nonatomic, strong) CaptureConfiguration *configuration;
@property (nonatomic, assign) NSUInteger packetCount;
@property (nonatomic, assign) NSUInteger totalBytes;
@property (nonatomic, copy) NSArray<NSDictionary *> *filterRules; // Array of PacketFilter dictionaries
@property (nonatomic, assign) CaptureSessionStatus status;
@property (nonatomic, copy) NSArray<CapturedPacket *> *packets;

- (instancetype)initWithSessionId:(NSUUID *)sessionId
                        startTime:(NSDate *)startTime
                          endTime:(NSDate * _Nullable)endTime
                    configuration:(CaptureConfiguration *)configuration
                      packetCount:(NSUInteger)packetCount
                       totalBytes:(NSUInteger)totalBytes
                      filterRules:(NSArray<NSDictionary *> *)filterRules
                           status:(CaptureSessionStatus)status
                          packets:(NSArray<CapturedPacket *> *)packets;

/// Convenience initializer for new session
- (instancetype)initWithConfiguration:(CaptureConfiguration *)configuration
                          filterRules:(NSArray<NSDictionary *> *)filterRules;

/// Add a packet to the session
- (void)addPacket:(CapturedPacket *)packet;

/// Convert to dictionary for JSON serialization
- (NSDictionary *)toDictionary;

/// Create from dictionary (JSON deserialization)
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END