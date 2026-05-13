//
//  ConfigurationManagerTests.m
//  PipeTests
//
//  Created by Leven on 2026/5/10.
//

#import <XCTest/XCTest.h>
#import "../Pipe/Services/ConfigurationManagerService.h"
#import "../Pipe/Models/AppConfiguration.h"
#import "../Pipe/Models/VPNConfiguration.h"

@interface ConfigurationManagerTests : XCTestCase

@property (nonatomic, strong) ConfigurationManagerService *configurationManager;
@property (nonatomic, strong) NSURL *testConfigurationFileURL;

@end

@implementation ConfigurationManagerTests

- (void)setUp {
    [super setUp];
    
    // Create a temporary file URL for testing
    NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    self.testConfigurationFileURL = [tempDir URLByAppendingPathComponent:@"test_configuration.json"];
    
    // Create configuration manager with test file URL
    self.configurationManager = [[ConfigurationManagerService alloc] initWithConfigurationFileURL:self.testConfigurationFileURL];
}

- (void)tearDown {
    // Clean up test file
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.testConfigurationFileURL.path]) {
        [fileManager removeItemAtURL:self.testConfigurationFileURL error:nil];
    }
    
    self.configurationManager = nil;
    self.testConfigurationFileURL = nil;
    
    [super tearDown];
}

#pragma mark - Basic Tests

- (void)testDefaultConfigurationCreation {
    // When: Loading configuration from non-existent file
    NSError *error = nil;
    AppConfiguration *config = [self.configurationManager loadConfigurationWithError:&error];
    
    // Then: Should return default configuration
    XCTAssertNotNil(config);
    XCTAssertNil(error);
    XCTAssertTrue([config isKindOfClass:[AppConfiguration class]]);
    
    // Verify default values
    XCTAssertNotNil(config.captureSettings);
    XCTAssertNotNil(config.vpnSettings);
    XCTAssertNotNil(config.uiSettings);
    XCTAssertNotNil(config.exportSettings);
    XCTAssertNotNil(config.privacySettings);
    
    XCTAssertEqual(config.captureSettings.defaultBufferSize, 65536);
    XCTAssertEqual(config.uiSettings.language, AppLanguageEnglish);
    XCTAssertEqual(config.vpnSettings.defaultProtocol, VPNProtocolWireGuard);
    XCTAssertEqual(config.exportSettings.defaultFormat, ExportFormatPCAP);
    XCTAssertTrue(config.privacySettings.encryptStorage);
}

- (void)testConfigurationSaveAndLoad {
    // Given: A custom configuration
    AppConfiguration *originalConfig = [AppConfiguration defaultConfiguration];
    
    // Modify some values
    originalConfig.captureSettings.defaultBufferSize = 131072;
    originalConfig.uiSettings.language = @"zh";
    originalConfig.uiSettings.refreshRate = 2.0;
    originalConfig.vpnSettings.defaultProtocol = @"OpenVPN";
    originalConfig.exportSettings.defaultFormat = @"json";
    originalConfig.privacySettings.encryptStorage = NO;
    
    // When: Saving configuration
    NSError *saveError = nil;
    BOOL saveSuccess = [self.configurationManager saveConfiguration:originalConfig error:&saveError];
    
    // Then: Save should succeed
    XCTAssertTrue(saveSuccess);
    XCTAssertNil(saveError);
    
    // When: Loading configuration back
    NSError *loadError = nil;
    AppConfiguration *loadedConfig = [self.configurationManager loadConfigurationWithError:&loadError];
    
    // Then: Load should succeed and match original
    XCTAssertNotNil(loadedConfig);
    XCTAssertNil(loadError);
    
    // Verify values match
    XCTAssertEqual(loadedConfig.captureSettings.defaultBufferSize, 131072);
    XCTAssertEqualObjects(loadedConfig.uiSettings.language, @"zh");
    XCTAssertEqual(loadedConfig.uiSettings.refreshRate, 2.0);
    XCTAssertEqualObjects(loadedConfig.vpnSettings.defaultProtocol, @"OpenVPN");
    XCTAssertEqualObjects(loadedConfig.exportSettings.defaultFormat, @"json");
    XCTAssertFalse(loadedConfig.privacySettings.encryptStorage);
}

