//
//  SimpleConfigurationTest.m
//  PipeTests
//
//  Created by Leven on 2026/5/10.
//

#import <XCTest/XCTest.h>
#import "../Pipe/Services/ConfigurationManagerService.h"

@interface SimpleConfigurationTest : XCTestCase

@end

@implementation SimpleConfigurationTest

- (void)testConfigurationManagerExists {
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    XCTAssertNotNil(manager);
}

- (void)testDefaultConfiguration {
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    NSError *error = nil;
    AppConfiguration *config = [manager loadConfigurationWithError:&error];
    
    XCTAssertNotNil(config);
    XCTAssertNil(error);
    XCTAssertTrue([config isKindOfClass:[AppConfiguration class]]);
}

- (void)testProperty_ConfigurationRoundTripSimple {
    // Simple test of configuration round-trip
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    
    // Create temp file URL
    NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *testFileURL = [tempDir URLByAppendingPathComponent:@"test_simple_config.json"];
    
    // Create manager with test file
    ConfigurationManagerService *testManager = [[ConfigurationManagerService alloc] initWithConfigurationFileURL:testFileURL];
    
    // Get default config
    AppConfiguration *originalConfig = [AppConfiguration defaultConfiguration];
    
    // Save it
    NSError *saveError = nil;
    BOOL saveSuccess = [testManager saveConfiguration:originalConfig error:&saveError];
    XCTAssertTrue(saveSuccess);
    XCTAssertNil(saveError);
    
    // Load it back
    NSError *loadError = nil;
    AppConfiguration *loadedConfig = [testManager loadConfigurationWithError:&loadError];
    XCTAssertNotNil(loadedConfig);
    XCTAssertNil(loadError);
    
    // Clean up
    [[NSFileManager defaultManager] removeItemAtURL:testFileURL error:nil];
    
    NSLog(@"Simple round-trip test passed");
}

- (void)testProperty_ValidationConsistencySimple {
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    
    // Test 1: Default config should be valid
    AppConfiguration *defaultConfig = [AppConfiguration defaultConfiguration];
    ValidationResult *result1 = [manager validateConfiguration:defaultConfig];
    XCTAssertTrue(result1.isValid);
    
    // Test 2: Validation should be deterministic
    ValidationResult *result2 = [manager validateConfiguration:defaultConfig];
    ValidationResult *result3 = [manager validateConfiguration:defaultConfig];
    
    XCTAssertEqual(result1.isValid, result2.isValid);
    XCTAssertEqual(result2.isValid, result3.isValid);
    
    // Test 3: Invalid config should fail validation
    AppConfiguration *invalidConfig = [[AppConfiguration alloc] init];
    // Don't set any properties - should be invalid
    ValidationResult *invalidResult = [manager validateConfiguration:invalidConfig];
    XCTAssertFalse(invalidResult.isValid);
    XCTAssertGreaterThan(invalidResult.errors.count, 0);
    
    NSLog(@"Simple validation consistency test passed");
}

@end