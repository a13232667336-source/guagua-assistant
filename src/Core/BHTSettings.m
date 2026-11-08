//
//  BHTSettings.m
//  呱呱助手
//
//  Created by nyaathea
//

#import "Core/BHTSettings.h"
#import "Core/BHTBundle.h"
#import "Core/BHTManager.h"

static NSDictionary<NSString*, NSDictionary*>* BHTSettingsPages(void) {
    static NSDictionary<NSString*, NSDictionary*>* pages;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pages = @{
            @"general" : @{
                @"titleKey" : @"MODERN_SETTINGS_LAYOUT_TITLE",
                @"subtitleKey" : @"MODERN_SETTINGS_LAYOUT_SUBTITLE",
                @"settings" : @[
                    @{@"key" : @"hide_promoted", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"hide_premium_offer", @"default" : @YES, @"type" : @"toggle"}
                ]
            },
            @"timelines" : @{
                @"titleKey" : @"MODERN_SETTINGS_TIMELINES_TITLE",
                @"subtitleKey" : @"MODERN_SETTINGS_TIMELINES_SUBTITLE",
                @"settings" : @[
                    @{@"key" : @"hide_who_to_follow", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"hide_timeline_prompts", @"default" : @YES, @"type" : @"toggle"}
                ]
            },
            @"media_downloads" : @{
                @"titleKey" : @"MODERN_SETTINGS_MEDIA_TITLE",
                @"subtitleKey" : @"MODERN_SETTINGS_MEDIA_SUBTITLE",
                @"settings" : @[
                    @{@"key" : @"download_videos", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"download_highest_quality", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"download_all_videos", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"direct_save", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"auto_highest_load", @"default" : @YES, @"type" : @"toggle"},
                    @{@"key" : @"restore_video_timestamp", @"default" : @YES, @"type" : @"toggle"}
                ]
            }
        };
    });
    return pages;
}

static NSDictionary<NSString*, NSDictionary*>* BHTSettingsIndex(void) {
    static NSDictionary<NSString*, NSDictionary*>* index;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString*, NSDictionary*>* map =
            [NSMutableDictionary dictionary];
        for (NSDictionary* page in BHTSettingsPages().allValues) {
            for (NSDictionary* setting in page[@"settings"]) {
                NSString* key = setting[@"key"];
                if (key) {
                    map[key] = setting;
                }
            }
        }
        index = [map copy];
    });
    return index;
}

@implementation BHTSettings

#pragma mark - Migration

// One-time migration of preferences saved under the old (inconsistent) key
// names to the normalised keys, so existing installs keep their settings.
+ (void)load {
    [self migrateUndoTweetToggle];
    [self synchronizeDownloadMasterToggles];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"nfb_key_migration_v1_done"]) {
        return;
    }

    NSDictionary<NSString*, NSString*>* renamedKeys = @{
        @"dis_rtl": @"disable_rtl",
        @"showScollIndicator": @"show_scroll_indicator",
        @"en_font": @"custom_fonts",
        @"dw_v": @"download_videos",
        @"video_layer_caption": @"disable_video_captions",
        @"autoHighestLoad": @"auto_highest_load",
        @"follow_con": @"follow_confirm",
        @"CopyProfileInfo": @"copy_profile_info",
        @"disableArticles": @"disable_articles",
        @"disableHighlights": @"disable_highlights",
        @"TweetToImage": @"tweet_to_image",
        @"like_con": @"like_confirm",
        @"tweet_con": @"tweet_confirm",
        @"disableSensitiveTweetWarnings": @"disable_sensitive_tweet_warnings",
        @"no_his": @"no_history",
        @"openInBrowser": @"always_open_safari",
        @"reply_sorting_enabled": @"reply_sorting",
        @"ios_in_app_article_webview_enabled": @"new_inapp_webview",
        @"tweet_url_host": @"sharing_domain",
    };

    // These old names double as Twitter's own feature-switch keys, so copy the
    // value across but leave the original in place rather than risk removing it.
    NSSet<NSString*>* sharedWithTwitter = [NSSet setWithArray:@[
        @"reply_sorting_enabled",
        @"ios_in_app_article_webview_enabled",
    ]];

    [renamedKeys enumerateKeysAndObjectsUsingBlock:^(
                     NSString* oldKey, NSString* newKey, BOOL* stop) {
        id value = [defaults objectForKey:oldKey];
        if (value == nil) {
            return;
        }
        if ([defaults objectForKey:newKey] == nil) {
            [defaults setObject:value forKey:newKey];
        }
        if (![sharedWithTwitter containsObject:oldKey]) {
            [defaults removeObjectForKey:oldKey];
        }
    }];

    [defaults setBool:YES forKey:@"nfb_key_migration_v1_done"];
}