- (void)testConfigurationValidation {
    // Given: A valid configuration
    AppConfiguration *validConfig = [AppConfiguration defaultConfiguration];
    
    // When: Validating configuration
    ValidationResult *validationResult = [self.configurationManager validateConfiguration:validConfig];
    
    // Then: Should be valid
    XCTAssertTrue(validationResult.isValid);
    XCTAssertEqual(validationResult.errors.count, 0);
    
    // Given: An invalid configuration (missing required fields)
    AppConfiguration *invalidConfig = [[AppConfiguration alloc] init];
    // Don't set any properties
    
    // When: Validating invalid configuration
    ValidationResult *invalidResult = [self.configurationManager validateConfiguration:invalidConfig];
    
    // Then: Should be invalid with errors
    XCTAssertFalse(invalidResult.isValid);
    XCTAssertGreaterThan(invalidResult.errors.count, 0);
    
    // Given: Configuration with invalid values
    AppConfiguration *badValueConfig = [AppConfiguration defaultConfiguration];
    badValueConfig.captureSettings.defaultBufferSize = 0; // Invalid: must be > 0
    badValueConfig.uiSettings.refreshRate = 0.05; // Invalid: must be >= 0.1
    
    // When: Validating configuration with bad values
    ValidationResult *badValueResult = [self.configurationManager validateConfiguration:badValueConfig];
    
    // Then: Should be invalid
    XCTAssertFalse(badValueResult.isValid);
    XCTAssertGreaterThan(badValueResult.errors.count, 0);
}

- (void)testConfigurationResetToDefaults {
    // Given: A modified configuration
    AppConfiguration *modifiedConfig = [AppConfiguration defaultConfiguration];
    modifiedConfig.captureSettings.defaultBufferSize = 999999;
    modifiedConfig.uiSettings.language = @"ja";
    
    // Save modified configuration
    NSError *saveError = nil;
    [self.configurationManager saveConfiguration:modifiedConfig error:&saveError];
    XCTAssertNil(saveError);
    
    // When: Resetting to defaults
    NSError *resetError = nil;
    BOOL resetSuccess = [self.configurationManager resetToDefaultsWithError:&resetError];
    
    // Then: Reset should succeed
    XCTAssertTrue(resetSuccess);
    XCTAssertNil(resetError);
    
    // When: Loading configuration after reset
    NSError *loadError = nil;
    AppConfiguration *resetConfig = [self.configurationManager loadConfigurationWithError:&loadError];
    
    // Then: Should have default values
    XCTAssertNotNil(resetConfig);
    XCTAssertNil(loadError);
    XCTAssertEqual(resetConfig.captureSettings.defaultBufferSize, 65536); // Default value
    XCTAssertEqualObjects(resetConfig.uiSettings.language, @"en"); // Default value
}

#pragma mark - Property-Based Testing (Manual Implementation)

