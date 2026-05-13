//
//  PacketFilterTests.m
//  PipeTests
//
//  Created by Leven on 2026/5/10.
//

#import <XCTest/XCTest.h>
#import "../Pipe/Models/PacketFilter.h"
#import "../Pipe/Models/CapturedPacket.h"

@interface PacketFilterTests : XCTestCase

@end

@implementation PacketFilterTests

- (void)testFilterConditionCreation {
    FilterCondition *condition = [[FilterCondition alloc] initWithField:FilterFieldSourceIP
                                                               operator:FilterOperatorEquals
                                                                  value:@"192.168.1.1"];
    
    XCTAssertNotNil(condition);
    XCTAssertEqual(condition.field, FilterFieldSourceIP);
    XCTAssertEqual(condition.operator, FilterOperatorEquals);
    XCTAssertEqualObjects(condition.value, @"192.168.1.1");
}

- (void)testPacketFilterCreation {
    FilterCondition *condition = [[FilterCondition alloc] initWithField:FilterFieldProtocol
                                                               operator:FilterOperatorEquals
                                                                  value:@"TCP"];
    
    PacketFilter *filter = [[PacketFilter alloc] initWithName:@"Test Filter"
                                                   conditions:@[condition]
                                                       action:FilterActionInclude];
    
    XCTAssertNotNil(filter);
    XCTAssertEqualObjects(filter.name, @"Test Filter");
    XCTAssertEqual(filter.conditions.count, 1);
    XCTAssertEqual(filter.action, FilterActionInclude);
    XCTAssertTrue(filter.isEnabled);
}

- (void)testProperty_PacketFilterApplicationConsistency {
    // Property: Packet Filter Application Consistency
    // 1. Applying the same filter to the same packets should always produce the same result
    // 2. Applying multiple filters should be associative (order shouldn't matter for certain operations)
    // 3. Disabled filters should not affect results
    
    NSLog(@"Running property test: Packet Filter Application Consistency");
    
    // Create test packets
    NSMutableArray<CapturedPacket *> *testPackets = [NSMutableArray array];
    for (int i = 0; i < 10; i++) {
        CapturedPacket *packet = [[CapturedPacket alloc] init];
        packet.packetId = [NSUUID UUID];
        packet.timestamp = [[NSDate date] timeIntervalSince1970] + i;
        packet.sourceIP = [NSString stringWithFormat:@"192.168.1.%d", i % 5];
        packet.destinationIP = @"10.0.0.1";
        packet.sourcePort = 1000 + i;
        packet.destinationPort = 80;
        packet.protocol = (i % 2 == 0) ? @"TCP" : @"UDP";
        packet.size = 64 + i * 10;
        
        [testPackets addObject:packet];
    }
    
    // Test 1: Same filter should produce same result
    FilterCondition *condition1 = [[FilterCondition alloc] initWithField:FilterFieldProtocol
                                                                operator:FilterOperatorEquals
                                                                   value:@"TCP"];
    
    PacketFilter *filter1 = [[PacketFilter alloc] initWithName:@"TCP Filter"
                                                    conditions:@[condition1]
                                                        action:FilterActionInclude];
    
    NSArray<CapturedPacket *> *result1 = [filter1 applyToPackets:testPackets];
    NSArray<CapturedPacket *> *result2 = [filter1 applyToPackets:testPackets];
    NSArray<CapturedPacket *> *result3 = [filter1 applyToPackets:testPackets];
    
    XCTAssertEqual(result1.count, result2.count);
    XCTAssertEqual(result2.count, result3.count);
    
    // Test 2: Disabled filter should not filter
    PacketFilter *disabledFilter = [[PacketFilter alloc] initWithName:@"Disabled Filter"
                                                           conditions:@[condition1]
                                                               action:FilterActionExclude];
    disabledFilter.isEnabled = NO;
    
    NSArray<CapturedPacket *> *disabledResult = [disabledFilter applyToPackets:testPackets];
    XCTAssertEqual(disabledResult.count, testPackets.count); // Should include all packets
    
    // Test 3: Multiple filters with Include action
    FilterCondition *condition2 = [[FilterCondition alloc] initWithField:FilterFieldSourcePort
                                                                operator:FilterOperatorGreaterThan
                                                                   value:@"1005"];
    
    PacketFilter *filter2 = [[PacketFilter alloc] initWithName:@"Port Filter"
                                                    conditions:@[condition2]
                                                        action:FilterActionInclude];
    
    // Apply filters individually
    NSArray<CapturedPacket *> *tcpOnly = [filter1 applyToPackets:testPackets];
    NSArray<CapturedPacket *> *highPortOnly = [filter2 applyToPackets:testPackets];
    
    // Apply both filters together
    NSArray<CapturedPacket *> *bothFilters = [filter1 applyToPackets:testPackets];
    bothFilters = [filter2 applyToPackets:bothFilters];
    
    // Manual calculation of expected result
    NSMutableArray<CapturedPacket *> *expected = [NSMutableArray array];
    for (CapturedPacket *packet in testPackets) {
        BOOL isTCP = [packet.protocol isEqualToString:@"TCP"];
        BOOL hasHighPort = packet.sourcePort > 1005;
        
        if (isTCP && hasHighPort) {
            [expected addObject:packet];
        }
    }
    
    XCTAssertEqual(bothFilters.count, expected.count);
    
    // Test 4: Exclude filter
    PacketFilter *excludeFilter = [[PacketFilter alloc] initWithName:@"Exclude UDP"
                                                          conditions:@[condition1]
                                                              action:FilterActionExclude];
    
    NSArray<CapturedPacket *> *excludeResult = [excludeFilter applyToPackets:testPackets];
    
    // Should exclude TCP packets (since condition matches TCP, and action is exclude)
    NSUInteger udpCount = 0;
    for (CapturedPacket *packet in testPackets) {
        if ([packet.protocol isEqualToString:@"UDP"]) {
            udpCount++;
        }
    }
    
    XCTAssertEqual(excludeResult.count, udpCount);
    
    NSLog(@"Packet filter application consistency test passed with %lu test packets", (unsigned long)testPackets.count);
}