// The Undo Tweet on/off toggle was merged into the timeout picker, where a
// timeout of 0 means off. Carry a prior "off" state across as a 0 timeout.
+ (void)migrateUndoTweetToggle {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"nfb_undo_timeout_migration_done"]) {
        return;
    }

    id oldToggle = [defaults objectForKey:@"undo_tweet"];
    if (oldToggle != nil && ![oldToggle boolValue] &&
        [defaults objectForKey:@"undo_tweet_timeout"] == nil) {
        [defaults setInteger:0 forKey:@"undo_tweet_timeout"];
    }
    [defaults removeObjectForKey:@"undo_tweet"];
    [defaults setBool:YES forKey:@"nfb_undo_timeout_migration_done"];
}

#pragma mark - Accessors

+ (NSArray<NSDictionary*>*)settingsForPage:(NSString*)pageKey {
    return pageKey ? BHTSettingsPages()[pageKey][@"settings"] : nil;
}

+ (NSString*)titleKeyForPage:(NSString*)pageKey {
    return pageKey ? BHTSettingsPages()[pageKey][@"titleKey"] : nil;
}

+ (NSString*)subtitleKeyForPage:(NSString*)pageKey {
    return pageKey ? BHTSettingsPages()[pageKey][@"subtitleKey"] : nil;
}

+ (NSDictionary*)settingForKey:(NSString*)key {
    return key ? BHTSettingsIndex()[key] : nil;
}

// A row backs a preference when it carries a default (toggles and pickers) or
// renders a stored value as its subtitle (the font and sharing domain rows,
// whose own key is just a row identifier).
+ (NSArray<NSString*>*)allPreferenceKeys {
    static NSArray<NSString*>* keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableOrderedSet<NSString*>* collected = [NSMutableOrderedSet orderedSet];
        for (NSDictionary* page in BHTSettingsPages().allValues) {
            for (NSDictionary* setting in page[@"settings"]) {
                NSString* key = setting[@"key"];
                if (key && setting[@"default"]) {
                    [collected addObject:key];
                }
                NSString* subtitleKey = setting[@"prefKeyForSubtitle"];
                if (subtitleKey) {
                    [collected addObject:subtitleKey];
                }
            }
        }
        keys = [collected.array copy];
    });
    return keys;
}

+ (BOOL)boolForKey:(NSString*)key {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (value != nil) {
        return [value boolValue];
    }
    return [[self settingForKey:key][@"default"] boolValue];
}

+ (NSInteger)integerForKey:(NSString*)key {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (value != nil) {
        return [value integerValue];
    }
    return [[self settingForKey:key][@"default"] integerValue];
}

#pragma mark - 下载媒体总开关

// 这些项不再单独出现在设置界面，全部跟随「下载媒体」：
//   始终下载最高画质 / 下载所有视频 / 保存到“照片” / 高质量媒体
+ (NSArray<NSString*>*)togglesDrivenByDownloadMaster {
    static NSArray<NSString*>* keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"download_highest_quality",
            @"download_all_videos",
            @"direct_save",
            @"auto_highest_load",
        ];
    });
    return keys;
}

+ (void)synchronizeDownloadMasterToggles {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    BOOL master = [self boolForKey:@"download_videos"];
    for (NSString* key in [self togglesDrivenByDownloadMaster]) {
        if ([defaults objectForKey:key] == nil || [defaults boolForKey:key] != master) {
            [defaults setBool:master forKey:key];
        }
    }
    [defaults synchronize];
}

+ (BOOL)downloadMasterEnabled {
    return [self boolForKey:@"download_videos"];
}

@end