- (void)testProperty_ConfigurationRoundTripIntegrity {
    // Property: Configuration Round-Trip Integrity
    // For any valid AppConfiguration, saving it and loading it back should produce an equivalent configuration
    
    NSLog(@"Running property test: Configuration Round-Trip Integrity");
    
    // Test with multiple configurations
    for (int i = 0; i < 10; i++) {
        @autoreleasepool {
            // Create a random configuration
            AppConfiguration *originalConfig = [self generateRandomConfiguration];
            
            // Validate it's a valid configuration
            ValidationResult *validationResult = [self.configurationManager validateConfiguration:originalConfig];
            if (!validationResult.isValid) {
                // Skip invalid configurations for this test
                continue;
            }
            
            // Save configuration
            NSError *saveError = nil;
            BOOL saveSuccess = [self.configurationManager saveConfiguration:originalConfig error:&saveError];
            XCTAssertTrue(saveSuccess, @"Failed to save configuration on iteration %d: %@", i, saveError);
            XCTAssertNil(saveError, @"Save error on iteration %d: %@", i, saveError);
            
            // Load configuration back
            NSError *loadError = nil;
            AppConfiguration *loadedConfig = [self.configurationManager loadConfigurationWithError:&loadError];
            XCTAssertNotNil(loadedConfig, @"Failed to load configuration on iteration %d: %@", i, loadError);
            XCTAssertNil(loadError, @"Load error on iteration %d: %@", i, loadError);
            
            // Compare configurations
            [self assertConfigurationsEqual:originalConfig loadedConfig:loadedConfig iteration:i];
        }
    }
}

- (void)testProperty_ConfigurationValidationConsistency {
    // Property: Configuration Validation Consistency
    // 1. Any configuration that passes validation should be saveable and loadable
    // 2. Any configuration that fails validation should not be saveable
    // 3. Validation results should be deterministic (same configuration always gets same result)
    
    NSLog(@"Running property test: Configuration Validation Consistency");
    
    // Test 1: Valid configurations should be saveable and loadable
    for (int i = 0; i < 5; i++) {
        @autoreleasepool {
            // Create a valid configuration
            AppConfiguration *validConfig = [AppConfiguration defaultConfiguration];
            
            // Modify with valid values
            validConfig.captureSettings.defaultBufferSize = 1024 + arc4random_uniform(1047552); // 1024-1048576
            validConfig.uiSettings.refreshRate = 0.1 + (arc4random_uniform(100) / 10.0); // 0.1-10.0
            
            // Validate
            ValidationResult *validationResult = [self.configurationManager validateConfiguration:validConfig];
            XCTAssertTrue(validationResult.isValid, @"Configuration should be valid on iteration %d", i);
            
            // Save should succeed
            NSError *saveError = nil;
            BOOL saveSuccess = [self.configurationManager saveConfiguration:validConfig error:&saveError];
            XCTAssertTrue(saveSuccess, @"Valid configuration should be saveable on iteration %d: %@", i, saveError);
            XCTAssertNil(saveError, @"Save error on iteration %d: %@", i, saveError);
            
            // Load should succeed
            NSError *loadError = nil;
            AppConfiguration *loadedConfig = [self.configurationManager loadConfigurationWithError:&loadError];
            XCTAssertNotNil(loadedConfig, @"Valid configuration should be loadable on iteration %d: %@", i, loadError);
            XCTAssertNil(loadError, @"Load error on iteration %d: %@", i, loadError);
        }
    }
    
    // Test 2: Invalid configurations should not be saveable
    for (int i = 0; i < 5; i++) {
        @autoreleasepool {
            // Create an invalid configuration
            AppConfiguration *invalidConfig = [self generateInvalidConfiguration];
            
            // Validate
            ValidationResult *validationResult = [self.configurationManager validateConfiguration:invalidConfig];
            XCTAssertFalse(validationResult.isValid, @"Configuration should be invalid on iteration %d", i);
            
            // Save should fail
            NSError *saveError = nil;
            BOOL saveSuccess = [self.configurationManager saveConfiguration:invalidConfig error:&saveError];
            XCTAssertFalse(saveSuccess, @"Invalid configuration should not be saveable on iteration %d", i);
            XCTAssertNotNil(saveError, @"Should have error when saving invalid configuration on iteration %d", i);
        }
    }
    
    // Test 3: Validation should be deterministic
    AppConfiguration *testConfig = [AppConfiguration defaultConfiguration];
    testConfig.captureSettings.defaultBufferSize = 50000;
    testConfig.uiSettings.refreshRate = 0.05;
    
    // Validate multiple times
    ValidationResult *result1 = [self.configurationManager validateConfiguration:testConfig];
    ValidationResult *result2 = [self.configurationManager validateConfiguration:testConfig];
    ValidationResult *result3 = [self.configurationManager validateConfiguration:testConfig];
    
    // Results should be identical
    XCTAssertEqual(result1.isValid, result2.isValid);
    XCTAssertEqual(result2.isValid, result3.isValid);
    XCTAssertEqual(result1.errors.count, result2.errors.count);
    XCTAssertEqual(result2.errors.count, result3.errors.count);
    
    // Error messages should be the same (order may vary, so check sets)
    NSSet *errors1 = [NSSet setWithArray:result1.errors];
    NSSet *errors2 = [NSSet setWithArray:result2.errors];
    NSSet *errors3 = [NSSet setWithArray:result3.errors];
    
    XCTAssertEqualObjects(errors1, errors2);
    XCTAssertEqualObjects(errors2, errors3);
}

