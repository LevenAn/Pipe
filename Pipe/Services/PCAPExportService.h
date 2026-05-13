//
//  PCAPExportService.h
//  Pipe
//

#import <Foundation/Foundation.h>
#import "../Models/CapturedPacket.h"

NS_ASSUME_NONNULL_BEGIN

@interface PCAPExportService : NSObject

/// Writes classic libpcap (DLT_RAW / LINKTYPE_RAW) with synthetic IPv4 datagrams built from `CapturedPacket`.
+ (BOOL)exportPackets:(NSArray<CapturedPacket *> *)packets
                toURL:(NSURL *)url
                error:(NSError **)error;

+ (NSData *)pcapDataFromPackets:(NSArray<CapturedPacket *> *)packets;

@end

NS_ASSUME_NONNULL_END
