//
//  ConfigurationSerializer.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "ConfigurationSerializer.h"
#import "ConfigurationManagerService.h"

@implementation ConfigurationSerializer

#pragma mark - Public Methods

+ (NSData *)serializeConfigurationToJSONData:(AppConfiguration *)configuration
                                  prettyPrint:(BOOL)prettyPrint
                                        error:(NSError **)error {
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration cannot be nil"}];
        }
        return nil;
    }
    
    // Validate configuration before serialization
    NSError *validationError = nil;
    if (![self validateConfigurationForSerialization:configuration error:&validationError]) {
        if (error) {
            *error = validationError;
        }
        return nil;
    }
    
    // Convert to dictionary
    NSDictionary *configDict = [configuration toDictionary];
    if (!configDict) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert configuration to dictionary"}];
        }
        return nil;
    }
    
    // Add metadata
    NSMutableDictionary *fullDict = [configDict mutableCopy];
    [self addMetadataToDictionary:fullDict];
    
    // Serialize to JSON
    NSError *jsonError = nil;
    NSJSONWritingOptions options = prettyPrint ? NSJSONWritingPrettyPrinted : 0;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fullDict
                                                      options:options
                                                        error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to serialize configuration to JSON",
                                          NSUnderlyingErrorKey: jsonError
                                      }];
        }
        return nil;
    }
    
    return jsonData;
}

+ (NSString *)serializeConfigurationToJSONString:(AppConfiguration *)configuration
                                      prettyPrint:(BOOL)prettyPrint
                                            error:(NSError **)error {
    NSData *jsonData = [self serializeConfigurationToJSONData:configuration
                                                   prettyPrint:prettyPrint
                                                         error:error];
    
    if (!jsonData) {
        return nil;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!jsonString) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert JSON data to string"}];
        }
        return nil;
    }
    
    return jsonString;
}

+ (BOOL)serializeConfiguration:(AppConfiguration *)configuration
                        toFile:(NSURL *)fileURL
                    prettyPrint:(BOOL)prettyPrint
                         error:(NSError **)error {
    if (!fileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"File URL cannot be nil"}];
        }
        return NO;
    }
    
    NSData *jsonData = [self serializeConfigurationToJSONData:configuration
                                                   prettyPrint:prettyPrint
                                                         error:error];
    
    if (!jsonData) {
        return NO;
    }
    
    // Write to file
    NSError *fileError = nil;
    BOOL success = [jsonData writeToURL:fileURL options:NSDataWritingAtomic error:&fileError];
    
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:500
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"Failed to write configuration to file",
                                          NSUnderlyingErrorKey: fileError
                                      }];
        }
        return NO;
    }
    
    return YES;
}

