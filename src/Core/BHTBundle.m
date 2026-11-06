//
//  BHTBundle.m
//  BHTwitter
//
//  Created by BandarHelal on 07/08/2022.
//

#import "BHTBundle.h"
#import "Core/NFBEmbedded.h"

@interface BHTBundle ()
@property (nonatomic, strong) NSBundle* mainBundle;
@end

@implementation BHTBundle
+ (instancetype)sharedBundle {
    static BHTBundle* sharedBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSURL* bundlePath = nil;
        if ([fileManager
                fileExistsAtPath:
                    @"/Library/Application Support/BHT/BHTwitter.bundle"]) {
            bundlePath = [NSURL
                fileURLWithPath:@"/Library/Application Support/BHT/BHTwitter.bundle"];
        } else if ([fileManager fileExistsAtPath:@"/var/jb/Library/Application "
                                                 @"Support/BHT/BHTwitter.bundle"]) {
            bundlePath = [NSURL
                fileURLWithPath:
                    @"/var/jb/Library/Application Support/BHT/BHTwitter.bundle"];
        } else {
            bundlePath = [[NSBundle mainBundle] URLForResource:@"BHTwitter"
                                                 withExtension:@"bundle"];
        }

        sharedBundle = [[self alloc] initWithBundlePath:bundlePath];
    });
    return sharedBundle;
}
- (instancetype)initWithBundlePath:(NSURL*)bundlePath {
    if (self = [super init]) {
        self.mainBundle = [NSBundle bundleWithPath:[bundlePath path]];
    }

    return self;
}

- (NSString*)localizedStringForKey:(NSString*)key {
    NSString* value = [self.mainBundle localizedStringForKey:key value:nil table:nil];
    if (value.length > 0) {
        return value;
    }
    // 资源包缺失时用编译进二进制的字符串表兜底，避免这里返回 nil 导致设置入口标题为空
    NSString* embedded = NFBEmbeddedString(key);
    return embedded.length ? embedded : key;
}

// Fetches one of Twitter's own strings, reusing the app's translations for
// every language. These flow through the terminology rename hook like any app
// string.
- (NSString*)localizedTwitterStringForKey:(NSString*)key {
    static NSBundle* twitterBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* path =
            [[NSBundle mainBundle] pathForResource:@"Localization_Localization"
                                            ofType:@"bundle"];
        twitterBundle =
            path ? [NSBundle bundleWithPath:path] : [NSBundle mainBundle];
    });
    return [twitterBundle localizedStringForKey:key value:key table:nil];
}
- (NSURL*)pathForFile:(NSString*)fileName {
    return [self.mainBundle URLForResource:fileName withExtension:nil];
}
@end
