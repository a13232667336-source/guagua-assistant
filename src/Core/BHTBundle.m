//
//  BHTBundle.m
//  呱呱助手 (Guagua Assistant)
//
//  资源包（字符串、头像）查找：越狱路径 → dylib 同目录 → app 内各层目录 →
//  旧版 BHTwitter.bundle 名称回落。注入器把 bundle 放在哪一层都能找到。
//

#import "BHTBundle.h"
#import <dlfcn.h>

@interface BHTBundle ()
@property (nonatomic, strong) NSBundle* mainBundle;
@end

static NSString* const kGuaguaBundleName = @"Guagua.bundle";
static NSString* const kLegacyBundleName = @"BHTwitter.bundle";

static BOOL NFBFileExists(NSString* path) {
    return path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

// 当前二进制的所在目录：TrollFools / 侧载注入时 bundle 通常和 dylib 放一起。
static NSString* NFBDylibDirectory(void) {
    Dl_info info;
    if (dladdr((const void*)&NFBDylibDirectory, &info) != 0 && info.dli_fname != NULL) {
        NSString* path = [NSString stringWithUTF8String:info.dli_fname];
        if (path.length > 0) {
            return [path stringByDeletingLastPathComponent];
        }
    }
    return nil;
}

static NSURL* NFBFindBundleURL(void) {
    NSMutableArray<NSString*>* candidates = [NSMutableArray array];

    // 1) 越狱 / rootless 安装路径
    [candidates addObject:[@"/Library/Application Support/Guagua/" stringByAppendingString:kGuaguaBundleName]];
    [candidates addObject:[@"/var/jb/Library/Application Support/Guagua/"
                            stringByAppendingString:kGuaguaBundleName]];
    [candidates addObject:[@"/Library/Application Support/BHT/" stringByAppendingString:kLegacyBundleName]];
    [candidates addObject:[@"/var/jb/Library/Application Support/BHT/"
                            stringByAppendingString:kLegacyBundleName]];

    // 2) dylib 同目录 + app 内常见层级（TrollFools 注入位置）
    NSString* dylibDir = NFBDylibDirectory();
    NSString* appPath = [[NSBundle mainBundle] bundlePath];
    NSArray<NSString*>* roots = @[
        dylibDir ?: @"",
        appPath ?: @"",
        appPath ? [appPath stringByAppendingPathComponent:@"Frameworks"] : @"",
        appPath ? [appPath stringByAppendingPathComponent:@"PlugIns"] : @"",
        appPath ? [appPath stringByAppendingPathComponent:@"TweakInject"] : @"",
    ];
    for (NSString* root in roots) {
        if (root.length == 0) {
            continue;
        }
        [candidates addObject:[root stringByAppendingPathComponent:kGuaguaBundleName]];
        [candidates addObject:[root stringByAppendingPathComponent:kLegacyBundleName]];
    }

    for (NSString* candidate in candidates) {
        if (NFBFileExists(candidate)) {
            return [NSURL fileURLWithPath:candidate];
        }
    }

    // 3) 最后让 NSBundle 自己按名字找，并扫一层子目录兜底
    for (NSString* name in @[ @"Guagua", @"BHTwitter" ]) {
        NSURL* url = [[NSBundle mainBundle] URLForResource:name withExtension:@"bundle"];
        if (url) {
            return url;
        }
    }
    if (appPath.length > 0) {
        for (NSString* sub in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appPath
                                                                                 error:nil]) {
            if ([sub isEqualToString:kGuaguaBundleName] || [sub isEqualToString:kLegacyBundleName]) {
                NSString* path = [appPath stringByAppendingPathComponent:sub];
                if (NFBFileExists(path)) {
                    return [NSURL fileURLWithPath:path];
                }
            }
        }
    }
    return nil;
}

@implementation BHTBundle

+ (instancetype)sharedBundle {
    static BHTBundle* sharedBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedBundle = [[self alloc] initWithBundlePath:NFBFindBundleURL()];
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
