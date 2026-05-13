//
//  PCAPExportService.m
//  Pipe
//

#import "PCAPExportService.h"
#import <arpa/inet.h>

/// LINKTYPE_RAW (101) — raw IPv4/IPv6 as used by Wireshark/tcpdump for IP-only captures.
static const uint32_t kPCAPLinkTypeRaw = 101;

static uint16_t IPv4Checksum(const uint8_t *header, size_t len) {
    uint32_t sum = 0;
    for (size_t i = 0; i + 1 < len; i += 2) {
        sum += (uint16_t)((header[i] << 8) | header[i + 1]);
    }
    if (len & 1) {
        sum += (uint16_t)(header[len - 1] << 8);
    }
    while (sum >> 16) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    return (uint16_t)~sum;
}

static BOOL ParseIPv4(NSString *ip, uint32_t *outHost) {
    if (!ip.length) {
        return NO;
    }
    struct in_addr addr;
    if (inet_pton(AF_INET, ip.UTF8String, &addr) == 1) {
        *outHost = addr.s_addr;
        return YES;
    }
    return NO;
}

static uint8_t IPProtocolForPacket(CapturedPacket *p) {
    switch (p.protocol) {
        case NetworkProtocolICMP: return 1;
        case NetworkProtocolTCP:
        case NetworkProtocolHTTP:
        case NetworkProtocolHTTPS:
            return 6;
        case NetworkProtocolUDP:
        case NetworkProtocolDNS:
            return 17;
        default:
            return 6;
    }
}

static NSData *SyntheticIPDatagram(CapturedPacket *p) {
    uint32_t src = 0, dst = 0;
    ParseIPv4(p.sourceIP, &src);
    ParseIPv4(p.destinationIP, &dst);

    NSData *payload = p.payload ?: [NSData data];
    uint8_t proto = IPProtocolForPacket(p);
    BOOL isUDP = (proto == 17);

    size_t l4Header = isUDP ? 8 : 20;
    size_t ipLen = 20 + l4Header + payload.length;
    NSMutableData *datagram = [NSMutableData dataWithLength:ipLen];
    uint8_t *buf = (uint8_t *)datagram.mutableBytes;

    buf[0] = 0x45;
    buf[1] = 0;
    uint16_t totalLen = (uint16_t)ipLen;
    buf[2] = (uint8_t)(totalLen >> 8);
    buf[3] = (uint8_t)(totalLen & 0xFF);
    buf[4] = buf[5] = 0;
    buf[6] = buf[7] = 0;
    buf[8] = 64;
    buf[9] = proto;
    buf[10] = buf[11] = 0;
    memcpy(buf + 12, &src, 4);
    memcpy(buf + 16, &dst, 4);

    uint16_t csum = IPv4Checksum(buf, 20);
    buf[10] = (uint8_t)(csum >> 8);
    buf[11] = (uint8_t)(csum & 0xFF);

    NSUInteger sport = p.sourcePort > 0xFFFF ? 0 : p.sourcePort;
    NSUInteger dport = p.destinationPort > 0xFFFF ? 0 : p.destinationPort;

    if (isUDP) {
        uint8_t *udp = buf + 20;
        udp[0] = (uint8_t)(sport >> 8);
        udp[1] = (uint8_t)(sport & 0xFF);
        udp[2] = (uint8_t)(dport >> 8);
        udp[3] = (uint8_t)(dport & 0xFF);
        uint16_t udpLen = (uint16_t)(8 + payload.length);
        udp[4] = (uint8_t)(udpLen >> 8);
        udp[5] = (uint8_t)(udpLen & 0xFF);
        udp[6] = udp[7] = 0;
        memcpy(udp + 8, payload.bytes, payload.length);
    } else {
        uint8_t *tcp = buf + 20;
        memset(tcp, 0, 20);
        tcp[0] = (uint8_t)(sport >> 8);
        tcp[1] = (uint8_t)(sport & 0xFF);
        tcp[2] = (uint8_t)(dport >> 8);
        tcp[3] = (uint8_t)(dport & 0xFF);
        tcp[12] = 0x50;
        if (p.metadata) {
            if (p.metadata.flags & PacketFlagSYN) tcp[13] |= 0x02;
            if (p.metadata.flags & PacketFlagACK) tcp[13] |= 0x10;
            if (p.metadata.flags & PacketFlagFIN) tcp[13] |= 0x01;
            if (p.metadata.flags & PacketFlagRST) tcp[13] |= 0x04;
            if (p.metadata.flags & PacketFlagPSH) tcp[13] |= 0x08;
        }
        memcpy(tcp + 20, payload.bytes, payload.length);
    }

    return datagram;
}

@implementation PCAPExportService

+ (NSData *)pcapDataFromPackets:(NSArray<CapturedPacket *> *)packets {
    NSMutableData *out = [NSMutableData data];
    uint32_t magic = 0xa1b2c3d4;
    uint16_t major = 2, minor = 4;
    int32_t thiszone = 0;
    uint32_t sigfigs = 0, snaplen = 0x0000ffff, network = kPCAPLinkTypeRaw;
    [out appendBytes:&magic length:4];
    [out appendBytes:&major length:2];
    [out appendBytes:&minor length:2];
    [out appendBytes:&thiszone length:4];
    [out appendBytes:&sigfigs length:4];
    [out appendBytes:&snaplen length:4];
    [out appendBytes:&network length:4];

    for (CapturedPacket *p in packets) {
        NSData *frame = SyntheticIPDatagram(p);
        NSTimeInterval ti = [p.timestamp timeIntervalSince1970];
        uint32_t sec = (uint32_t)floor(ti);
        uint32_t usec = (uint32_t)round((ti - floor(ti)) * 1e6);
        uint32_t incl = (uint32_t)frame.length;
        uint32_t orig = incl;
        [out appendBytes:&sec length:4];
        [out appendBytes:&usec length:4];
        [out appendBytes:&incl length:4];
        [out appendBytes:&orig length:4];
        [out appendData:frame];
    }
    return out;
}

+ (BOOL)exportPackets:(NSArray<CapturedPacket *> *)packets
                toURL:(NSURL *)url
                error:(NSError **)error {
    if (packets.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"PCAPExportService" code:400
                                     userInfo:@{NSLocalizedDescriptionKey: @"No packets to export"}];
        }
        return NO;
    }
    NSData *data = [self pcapDataFromPackets:packets];
    NSError *werr = nil;
    if (![data writeToURL:url options:NSDataWritingAtomic error:&werr]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PCAPExportService" code:500
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Failed to write PCAP file",
                                         NSUnderlyingErrorKey: werr
                                     }];
        }
        return NO;
    }
    return YES;
}

@end
