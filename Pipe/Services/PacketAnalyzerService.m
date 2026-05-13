//
//  PacketAnalyzerService.m
//  Pipe
//

#import "PacketAnalyzerService.h"

static NSString *const kAnalyzerDomain = @"PacketAnalyzerService";

#pragma mark - ProtocolDetectionResult

@implementation ProtocolDetectionResult

- (instancetype)initWithProtocolType:(ProtocolType)protocolType
                        protocolName:(NSString *)protocolName
                          confidence:(CGFloat)confidence
                             details:(NSDictionary *)details {
    self = [super init];
    if (self) {
        _protocolType = protocolType;
        _protocolName = [protocolName copy];
        _confidence = confidence;
        _details = [details copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"protocolType": @(self.protocolType),
        @"protocolName": self.protocolName ?: @"",
        @"confidence": @(self.confidence),
        @"details": self.details ?: @{}
    };
}

@end

#pragma mark - PacketAnalysisResult

@implementation PacketAnalysisResult

- (instancetype)initWithPacket:(CapturedPacket *)packet
            protocolDetection:(ProtocolDetectionResult *)protocolDetection
             formattedSummary:(NSString *)formattedSummary
             formattedDetails:(NSString *)formattedDetails
              extractedFields:(NSDictionary *)extractedFields
                 isMalicious:(BOOL)isMalicious
             maliciousReason:(NSString *)maliciousReason {
    self = [super init];
    if (self) {
        _packet = packet;
        _protocolDetection = protocolDetection;
        _formattedSummary = [formattedSummary copy];
        _formattedDetails = [formattedDetails copy];
        _extractedFields = [extractedFields copy];
        _isMalicious = isMalicious;
        _maliciousReason = [maliciousReason copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"packet": [self.packet toDictionary],
        @"protocolDetection": [self.protocolDetection toDictionary],
        @"formattedSummary": self.formattedSummary ?: @"",
        @"formattedDetails": self.formattedDetails ?: @"",
        @"extractedFields": self.extractedFields ?: @{},
        @"isMalicious": @(self.isMalicious),
        @"maliciousReason": self.maliciousReason ?: @""
    };
}

@end

#pragma mark - SearchOptions

@implementation SearchOptions

- (instancetype)initWithQuery:(NSString *)query
               caseSensitive:(BOOL)caseSensitive
             searchSourceIP:(BOOL)searchSourceIP
        searchDestinationIP:(BOOL)searchDestinationIP
              searchProtocol:(BOOL)searchProtocol
               searchPayload:(BOOL)searchPayload
                   startDate:(NSDate *)startDate
                     endDate:(NSDate *)endDate
                     minSize:(NSUInteger)minSize
                     maxSize:(NSUInteger)maxSize {
    self = [super init];
    if (self) {
        _query = [query copy];
        _caseSensitive = caseSensitive;
        _searchSourceIP = searchSourceIP;
        _searchDestinationIP = searchDestinationIP;
        _searchProtocol = searchProtocol;
        _searchPayload = searchPayload;
        _startDate = startDate;
        _endDate = endDate;
        _minSize = minSize;
        _maxSize = maxSize;
    }
    return self;
}

+ (instancetype)defaultOptions {
    return [[SearchOptions alloc] initWithQuery:@""
                                 caseSensitive:NO
                               searchSourceIP:YES
                          searchDestinationIP:YES
                               searchProtocol:YES
                                searchPayload:YES
                                    startDate:nil
                                      endDate:nil
                                      minSize:0
                                      maxSize:NSUIntegerMax];
}

- (NSDictionary *)toDictionary {
    return @{
        @"query": self.query ?: @"",
        @"caseSensitive": @(self.caseSensitive),
        @"searchSourceIP": @(self.searchSourceIP),
        @"searchDestinationIP": @(self.searchDestinationIP),
        @"searchProtocol": @(self.searchProtocol),
        @"searchPayload": @(self.searchPayload),
        @"startDate": self.startDate ? @([self.startDate timeIntervalSince1970]) : @0,
        @"endDate": self.endDate ? @([self.endDate timeIntervalSince1970]) : @0,
        @"minSize": @(self.minSize),
        @"maxSize": @(self.maxSize)
    };
}

@end

#pragma mark - SearchResult

@implementation SearchResult

- (instancetype)initWithAnalysisResult:(PacketAnalysisResult *)analysisResult
                        relevanceScore:(CGFloat)relevanceScore
                         matchedFields:(NSArray<NSString *> *)matchedFields
                         matchedRanges:(NSArray<NSValue *> *)matchedRanges {
    self = [super init];
    if (self) {
        _analysisResult = analysisResult;
        _relevanceScore = relevanceScore;
        _matchedFields = [matchedFields copy];
        _matchedRanges = [matchedRanges copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"analysisResult": [self.analysisResult toDictionary],
        @"relevanceScore": @(self.relevanceScore),
        @"matchedFields": self.matchedFields ?: @[],
        @"matchedRanges": self.matchedRanges ?: @[]
    };
}

@end

#pragma mark - PacketAnalyzerService

@interface PacketAnalyzerService ()

@property (nonatomic, strong) NSCache<NSUUID *, PacketAnalysisResult *> *cache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *stats;

@end

@implementation PacketAnalyzerService

+ (instancetype)sharedService {
    static PacketAnalyzerService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] initWithDelegate:nil]; });
    return s;
}

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<PacketAnalyzerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 5000;
        _stats = [NSMutableDictionary dictionary];
        _deepPacketInspectionEnabled = YES;
        _maxPayloadSize = 65536;
        _confidenceThreshold = 0.35f;
        _maliciousDetectionEnabled = YES;
    }
    return self;
}

