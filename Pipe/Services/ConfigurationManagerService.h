//
//  ConfigurationManagerService.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "../Models/AppConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration validation result
@interface ValidationResult : NSObject

@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, copy) NSArray<NSString *> *errors;
@property (nonatomic, copy) NSArray<NSString *> *warnings;

- (instancetype)initWithIsValid:(BOOL)isValid
                         errors:(NSArray<NSString *> *)errors
                       warnings:(NSArray<NSString *> *)warnings;

/// Success result
+ (instancetype)success;

/// Failure result with errors
+ (instancetype)failureWithErrors:(NSArray<NSString *> *)errors;

@end

/// Configuration schema
@interface ConfigurationSchema : NSObject

@property (nonatomic, copy) NSDictionary *schemaDefinition;
@property (nonatomic, copy) NSArray<NSString *> *requiredFields;
@property (nonatomic, copy) NSDictionary *fieldTypes;
@property (nonatomic, copy) NSDictionary *fieldConstraints;

- (instancetype)initWithSchemaDefinition:(NSDictionary *)schemaDefinition
                           requiredFields:(NSArray<NSString *> *)requiredFields
                               fieldTypes:(NSDictionary *)fieldTypes
                         fieldConstraints:(NSDictionary *)fieldConstraints;

@end

/// Configuration manager protocol
@protocol ConfigurationManagerProtocol <NSObject>

/// Load configuration from default location
- (AppConfiguration *)loadConfigurationWithError:(NSError **)error;

/// Save configuration to default location
- (BOOL)saveConfiguration:(AppConfiguration *)configuration error:(NSError **)error;

/// Load configuration from specific URL
- (AppConfiguration *)loadConfigurationFromURL:(NSURL *)url error:(NSError **)error;

/// Save configuration to specific URL
- (BOOL)saveConfiguration:(AppConfiguration *)configuration toURL:(NSURL *)url error:(NSError **)error;

/// Validate configuration
- (ValidationResult *)validateConfiguration:(AppConfiguration *)configuration;

/// Reset to default configuration
- (BOOL)resetToDefaultsWithError:(NSError **)error;

/// Get configuration schema
- (ConfigurationSchema *)getConfigurationSchema;

/// Import configuration from JSON data
- (AppConfiguration *)importConfigurationFromJSONData:(NSData *)jsonData error:(NSError **)error;

/// Export configuration to JSON data
- (NSData *)exportConfigurationToJSONData:(AppConfiguration *)configuration error:(NSError **)error;

@end

/// Configuration manager service
@interface ConfigurationManagerService : NSObject <ConfigurationManagerProtocol>

/// Shared instance
+ (instancetype)sharedManager;

/// Initialize with custom file URL
- (instancetype)initWithConfigurationFileURL:(NSURL *)fileURL;

/// Default configuration file URL
@property (nonatomic, strong, readonly) NSURL *defaultConfigurationFileURL;

@end

NS_ASSUME_NONNULL_END