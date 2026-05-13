//
//  PacketStorageService.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "PacketStorageService.h"
#import "PCAPExportService.h"

@interface PacketStorageService ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<CapturedPacket *> *> *sessionPackets;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CaptureSession *> *activeSessions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CaptureSession *> *archivedSessions;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSURL *storageDirectory;

@end

@implementation StorageLimits

- (instancetype)initWithMaxPackets:(NSUInteger)maxPackets
                         maxSizeMB:(NSUInteger)maxSizeMB
                      maxSessions:(NSUInteger)maxSessions {
    self = [super init];
    if (self) {
        _maxPackets = maxPackets;
        _maxSizeMB = maxSizeMB;
        _maxSessions = maxSessions;
    }
    return self;
}

+ (instancetype)defaultLimits {
    return [[StorageLimits alloc] initWithMaxPackets:10000    // 10,000 packets
                                           maxSizeMB:100      // 100MB
                                        maxSessions:10];     // 10 sessions
}

+ (instancetype)unlimited {
    return [[StorageLimits alloc] initWithMaxPackets:0        // 0 = unlimited
                                           maxSizeMB:0        // 0 = unlimited
                                        maxSessions:0];      // 0 = unlimited
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<StorageLimits: maxPackets=%lu, maxSizeMB=%lu, maxSessions=%lu>",
            (unsigned long)self.maxPackets, (unsigned long)self.maxSizeMB, (unsigned long)self.maxSessions];
}

@end

@implementation StorageStatistics

- (NSDictionary *)toDictionary {
    return @{
        @"totalPackets": @(self.totalPackets),
        @"totalSessions": @(self.totalSessions),
        @"totalSizeBytes": @(self.totalSizeBytes),
        @"activeSessions": @(self.activeSessions),
        @"archivedSessions": @(self.archivedSessions)
    };
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<StorageStatistics: packets=%lu, sessions=%lu, size=%lu bytes>",
            (unsigned long)self.totalPackets, (unsigned long)self.totalSessions, (unsigned long)self.totalSizeBytes];
}

@end

@implementation PacketStorageService

#pragma mark - Singleton

+ (instancetype)sharedService {
    static PacketStorageService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithStorageLimits:[StorageLimits defaultLimits]];
    });
    return sharedInstance;
}

#pragma mark - Initialization

- (instancetype)initWithStorageLimits:(StorageLimits *)limits {
    self = [super init];
    if (self) {
        _storageLimits = limits ?: [StorageLimits defaultLimits];
        _sessionPackets = [NSMutableDictionary dictionary];
        _activeSessions = [NSMutableDictionary dictionary];
        _archivedSessions = [NSMutableDictionary dictionary];
        _fileManager = [NSFileManager defaultManager];
        
        // Set up storage directory
        [self setupStorageDirectory];
    }
    return self;
}

- (void)setupStorageDirectory {
    NSURL *documentsDirectory = [[self.fileManager URLsForDirectory:NSDocumentDirectory
                                                          inDomains:NSUserDomainMask] firstObject];
    self.storageDirectory = [documentsDirectory URLByAppendingPathComponent:@"PacketStorage"];
    
    // Create directory if it doesn't exist
    NSError *error = nil;
    if (![self.fileManager fileExistsAtPath:self.storageDirectory.path]) {
        [self.fileManager createDirectoryAtURL:self.storageDirectory
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        
        if (error) {
            NSLog(@"Failed to create storage directory: %@", error);
        }
    }
}

#pragma mark - PacketStorageServiceProtocol

- (BOOL)savePackets:(NSArray<CapturedPacket *> *)packets
          forSession:(CaptureSession *)session
               error:(NSError **)error {
    if (!session || !session.sessionId) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid session"}];
        }
        return NO;
    }
    
    NSString *sessionKey = [session.sessionId UUIDString];
    
    // Check storage limits
    if (![self isStorageWithinLimitsAfterAddingPackets:packets.count]) {
        // Try to clean up
        NSError *cleanupError = nil;
        if (![self cleanupStorageWithError:&cleanupError]) {
            if (error) {
                *error = [NSError errorWithDomain:@"PacketStorageService"
                                              code:507  // Insufficient Storage
                                          userInfo:@{
                                              NSLocalizedDescriptionKey: @"Storage limit exceeded and cleanup failed",
                                              NSUnderlyingErrorKey: cleanupError
                                          }];
            }
            return NO;
        }
        
        // Check again after cleanup
        if (![self isStorageWithinLimitsAfterAddingPackets:packets.count]) {
            if (error) {
                *error = [NSError errorWithDomain:@"PacketStorageService"
                                              code:507
                                          userInfo:@{NSLocalizedDescriptionKey: @"Storage limit exceeded even after cleanup"}];
            }
            return NO;
        }
    }
    
    // Save to memory
    self.sessionPackets[sessionKey] = [packets copy];
    self.activeSessions[sessionKey] = session;
    
    if (!session.configuration.privateMode) {
        [self saveSessionToDisk:session packets:packets];
    } else {
        NSLog(@"Private mode: skipped disk persist for session %@", session.sessionId);
    }
    
    NSLog(@"Saved %lu packets for session %@", (unsigned long)packets.count, session.sessionId);
    
    return YES;
}

