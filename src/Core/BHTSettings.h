//
//  BHTSettings.h
//  呱呱助手 (Guagua Assistant)
//

#import <Foundation/Foundation.h>

// Single source of truth for every user setting: per-page toggle lists,
// page titles and the default value used when a key was never toggled.
@interface BHTSettings : NSObject

+ (NSArray<NSDictionary*>*)settingsForPage:(NSString*)pageKey;
+ (NSString*)titleKeyForPage:(NSString*)pageKey;
+ (NSString*)subtitleKeyForPage:(NSString*)pageKey;
+ (NSDictionary*)settingForKey:(NSString*)key;

// Every NSUserDefaults key the registry owns, for bulk work like the settings
// export. Rows that only push another screen have no preference behind them and
// are left out.
+ (NSArray<NSString*>*)allPreferenceKeys;
+ (BOOL)boolForKey:(NSString*)key;
+ (NSInteger)integerForKey:(NSString*)key;

// “下载媒体”总开关：一键开通 / 一键关闭下面这一整组能力。
+ (NSArray<NSString*>*)togglesDrivenByDownloadMaster;
+ (void)synchronizeDownloadMasterToggles;
+ (BOOL)downloadMasterEnabled;

@end
