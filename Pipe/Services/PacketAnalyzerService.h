//
//  PacketAnalyzerService.h
//  Pipe
//
//  Created by Leven on 2026/5/11.
//

#import <Foundation/Foundation.h>
#import "../Models/CapturedPacket.h"

NS_ASSUME_NONNULL_BEGIN

/// Protocol types that can be detected
typedef NS_ENUM(NSInteger, ProtocolType) {
    ProtocolTypeUnknown,
    ProtocolTypeHTTP,
    ProtocolTypeHTTPS,
    ProtocolTypeDNS,
    ProtocolTypeTCP,
    ProtocolTypeUDP,
    ProtocolTypeICMP,
    ProtocolTypeARP,
    ProtocolTypeSSH,
    ProtocolTypeFTP,
    ProtocolTypeSMTP,
    ProtocolTypePOP3,
    ProtocolTypeIMAP,
    ProtocolTypeDHCP,
    ProtocolTypeNTP
};

/// Protocol detection result
@interface ProtocolDetectionResult : NSObject

@property (nonatomic, assign) ProtocolType protocolType;
@property (nonatomic, copy) NSString *protocolName;
@property (nonatomic, assign) CGFloat confidence; // 0.0 to 1.0
@property (nonatomic, copy) NSDictionary *details;

- (instancetype)initWithProtocolType:(ProtocolType)protocolType
                        protocolName:(NSString *)protocolName
                          confidence:(CGFloat)confidence
                             details:(NSDictionary *)details;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Packet analysis result
@interface PacketAnalysisResult : NSObject

@property (nonatomic, strong) CapturedPacket *packet;
@property (nonatomic, strong) ProtocolDetectionResult *protocolDetection;
@property (nonatomic, copy) NSString *formattedSummary;
@property (nonatomic, copy) NSString *formattedDetails;
@property (nonatomic, copy) NSDictionary *extractedFields;
@property (nonatomic, assign) BOOL isMalicious;
@property (nonatomic, copy) NSString *maliciousReason;

- (instancetype)initWithPacket:(CapturedPacket *)packet
            protocolDetection:(ProtocolDetectionResult *)protocolDetection
             formattedSummary:(NSString *)formattedSummary
             formattedDetails:(NSString *)formattedDetails
              extractedFields:(NSDictionary *)extractedFields
                 isMalicious:(BOOL)isMalicious
             maliciousReason:(NSString *)maliciousReason;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Search options for packet search
@interface SearchOptions : NSObject

@property (nonatomic, copy) NSString *query;
@property (nonatomic, assign) BOOL caseSensitive;
@property (nonatomic, assign) BOOL searchSourceIP;
@property (nonatomic, assign) BOOL searchDestinationIP;
@property (nonatomic, assign) BOOL searchProtocol;
@property (nonatomic, assign) BOOL searchPayload;
@property (nonatomic, assign) NSDate *startDate;
@property (nonatomic, assign) NSDate *endDate;
@property (nonatomic, assign) NSUInteger minSize;
@property (nonatomic, assign) NSUInteger maxSize;

- (instancetype)initWithQuery:(NSString *)query
               caseSensitive:(BOOL)caseSensitive
             searchSourceIP:(BOOL)searchSourceIP
          searchDestinationIP:(BOOL)searchDestinationIP
              searchProtocol:(BOOL)searchProtocol
                searchPayload:(BOOL)searchPayload
                   startDate:(NSDate *)startDate
                     endDate:(NSDate *)endDate
                     minSize:(NSUInteger)minSize
                     maxSize:(NSUInteger)maxSize;

/// Default search options
+ (instancetype)defaultOptions;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Search result
@interface SearchResult : NSObject

@property (nonatomic, strong) PacketAnalysisResult *analysisResult;
@property (nonatomic, assign) CGFloat relevanceScore; // 0.0 to 1.0
@property (nonatomic, copy) NSArray<NSString *> *matchedFields;
@property (nonatomic, copy) NSArray<NSValue *> *matchedRanges; // NSRange values

