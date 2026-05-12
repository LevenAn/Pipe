//
//  PacketStorageService.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "../Models/CapturedPacket.h"
#import "../Models/CaptureSession.h"

NS_ASSUME_NONNULL_BEGIN

/// Storage limits
@interface StorageLimits : NSObject

@property (nonatomic, assign) NSUInteger maxPackets;
@property (nonatomic, assign) NSUInteger maxSizeMB;
@property (nonatomic, assign) NSUInteger maxSessions;

- (instancetype)initWithMaxPackets:(NSUInteger)maxPackets
                         maxSizeMB:(NSUInteger)maxSizeMB
                      maxSessions:(NSUInteger)maxSessions;

/// Default limits
+ (instancetype)defaultLimits;

/// Unlimited storage
+ (instancetype)unlimited;

@end

/// Storage statistics
@interface StorageStatistics : NSObject

@property (nonatomic, assign) NSUInteger totalPackets;
@property (nonatomic, assign) NSUInteger totalSessions;
@property (nonatomic, assign) NSUInteger totalSizeBytes;
@property (nonatomic, assign) NSUInteger activeSessions;
@property (nonatomic, assign) NSUInteger archivedSessions;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Packet storage service protocol
@protocol PacketStorageServiceProtocol <NSObject>

/// Save captured packets from session
- (BOOL)savePackets:(NSArray<CapturedPacket *> *)packets
          forSession:(CaptureSession *)session
               error:(NSError **)error;

/// Load packets for session
- (NSArray<CapturedPacket *> *)loadPacketsForSession:(CaptureSession *)session
                                               error:(NSError **)error;

/// Delete packets for session
- (BOOL)deletePacketsForSession:(CaptureSession *)session
                          error:(NSError **)error;

/// Archive session (move to long-term storage)
- (BOOL)archiveSession:(CaptureSession *)session
                 error:(NSError **)error;

/// Restore archived session
- (BOOL)restoreSession:(CaptureSession *)session
                 error:(NSError **)error;

/// Get storage statistics
- (StorageStatistics *)storageStatistics;

/// Check storage limits
- (BOOL)isStorageWithinLimits;

/// Clean up old data to stay within limits
- (BOOL)cleanupStorageWithError:(NSError **)error;

/// Export packets to file
- (BOOL)exportPackets:(NSArray<CapturedPacket *> *)packets
                toURL:(NSURL *)url
                error:(NSError **)error;

/// Import packets from file
- (NSArray<CapturedPacket *> *)importPacketsFromURL:(NSURL *)url
                                              error:(NSError **)error;

@end

/// Packet storage service
@interface PacketStorageService : NSObject <PacketStorageServiceProtocol>

/// Shared instance
+ (instancetype)sharedService;

/// Initialize with storage limits
- (instancetype)initWithStorageLimits:(StorageLimits *)limits;

/// Current storage limits
@property (nonatomic, strong) StorageLimits *storageLimits;

@end

NS_ASSUME_NONNULL_END