+ (NSString *)generateConfigurationSchemaJSON:(BOOL)prettyPrint {
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    ConfigurationSchema *schema = [manager getConfigurationSchema];
    
    if (!schema.schemaDefinition) {
        return @"{}";
    }
    
    NSMutableDictionary *fullSchema = [schema.schemaDefinition mutableCopy];
    
    // Add properties
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    NSMutableDictionary *required = [NSMutableDictionary dictionary];
    
    for (NSString *fieldName in schema.fieldTypes) {
        NSString *type = schema.fieldTypes[fieldName];
        NSMutableDictionary *property = [NSMutableDictionary dictionary];
        property[@"type"] = type;
        
        // Add description based on field name
        NSString *description = [self descriptionForField:fieldName];
        if (description) {
            property[@"description"] = description;
        }
        
        // Add constraints
        NSDictionary *constraints = schema.fieldConstraints[fieldName];
        if (constraints) {
            [property addEntriesFromDictionary:constraints];
        }
        
        // Handle nested structures
        if ([type isEqualToString:@"object"]) {
            property[@"properties"] = [self propertiesForNestedField:fieldName];
        } else if ([type isEqualToString:@"array"]) {
            property[@"items"] = [self itemsForArrayField:fieldName];
        }
        
        properties[fieldName] = property;
    }
    
    // Add required fields
    if (schema.requiredFields.count > 0) {
        fullSchema[@"required"] = schema.requiredFields;
    }
    
    fullSchema[@"properties"] = properties;
    
    // Serialize to JSON
    NSError *error = nil;
    NSJSONWritingOptions options = prettyPrint ? NSJSONWritingPrettyPrinted : 0;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fullSchema
                                                      options:options
                                                        error:&error];
    
    if (error || !jsonData) {
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (BOOL)validateConfigurationForSerialization:(AppConfiguration *)configuration error:(NSError **)error {
    if (!configuration) {
        if (error) {
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey: @"Configuration cannot be nil"}];
        }
        return NO;
    }
    
    // Use ConfigurationManagerService for validation
    ConfigurationManagerService *manager = [ConfigurationManagerService sharedManager];
    ValidationResult *validationResult = [manager validateConfiguration:configuration];
    
    if (!validationResult.isValid) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Configuration validation failed: %@",
                                      [validationResult.errors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:422
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: errorMessage,
                                          @"validationErrors": validationResult.errors,
                                          @"validationWarnings": validationResult.warnings
                                      }];
        }
        return NO;
    }
    
    // Additional serialization-specific validation
    NSMutableArray<NSString *> *serializationErrors = [NSMutableArray array];
    
    // Check that all required data can be converted to JSON
    @try {
        NSDictionary *testDict = [configuration toDictionary];
        if (!testDict) {
            [serializationErrors addObject:@"Failed to convert configuration to dictionary"];
        } else {
            // Test JSON serialization
            NSError *testError = nil;
            [NSJSONSerialization dataWithJSONObject:testDict options:0 error:&testError];
            if (testError) {
                [serializationErrors addObject:[NSString stringWithFormat:@"JSON serialization test failed: %@", testError.localizedDescription]];
            }
        }
    } @catch (NSException *exception) {
        [serializationErrors addObject:[NSString stringWithFormat:@"Exception during serialization test: %@", exception.reason]];
    }
    
    if (serializationErrors.count > 0) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Serialization validation failed: %@",
                                      [serializationErrors componentsJoinedByString:@", "]];
            *error = [NSError errorWithDomain:@"ConfigurationSerializer"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Private Methods

+ (void)addMetadataToDictionary:(NSMutableDictionary *)dict {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    
    dict[@"$schema"] = @"https://pipe.app/schema/v1.0.0";
    dict[@"version"] = @"1.0.0";
    dict[@"generated"] = [dateFormatter stringFromDate:[NSDate date]];
    dict[@"generator"] = @"Pipe Configuration Serializer";
}

+ (NSString *)descriptionForField:(NSString *)fieldName {
    static NSDictionary *descriptions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptions = @{
            @"captureSettings": @"Packet capture settings including buffer size, filters, and storage limits",
            @"vpnSettings": @"VPN connection settings including protocol, auto-reconnect, and security features",
            @"uiSettings": @"User interface settings including theme, language, and refresh rate",
            @"exportSettings": @"Data export settings including format, compression, and metadata inclusion",
            @"privacySettings": @"Privacy and security settings including encryption and data anonymization"
        };
    });
    
    return descriptions[fieldName];
}