#pragma mark - Helpers

- (NSString *)stringForNetworkProtocol:(NetworkProtocol)p {
    switch (p) {
        case NetworkProtocolTCP: return @"TCP";
        case NetworkProtocolUDP: return @"UDP";
        case NetworkProtocolHTTP: return @"HTTP";
        case NetworkProtocolHTTPS: return @"HTTPS";
        case NetworkProtocolDNS: return @"DNS";
        case NetworkProtocolICMP: return @"ICMP";
        case NetworkProtocolARP: return @"ARP";
        default: return @"Other";
    }
}

- (NSString *)asciiPrefixFromData:(NSData *)data max:(NSUInteger)max {
    if (!data.length) {
        return @"";
    }
    NSUInteger n = MIN(max, data.length);
    NSMutableString *s = [NSMutableString stringWithCapacity:n];
    const uint8_t *b = data.bytes;
    for (NSUInteger i = 0; i < n; i++) {
        uint8_t c = b[i];
        if (c >= 32 && c < 127) {
            [s appendFormat:@"%c", (char)c];
        } else {
            [s appendString:@"."];
        }
    }
    return s;
}

- (BOOL)payloadLooksLikeHTTP:(NSData *)payload {
    NSString *pre = [self asciiPrefixFromData:payload max:16];
    return [pre hasPrefix:@"GET "] || [pre hasPrefix:@"POST "] || [pre hasPrefix:@"PUT "] ||
           [pre hasPrefix:@"HEAD "] || [pre hasPrefix:@"DELETE "] || [pre hasPrefix:@"HTTP/"];
}

