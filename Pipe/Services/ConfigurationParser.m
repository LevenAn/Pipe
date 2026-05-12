//
//  ConfigurationParser.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "ConfigurationParser.h"
#import "ConfigurationManagerService.h"

@implementation ConfigurationParser

#pragma mark - Public Methods

+ (AppConfiguration *)parseConfigurationFromJSONData:(NSData *)jsonData error:(NSError **)error {
    if (!jsonData) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"JSON data cannot be nil"}];
        }
        return nil;
    }
    
    // Validate JSON structure first
    NSError *validationError = nil;
    if (![self validateJSONData:jsonData error:&validationError]) {
        if (error) {
            *error = validationError;
        }
        return nil;
    }
    
    // Parse JSON
    NSError *jsonError = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                              options:0
                                                                error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Invalid JSON format",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return nil;
    }
    
    // Parse configuration from dictionary
    AppConfiguration *configuration = [AppConfiguration fromDictionary:jsonDict];
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse configuration from JSON dictionary"}];
        }
        return nil;
    }
    
    // Validate the parsed configuration
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    ValidationResult *validationResult = [manager validateConfiguration:configuration];
    if (!validationResult.isValid) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Configuration validation failed: %@",
                                      [validationResult.errors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: errorMessage,
                                          @"validationErrors": validationResult.errors,
                                          @"validationWarnings": validationResult.warnings
                                      }];
        }
        return nil;
    }
    
    return configuration;
}

+ (AppConfiguration *)parseConfigurationFromJSONString:(NSString *)jsonString error:(NSError **)error {
    if (!jsonString) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"JSON string cannot be nil"}];
        }
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert string to UTF-8 data"}];
        }
        return nil;
    }
    
    return [self parseConfigurationFromJSONData:jsonData error:error];
}

+ (AppConfiguration *)parseConfigurationFromFileURL:(NSURL *)fileURL error:(NSError **)error {
    if (!fileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"File URL cannot be nil"}];
        }
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:fileURL.path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:404
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration file not found"}];
        }
        return nil;
    }
    
    NSError *fileError = nil;
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:0 error:&fileError];
    
    if (fileError) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to read configuration file",
                                          NSUnderlyingErrorKey: fileError
                                      }];
        }
        return nil;
    }
    
    return [self parseConfigurationFromJSONData:fileData error:error];
}

+ (BOOL)validateJSONData:(NSData *)jsonData error:(NSError **)error {
    if (!jsonData) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"JSON data cannot be nil"}];
        }
        return NO;
    }
    
    // Check if data is valid JSON
    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                     options:0
                                                       error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Invalid JSON format",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return NO;
    }
    
    // Check if it's a dictionary
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:422
                                      userInfo:@{NSLocalizedDescriptionKey: @"JSON root must be an object"}];
        }
        return NO;
    }
    
    NSDictionary *jsonDict = (NSDictionary *)jsonObject;
    
    // Get schema from manager
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    ConfigurationSchema *schema = [manager getConfigurationSchema];
    
    // Validate against schema
    ValidationResult *schemaValidation = [self validateJSONDictionary:jsonDict againstSchema:schema];
    if (!schemaValidation.isValid) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Schema validation failed: %@",
                                      [schemaValidation.errors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationParser"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: errorMessage,
                                          @"validationErrors": schemaValidation.errors,
                                          @"validationWarnings": schemaValidation.warnings
                                      }];
        }
        return NO;
    }
    
    return YES;
}

+ (NSArray<NSString *> *)getSchemaValidationErrors:(NSData *)jsonData {
    if (!jsonData) {
        return @[@"JSON data cannot be nil"];
    }
    
    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                     options:0
                                                       error:&jsonError];
    
    if (jsonError) {
        return @[[NSString stringWithFormat:@"Invalid JSON format: %@", jsonError.localizedDescription]];
    }
    
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return @[@"JSON root must be an object"];
    }
    
    NSDictionary *jsonDict = (NSDictionary *)jsonObject;
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    ConfigurationSchema *schema = [manager getConfigurationSchema];
    
    ValidationResult *schemaValidation = [self validateJSONDictionary:jsonDict againstSchema:schema];
    return schemaValidation.errors;
}

#pragma mark - Private Methods