- (NSArray<CapturedPacket *> *)loadPacketsForSession:(CaptureSession *)session
                                               error:(NSError **)error {
    if (!session || !session.sessionId) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid session"}];
        }
        return nil;
    }
    
    NSString *sessionKey = [session.sessionId UUIDString];
    
    // Try to load from memory first
    NSArray<CapturedPacket *> *packets = self.sessionPackets[sessionKey];
    if (packets) {
        return packets;
    }
    
    // Try to load from disk
    packets = [self loadSessionFromDisk:session];
    if (packets) {
        self.sessionPackets[sessionKey] = packets;
        self.activeSessions[sessionKey] = session;
        return packets;
    }
    
    // Not found
    if (error) {
        *error = [NSError errorWithDomain:@"PacketStorageService"
                                      code:404
                                  userInfo:@{NSLocalizedDescriptionKey: @"Session not found"}];
    }
    return nil;
}

- (BOOL)deletePacketsForSession:(CaptureSession *)session
                          error:(NSError **)error {
    if (!session || !session.sessionId) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid session"}];
        }
        return NO;
    }
    
    NSString *sessionKey = [session.sessionId UUIDString];
    
    // Remove from memory
    [self.sessionPackets removeObjectForKey:sessionKey];
    [self.activeSessions removeObjectForKey:sessionKey];
    [self.archivedSessions removeObjectForKey:sessionKey];
    
    // Delete from disk
    [self deleteSessionFromDisk:session];
    
        NSLog(@"Deleted packets for session %@", session.sessionId);
    
    return YES;
}

- (BOOL)archiveSession:(CaptureSession *)session
                 error:(NSError **)error {
    if (!session || !session.sessionId) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid session"}];
        }
        return NO;
    }
    
    NSString *sessionKey = [session.sessionId UUIDString];
    
    // Move from active to archived
    CaptureSession *activeSession = self.activeSessions[sessionKey];
    if (activeSession) {
        self.archivedSessions[sessionKey] = activeSession;
        [self.activeSessions removeObjectForKey:sessionKey];
        
        // In a real implementation, would move to different storage location
        NSLog(@"Archived session %@", session.sessionId);
        return YES;
    }
    
    if (error) {
        *error = [NSError errorWithDomain:@"PacketStorageService"
                                      code:404
                                  userInfo:@{NSLocalizedDescriptionKey: @"Session not found in active sessions"}];
    }
    return NO;
}

- (BOOL)restoreSession:(CaptureSession *)session
                 error:(NSError **)error {
    if (!session || !session.sessionId) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid session"}];
        }
        return NO;
    }
    
    NSString *sessionKey = [session.sessionId UUIDString];
    
    // Move from archived to active
    CaptureSession *archivedSession = self.archivedSessions[sessionKey];
    if (archivedSession) {
        self.activeSessions[sessionKey] = archivedSession;
        [self.archivedSessions removeObjectForKey:sessionKey];
        
        NSLog(@"Restored session %@ from archive", session.sessionId);
        return YES;
    }
    
    if (error) {
        *error = [NSError errorWithDomain:@"PacketStorageService"
                                      code:404
                                  userInfo:@{NSLocalizedDescriptionKey: @"Session not found in archived sessions"}];
    }
    return NO;
}

