//
//  BHTBundle.m
//  呱呱助手 (Guagua Assistant)
//
//  资源包查找：优先 呱呱助手 自己的 bundle，找不到时回落到旧的
//  呱呱助手 (Guagua Assistant).bundle 名字，方便从老版本升级而不必重装资源。
//

#import "BHTBundle.h"

@interface BHTBundle ()
@property (nonatomic, strong) NSBundle* mainBundle;
@end

static NSString* const kGuaguaBundleName = @"Guagua.bundle";
static NSString* const kLegacyBundleName = @"BHTwitter.bundle";

static BOOL NFBFileExists(NSString* path) {
    return path != nil && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

@implementation BHTBundle

+ (instancetype)sharedBundle {
    static BHTBundle* sharedBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Jailbreak / rootless 布局 + TrollStore/侧载时 bundle 就在 app 里。
        NSArray<NSString*>* candidates = @[
            [@"/Library/Application Support/Guagua/" stringByAppendingString:kGuaguaBundleName],
            [@"/var/jb/Library/Application Support/Guagua/"
                stringByAppendingString:kGuaguaBundleName],
            [@"/Library/Application Support/BHT/" stringByAppendingString:kLegacyBundleName],
            [@"/var/jb/Library/Application Support/BHT/"
                stringByAppendingString:kLegacyBundleName],
        ];

        NSURL* bundlePath = nil;
        for (NSString* candidate in candidates) {
            if (NFBFileExists(candidate)) {
                bundlePath = [NSURL fileURLWithPath:candidate];
                break;
            }
        }

        if (bundlePath == nil) {
            bundlePath = [[NSBundle mainBundle] URLForResource:@"Guagua" withExtension:@"bundle"];
        }
        if (bundlePath == nil) {
            bundlePath = [[NSBundle mainBundle] URLForResource:@"BHTwitter" withExtension:@"bundle"];
        }

        sharedBundle = [[self alloc] initWithBundlePath:bundlePath];
    });
    return sharedBundle;
}

- (instancetype)initWithBundlePath:(NSURL*)bundlePath {
    if (self = [super init]) {
        self.mainBundle = bundlePath ? [NSBundle bundleWithPath:[bundlePath path]] : nil;
    }

    return self;
}

- (NSString*)localizedStringForKey:(NSString*)key {
    NSString* value = [self.mainBundle localizedStringForKey:key value:nil table:nil];
    return value.length ? value : key;
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