- (NSDictionary *)extractHTTPInfo:(CapturedPacket *)packet {
    if (!self.deepPacketInspectionEnabled || !packet.payload.length) {
        return @{};
    }
    NSData *slice = packet.payload;
    if (slice.length > self.maxPayloadSize) {
        slice = [slice subdataWithRange:NSMakeRange(0, self.maxPayloadSize)];
    }
    NSString *text = [[NSString alloc] initWithData:slice encoding:NSUTF8StringEncoding];
    if (!text.length) {
        text = [self asciiPrefixFromData:slice max:MIN(slice.length, 2048)];
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (lines.count) {
        info[@"startLine"] = lines[0];
    }
    for (NSString *line in lines) {
        NSRange r = [line rangeOfString:@":"];
        if (r.location != NSNotFound && r.location > 0) {
            NSString *key = [[line substringToIndex:r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *val = [[line substringFromIndex:NSMaxRange(r)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (key.length) {
                info[key] = val;
            }
        }
    }
    return [info copy];
}

- (NSDictionary *)extractDNSInfo:(CapturedPacket *)packet {
    if (!packet.payload.length || packet.payload.length < 12) {
        return @{};
    }
    const uint8_t *b = packet.payload.bytes;
    uint16_t flags = (uint16_t)((b[2] << 8) | b[3]);
    NSMutableDictionary *d = [@{
        @"id": @((uint16_t)((b[0] << 8) | b[1])),
        @"flags": @(flags),
        @"qdcount": @((uint16_t)((b[4] << 8) | b[5]))
    } mutableCopy];
    return [d copy];
}

- (ProtocolDetectionResult *)detectProtocol:(CapturedPacket *)packet {
    NSMutableDictionary *details = [NSMutableDictionary dictionary];
    NetworkProtocol np = packet.protocol;

    if (np == NetworkProtocolDNS || packet.destinationPort == 53 || packet.sourcePort == 53) {
        [details addEntriesFromDictionary:[self extractDNSInfo:packet]];
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeDNS
                                                        protocolName:@"DNS"
                                                          confidence:0.95
                                                             details:[details copy]];
    }
    if (np == NetworkProtocolHTTPS || packet.destinationPort == 443 || packet.sourcePort == 443) {
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeHTTPS
                                                        protocolName:@"HTTPS"
                                                          confidence:0.9
                                                             details:@{@"note": @"TLS encrypted; payload not decrypted"}];
    }
    if (np == NetworkProtocolHTTP || [self payloadLooksLikeHTTP:packet.payload]) {
        [details addEntriesFromDictionary:[self extractHTTPInfo:packet]];
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeHTTP
                                                        protocolName:@"HTTP"
                                                          confidence:0.9
                                                             details:[details copy]];
    }
    if (np == NetworkProtocolUDP) {
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeUDP
                                                        protocolName:@"UDP"
                                                          confidence:0.75
                                                             details:details];
    }
    if (np == NetworkProtocolTCP) {
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeTCP
                                                        protocolName:@"TCP"
                                                          confidence:0.75
                                                             details:details];
    }
    if (np == NetworkProtocolICMP) {
        return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeICMP
                                                        protocolName:@"ICMP"
                                                          confidence:0.8
                                                             details:details];
    }
    return [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeUnknown
                                                    protocolName:@"Unknown"
                                                      confidence:0.2
                                                         details:details];
}

- (NSString *)formatPacketForDisplay:(CapturedPacket *)packet {
    return [NSString stringWithFormat:@"%@  %@:%lu → %@:%lu  %lu bytes",
            [self stringForNetworkProtocol:packet.protocol],
            packet.sourceIP, (unsigned long)packet.sourcePort,
            packet.destinationIP, (unsigned long)packet.destinationPort,
            (unsigned long)packet.size];
}

- (NSString *)formatPacketWithDetails:(CapturedPacket *)packet {
    ProtocolDetectionResult *det = [self detectProtocol:packet];
    NSMutableString *m = [NSMutableString string];
    [m appendFormat:@"%@\n", [self formatPacketForDisplay:packet]];
    [m appendFormat:@"Time: %@\n", packet.timestamp];
    [m appendFormat:@"Detected: %@ (%.0f%%)\n", det.protocolName, det.confidence * 100];
    if (packet.headers.count) {
        [m appendString:@"Headers:\n"];
        [packet.headers enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            [m appendFormat:@"  %@: %@\n", k, v];
        }];
    }
    if (packet.payload.length) {
        NSUInteger show = MIN(packet.payload.length, self.maxPayloadSize);
        [m appendFormat:@"Payload (%lu bytes, preview):\n%@\n",
         (unsigned long)packet.payload.length,
         [self asciiPrefixFromData:[packet.payload subdataWithRange:NSMakeRange(0, show)] max:512]];
    } else {
        [m appendString:@"Payload: (empty)\n"];
    }
    if (packet.metadata) {
        [m appendFormat:@"Meta: iface=%@ dir=%ld flags=%lu seq=%ld ack=%ld\n",
         packet.metadata.interface,
         (long)packet.metadata.direction,
         (unsigned long)packet.metadata.flags,
         (long)packet.metadata.sequenceNumber,
         (long)packet.metadata.acknowledgementNumber];
    }
    return [m copy];
}