#pragma mark - JSON Import/Export Tests

- (void)testJSONImportExport {
    // Given: A configuration
    AppConfiguration *originalConfig = [AppConfiguration defaultConfiguration];
    originalConfig.captureSettings.defaultBufferSize = 32768;
    originalConfig.uiSettings.language = @"es";
    originalConfig.vpnSettings.defaultProtocol = @"IKEv2";
    
    // When: Exporting to JSON data
    NSError *exportError = nil;
    NSData *jsonData = [self.configurationManager exportConfigurationToJSONData:originalConfig error:&exportError];
    
    // Then: Export should succeed
    XCTAssertNotNil(jsonData);
    XCTAssertNil(exportError);
    
    // When: Importing from JSON data
    NSError *importError = nil;
    AppConfiguration *importedConfig = [self.configurationManager importConfigurationFromJSONData:jsonData error:&importError];
    
    // Then: Import should succeed and match original
    XCTAssertNotNil(importedConfig);
    XCTAssertNil(importError);
    
    // Verify values match
    XCTAssertEqual(importedConfig.captureSettings.defaultBufferSize, 32768);
    XCTAssertEqualObjects(importedConfig.uiSettings.language, @"es");
    XCTAssertEqualObjects(importedConfig.vpnSettings.defaultProtocol, @"IKEv2");
}

- (void)testInvalidJSONImport {
    // Given: Invalid JSON data
    NSString *invalidJSON = @"{not valid json}";
    NSData *invalidData = [invalidJSON dataUsingEncoding:NSUTF8StringEncoding];
    
    // When: Importing invalid JSON
    NSError *importError = nil;
    AppConfiguration *config = [self.configurationManager importConfigurationFromJSONData:invalidData error:&importError];
    
    // Then: Should fail
    XCTAssertNil(config);
    XCTAssertNotNil(importError);
}

#pragma mark - Encryption Tests

- (void)testEncryptionRoundTrip {
    // Given: A configuration with encryption enabled
    AppConfiguration *originalConfig = [AppConfiguration defaultConfiguration];
    originalConfig.privacySettings.encryptStorage = YES;
    originalConfig.captureSettings.defaultBufferSize = 8192;
    originalConfig.uiSettings.language = @"fr";
    
    // When: Saving with encryption
    NSError *saveError = nil;
    BOOL saveSuccess = [self.configurationManager saveConfiguration:originalConfig error:&saveError];
    
    // Then: Save should succeed
    XCTAssertTrue(saveSuccess);
    XCTAssertNil(saveError);
    
    // Verify file exists and has content
    NSFileManager *fileManager = [NSFileManager defaultManager];
    XCTAssertTrue([fileManager fileExistsAtPath:self.testConfigurationFileURL.path]);
    
    NSData *fileData = [NSData dataWithContentsOfURL:self.testConfigurationFileURL];
    XCTAssertNotNil(fileData);
    XCTAssertGreaterThan(fileData.length, 0);
    
    // File should be encrypted (not plain JSON)
    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&jsonError];
    XCTAssertNotNil(jsonError); // Should fail to parse as JSON
    
    // When: Loading encrypted configuration
    NSError *loadError = nil;
    AppConfiguration *loadedConfig = [self.configurationManager loadConfigurationWithError:&loadError];
    
    // Then: Load should succeed and match original
    XCTAssertNotNil(loadedConfig);
    XCTAssertNil(loadError);
    
    XCTAssertEqual(loadedConfig.captureSettings.defaultBufferSize, 8192);
    XCTAssertEqualObjects(loadedConfig.uiSettings.language, @"fr");
    XCTAssertTrue(loadedConfig.privacySettings.encryptStorage);
}

