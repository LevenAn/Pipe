//
//  AppConfiguration.m
//  Pipe
//
//  Created by Leven on 2026/5/10.
//

#import "AppConfiguration.h"

@implementation StorageLimit

- (instancetype)initWithMaxSizeMB:(NSUInteger)maxSizeMB
                       maxPackets:(NSUInteger)maxPackets
                      maxSessions:(NSUInteger)maxSessions {
    self = [super init];
    if (self) {
        _maxSizeMB = maxSizeMB;
        _maxPackets = maxPackets;
        _maxSessions = maxSessions;
    }
    return self;
}

+ (instancetype)defaultLimit {
    return [[StorageLimit alloc] initWithMaxSizeMB:100  // 100MB
                                        maxPackets:10000  // 10,000 packets
                                       maxSessions:10];  // 10 sessions
}

+ (instancetype)unlimited {
    return [[StorageLimit alloc] initWithMaxSizeMB:0  // 0 means unlimited
                                        maxPackets:0
                                       maxSessions:0];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _maxSizeMB = [coder decodeIntegerForKey:@"maxSizeMB"];
        _maxPackets = [coder decodeIntegerForKey:@"maxPackets"];
        _maxSessions = [coder decodeIntegerForKey:@"maxSessions"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.maxSizeMB forKey:@"maxSizeMB"];
    [coder encodeInteger:self.maxPackets forKey:@"maxPackets"];
    [coder encodeInteger:self.maxSessions forKey:@"maxSessions"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    StorageLimit *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_maxSizeMB = self.maxSizeMB;
        copy->_maxPackets = self.maxPackets;
        copy->_maxSessions = self.maxSessions;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<StorageLimit: maxSize=%ldMB, maxPackets=%ld, maxSessions=%ld>",
            (long)self.maxSizeMB, (long)self.maxPackets, (long)self.maxSessions];
}

@end

@implementation CaptureSettings

