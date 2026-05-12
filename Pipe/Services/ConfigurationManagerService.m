//
//  ConfigurationManagerService.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "ConfigurationManagerService.h"
#import <CommonCrypto/CommonCrypto.h>

// Encryption key for sensitive data (in production, this should be stored in Keychain)
static NSString *const kEncryptionKey = @"com.pipe.configuration.encryption.key";
static NSString *const kConfigurationFileName = @"app_configuration.json";
static NSString *const kConfigurationSchemaVersion = @"1.0.0";

@implementation ValidationResult

- (instancetype)initWithIsValid:(BOOL)isValid
                         errors:(NSArray<NSString *> *)errors
                       warnings:(NSArray<NSString *> *)warnings {
    self = [super init];
    if (self) {
        _isValid = isValid;
        _errors = [errors copy];
        _warnings = [warnings copy];
    }
    return self;
}

+ (instancetype)success {
    return [[ValidationResult alloc] initWithIsValid:YES errors:@[] warnings:@[]];
}

+ (instancetype)failureWithErrors:(NSArray<NSString *> *)errors {
    return [[ValidationResult alloc] initWithIsValid:NO errors:errors warnings:@[]];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ValidationResult: valid=%d, errors=%ld, warnings=%ld>",
            self.isValid, (long)self.errors.count, (long)self.warnings.count];
}

@end

@implementation ConfigurationSchema

- (instancetype)initWithSchemaDefinition:(NSDictionary *)schemaDefinition
                           requiredFields:(NSArray<NSString *> *)requiredFields
                               fieldTypes:(NSDictionary *)fieldTypes
                         fieldConstraints:(NSDictionary *)fieldConstraints {
    self = [super init];
    if (self) {
        _schemaDefinition = [schemaDefinition copy];
        _requiredFields = [requiredFields copy];
        _fieldTypes = [fieldTypes copy];
        _fieldConstraints = [fieldConstraints copy];
    }
    return self;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ConfigurationSchema: version=%@, requiredFields=%ld>",
            self.schemaDefinition[@"version"], (long)self.requiredFields.count];
}

@end

@interface ConfigurationManagerService ()

@property (nonatomic, strong) NSURL *configurationFileURL;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) ConfigurationSchema *schema;

@end

@implementation ConfigurationManagerService

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static ConfigurationManagerService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithConfigurationFileURL:nil];
}

- (instancetype)initWithConfigurationFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        
        if (fileURL) {
            _configurationFileURL = fileURL;
        } else {
            _configurationFileURL = [self defaultConfigurationFileURL];
        }
        
        _schema = [self createConfigurationSchema];
        
        // Ensure configuration file exists
        [self ensureConfigurationFileExists];
    }
    return self;
}

#pragma mark - File Management

- (NSURL *)defaultConfigurationFileURL {
    NSURL *documentsDirectory = [[self.fileManager URLsForDirectory:NSDocumentDirectory
                                                         inDomains:NSUserDomainMask] firstObject];
    return [documentsDirectory URLByAppendingPathComponent:kConfigurationFileName];
}

- (void)ensureConfigurationFileExists {
    if (![self.fileManager fileExistsAtPath:self.configurationFileURL.path]) {
        // Create default configuration
        AppConfiguration *defaultConfig = [AppConfiguration defaultConfiguration];
        NSError *error = nil;
        [self saveConfiguration:defaultConfig error:&error];
        
        if (error) {
            NSLog(@"Failed to create default configuration: %@", error);
        }
    }
}

#pragma mark - ConfigurationManagerProtocol

- (AppConfiguration *)loadConfigurationWithError:(NSError **)error {
    return [self loadConfigurationFromURL:self.configurationFileURL error:error];
}

- (BOOL)saveConfiguration:(AppConfiguration *)configuration error:(NSError **)error {
    return [self saveConfiguration:configuration toURL:self.configurationFileURL error:error];
}