- (void)testNoEncryptionRoundTrip {
    // Given: A configuration with encryption disabled
    AppConfiguration *originalConfig = [AppConfiguration defaultConfiguration];
    originalConfig.privacySettings.encryptStorage = NO;
    originalConfig.captureSettings.defaultBufferSize = 16384;
    originalConfig.uiSettings.language = @"ja";
    
    // When: Saving without encryption
    NSError *saveError = nil;
    BOOL saveSuccess = [self.configurationManager saveConfiguration:originalConfig error:&saveError];
    
    // Then: Save should succeed
    XCTAssertTrue(saveSuccess);
    XCTAssertNil(saveError);
    
    // Verify file exists and is plain JSON
    NSFileManager *fileManager = [NSFileManager defaultManager];
    XCTAssertTrue([fileManager fileExistsAtPath:self.testConfigurationFileURL.path]);
    
    NSData *fileData = [NSData dataWithContentsOfURL:self.testConfigurationFileURL];
    XCTAssertNotNil(fileData);
    
    // File should be plain JSON
    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&jsonError];
    XCTAssertNotNil(jsonObject);
    XCTAssertNil(jsonError);
    XCTAssertTrue([jsonObject isKindOfClass:[NSDictionary class]]);
    
    // When: Loading plain configuration
    NSError *loadError = nil;
    AppConfiguration *loadedConfig = [self.configurationManager loadConfigurationWithError:&loadError];
    
    // Then: Load should succeed and match original
    XCTAssertNotNil(loadedConfig);
    XCTAssertNil(loadError);
    
    XCTAssertEqual(loadedConfig.captureSettings.defaultBufferSize, 16384);
    XCTAssertEqualObjects(loadedConfig.uiSettings.language, @"ja");
    XCTAssertFalse(loadedConfig.privacySettings.encryptStorage);
}

#pragma mark - Helper Methods

- (AppConfiguration *)generateRandomConfiguration {
    AppConfiguration *config = [AppConfiguration defaultConfiguration];
    
    // Randomize values within valid ranges
    config.captureSettings.defaultBufferSize = 1024 + arc4random_uniform(1047552); // 1024-1048576
    config.captureSettings.autoStartOnLaunch = arc4random_uniform(2) == 1;
    
    // Random language
    NSArray *languages = @[@"en", @"zh", @"ja", @"es", @"fr"];
    config.uiSettings.language = languages[arc4random_uniform((uint32_t)languages.count)];
    
    config.uiSettings.refreshRate = 0.1 + (arc4random_uniform(100) / 10.0); // 0.1-10.0
    config.uiSettings.theme = @[@"light", @"dark", @"system"][arc4random_uniform(3)];
    config.uiSettings.showAdvancedOptions = arc4random_uniform(2) == 1;
    
    // Random VPN protocol
    NSArray *protocols = @[@"WireGuard", @"OpenVPN", @"IKEv2"];
    config.vpnSettings.defaultProtocol = protocols[arc4random_uniform((uint32_t)protocols.count)];
    config.vpnSettings.autoReconnect = arc4random_uniform(2) == 1;
    config.vpnSettings.killSwitch = arc4random_uniform(2) == 1;
    config.vpnSettings.dnsLeakProtection = arc4random_uniform(2) == 1;
    
    // Random export format
    NSArray *formats = @[@"pcap", @"json", @"csv"];
    config.exportSettings.defaultFormat = formats[arc4random_uniform((uint32_t)formats.count)];
    config.exportSettings.compression = arc4random_uniform(2) == 1;
    config.exportSettings.includeMetadata = arc4random_uniform(2) == 1;
    
    config.privacySettings.encryptStorage = arc4random_uniform(2) == 1;
    config.privacySettings.clearOnClose = arc4random_uniform(2) == 1;
    config.privacySettings.anonymizeIPs = arc4random_uniform(2) == 1;
    
    return config;
}