- (instancetype)initWithAnalysisResult:(PacketAnalysisResult *)analysisResult
                        relevanceScore:(CGFloat)relevanceScore
                         matchedFields:(NSArray<NSString *> *)matchedFields
                         matchedRanges:(NSArray<NSValue *> *)matchedRanges;

/// Convert to dictionary
- (NSDictionary *)toDictionary;

@end

/// Packet analyzer delegate
@protocol PacketAnalyzerDelegate <NSObject>

@optional
/// Called when analysis is complete for a packet
- (void)packetAnalyzerDidAnalyzePacket:(PacketAnalysisResult *)result;

/// Called when batch analysis is complete
- (void)packetAnalyzerDidCompleteBatchAnalysis:(NSArray<PacketAnalysisResult *> *)results;

/// Called when search is complete
- (void)packetAnalyzerDidCompleteSearch:(NSArray<SearchResult *> *)results;

/// Called when an error occurs during analysis
- (void)packetAnalyzerDidEncounterError:(NSError *)error;

@end

/// Packet analyzer service protocol
@protocol PacketAnalyzerServiceProtocol <NSObject>

/// Analyze a single packet
- (PacketAnalysisResult *)analyzePacket:(CapturedPacket *)packet;

/// Analyze multiple packets
- (NSArray<PacketAnalysisResult *> *)analyzePackets:(NSArray<CapturedPacket *> *)packets;

/// Format packet for display
- (NSString *)formatPacketForDisplay:(CapturedPacket *)packet;

/// Format packet with detailed information
- (NSString *)formatPacketWithDetails:(CapturedPacket *)packet;

/// Search packets with options
- (NSArray<SearchResult *> *)searchPackets:(NSArray<CapturedPacket *> *)packets
                               withOptions:(SearchOptions *)options;

/// Detect protocol from packet
- (ProtocolDetectionResult *)detectProtocol:(CapturedPacket *)packet;

/// Extract HTTP information from packet (if applicable)
- (NSDictionary *)extractHTTPInfo:(CapturedPacket *)packet;

/// Extract DNS information from packet (if applicable)
- (NSDictionary *)extractDNSInfo:(CapturedPacket *)packet;

/// Check if packet appears malicious
- (BOOL)isPacketMalicious:(CapturedPacket *)packet reason:(NSString * _Nullable * _Nullable)reason;

/// Get statistics about analyzed packets
- (NSDictionary *)analysisStatistics;

/// Clear analysis cache
- (BOOL)clearAnalysisCacheWithError:(NSError **)error;

@end

/// Packet analyzer service
@interface PacketAnalyzerService : NSObject <PacketAnalyzerServiceProtocol>

/// Shared instance
+ (instancetype)sharedService;

/// Initialize with delegate
- (instancetype)initWithDelegate:(id<PacketAnalyzerDelegate>)delegate;

/// Analysis delegate
@property (nonatomic, weak) id<PacketAnalyzerDelegate> delegate;

/// Enable/disable deep packet inspection
@property (nonatomic, assign) BOOL deepPacketInspectionEnabled;

/// Maximum payload size to analyze (bytes)
@property (nonatomic, assign) NSUInteger maxPayloadSize;

/// Protocol detection confidence threshold (0.0 to 1.0)
@property (nonatomic, assign) CGFloat confidenceThreshold;

/// Enable/disable malicious packet detection
@property (nonatomic, assign) BOOL maliciousDetectionEnabled;

/// Update protocol signatures
- (BOOL)updateProtocolSignaturesWithData:(NSData *)signaturesData
                                   error:(NSError **)error;

/// Load default protocol signatures
- (BOOL)loadDefaultProtocolSignaturesWithError:(NSError **)error;

/// Save analysis results to file
- (BOOL)saveAnalysisResults:(NSArray<PacketAnalysisResult *> *)results
                      toURL:(NSURL *)url
                      error:(NSError **)error;

/// Load analysis results from file
- (NSArray<PacketAnalysisResult *> *)loadAnalysisResultsFromURL:(NSURL *)url
                                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END