//
//  AppConfiguration.h
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import <Foundation/Foundation.h>
#import "VPNConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/// App language
typedef NS_ENUM(NSInteger, AppLanguage) {
    AppLanguageEnglish,
    AppLanguageChinese,
    AppLanguageJapanese,
    AppLanguageSpanish,
    AppLanguageFrench
};

/// App theme
typedef NS_ENUM(NSInteger, AppTheme) {
    AppThemeLight,
    AppThemeDark,
    AppThemeSystem
};

/// Export format
typedef NS_ENUM(NSInteger, ExportFormat) {
    ExportFormatPCAP,
    ExportFormatJSON,
    ExportFormatCSV
};

/// Storage limit
@interface StorageLimit : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) NSUInteger maxSizeMB;
@property (nonatomic, assign) NSUInteger maxPackets;
@property (nonatomic, assign) NSUInteger maxSessions;

- (instancetype)initWithMaxSizeMB:(NSUInteger)maxSizeMB
                       maxPackets:(NSUInteger)maxPackets
                      maxSessions:(NSUInteger)maxSessions;

/// Default storage limit
+ (instancetype)defaultLimit;

/// Unlimited storage
+ (instancetype)unlimited;

@end

/// Capture settings
@interface CaptureSettings : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) NSUInteger defaultBufferSize;
@property (nonatomic, assign) BOOL autoStartOnLaunch;
@property (nonatomic, copy) NSArray<NSDictionary *> *defaultFilters; // Array of PacketFilter dictionaries
@property (nonatomic, strong) StorageLimit *storageLimit;

- (instancetype)initWithDefaultBufferSize:(NSUInteger)defaultBufferSize
                        autoStartOnLaunch:(BOOL)autoStartOnLaunch
                           defaultFilters:(NSArray<NSDictionary *> *)defaultFilters
                             storageLimit:(StorageLimit *)storageLimit;

@end

/// VPN settings
@interface VPNSettings : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) VPNProtocol defaultProtocol;
@property (nonatomic, assign) BOOL autoReconnect;
@property (nonatomic, assign) BOOL killSwitch;
@property (nonatomic, assign) BOOL dnsLeakProtection;

- (instancetype)initWithDefaultProtocol:(VPNProtocol)defaultProtocol
                          autoReconnect:(BOOL)autoReconnect
                             killSwitch:(BOOL)killSwitch
                      dnsLeakProtection:(BOOL)dnsLeakProtection;

@end

/// UI settings
@interface UISettings : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) AppTheme theme;
@property (nonatomic, assign) AppLanguage language;
@property (nonatomic, assign) NSTimeInterval refreshRate;
@property (nonatomic, assign) BOOL showAdvancedOptions;

- (instancetype)initWithTheme:(AppTheme)theme
                     language:(AppLanguage)language
                  refreshRate:(NSTimeInterval)refreshRate
           showAdvancedOptions:(BOOL)showAdvancedOptions;

@end

/// Export settings
@interface ExportSettings : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) ExportFormat defaultFormat;
@property (nonatomic, assign) BOOL compression;
@property (nonatomic, assign) BOOL includeMetadata;

- (instancetype)initWithDefaultFormat:(ExportFormat)defaultFormat
                           compression:(BOOL)compression
                        includeMetadata:(BOOL)includeMetadata;

@end

/// Privacy settings
@interface PrivacySettings : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) BOOL encryptStorage;
@property (nonatomic, assign) BOOL clearOnClose;
@property (nonatomic, assign) BOOL anonymizeIPs;

- (instancetype)initWithEncryptStorage:(BOOL)encryptStorage
                          clearOnClose:(BOOL)clearOnClose
                          anonymizeIPs:(BOOL)anonymizeIPs;

@end

/// Main app configuration
@interface AppConfiguration : NSObject <NSCoding, NSCopying>

@property (nonatomic, strong) CaptureSettings *captureSettings;
@property (nonatomic, strong) VPNSettings *vpnSettings;
@property (nonatomic, strong) UISettings *uiSettings;
@property (nonatomic, strong) ExportSettings *exportSettings;
@property (nonatomic, strong) PrivacySettings *privacySettings;

- (instancetype)initWithCaptureSettings:(CaptureSettings *)captureSettings
                            vpnSettings:(VPNSettings *)vpnSettings
                             uiSettings:(UISettings *)uiSettings
                         exportSettings:(ExportSettings *)exportSettings
                         privacySettings:(PrivacySettings *)privacySettings;

/// Default configuration
+ (instancetype)defaultConfiguration;

/// Convert to dictionary for JSON serialization
- (NSDictionary *)toDictionary;

/// Create from dictionary (JSON deserialization)
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END