- (AppConfiguration *)generateInvalidConfiguration {
    AppConfiguration *config = [[AppConfiguration alloc] init];
    
    // Create invalid values
    if (arc4random_uniform(2) == 1) {
        // Sometimes create a partially valid config
        config.captureSettings = [[CaptureSettings alloc] init];
        config.captureSettings.defaultBufferSize = 0; // Invalid
    }
    
    if (arc4random_uniform(2) == 1) {
        config.uiSettings = [[UISettings alloc] init];
        config.uiSettings.refreshRate = -1.0; // Invalid
        config.uiSettings.language = AppLanguageEnglish; // This will be converted to string
    }
    
    // Sometimes don't set required fields at all
    return config;
}

- (void)assertConfigurationsEqual:(AppConfiguration *)originalConfig loadedConfig:(AppConfiguration *)loadedConfig iteration:(int)iteration {
    // Compare all properties
    XCTAssertEqual(originalConfig.captureSettings.defaultBufferSize, loadedConfig.captureSettings.defaultBufferSize,
                  @"Buffer size mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.captureSettings.autoStartOnLaunch, loadedConfig.captureSettings.autoStartOnLaunch,
                  @"Auto start mismatch on iteration %d", iteration);
    
    XCTAssertEqualObjects(originalConfig.uiSettings.language, loadedConfig.uiSettings.language,
                         @"Language mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.uiSettings.refreshRate, loadedConfig.uiSettings.refreshRate,
                  @"Refresh rate mismatch on iteration %d", iteration);
    XCTAssertEqualObjects(originalConfig.uiSettings.theme, loadedConfig.uiSettings.theme,
                         @"Theme mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.uiSettings.showAdvancedOptions, loadedConfig.uiSettings.showAdvancedOptions,
                  @"Show advanced options mismatch on iteration %d", iteration);
    
    XCTAssertEqualObjects(originalConfig.vpnSettings.defaultProtocol, loadedConfig.vpnSettings.defaultProtocol,
                         @"VPN protocol mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.vpnSettings.autoReconnect, loadedConfig.vpnSettings.autoReconnect,
                  @"Auto reconnect mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.vpnSettings.killSwitch, loadedConfig.vpnSettings.killSwitch,
                  @"Kill switch mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.vpnSettings.dnsLeakProtection, loadedConfig.vpnSettings.dnsLeakProtection,
                  @"DNS leak protection mismatch on iteration %d", iteration);
    
    XCTAssertEqualObjects(originalConfig.exportSettings.defaultFormat, loadedConfig.exportSettings.defaultFormat,
                         @"Export format mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.exportSettings.compression, loadedConfig.exportSettings.compression,
                  @"Compression mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.exportSettings.includeMetadata, loadedConfig.exportSettings.includeMetadata,
                  @"Include metadata mismatch on iteration %d", iteration);
    
    XCTAssertEqual(originalConfig.privacySettings.encryptStorage, loadedConfig.privacySettings.encryptStorage,
                  @"Encrypt storage mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.privacySettings.clearOnClose, loadedConfig.privacySettings.clearOnClose,
                  @"Clear on close mismatch on iteration %d", iteration);
    XCTAssertEqual(originalConfig.privacySettings.anonymizeIPs, loadedConfig.privacySettings.anonymizeIPs,
                  @"Anonymize IPs mismatch on iteration %d", iteration);
}

@end