- (AppConfiguration *)loadConfigurationFromURL:(NSURL *)url error:(NSError **)error {
    if (![self.fileManager fileExistsAtPath:url.path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:404
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration file not found"}];
        }
        return [AppConfiguration defaultConfiguration];
    }
    
    NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!fileData) {
        return [AppConfiguration defaultConfiguration];
    }
    
    // Try to decrypt if encrypted
    NSData *decryptedData = [self decryptDataIfNeeded:fileData];
    if (!decryptedData) {
        decryptedData = fileData;
    }
    
    return [self parseConfigurationFromJSONData:decryptedData error:error];
}

- (BOOL)saveConfiguration:(AppConfiguration *)configuration toURL:(NSURL *)url error:(NSError **)error {
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration cannot be nil"}];
        }
        return NO;
    }
    
    // Validate configuration before saving
    ValidationResult *validationResult = [self validateConfiguration:configuration];
    if (!validationResult.isValid) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration validation failed",
                                                 @"validationErrors": validationResult.errors}];
        }
        return NO;
    }
    
    // Convert to JSON data
    NSData *jsonData = [self convertConfigurationToJSONData:configuration error:error];
    if (!jsonData) {
        return NO;
    }
    
    // Encrypt if privacy settings require it
    if (configuration.privacySettings.encryptStorage) {
        jsonData = [self encryptData:jsonData];
        if (!jsonData) {
            if (error) {
                *error = [NSError errorWithDomain:@"ConfigurationManager"
                                              code:500
                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to encrypt configuration"}];
            }
            return NO;
        }
    }
    
    // Save to file
    return [jsonData writeToURL:url options:NSDataWritingAtomic error:error];
}

- (ValidationResult *)validateConfiguration:(AppConfiguration *)configuration {
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    
    // Validate capture settings
    if (!configuration.captureSettings) {
        [errors addObject:@"Capture settings are required"];
    } else {
        if (configuration.captureSettings.defaultBufferSize == 0) {
            [errors addObject:@"Default buffer size must be greater than 0"];
        }
        
        if (configuration.captureSettings.storageLimit.maxSizeMB > 1024 * 10) { // 10GB limit
            [warnings addObject:@"Storage limit exceeds recommended maximum (10GB)"];
        }
    }
    
    // Validate VPN settings
    if (!configuration.vpnSettings) {
        [errors addObject:@"VPN settings are required"];
    }
    
    // Validate UI settings
    if (!configuration.uiSettings) {
        [errors addObject:@"UI settings are required"];
    } else {
        if (configuration.uiSettings.refreshRate < 0.1 || configuration.uiSettings.refreshRate > 10.0) {
            [errors addObject:@"Refresh rate must be between 0.1 and 10.0 seconds"];
        }
    }
    
    // Validate export settings
    if (!configuration.exportSettings) {
        [errors addObject:@"Export settings are required"];
    }
    
    // Validate privacy settings
    if (!configuration.privacySettings) {
        [errors addObject:@"Privacy settings are required"];
    }
    
    BOOL isValid = (errors.count == 0);
    return [[ValidationResult alloc] initWithIsValid:isValid errors:errors warnings:warnings];
}

- (BOOL)resetToDefaultsWithError:(NSError **)error {
    AppConfiguration *defaultConfig = [AppConfiguration defaultConfiguration];
    return [self saveConfiguration:defaultConfig error:error];
}

- (ConfigurationSchema *)getConfigurationSchema {
    return self.schema;
}

- (AppConfiguration *)importConfigurationFromJSONData:(NSData *)jsonData error:(NSError **)error {
    return [self parseConfigurationFromJSONData:jsonData error:error];
}

- (NSData *)exportConfigurationToJSONData:(AppConfiguration *)configuration error:(NSError **)error {
    return [self convertConfigurationToJSONData:configuration error:error];
}

#pragma mark - JSON Parsing and Serialization