- (BOOL)isPacketMalicious:(CapturedPacket *)packet reason:(NSString *__autoreleasing *)reason {
    if (!self.maliciousDetectionEnabled) {
        if (reason) {
            *reason = nil;
        }
        return NO;
    }
    NSString *blob = [self asciiPrefixFromData:packet.payload max:4096];
    NSArray *bad = @[@"<script", @"eval(", @"base64_decode", @"cmd.exe", @"/bin/bash"];
    for (NSString *b in bad) {
        if ([blob rangeOfString:b options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (reason) {
                *reason = [NSString stringWithFormat:@"Heuristic match: %@", b];
            }
            return YES;
        }
    }
    if (reason) {
        *reason = nil;
    }
    return NO;
}

- (PacketAnalysisResult *)analyzePacket:(CapturedPacket *)packet {
    if (!packet) {
        return nil;
    }
    PacketAnalysisResult *cached = [self.cache objectForKey:packet.packetId];
    if (cached) {
        return cached;
    }
    ProtocolDetectionResult *det = [self detectProtocol:packet];
    NSString *summary = [self formatPacketForDisplay:packet];
    NSString *details = [self formatPacketWithDetails:packet];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    fields[@"protocol"] = [self stringForNetworkProtocol:packet.protocol];
    fields[@"detected"] = det.protocolName;
    if (det.protocolType == ProtocolTypeHTTP) {
        [fields addEntriesFromDictionary:[self extractHTTPInfo:packet]];
    }
    if (det.protocolType == ProtocolTypeDNS) {
        [fields addEntriesFromDictionary:[self extractDNSInfo:packet]];
    }
    NSString *malReason = nil;
    BOOL mal = [self isPacketMalicious:packet reason:&malReason];
    PacketAnalysisResult *res = [[PacketAnalysisResult alloc] initWithPacket:packet
                                                         protocolDetection:det
                                                          formattedSummary:summary
                                                          formattedDetails:details
                                                           extractedFields:[fields copy]
                                                                 isMalicious:mal
                                                             maliciousReason:malReason ?: @""];
    [self.cache setObject:res forKey:packet.packetId];

    NSString *key = det.protocolName ?: @"Unknown";
    self.stats[key] = @([self.stats[key] unsignedIntegerValue] + 1);

    if ([self.delegate respondsToSelector:@selector(packetAnalyzerDidAnalyzePacket:)]) {
        [self.delegate packetAnalyzerDidAnalyzePacket:res];
    }
    return res;
}

- (NSArray<PacketAnalysisResult *> *)analyzePackets:(NSArray<CapturedPacket *> *)packets {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:packets.count];
    for (CapturedPacket *p in packets) {
        PacketAnalysisResult *r = [self analyzePacket:p];
        if (r) {
            [out addObject:r];
        }
    }
    if ([self.delegate respondsToSelector:@selector(packetAnalyzerDidCompleteBatchAnalysis:)]) {
        [self.delegate packetAnalyzerDidCompleteBatchAnalysis:[out copy]];
    }
    return [out copy];
}