- (StorageStatistics *)storageStatistics {
    StorageStatistics *stats = [[StorageStatistics alloc] init];
    
    // Calculate statistics
    NSUInteger totalPackets = 0;
    NSUInteger totalSizeBytes = 0;
    
    for (NSArray<CapturedPacket *> *packets in self.sessionPackets.allValues) {
        totalPackets += packets.count;
        
        // Estimate size (roughly 1KB per packet)
        totalSizeBytes += packets.count * 1024;
    }
    
    stats.totalPackets = totalPackets;
    stats.totalSessions = self.activeSessions.count + self.archivedSessions.count;
    stats.totalSizeBytes = totalSizeBytes;
    stats.activeSessions = self.activeSessions.count;
    stats.archivedSessions = self.archivedSessions.count;
    
    return stats;
}

- (BOOL)isStorageWithinLimits {
    StorageStatistics *stats = [self storageStatistics];
    
    // Check packet limit
    if (self.storageLimits.maxPackets > 0 && stats.totalPackets > self.storageLimits.maxPackets) {
        return NO;
    }
    
    // Check size limit (convert MB to bytes)
    if (self.storageLimits.maxSizeMB > 0) {
        NSUInteger maxSizeBytes = self.storageLimits.maxSizeMB * 1024 * 1024;
        if (stats.totalSizeBytes > maxSizeBytes) {
            return NO;
        }
    }
    
    // Check session limit
    if (self.storageLimits.maxSessions > 0 && stats.totalSessions > self.storageLimits.maxSessions) {
        return NO;
    }
    
    return YES;
}

- (BOOL)cleanupStorageWithError:(NSError **)error {
    StorageStatistics *stats = [self storageStatistics];
    BOOL needsCleanup = NO;
    
    // Check which limits are exceeded
    if (self.storageLimits.maxPackets > 0 && stats.totalPackets > self.storageLimits.maxPackets) {
        needsCleanup = YES;
        NSLog(@"Packet limit exceeded: %lu > %lu", (unsigned long)stats.totalPackets, (unsigned long)self.storageLimits.maxPackets);
    }
    
    if (self.storageLimits.maxSizeMB > 0) {
        NSUInteger maxSizeBytes = self.storageLimits.maxSizeMB * 1024 * 1024;
        if (stats.totalSizeBytes > maxSizeBytes) {
            needsCleanup = YES;
            NSLog(@"Size limit exceeded: %lu bytes > %lu bytes", (unsigned long)stats.totalSizeBytes, (unsigned long)maxSizeBytes);
        }
    }
    
    if (self.storageLimits.maxSessions > 0 && stats.totalSessions > self.storageLimits.maxSessions) {
        needsCleanup = YES;
        NSLog(@"Session limit exceeded: %lu > %lu", (unsigned long)stats.totalSessions, (unsigned long)self.storageLimits.maxSessions);
    }
    
    if (!needsCleanup) {
        return YES; // No cleanup needed
    }
    
    // Cleanup strategy: remove oldest archived sessions first, then oldest active sessions
    NSMutableArray<NSString *> *sessionsToDelete = [NSMutableArray array];
    
    // Sort archived sessions by some criteria (e.g., oldest first)
    // For now, just take all archived sessions
    [sessionsToDelete addObjectsFromArray:self.archivedSessions.allKeys];
    
    // If still need to clean up, take oldest active sessions
    if ([self storageStatistics].totalSessions > self.storageLimits.maxSessions) {
        // Sort active sessions (simplified - just take some)
        NSArray<NSString *> *activeSessionKeys = self.activeSessions.allKeys;
        NSUInteger sessionsToRemove = MIN(activeSessionKeys.count, [self storageStatistics].totalSessions - self.storageLimits.maxSessions);
        
        for (NSUInteger i = 0; i < sessionsToRemove; i++) {
            if (i < activeSessionKeys.count) {
                [sessionsToDelete addObject:activeSessionKeys[i]];
            }
        }
    }
    
    // Delete selected sessions
    for (NSString *sessionKey in sessionsToDelete) {
        CaptureSession *session = self.archivedSessions[sessionKey] ?: self.activeSessions[sessionKey];
        if (session) {
            NSError *deleteError = nil;
            [self deletePacketsForSession:session error:&deleteError];
            if (deleteError) {
                NSLog(@"Failed to delete session %@ during cleanup: %@", sessionKey, deleteError);
            }
        }
    }
    
    NSLog(@"Cleanup completed. Removed %lu sessions.", (unsigned long)sessionsToDelete.count);
    
    return YES;
}