- (AppConfiguration *)parseConfigurationFromJSONData:(NSData *)jsonData error:(NSError **)error {
    if (!jsonData) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"JSON data cannot be nil"}];
        }
        return nil;
    }
    
    NSError *jsonError = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                              options:0
                                                                error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        }
        return nil;
    }
    
    // Validate JSON against schema
    ValidationResult *schemaValidation = [self validateJSONAgainstSchema:jsonDict];
    if (!schemaValidation.isValid) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Schema validation failed: %@",
                                      [schemaValidation.errors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        }
        return nil;
    }
    
    // Parse configuration from dictionary
    AppConfiguration *configuration = [AppConfiguration fromDictionary:jsonDict];
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse configuration from JSON"}];
        }
        return nil;
    }
    
    // Validate the parsed configuration
    ValidationResult *validationResult = [self validateConfiguration:configuration];
    if (!validationResult.isValid) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Configuration validation failed: %@",
                                      [validationResult.errors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        }
        return nil;
    }
    
    return configuration;
}

- (NSData *)convertConfigurationToJSONData:(AppConfiguration *)configuration error:(NSError **)error {
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationManager"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration cannot be nil"}];
        }
        return nil;
    }
    
    // Convert to dictionary
    NSDictionary *configDict = [configuration toDictionary];
    
    // Add metadata
    NSMutableDictionary *fullDict = [configDict mutableCopy];
    fullDict[@"$schema"] = @"https://pipe.app/schema/v1.0.0";
    fullDict[@"version"] = kConfigurationSchemaVersion;
    fullDict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    // Convert to JSON data
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fullDict
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        }
        return nil;
    }
    
    return jsonData;
}

#pragma mark - Schema Validation

- (ValidationResult *)validateJSONAgainstSchema:(NSDictionary *)jsonDict {
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    
    // Check required fields
    for (NSString *requiredField in self.schema.requiredFields) {
        if (!jsonDict[requiredField]) {
            [errors addObject:[NSString stringWithFormat:@"Missing required field: %@", requiredField]];
        }
    }
    
    // Check field types (basic validation)
    for (NSString *fieldName in self.schema.fieldTypes) {
        id fieldValue = jsonDict[fieldName];
        NSString *expectedType = self.schema.fieldTypes[fieldName];
        
        if (fieldValue) {
            if ([expectedType isEqualToString:@"string"] && ![fieldValue isKindOfClass:[NSString class]]) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be a string", fieldName]];
            } else if ([expectedType isEqualToString:@"number"] && ![fieldValue isKindOfClass:[NSNumber class]]) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be a number", fieldName]];
            } else if ([expectedType isEqualToString:@"boolean"] && ![fieldValue isKindOfClass:[NSNumber class]]) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be a boolean", fieldName]];
            } else if ([expectedType isEqualToString:@"array"] && ![fieldValue isKindOfClass:[NSArray class]]) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be an array", fieldName]];
            } else if ([expectedType isEqualToString:@"object"] && ![fieldValue isKindOfClass:[NSDictionary class]]) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be an object", fieldName]];
            }
        }
    }
    
    // Check constraints
    for (NSString *fieldName in self.schema.fieldConstraints) {
        id fieldValue = jsonDict[fieldName];
        NSDictionary *constraints = self.schema.fieldConstraints[fieldName];
        
        if (fieldValue && constraints) {
            // Check min value
            NSNumber *minValue = constraints[@"min"];
            if (minValue && [fieldValue isKindOfClass:[NSNumber class]]) {
                if ([fieldValue doubleValue] < [minValue doubleValue]) {
                    [errors addObject:[NSString stringWithFormat:@"Field %@ should be at least %@", fieldName, minValue]];
                }
            }
            
            // Check max value
            NSNumber *maxValue = constraints[@"max"];
            if (maxValue && [fieldValue isKindOfClass:[NSNumber class]]) {
                if ([fieldValue doubleValue] > [maxValue doubleValue]) {
                    [errors addObject:[NSString stringWithFormat:@"Field %@ should be at most %@", fieldName, maxValue]];
                }
            }
            
            // Check pattern (regex)
            NSString *pattern = constraints[@"pattern"];
            if (pattern && [fieldValue isKindOfClass:[NSString class]]) {
                NSError *regexError = nil;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                       options:0
                                                                                         error:&regexError];
                if (!regexError) {
                    NSUInteger matches = [regex numberOfMatchesInString:fieldValue
                                                                options:0
                                                                  range:NSMakeRange(0, [fieldValue length])];
                    if (matches == 0) {
                        [errors addObject:[NSString stringWithFormat:@"Field %@ does not match pattern: %@", fieldName, pattern]];
                    }
                }
            }
        }
    }
    
    BOOL isValid = (errors.count == 0);
    return [[ValidationResult alloc] initWithIsValid:isValid errors:errors warnings:warnings];
}