- (NSArray<SearchResult *> *)searchPackets:(NSArray<CapturedPacket *> *)packets
                               withOptions:(SearchOptions *)options {
    if (!options) {
        options = [SearchOptions defaultOptions];
    }
    NSString *q = options.query ?: @"";
    NSString *needle = options.caseSensitive ? q : q.lowercaseString;
    NSMutableArray *results = [NSMutableArray array];

    for (CapturedPacket *p in packets) {
        if (options.startDate && [p.timestamp compare:options.startDate] == NSOrderedAscending) {
            continue;
        }
        if (options.endDate && [p.timestamp compare:options.endDate] == NSOrderedDescending) {
            continue;
        }
        if (p.size < options.minSize || p.size > options.maxSize) {
            continue;
        }

        NSMutableArray *matchedFields = [NSMutableArray array];
        NSMutableArray *matchedRanges = [NSMutableArray array];
        __block CGFloat score = 0;

        if (needle.length == 0) {
            PacketAnalysisResult *ar = [self analyzePacket:p];
            [results addObject:[[SearchResult alloc] initWithAnalysisResult:ar relevanceScore:0.1
                                                            matchedFields:@[]
                                                            matchedRanges:@[]]];
            continue;
        }

        void (^hit)(NSString *, NSString *) = ^(NSString *field, NSString *hay) {
            NSString *h = options.caseSensitive ? hay : hay.lowercaseString;
            NSRange r = [h rangeOfString:needle];
            if (r.location != NSNotFound) {
                [matchedFields addObject:field];
                [matchedRanges addObject:[NSValue valueWithRange:r]];
                score += 0.25f;
            }
        };

        if (options.searchSourceIP) {
            hit(@"sourceIP", p.sourceIP ?: @"");
        }
        if (options.searchDestinationIP) {
            hit(@"destinationIP", p.destinationIP ?: @"");
        }
        if (options.searchProtocol) {
            hit(@"protocol", [self stringForNetworkProtocol:p.protocol]);
        }
        if (options.searchPayload && p.payload.length) {
            NSString *pl = [self asciiPrefixFromData:p.payload max:MIN(p.payload.length, self.maxPayloadSize)];
            hit(@"payload", pl);
        }

        if (matchedFields.count) {
            PacketAnalysisResult *ar = [self analyzePacket:p];
            [results addObject:[[SearchResult alloc] initWithAnalysisResult:ar
                                                             relevanceScore:MIN(1.0f, score)
                                                              matchedFields:[matchedFields copy]
                                                              matchedRanges:[matchedRanges copy]]];
        }
    }

    if ([self.delegate respondsToSelector:@selector(packetAnalyzerDidCompleteSearch:)]) {
        [self.delegate packetAnalyzerDidCompleteSearch:[results copy]];
    }
    return [results copy];
}

- (NSDictionary *)analysisStatistics {
    return [self.stats copy];
}

- (BOOL)clearAnalysisCacheWithError:(NSError **)error {
    [self.cache removeAllObjects];
    [self.stats removeAllObjects];
    return YES;
}

- (BOOL)updateProtocolSignaturesWithData:(NSData *)signaturesData error:(NSError **)error {
    return signaturesData != nil;
}

- (BOOL)loadDefaultProtocolSignaturesWithError:(NSError **)error {
    return YES;
}

- (BOOL)saveAnalysisResults:(NSArray<PacketAnalysisResult *> *)results
                      toURL:(NSURL *)url
                      error:(NSError **)error {
    NSMutableArray *arr = [NSMutableArray array];
    for (PacketAnalysisResult *r in results) {
        [arr addObject:[r toDictionary]];
    }
    NSError *je = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:&je];
    if (!d) {
        if (error) {
            *error = [NSError errorWithDomain:kAnalyzerDomain code:500 userInfo:@{NSLocalizedDescriptionKey: @"JSON error", NSUnderlyingErrorKey: je}];
        }
        return NO;
    }
    return [d writeToURL:url options:NSDataWritingAtomic error:error];
}

- (NSArray<PacketAnalysisResult *> *)loadAnalysisResultsFromURL:(NSURL *)url error:(NSError **)error {
    NSData *d = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!d) {
        return nil;
    }
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:error];
    if (![obj isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:kAnalyzerDomain code:422 userInfo:@{NSLocalizedDescriptionKey: @"Invalid analysis file"}];
        }
        return nil;
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *dict in (NSArray *)obj) {
        NSDictionary *pd = dict[@"packet"];
        if (![pd isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        CapturedPacket *p = [CapturedPacket fromDictionary:pd];
        if (!p) {
            continue;
        }
        ProtocolDetectionResult *det = [[ProtocolDetectionResult alloc] initWithProtocolType:ProtocolTypeUnknown
                                                                                protocolName:dict[@"protocolDetection"][@"protocolName"] ?: @"Unknown"
                                                                                  confidence:1
                                                                                     details:@{}];
        PacketAnalysisResult *r = [[PacketAnalysisResult alloc] initWithPacket:p
                                                             protocolDetection:det
                                                              formattedSummary:dict[@"formattedSummary"] ?: @""
                                                              formattedDetails:dict[@"formattedDetails"] ?: @""
                                                               extractedFields:dict[@"extractedFields"] ?: @{}
                                                                     isMalicious:[dict[@"isMalicious"] boolValue]
                                                                 maliciousReason:dict[@"maliciousReason"] ?: @""];
        [out addObject:r];
    }
    return [out copy];
}

@end
