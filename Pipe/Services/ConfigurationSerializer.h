//
//  ConfigurationSerializer.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "../Models/AppConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration serializer for JSON files
@interface ConfigurationSerializer : NSObject

/// Serialize configuration to JSON data
/// @param configuration Configuration to serialize
/// @param prettyPrint Whether to format JSON with indentation
/// @param error Error output parameter
/// @return JSON data or nil on error
+ (NSData *)serializeConfigurationToJSONData:(AppConfiguration *)configuration
                                  prettyPrint:(BOOL)prettyPrint
                                        error:(NSError **)error;

/// Serialize configuration to JSON string
/// @param configuration Configuration to serialize
/// @param prettyPrint Whether to format JSON with indentation
/// @param error Error output parameter
/// @return JSON string or nil on error
+ (NSString *)serializeConfigurationToJSONString:(AppConfiguration *)configuration
                                      prettyPrint:(BOOL)prettyPrint
                                            error:(NSError **)error;

/// Serialize configuration to file
/// @param configuration Configuration to serialize
/// @param fileURL File URL to write to
/// @param prettyPrint Whether to format JSON with indentation
/// @param error Error output parameter
/// @return YES if successful, NO otherwise
+ (BOOL)serializeConfiguration:(AppConfiguration *)configuration
                        toFile:(NSURL *)fileURL
                    prettyPrint:(BOOL)prettyPrint
                         error:(NSError **)error;

/// Generate configuration schema JSON
/// @param prettyPrint Whether to format JSON with indentation
/// @return JSON schema as string
+ (NSString *)generateConfigurationSchemaJSON:(BOOL)prettyPrint;

/// Validate configuration can be serialized
/// @param configuration Configuration to validate
/// @param error Error output parameter
/// @return YES if valid, NO otherwise
+ (BOOL)validateConfigurationForSerialization:(AppConfiguration *)configuration error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END