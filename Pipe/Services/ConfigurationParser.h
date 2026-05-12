//
//  ConfigurationParser.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "../Models/AppConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration parser for JSON files
@interface ConfigurationParser : NSObject

/// Parse configuration from JSON data
/// @param jsonData JSON data to parse
/// @param error Error output parameter
/// @return Parsed configuration or nil on error
+ (AppConfiguration *)parseConfigurationFromJSONData:(NSData *)jsonData error:(NSError **)error;

/// Parse configuration from JSON string
/// @param jsonString JSON string to parse
/// @param error Error output parameter
/// @return Parsed configuration or nil on error
+ (AppConfiguration *)parseConfigurationFromJSONString:(NSString *)jsonString error:(NSError **)error;

/// Parse configuration from file URL
/// @param fileURL File URL containing JSON configuration
/// @param error Error output parameter
/// @return Parsed configuration or nil on error
+ (AppConfiguration *)parseConfigurationFromFileURL:(NSURL *)fileURL error:(NSError **)error;

/// Validate JSON data against configuration schema
/// @param jsonData JSON data to validate
/// @param error Error output parameter
/// @return YES if valid, NO otherwise
+ (BOOL)validateJSONData:(NSData *)jsonData error:(NSError **)error;

/// Get schema validation errors
/// @param jsonData JSON data to validate
/// @return Array of validation error messages
+ (NSArray<NSString *> *)getSchemaValidationErrors:(NSData *)jsonData;

@end

NS_ASSUME_NONNULL_END