- (instancetype)initWithDefaultBufferSize:(NSUInteger)defaultBufferSize
                        autoStartOnLaunch:(BOOL)autoStartOnLaunch
                           defaultFilters:(NSArray<NSDictionary *> *)defaultFilters
                             storageLimit:(StorageLimit *)storageLimit {
    self = [super init];
    if (self) {
        _defaultBufferSize = defaultBufferSize;
        _autoStartOnLaunch = autoStartOnLaunch;
        _defaultFilters = [defaultFilters copy];
        _storageLimit = storageLimit;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _defaultBufferSize = [coder decodeIntegerForKey:@"defaultBufferSize"];
        _autoStartOnLaunch = [coder decodeBoolForKey:@"autoStartOnLaunch"];
        _defaultFilters = [coder decodeObjectForKey:@"defaultFilters"];
        _storageLimit = [coder decodeObjectForKey:@"storageLimit"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.defaultBufferSize forKey:@"defaultBufferSize"];
    [coder encodeBool:self.autoStartOnLaunch forKey:@"autoStartOnLaunch"];
    [coder encodeObject:self.defaultFilters forKey:@"defaultFilters"];
    [coder encodeObject:self.storageLimit forKey:@"storageLimit"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CaptureSettings *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_defaultBufferSize = self.defaultBufferSize;
        copy->_autoStartOnLaunch = self.autoStartOnLaunch;
        copy->_defaultFilters = [self.defaultFilters copyWithZone:zone];
        copy->_storageLimit = [self.storageLimit copyWithZone:zone];
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<CaptureSettings: bufferSize=%ld, autoStart=%d, filters=%ld>",
            (long)self.defaultBufferSize, self.autoStartOnLaunch, (long)self.defaultFilters.count];
}

@end

@implementation VPNSettings

- (instancetype)initWithDefaultProtocol:(VPNProtocol)defaultProtocol
                          autoReconnect:(BOOL)autoReconnect
                             killSwitch:(BOOL)killSwitch
                      dnsLeakProtection:(BOOL)dnsLeakProtection {
    self = [super init];
    if (self) {
        _defaultProtocol = defaultProtocol;
        _autoReconnect = autoReconnect;
        _killSwitch = killSwitch;
        _dnsLeakProtection = dnsLeakProtection;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _defaultProtocol = [coder decodeIntegerForKey:@"defaultProtocol"];
        _autoReconnect = [coder decodeBoolForKey:@"autoReconnect"];
        _killSwitch = [coder decodeBoolForKey:@"killSwitch"];
        _dnsLeakProtection = [coder decodeBoolForKey:@"dnsLeakProtection"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.defaultProtocol forKey:@"defaultProtocol"];
    [coder encodeBool:self.autoReconnect forKey:@"autoReconnect"];
    [coder encodeBool:self.killSwitch forKey:@"killSwitch"];
    [coder encodeBool:self.dnsLeakProtection forKey:@"dnsLeakProtection"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    VPNSettings *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_defaultProtocol = self.defaultProtocol;
        copy->_autoReconnect = self.autoReconnect;
        copy->_killSwitch = self.killSwitch;
        copy->_dnsLeakProtection = self.dnsLeakProtection;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<VPNSettings: protocol=%ld, autoReconnect=%d, killSwitch=%d, dnsLeakProtection=%d>",
            (long)self.defaultProtocol, self.autoReconnect, self.killSwitch, self.dnsLeakProtection];
}

@end

@implementation UISettings

- (instancetype)initWithTheme:(AppTheme)theme
                     language:(AppLanguage)language
                  refreshRate:(NSTimeInterval)refreshRate
           showAdvancedOptions:(BOOL)showAdvancedOptions {
    self = [super init];
    if (self) {
        _theme = theme;
        _language = language;
        _refreshRate = refreshRate;
        _showAdvancedOptions = showAdvancedOptions;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _theme = [coder decodeIntegerForKey:@"theme"];
        _language = [coder decodeIntegerForKey:@"language"];
        _refreshRate = [coder decodeDoubleForKey:@"refreshRate"];
        _showAdvancedOptions = [coder decodeBoolForKey:@"showAdvancedOptions"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.theme forKey:@"theme"];
    [coder encodeInteger:self.language forKey:@"language"];
    [coder encodeDouble:self.refreshRate forKey:@"refreshRate"];
    [coder encodeBool:self.showAdvancedOptions forKey:@"showAdvancedOptions"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    UISettings *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_theme = self.theme;
        copy->_language = self.language;
        copy->_refreshRate = self.refreshRate;
        copy->_showAdvancedOptions = self.showAdvancedOptions;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<UISettings: theme=%ld, language=%ld, refreshRate=%.2f, showAdvanced=%d>",
            (long)self.theme, (long)self.language, self.refreshRate, self.showAdvancedOptions];
}

@end

@implementation ExportSettings

- (instancetype)initWithDefaultFormat:(ExportFormat)defaultFormat
                           compression:(BOOL)compression
                        includeMetadata:(BOOL)includeMetadata {
    self = [super init];
    if (self) {
        _defaultFormat = defaultFormat;
        _compression = compression;
        _includeMetadata = includeMetadata;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _defaultFormat = [coder decodeIntegerForKey:@"defaultFormat"];
        _compression = [coder decodeBoolForKey:@"compression"];
        _includeMetadata = [coder decodeBoolForKey:@"includeMetadata"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.defaultFormat forKey:@"defaultFormat"];
    [coder encodeBool:self.compression forKey:@"compression"];
    [coder encodeBool:self.includeMetadata forKey:@"includeMetadata"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ExportSettings *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_defaultFormat = self.defaultFormat;
        copy->_compression = self.compression;
        copy->_includeMetadata = self.includeMetadata;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ExportSettings: format=%ld, compression=%d, includeMetadata=%d>",
            (long)self.defaultFormat, self.compression, self.includeMetadata];
}

@end

@implementation PrivacySettings

- (instancetype)initWithEncryptStorage:(BOOL)encryptStorage
                          clearOnClose:(BOOL)clearOnClose
                          anonymizeIPs:(BOOL)anonymizeIPs {
    self = [super init];
    if (self) {
        _encryptStorage = encryptStorage;
        _clearOnClose = clearOnClose;
        _anonymizeIPs = anonymizeIPs;
    }
    return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _encryptStorage = [coder decodeBoolForKey:@"encryptStorage"];
        _clearOnClose = [coder decodeBoolForKey:@"clearOnClose"];
        _anonymizeIPs = [coder decodeBoolForKey:@"anonymizeIPs"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.encryptStorage forKey:@"encryptStorage"];
    [coder encodeBool:self.clearOnClose forKey:@"clearOnClose"];
    [coder encodeBool:self.anonymizeIPs forKey:@"anonymizeIPs"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PrivacySettings *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_encryptStorage = self.encryptStorage;
        copy->_clearOnClose = self.clearOnClose;
        copy->_anonymizeIPs = self.anonymizeIPs;
    }
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<PrivacySettings: encryptStorage=%d, clearOnClose=%d, anonymizeIPs=%d>",
            self.encryptStorage, self.clearOnClose, self.anonymizeIPs];
}

@end

@implementation AppConfiguration

- (instancetype)initWithCaptureSettings:(CaptureSettings *)captureSettings
                            vpnSettings:(VPNSettings *)vpnSettings
                             uiSettings:(UISettings *)uiSettings
                         exportSettings:(ExportSettings *)exportSettings
                         privacySettings:(PrivacySettings *)privacySettings {
    self = [super init];
    if (self) {
        _captureSettings = captureSettings;
        _vpnSettings = vpnSettings;
        _uiSettings = uiSettings;
        _exportSettings = exportSettings;
        _privacySettings = privacySettings;
    }
    return self;
}

+ (instancetype)defaultConfiguration {
    CaptureSettings *captureSettings = [[CaptureSettings alloc] initWithDefaultBufferSize:65536
                                                                        autoStartOnLaunch:NO
                                                                           defaultFilters:@[]
                                                                             storageLimit:[StorageLimit defaultLimit]];
    
    VPNSettings *vpnSettings = [[VPNSettings alloc] initWithDefaultProtocol:VPNProtocolWireGuard
                                                              autoReconnect:YES
                                                                 killSwitch:YES
                                                          dnsLeakProtection:YES];
    
    UISettings *uiSettings = [[UISettings alloc] initWithTheme:AppThemeSystem
                                                      language:AppLanguageEnglish
                                                   refreshRate:1.0  // 1 second
                                            showAdvancedOptions:NO];
    
    ExportSettings *exportSettings = [[ExportSettings alloc] initWithDefaultFormat:ExportFormatPCAP
                                                                        compression:YES
                                                                   includeMetadata:YES];
    
    PrivacySettings *privacySettings = [[PrivacySettings alloc] initWithEncryptStorage:YES
                                                                          clearOnClose:NO
                                                                          anonymizeIPs:NO];
    
    return [[AppConfiguration alloc] initWithCaptureSettings:captureSettings
                                                 vpnSettings:vpnSettings
                                                  uiSettings:uiSettings
                                              exportSettings:exportSettings
                                            privacySettings:privacySettings];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _captureSettings = [coder decodeObjectForKey:@"captureSettings"];
        _vpnSettings = [coder decodeObjectForKey:@"vpnSettings"];
        _uiSettings = [coder decodeObjectForKey:@"uiSettings"];
        _exportSettings = [coder decodeObjectForKey:@"exportSettings"];
        _privacySettings = [coder decodeObjectForKey:@"privacySettings"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.captureSettings forKey:@"captureSettings"];
    [coder encodeObject:self.vpnSettings forKey:@"vpnSettings"];
    [coder encodeObject:self.uiSettings forKey:@"uiSettings"];
    [coder encodeObject:self.exportSettings forKey:@"exportSettings"];
    [coder encodeObject:self.privacySettings forKey:@"privacySettings"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    AppConfiguration *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_captureSettings = [self.captureSettings copyWithZone:zone];
        copy->_vpnSettings = [self.vpnSettings copyWithZone:zone];
        copy->_uiSettings = [self.uiSettings copyWithZone:zone];
        copy->_exportSettings = [self.exportSettings copyWithZone:zone];
        copy->_privacySettings = [self.privacySettings copyWithZone:zone];
    }
    return copy;
}

#pragma mark - JSON Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (self.captureSettings) {
        NSMutableDictionary *captureDict = [NSMutableDictionary dictionary];
        captureDict[@"defaultBufferSize"] = @(self.captureSettings.defaultBufferSize);
        captureDict[@"autoStartOnLaunch"] = @(self.captureSettings.autoStartOnLaunch);
        captureDict[@"defaultFilters"] = self.captureSettings.defaultFilters ?: @[];
        
        if (self.captureSettings.storageLimit) {
            NSMutableDictionary *storageDict = [NSMutableDictionary dictionary];
            storageDict[@"maxSizeMB"] = @(self.captureSettings.storageLimit.maxSizeMB);
            storageDict[@"maxPackets"] = @(self.captureSettings.storageLimit.maxPackets);
            storageDict[@"maxSessions"] = @(self.captureSettings.storageLimit.maxSessions);
            captureDict[@"storageLimit"] = storageDict;
        }
        
        dict[@"captureSettings"] = captureDict;
    }
    
    if (self.vpnSettings) {
        NSMutableDictionary *vpnDict = [NSMutableDictionary dictionary];
        vpnDict[@"defaultProtocol"] = [self protocolString:self.vpnSettings.defaultProtocol];
        vpnDict[@"autoReconnect"] = @(self.vpnSettings.autoReconnect);
        vpnDict[@"killSwitch"] = @(self.vpnSettings.killSwitch);
        vpnDict[@"dnsLeakProtection"] = @(self.vpnSettings.dnsLeakProtection);
        dict[@"vpnSettings"] = vpnDict;
    }
    
    if (self.uiSettings) {
        NSMutableDictionary *uiDict = [NSMutableDictionary dictionary];
        uiDict[@"theme"] = [self themeString:self.uiSettings.theme];
        uiDict[@"language"] = [self languageString:self.uiSettings.language];
        uiDict[@"refreshRate"] = @(self.uiSettings.refreshRate);
        uiDict[@"showAdvancedOptions"] = @(self.uiSettings.showAdvancedOptions);
        dict[@"uiSettings"] = uiDict;
    }
    
    if (self.exportSettings) {
        NSMutableDictionary *exportDict = [NSMutableDictionary dictionary];
        exportDict[@"defaultFormat"] = [self exportFormatString:self.exportSettings.defaultFormat];
        exportDict[@"compression"] = @(self.exportSettings.compression);
        exportDict[@"includeMetadata"] = @(self.exportSettings.includeMetadata);
        dict[@"exportSettings"] = exportDict;
    }
    
    if (self.privacySettings) {
        NSMutableDictionary *privacyDict = [NSMutableDictionary dictionary];
        privacyDict[@"encryptStorage"] = @(self.privacySettings.encryptStorage);
        privacyDict[@"clearOnClose"] = @(self.privacySettings.clearOnClose);
        privacyDict[@"anonymizeIPs"] = @(self.privacySettings.anonymizeIPs);
        dict[@"privacySettings"] = privacyDict;
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return [self defaultConfiguration];
    }
    
    CaptureSettings *captureSettings = nil;
    NSDictionary *captureDict = dictionary[@"captureSettings"];
    if ([captureDict isKindOfClass:[NSDictionary class]]) {
        NSUInteger defaultBufferSize = [captureDict[@"defaultBufferSize"] unsignedIntegerValue];
        BOOL autoStartOnLaunch = [captureDict[@"autoStartOnLaunch"] boolValue];
        NSArray *defaultFilters = captureDict[@"defaultFilters"] ?: @[];
        
        StorageLimit *storageLimit = [StorageLimit defaultLimit];
        NSDictionary *storageDict = captureDict[@"storageLimit"];
        if ([storageDict isKindOfClass:[NSDictionary class]]) {
            NSUInteger maxSizeMB = [storageDict[@"maxSizeMB"] unsignedIntegerValue];
            NSUInteger maxPackets = [storageDict[@"maxPackets"] unsignedIntegerValue];
            NSUInteger maxSessions = [storageDict[@"maxSessions"] unsignedIntegerValue];
            storageLimit = [[StorageLimit alloc] initWithMaxSizeMB:maxSizeMB
                                                        maxPackets:maxPackets
                                                       maxSessions:maxSessions];
        }
        
        captureSettings = [[CaptureSettings alloc] initWithDefaultBufferSize:defaultBufferSize
                                                           autoStartOnLaunch:autoStartOnLaunch
                                                              defaultFilters:defaultFilters
                                                                storageLimit:storageLimit];
    } else {
        captureSettings = [[CaptureSettings alloc] initWithDefaultBufferSize:65536
                                                           autoStartOnLaunch:NO
                                                              defaultFilters:@[]
                                                                storageLimit:[StorageLimit defaultLimit]];
    }
    
    VPNSettings *vpnSettings = nil;
    NSDictionary *vpnDict = dictionary[@"vpnSettings"];
    if ([vpnDict isKindOfClass:[NSDictionary class]]) {
        VPNProtocol defaultProtocol = [self protocolFromString:vpnDict[@"defaultProtocol"]];
        BOOL autoReconnect = [vpnDict[@"autoReconnect"] boolValue];
        BOOL killSwitch = [vpnDict[@"killSwitch"] boolValue];
        BOOL dnsLeakProtection = [vpnDict[@"dnsLeakProtection"] boolValue];
        
        vpnSettings = [[VPNSettings alloc] initWithDefaultProtocol:defaultProtocol
                                                     autoReconnect:autoReconnect
                                                        killSwitch:killSwitch
                                                 dnsLeakProtection:dnsLeakProtection];
    } else {
        vpnSettings = [[VPNSettings alloc] initWithDefaultProtocol:VPNProtocolWireGuard
                                                     autoReconnect:YES
                                                        killSwitch:YES
                                                 dnsLeakProtection:YES];
    }
    
    UISettings *uiSettings = nil;
    NSDictionary *uiDict = dictionary[@"uiSettings"];
    if ([uiDict isKindOfClass:[NSDictionary class]]) {
        AppTheme theme = [self themeFromString:uiDict[@"theme"]];
        AppLanguage language = [self languageFromString:uiDict[@"language"]];
        NSTimeInterval refreshRate = [uiDict[@"refreshRate"] doubleValue];
        BOOL showAdvancedOptions = [uiDict[@"showAdvancedOptions"] boolValue];
        
        uiSettings = [[UISettings alloc] initWithTheme:theme
                                              language:language
                                           refreshRate:refreshRate
                                    showAdvancedOptions:showAdvancedOptions];
    } else {
        uiSettings = [[UISettings alloc] initWithTheme:AppThemeSystem
                                              language:AppLanguageEnglish
                                           refreshRate:1.0
                                    showAdvancedOptions:NO];
    }
    
    ExportSettings *exportSettings = nil;
    NSDictionary *exportDict = dictionary[@"exportSettings"];
    if ([exportDict isKindOfClass:[NSDictionary class]]) {
        ExportFormat defaultFormat = [self exportFormatFromString:exportDict[@"defaultFormat"]];
        BOOL compression = [exportDict[@"compression"] boolValue];
        BOOL includeMetadata = [exportDict[@"includeMetadata"] boolValue];
        
        exportSettings = [[ExportSettings alloc] initWithDefaultFormat:defaultFormat
                                                            compression:compression
                                                       includeMetadata:includeMetadata];
    } else {
        exportSettings = [[ExportSettings alloc] initWithDefaultFormat:ExportFormatPCAP
                                                            compression:YES
                                                       includeMetadata:YES];
    }
    
    PrivacySettings *privacySettings = nil;
    NSDictionary *privacyDict = dictionary[@"privacySettings"];
    if ([privacyDict isKindOfClass:[NSDictionary class]]) {
        BOOL encryptStorage = [privacyDict[@"encryptStorage"] boolValue];
        BOOL clearOnClose = [privacyDict[@"clearOnClose"] boolValue];
        BOOL anonymizeIPs = [privacyDict[@"anonymizeIPs"] boolValue];
        
        privacySettings = [[PrivacySettings alloc] initWithEncryptStorage:encryptStorage
                                                             clearOnClose:clearOnClose
                                                             anonymizeIPs:anonymizeIPs];
    } else {
        privacySettings = [[PrivacySettings alloc] initWithEncryptStorage:YES
                                                             clearOnClose:NO
                                                             anonymizeIPs:NO];
    }
    
    return [[AppConfiguration alloc] initWithCaptureSettings:captureSettings
                                                 vpnSettings:vpnSettings
                                                  uiSettings:uiSettings
                                              exportSettings:exportSettings
                                            privacySettings:privacySettings];
}

#pragma mark - String Conversion Helpers

- (NSString *)protocolString:(VPNProtocol)protocol {
    switch (protocol) {
        case VPNProtocolWireGuard: return @"WireGuard";
        case VPNProtocolOpenVPN: return @"OpenVPN";
        case VPNProtocolIKEv2: return @"IKEv2";
        default: return @"WireGuard";
    }
}

+ (VPNProtocol)protocolFromString:(NSString *)string {
    if ([string isEqualToString:@"WireGuard"]) return VPNProtocolWireGuard;
    if ([string isEqualToString:@"OpenVPN"]) return VPNProtocolOpenVPN;
    if ([string isEqualToString:@"IKEv2"]) return VPNProtocolIKEv2;
    return VPNProtocolWireGuard;
}

- (NSString *)themeString:(AppTheme)theme {
    switch (theme) {
        case AppThemeLight: return @"light";
        case AppThemeDark: return @"dark";
        case AppThemeSystem: return @"system";
        default: return @"system";
    }
}

+ (AppTheme)themeFromString:(NSString *)string {
    if ([string isEqualToString:@"light"]) return AppThemeLight;
    if ([string isEqualToString:@"dark"]) return AppThemeDark;
    if ([string isEqualToString:@"system"]) return AppThemeSystem;
    return AppThemeSystem;
}

- (NSString *)languageString:(AppLanguage)language {
    switch (language) {
        case AppLanguageEnglish: return @"en";
        case AppLanguageChinese: return @"zh";
        case AppLanguageJapanese: return @"ja";
        case AppLanguageSpanish: return @"es";
        case AppLanguageFrench: return @"fr";
        default: return @"en";
    }
}

+ (AppLanguage)languageFromString:(NSString *)string {
    if ([string isEqualToString:@"en"]) return AppLanguageEnglish;
    if ([string isEqualToString:@"zh"]) return AppLanguageChinese;
    if ([string isEqualToString:@"ja"]) return AppLanguageJapanese;
    if ([string isEqualToString:@"es"]) return AppLanguageSpanish;
    if ([string isEqualToString:@"fr"]) return AppLanguageFrench;
    return AppLanguageEnglish;
}

- (NSString *)exportFormatString:(ExportFormat)format {
    switch (format) {
        case ExportFormatPCAP: return @"pcap";
        case ExportFormatJSON: return @"json";
        case ExportFormatCSV: return @"csv";
        default: return @"pcap";
    }
}

+ (ExportFormat)exportFormatFromString:(NSString *)string {
    if ([string isEqualToString:@"pcap"]) return ExportFormatPCAP;
    if ([string isEqualToString:@"json"]) return ExportFormatJSON;
    if ([string isEqualToString:@"csv"]) return ExportFormatCSV;
    return ExportFormatPCAP;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<AppConfiguration: captureSettings=%@, vpnSettings=%@, uiSettings=%@>",
            self.captureSettings, self.vpnSettings, self.uiSettings];
}

@end