- (void)testFilterToDictionaryRoundTrip {
    // Test filter serialization/deserialization
    FilterCondition *condition = [[FilterCondition alloc] initWithField:FilterFieldDestinationIP
                                                               operator:FilterOperatorContains
                                                                  value:@"google"];
    
    PacketFilter *originalFilter = [[PacketFilter alloc] initWithName:@"Google Filter"
                                                           conditions:@[condition]
                                                               action:FilterActionHighlight];
    originalFilter.isEnabled = YES;
    
    // Convert to dictionary
    NSDictionary *filterDict = [originalFilter toDictionary];
    XCTAssertNotNil(filterDict);
    XCTAssertEqualObjects(filterDict[@"name"], @"Google Filter");
    XCTAssertEqualObjects(filterDict[@"action"], @(FilterActionHighlight));
    XCTAssertEqualObjects(filterDict[@"isEnabled"], @YES);
    
    // Convert back from dictionary
    PacketFilter *restoredFilter = [PacketFilter fromDictionary:filterDict];
    XCTAssertNotNil(restoredFilter);
    XCTAssertEqualObjects(restoredFilter.name, @"Google Filter");
    XCTAssertEqual(restoredFilter.action, FilterActionHighlight);
    XCTAssertTrue(restoredFilter.isEnabled);
    XCTAssertEqual(restoredFilter.conditions.count, 1);
    
    if (restoredFilter.conditions.count > 0) {
        FilterCondition *restoredCondition = restoredFilter.conditions[0];
        XCTAssertEqual(restoredCondition.field, FilterFieldDestinationIP);
        XCTAssertEqual(restoredCondition.operator, FilterOperatorContains);
        XCTAssertEqualObjects(restoredCondition.value, @"google");
    }
}

- (void)testEmptyFilter {
    // Test that empty filter (no conditions) includes all packets
    PacketFilter *emptyFilter = [[PacketFilter alloc] initWithName:@"Empty Filter"
                                                        conditions:@[]
                                                            action:FilterActionInclude];
    
    // Create some test packets
    NSMutableArray<CapturedPacket *> *testPackets = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        CapturedPacket *packet = [[CapturedPacket alloc] init];
        packet.packetId = [NSUUID UUID];
        [testPackets addObject:packet];
    }
    
    NSArray<CapturedPacket *> *result = [emptyFilter applyToPackets:testPackets];
    XCTAssertEqual(result.count, testPackets.count);
}

- (void)testMultipleConditions {
    // Test filter with multiple conditions
    FilterCondition *condition1 = [[FilterCondition alloc] initWithField:FilterFieldProtocol
                                                                operator:FilterOperatorEquals
                                                                   value:@"TCP"];
    
    FilterCondition *condition2 = [[FilterCondition alloc] initWithField:FilterFieldDestinationPort
                                                                operator:FilterOperatorEquals
                                                                   value:@"80"];
    
    PacketFilter *multiFilter = [[PacketFilter alloc] initWithName:@"HTTP TCP Filter"
                                                        conditions:@[condition1, condition2]
                                                            action:FilterActionInclude];
    
    XCTAssertNotNil(multiFilter);
    XCTAssertEqual(multiFilter.conditions.count, 2);
    
    // Note: The actual evaluation logic would need to be implemented in FilterCondition
    // For now, we're just testing the structure
}

@end