- (BOOL)exportPackets:(NSArray<CapturedPacket *> *)packets
                toURL:(NSURL *)url
                error:(NSError **)error {
    if (packets.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"No packets to export"}];
        }
        return NO;
    }

    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"pcap"]) {
        return [PCAPExportService exportPackets:packets toURL:url error:error];
    }
    
    // Convert packets to dictionary array
    NSMutableArray *packetDicts = [NSMutableArray array];
    for (CapturedPacket *packet in packets) {
        [packetDicts addObject:[packet toDictionary]];
    }
    
    // Create export dictionary
    NSDictionary *exportDict = @{
        @"version": @"1.0.0",
        @"exportDate": @([[NSDate date] timeIntervalSince1970]),
        @"packetCount": @(packets.count),
        @"packets": packetDicts
    };
    
    // Convert to JSON
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportDict
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to serialize packets for export",
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
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to write export file",
                                          NSUnderlyingErrorKey: writeError
                                      }];
        }
        return NO;
    }
    
    NSLog(@"Exported %lu packets to %@", (unsigned long)packets.count, url.path);
    
    return YES;
}

- (NSArray<CapturedPacket *> *)importPacketsFromURL:(NSURL *)url
                                              error:(NSError **)error {
    // Read file
    NSError *readError = nil;
    NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    
    if (readError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:404
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to read import file",
                                          NSUnderlyingErrorKey: readError
                                      }];
        }
        return nil;
    }
    
    // Parse JSON
    NSError *jsonError = nil;
    NSDictionary *importDict = [NSJSONSerialization JSONObjectWithData:fileData
                                                                options:0
                                                                  error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Invalid import file format",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return nil;
    }
    
    // Extract packets
    NSArray *packetDicts = importDict[@"packets"];
    if (![packetDicts isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PacketStorageService"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid packet data in import file"}];
        }
        return nil;
    }
    
    // Convert to CapturedPacket objects
    NSMutableArray<CapturedPacket *> *packets = [NSMutableArray array];
    for (NSDictionary *packetDict in packetDicts) {
        CapturedPacket *packet = [CapturedPacket fromDictionary:packetDict];
        if (packet) {
            [packets addObject:packet];
        }
    }
    
    NSLog(@"Imported %lu packets from %@", (unsigned long)packets.count, url.path);
    
    return [packets copy];
}

#pragma mark - Private Methods

- (BOOL)isStorageWithinLimitsAfterAddingPackets:(NSUInteger)additionalPackets {
    StorageStatistics *stats = [self storageStatistics];
    
    // Check packet limit
    if (self.storageLimits.maxPackets > 0) {
        NSUInteger newTotalPackets = stats.totalPackets + additionalPackets;
        if (newTotalPackets > self.storageLimits.maxPackets) {
            return NO;
        }
    }
    
    // Check size limit (estimate 1KB per additional packet)
    if (self.storageLimits.maxSizeMB > 0) {
        NSUInteger additionalSizeBytes = additionalPackets * 1024;
        NSUInteger newTotalSizeBytes = stats.totalSizeBytes + additionalSizeBytes;
        NSUInteger maxSizeBytes = self.storageLimits.maxSizeMB * 1024 * 1024;
        
        if (newTotalSizeBytes > maxSizeBytes) {
            return NO;
        }
    }
    
    return YES;
}

- (void)saveSessionToDisk:(CaptureSession *)session packets:(NSArray<CapturedPacket *> *)packets {
    // In a real implementation, this would save to persistent storage
    // For now, we'll just log
    NSLog(@"Would save session %@ with %lu packets to disk", session.sessionId, (unsigned long)packets.count);
}

- (NSArray<CapturedPacket *> *)loadSessionFromDisk:(CaptureSession *)session {
    // In a real implementation, this would load from persistent storage
    // For now, return nil to indicate not found on disk
    return nil;
}

- (void)deleteSessionFromDisk:(CaptureSession *)session {
    // In a real implementation, this would delete from persistent storage
    // For now, just log
    NSLog(@"Would delete session %@ from disk", session.sessionId);
}

#pragma mark - Description

- (NSString *)description {
    StorageStatistics *stats = [self storageStatistics];
    return [NSString stringWithFormat:@"<PacketStorageService: packets=%lu, sessions=%lu, withinLimits=%d>",
            (unsigned long)stats.totalPackets, (unsigned long)stats.totalSessions, [self isStorageWithinLimits]];
}

@end