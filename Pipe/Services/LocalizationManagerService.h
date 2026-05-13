//
//  LocalizationManagerService.h
//  Pipe
//

#import <Foundation/Foundation.h>
#import "../Models/AppConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalizationManagerService : NSObject

+ (instancetype)sharedService;

/// Override device language when non-nil.
@property (nonatomic, assign) AppLanguage preferredLanguage;

- (void)applyPreferredLanguageFromUISettings:(UISettings *)uiSettings;

/// Localized string with optional printf-style args (single %@ or %d supported in value).
- (NSString *)stringForKey:(NSString *)key;

- (NSString *)stringForKey:(NSString *)key arguments:(NSArray<id> *)arguments;

@end

NS_ASSUME_NONNULL_END