#pragma mark - Encryption/Decryption

- (NSData *)encryptData:(NSData *)data {
    // In production, use proper key management (Keychain)
    // This is a simplified example using AES encryption
    
    // Generate a random IV
    unsigned char iv[16];
    arc4random_buf(iv, 16);
    
    // Create key from password
    const char *keyStr = [kEncryptionKey UTF8String];
    unsigned char key[32];
    CCKeyDerivationPBKDF(kCCPBKDF2, keyStr, strlen(keyStr), iv, 16, kCCPRFHmacAlgSHA256, 10000, 32, key);
    
    // Encrypt data
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          key,
                                          32,
                                          iv,
                                          [data bytes],
                                          [data length],
                                          buffer,
                                          bufferSize,
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        // Combine IV and encrypted data
        NSMutableData *encryptedData = [NSMutableData dataWithBytes:iv length:16];
        [encryptedData appendBytes:buffer length:numBytesEncrypted];
        free(buffer);
        return encryptedData;
    }
    
    free(buffer);
    return nil;
}

- (NSData *)decryptDataIfNeeded:(NSData *)data {
    // Check if data is encrypted (starts with IV)
    if ([data length] < 16) {
        return nil; // Not encrypted or invalid
    }
    
    // Extract IV
    unsigned char iv[16];
    [data getBytes:iv length:16];
    
    // Extract encrypted data
    NSData *encryptedData = [data subdataWithRange:NSMakeRange(16, [data length] - 16)];
    
    // Create key from password
    const char *keyStr = [kEncryptionKey UTF8String];
    unsigned char key[32];
    CCKeyDerivationPBKDF(kCCPBKDF2, keyStr, strlen(keyStr), iv, 16, kCCPRFHmacAlgSHA256, 10000, 32, key);
    
    // Decrypt data
    size_t bufferSize = [encryptedData length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          key,
                                          32,
                                          iv,
                                          [encryptedData bytes],
                                          [encryptedData length],
                                          buffer,
                                          bufferSize,
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        NSData *decryptedData = [NSData dataWithBytes:buffer length:numBytesDecrypted];
        free(buffer);
        return decryptedData;
    }
    
    free(buffer);
    return nil;
}

#pragma mark - Schema Creation

- (ConfigurationSchema *)createConfigurationSchema {
    NSDictionary *schemaDefinition = @{
        @"$schema": @"http://json-schema.org/draft-07/schema#",
        @"title": @"Pipe Configuration Schema",
        @"description": @"Configuration schema for Pipe packet capture and VPN application",
        @"type": @"object",
        @"version": kConfigurationSchemaVersion
    };
    
    NSArray<NSString *> *requiredFields = @[
        @"captureSettings",
        @"vpnSettings",
        @"uiSettings",
        @"exportSettings",
        @"privacySettings"
    ];
    
    NSDictionary *fieldTypes = @{
        @"captureSettings": @"object",
        @"vpnSettings": @"object",
        @"uiSettings": @"object",
        @"exportSettings": @"object",
        @"privacySettings": @"object"
    };
    
    NSDictionary *fieldConstraints = @{
        @"uiSettings.refreshRate": @{
            @"min": @0.1,
            @"max": @10.0
        },
        @"captureSettings.defaultBufferSize": @{
            @"min": @1024,
            @"max": @1048576  // 1MB
        }
    };
    
    return [[ConfigurationSchema alloc] initWithSchemaDefinition:schemaDefinition
                                                   requiredFields:requiredFields
                                                       fieldTypes:fieldTypes
                                                 fieldConstraints:fieldConstraints];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ConfigurationManagerService: fileURL=%@>", self.configurationFileURL];
}

@end