+ (ValidationResult *)validateJSONDictionary:(NSDictionary *)jsonDict againstSchema:(ConfigurationSchema *)schema {
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    
    // Check required fields
    for (NSString *requiredField in schema.requiredFields) {
        if (!jsonDict[requiredField]) {
            [errors addObject:[NSString stringWithFormat:@"Missing required field: %@", requiredField]];
        }
    }
    
    // Check field types
    for (NSString *fieldName in schema.fieldTypes) {
        id fieldValue = jsonDict[fieldName];
        NSString *expectedType = schema.fieldTypes[fieldName];
        
        if (fieldValue) {
            BOOL typeValid = NO;
            
            if ([expectedType isEqualToString:@"string"]) {
                typeValid = [fieldValue isKindOfClass:[NSString class]];
            } else if ([expectedType isEqualToString:@"number"]) {
                typeValid = [fieldValue isKindOfClass:[NSNumber class]];
            } else if ([expectedType isEqualToString:@"boolean"]) {
                typeValid = [fieldValue isKindOfClass:[NSNumber class]];
                if (typeValid) {
                    // Check if it's actually a boolean (0 or 1)
                    NSNumber *num = (NSNumber *)fieldValue;
                    typeValid = [num isEqualToNumber:@(0)] || [num isEqualToNumber:@(1)] ||
                               [num isEqualToNumber:@(YES)] || [num isEqualToNumber:@(NO)];
                }
            } else if ([expectedType isEqualToString:@"array"]) {
                typeValid = [fieldValue isKindOfClass:[NSArray class]];
            } else if ([expectedType isEqualToString:@"object"]) {
                typeValid = [fieldValue isKindOfClass:[NSDictionary class]];
            }
            
            if (!typeValid) {
                [errors addObject:[NSString stringWithFormat:@"Field %@ should be of type %@", fieldName, expectedType]];
            }
        }
    }
    
    // Check nested structures
    [self validateNestedStructures:jsonDict path:@"" errors:errors warnings:warnings];
    
    BOOL isValid = (errors.count == 0);
    return [[ValidationResult alloc] initWithIsValid:isValid errors:errors warnings:warnings];
}

+ (void)validateNestedStructures:(NSDictionary *)dict path:(NSString *)path errors:(NSMutableArray<NSString *> *)errors warnings:(NSMutableArray<NSString *> *)warnings {
    // Validate captureSettings
    if (dict[@"captureSettings"] && [dict[@"captureSettings"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *captureSettings = dict[@"captureSettings"];
        
        // Check defaultBufferSize
        id bufferSize = captureSettings[@"defaultBufferSize"];
        if (bufferSize && [bufferSize isKindOfClass:[NSNumber class]]) {
            NSInteger bufferSizeValue = [bufferSize integerValue];
            if (bufferSizeValue < 1024) {
                [errors addObject:[NSString stringWithFormat:@"%@captureSettings.defaultBufferSize must be at least 1024", path]];
            } else if (bufferSizeValue > 1048576) {
                [warnings addObject:[NSString stringWithFormat:@"%@captureSettings.defaultBufferSize exceeds recommended maximum (1MB)", path]];
            }
        }
        
        // Check defaultFilters
        id defaultFilters = captureSettings[@"defaultFilters"];
        if (defaultFilters && ![defaultFilters isKindOfClass:[NSArray class]]) {
            [errors addObject:[NSString stringWithFormat:@"%@captureSettings.defaultFilters must be an array", path]];
        }
    }
    
    // Validate uiSettings
    if (dict[@"uiSettings"] && [dict[@"uiSettings"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *uiSettings = dict[@"uiSettings"];
        
        // Check refreshRate
        id refreshRate = uiSettings[@"refreshRate"];
        if (refreshRate && [refreshRate isKindOfClass:[NSNumber class]]) {
            double refreshRateValue = [refreshRate doubleValue];
            if (refreshRateValue < 0.1) {
                [errors addObject:[NSString stringWithFormat:@"%@uiSettings.refreshRate must be at least 0.1 seconds", path]];
            } else if (refreshRateValue > 10.0) {
                [errors addObject:[NSString stringWithFormat:@"%@uiSettings.refreshRate must be at most 10.0 seconds", path]];
            }
        }
        
        // Check language
        id language = uiSettings[@"language"];
        if (language && [language isKindOfClass:[NSString class]]) {
            NSArray *validLanguages = @[@"en", @"zh", @"ja", @"es", @"fr"];
            if (![validLanguages containsObject:language]) {
                [errors addObject:[NSString stringWithFormat:@"%@uiSettings.language must be one of: %@", path, [validLanguages componentsJoinedByString:@", "]]];
            }
        }
    }
    
    // Validate vpnSettings
    if (dict[@"vpnSettings"] && [dict[@"vpnSettings"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *vpnSettings = dict[@"vpnSettings"];
        
        // Check defaultProtocol
        id defaultProtocol = vpnSettings[@"defaultProtocol"];
        if (defaultProtocol && [defaultProtocol isKindOfClass:[NSString class]]) {
            NSArray *validProtocols = @[@"WireGuard", @"OpenVPN", @"IKEv2"];
            if (![validProtocols containsObject:defaultProtocol]) {
                [errors addObject:[NSString stringWithFormat:@"%@vpnSettings.defaultProtocol must be one of: %@", path, [validProtocols componentsJoinedByString:@", "]]];
            }
        }
    }
    
    // Validate exportSettings
    if (dict[@"exportSettings"] && [dict[@"exportSettings"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *exportSettings = dict[@"exportSettings"];
        
        // Check defaultFormat
        id defaultFormat = exportSettings[@"defaultFormat"];
        if (defaultFormat && [defaultFormat isKindOfClass:[NSString class]]) {
            NSArray *validFormats = @[@"pcap", @"json", @"csv"];
            if (![validFormats containsObject:defaultFormat]) {
                [errors addObject:[NSString stringWithFormat:@"%@exportSettings.defaultFormat must be one of: %@", path, [validFormats componentsJoinedByString:@", "]]];
            }
        }
    }
}

#pragma mark - Description

+ (NSString *)description {
    return @"<ConfigurationParser>";
}

@end