+ (NSDictionary *)propertiesForNestedField:(NSString *)fieldName {
    static NSDictionary *nestedProperties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nestedProperties = @{
            @"captureSettings": @{
                @"defaultBufferSize": @{
                    @"type": @"number",
                    @"description": @"Default buffer size for packet capture in bytes",
                    @"minimum": @1024,
                    @"maximum": @1048576,
                    @"default": @65536
                },
                @"autoStartOnLaunch": @{
                    @"type": @"boolean",
                    @"description": @"Whether to automatically start packet capture on app launch",
                    @"default": @NO
                },
                @"defaultFilters": @{
                    @"type": @"array",
                    @"description": @"Default packet filter rules",
                    @"items": @{@"type": @"object"},
                    @"default": @[]
                },
                @"storageLimit": @{
                    @"type": @"object",
                    @"description": @"Storage limits for captured packets",
                    @"properties": @{
                        @"maxSizeMB": @{
                            @"type": @"number",
                            @"description": @"Maximum storage size in megabytes (0 = unlimited)",
                            @"minimum": @0,
                            @"default": @100
                        },
                        @"maxPackets": @{
                            @"type": @"number",
                            @"description": @"Maximum number of packets to store (0 = unlimited)",
                            @"minimum": @0,
                            @"default": @10000
                        },
                        @"maxSessions": @{
                            @"type": @"number",
                            @"description": @"Maximum number of capture sessions to keep (0 = unlimited)",
                            @"minimum": @0,
                            @"default": @10
                        }
                    }
                }
            },
            @"vpnSettings": @{
                @"defaultProtocol": @{
                    @"type": @"string",
                    @"description": @"Default VPN protocol to use",
                    @"enum": @[@"WireGuard", @"OpenVPN", @"IKEv2"],
                    @"default": @"WireGuard"
                },
                @"autoReconnect": @{
                    @"type": @"boolean",
                    @"description": @"Whether to automatically reconnect VPN on connection loss",
                    @"default": @YES
                },
                @"killSwitch": @{
                    @"type": @"boolean",
                    @"description": @"Whether to enable kill switch (block all traffic when VPN disconnects)",
                    @"default": @YES
                },
                @"dnsLeakProtection": @{
                    @"type": @"boolean",
                    @"description": @"Whether to enable DNS leak protection",
                    @"default": @YES
                }
            },
            @"uiSettings": @{
                @"theme": @{
                    @"type": @"string",
                    @"description": @"UI theme preference",
                    @"enum": @[@"light", @"dark", @"system"],
                    @"default": @"system"
                },
                @"language": @{
                    @"type": @"string",
                    @"description": @"UI language preference",
                    @"enum": @[@"en", @"zh", @"ja", @"es", @"fr"],
                    @"default": @"en"
                },
                @"refreshRate": @{
                    @"type": @"number",
                    @"description": @"UI refresh rate in seconds",
                    @"minimum": @0.1,
                    @"maximum": @10.0,
                    @"default": @1.0
                },
                @"showAdvancedOptions": @{
                    @"type": @"boolean",
                    @"description": @"Whether to show advanced options in UI",
                    @"default": @NO
                }
            },
            @"exportSettings": @{
                @"defaultFormat": @{
                    @"type": @"string",
                    @"description": @"Default export format for captured packets",
                    @"enum": @[@"pcap", @"json", @"csv"],
                    @"default": @"pcap"
                },
                @"compression": @{
                    @"type": @"boolean",
                    @"description": @"Whether to compress exported files",
                    @"default": @YES
                },
                @"includeMetadata": @{
                    @"type": @"boolean",
                    @"description": @"Whether to include metadata in exports",
                    @"default": @YES
                }
            },
            @"privacySettings": @{
                @"encryptStorage": @{
                    @"type": @"boolean",
                    @"description": @"Whether to encrypt stored configuration and captured data",
                    @"default": @YES
                },
                @"clearOnClose": @{
                    @"type": @"boolean",
                    @"description": @"Whether to clear captured data when app closes",
                    @"default": @NO
                },
                @"anonymizeIPs": @{
                    @"type": @"boolean",
                    @"description": @"Whether to anonymize IP addresses in captured packets",
                    @"default": @NO
                }
            }
        };
    });
    
    return nestedProperties[fieldName];
}

+ (NSDictionary *)itemsForArrayField:(NSString *)fieldName {
    if ([fieldName isEqualToString:@"defaultFilters"]) {
        return @{
            @"type": @"object",
            @"description": @"Packet filter rule",
            @"properties": @{
                @"id": @{
                    @"type": @"string",
                    @"description": @"Unique filter identifier"
                },
                @"name": @{
                    @"type": @"string",
                    @"description": @"Filter name"
                },
                @"conditions": @{
                    @"type": @"array",
                    @"description": @"Filter conditions",
                    @"items": @{
                        @"type": @"object",
                        @"properties": @{
                            @"field": @{
                                @"type": @"string",
                                @"enum": @[@"protocol", @"sourceIP", @"destinationIP", @"sourcePort", @"destinationPort", @"size", @"content"]
                            },
                            @"operator": @{
                                @"type": @"string",
                                @"enum": @[@"equals", @"contains", @"startsWith", @"endsWith", @"greaterThan", @"lessThan", @"matchesRegex"]
                            },
                            @"value": @{
                                @"type": @"string",
                                @"description": @"Value to compare against"
                            }
                        }
                    }
                },
                @"action": @{
                    @"type": @"string",
                    @"enum": @[@"include", @"exclude", @"highlight", @"alert"]
                },
                @"isEnabled": @{
                    @"type": @"boolean",
                    @"description": @"Whether the filter is enabled"
                }
            }
        };
    }
    
    return @{@"type": @"string"};
}

#pragma mark - Description

+ (NSString *)description {
    return @"<ConfigurationSerializer>";
}

@end