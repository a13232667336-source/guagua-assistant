//
//  Settings.x
//  NeoFreeBird
//

#import "Headers/XHeaders.h"
#import "HookHelpers.h"

// MARK: - NeoFreeBird settings entry

static const void* SettingsEntryKey = &SettingsEntryKey;
static const void* SettingsRootKey = &SettingsRootKey;

static BOOL isSettingsClass(UIViewController* viewController) {
    return [viewController isKindOfClass:objc_getClass("T1GenericSettingsViewController")] ||
           [viewController isKindOfClass:objc_getClass("T1SettingsViewController")];
}

// The generic controller backs the root and every sub-page alike, so the root is
// the first settings-class controller in the navigation stack.
static BOOL settingsVCIsRoot(TFNItemsDataViewController* settingsVC) {
    for (UIViewController* viewController in settingsVC.navigationController.viewControllers) {
        if (viewController == settingsVC) {
            return YES;
        }

        if (isSettingsClass(viewController)) {
            return NO;
        }
    }

    return NO;
}

static BOOL sectionsContainNeoFreeBirdEntry(NSArray* sections) {
    for (id section in sections) {
        if (![section isKindOfClass:[NSArray class]]) {
            continue;
        }

        for (id entry in (NSArray*)section) {
            if (objc_getAssociatedObject(entry, SettingsEntryKey)) {
                return YES;
            }
        }
    }

    return NO;
}

static TFNSettingsNavigationItem* makeNeoFreeBirdSettingsItem(
    TFNItemsDataViewController* settingsVC) {
    UIColor* iconColor;
    if (@available(iOS 12.0, *)) {
        if (settingsVC.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            iconColor = [UIColor systemGray2Color];
        } else {
            iconColor = [UIColor secondaryLabelColor];
        }
    } else {
        iconColor = [UIColor secondaryLabelColor];
    }

    UIImage* twitterIcon = [UIImage tfn_vectorImageNamed:@"twitter"
                                                fitsSize:CGSizeMake(20, 20)
                                               fillColor:iconColor];

    TFNTwitterAccount* account = [(T1GenericSettingsViewController*)settingsVC account];
    TFNSettingsNavigationItem* bhtwitter = [[objc_getClass("TFNSettingsNavigationItem") alloc]
            initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"]
                   detail:[[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_DETAIL"]
                 iconName:nil
        controllerFactory:^UIViewController* {
            return [BHTManager BHTSettingsWithAccount:account];
        }];

    if (twitterIcon) {
        [bhtwitter setValue:twitterIcon forKey:@"icon"];
    }

    objc_setAssociatedObject(bhtwitter, SettingsEntryKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return bhtwitter;
}

static NSArray* sectionsByInsertingEntry(TFNItemsDataViewController* settingsVC,
                                         NSArray* sections) {
    NSMutableArray* newSections = [sections mutableCopy] ?: [NSMutableArray array];
    [newSections insertObject:@[makeNeoFreeBirdSettingsItem(settingsVC)] atIndex:0];
    return newSections;
}

// Async settings fetches rebuild the sections and discard one-shot inserts, and
// root-ness is unknowable during the first build (not yet on the nav stack). So
// tag the root in viewWillAppear, insert once to repair the first build, and let
// the rebuild transform below re-add the entry on every later snapshot.
static void insertNeoFreeBirdSettingsIfRoot(TFNItemsDataViewController* settingsVC) {
    if (!settingsVCIsRoot(settingsVC)) {
        return;
    }

    objc_setAssociatedObject(settingsVC, SettingsRootKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (sectionsContainNeoFreeBirdEntry(settingsVC.sections)) {
        return;
    }

    settingsVC.sections = sectionsByInsertingEntry(settingsVC, settingsVC.sections);
}

static NSArray* sectionsWithNeoFreeBirdEntry(TFNItemsDataViewController* settingsVC,
                                             NSArray* sections) {
    if (!isSettingsClass(settingsVC)) {
        return sections;
    }

    if (![objc_getAssociatedObject(settingsVC, SettingsRootKey) boolValue]) {
        return sections;
    }

    if (sectionsContainNeoFreeBirdEntry(sections)) {
        return sections;
    }

    return sectionsByInsertingEntry(settingsVC, sections);
}

%hook T1GenericSettingsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    insertNeoFreeBirdSettingsIfRoot(self);
}
%end

%hook T1SettingsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    insertNeoFreeBirdSettingsIfRoot(self);
}
%end

// Every sections rebuild runs through this transform right before setSections:,
// so hooking it on the base class covers both settings roots.
%hook TFNItemsDataViewController
- (NSArray*)updatedSections:(NSArray*)sections forStyle:(NSInteger)style {
    NSArray* updatedSections = %orig;
    return sectionsWithNeoFreeBirdEntry(self, updatedSections);
}
%end

// MARK: - Change font

%hook UIFontPickerViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig(arg1);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:[[BHTBundle sharedBundle]
                          localizedStringForKey:@"CUSTOM_FONTS_NAVIGATION_BUTTON_TITLE"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(customFontsHandler)];
}
%new
- (void)customFontsHandler {
    if ([[NSFileManager defaultManager]
            fileExistsAtPath:@"/var/mobile/Library/Fonts/AddedFontCache.plist"]) {
        NSAttributedString* AttString = [[NSAttributedString alloc]
            initWithString:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_FONTS_MENU_TITLE"]
                attributes:@{
                    NSFontAttributeName: [BHTManager menuTitleFont],
                    NSForegroundColorAttributeName: UIColor.labelColor
                }];
        TFNActiveTextItem* title =
            [[%c(TFNActiveTextItem) alloc] initWithTextModel:[[%c(TFNAttributedTextModel) alloc]
                                                                     initWithAttributedString:AttString]
                                                    activeRanges:nil];

        NSMutableArray* actions = [[NSMutableArray alloc] init];
        [actions addObject:title];

        NSDictionary* plistDictionary = [NSPropertyListSerialization
            propertyListWithData:
                [NSData dataWithContentsOfURL:
                            [NSURL fileURLWithPath:@"/var/mobile/Library/Fonts/AddedFontCache.plist"]]
                         options:NSPropertyListImmutable
                          format:NULL
                           error:nil];
        [plistDictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj,
                                                             BOOL* _Nonnull stop) {
            @try {
                NSString* fontName = ((NSArray*)[obj valueForKey:@"psNames"]).firstObject;
                TFNActionItem* fontAction = [%c(TFNActionItem)
                    actionItemWithTitle:fontName
                                 action:^{
                                     if (self.configuration.includeFaces) {
                                         [self setSelectedFontDescriptor:[UIFontDescriptor
                                                                             fontDescriptorWithFontAttributes:@{
                                                                                 UIFontDescriptorNameAttribute:
                                                                                     fontName
                                                                             }]];
                                     } else {
                                         [self setSelectedFontDescriptor:[UIFontDescriptor
                                                                             fontDescriptorWithFontAttributes:@{
                                                                                 UIFontDescriptorFamilyAttribute:
                                                                                     fontName
                                                                             }]];
                                     }
                                     [self.delegate fontPickerViewControllerDidPickFont:self];
                                 }];
                [actions addObject:fontAction];
            } @catch (NSException* exception) {
                NSLog(@"Unable to find installed fonts /n reason: %@", exception.reason);
            }
        }];

        TFNMenuSheetViewController* alert = [[%c(TFNMenuSheetViewController) alloc]
            initWithActionItems:[NSArray arrayWithArray:actions]];
        [alert tfnPresentedCustomPresentFromViewController:self animated:YES completion:nil];
    } else {
        UIAlertController* errAlert = [UIAlertController
            alertControllerWithTitle:@"BHTwitter"
                             message:[[BHTBundle sharedBundle]
                                         localizedStringForKey:@"CUSTOM_FONTS_TUT_ALERT_MESSAGE"]
                      preferredStyle:UIAlertControllerStyleAlert];

        [errAlert
            addAction:
                [UIAlertAction
                    actionWithTitle:[[BHTBundle sharedBundle]
                                        localizedStringForKey:@"INSTALL_IFONT_BUTTON_TITLE"]
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction* _Nonnull action) {
                                [[UIApplication sharedApplication]
                                              openURL:[NSURL
                                                          URLWithString:
                                                              @"https://apps.apple.com/sa/app/"
                                                              @"ifont-find-install-any-font/id1173222289"]
                                              options:@{}
                                    completionHandler:nil];
                            }]];
        [errAlert addAction:[UIAlertAction
                                actionWithTitle:[[BHTBundle sharedBundle]
                                                    localizedTwitterStringForKey:@"OK_ACTION_LABEL"]
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];
        [self presentViewController:errAlert animated:true completion:nil];
    }
}
%end

// The picked font name for a weight, or nil when the user runs Twitter's own.
static NSString* CustomFontName(BOOL isBold) {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"custom_fonts"]) {
        return nil;
    }

    return [defaults objectForKey:isBold ? @"bhtwitter_font_2"
                                         : @"bhtwitter_font_1"];
}

%hook UIFont
+ (UIFont*)tfn_fontWithName:(NSString*)name size:(CGFloat)size {
    UIFont* origFont = %orig;

    BOOL isBold = [name containsString:@"Bold"] || [name containsString:@"Heavy"];
    NSString* customName = CustomFontName(isBold);
    if (!customName) {
        return origFont;
    }

    return [UIFont fontWithName:customName size:size] ?: origFont;
}
%end

%hook XFontCatalog

+ (UIFont*)tabularDigitsFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont* origFont = %orig;

    NSString* customName = CustomFontName(weight >= UIFontWeightSemibold);
    if (!customName) {
        return origFont;
    }

    UIFont* customFont = [UIFont fontWithName:customName size:size];
    if (!customFont) {
        return origFont;
    }

    // Keep the digits equal width so the timestamp doesn't shuffle its layout
    // on every tick; fonts without tabular figures just ignore the feature.
    return [customFont tfn_withMonospacedDigits] ?: customFont;
}

%end


// MARK: - 万能入口兜底（X 12.4x 设置页结构变了也能进）

// 目标：不管设置页是 TFNItemsDataViewController 还是 SwiftUI / 别的类，
// 都能在 X 的设置界面里找到一个能点进插件设置的入口：
//   1) 先按原逻辑把条目插进 sections（结构对得上时就是原生那一行）；
//   2) 0.6 秒后如果发现 sections 里没有我们的条目，就在设置页右下角挂一个
//      「NeoFreeBird」悬浮按钮，点它直接推我们的设置页。

static const void* kNFBFallbackEntryKey = &kNFBFallbackEntryKey;

static BOOL NFBNameLooksLikeSettings(UIViewController* vc);

static BOOL NFBLooksLikeSettingsScreen(UIViewController* vc) {
    if (NFBNameLooksLikeSettings(vc)) {
        return YES;
    }
    NSString* title = vc.navigationItem.title;
    if (![title isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString* lower = title.lowercaseString;
    return [title containsString:@"\u8bbe\u7f6e"] || [lower containsString:@"settings"] ||
           [lower containsString:@"preferences"];
}

static BOOL NFBNameLooksLikeSettings(UIViewController* vc) {
    NSString* name = NSStringFromClass([vc class]);
    return [name containsString:@"Setting"] || [name containsString:@"Preferences"];
}

static BOOL NFBSectionsHaveEntry(id vc) {
    @try {
        id sections = [vc valueForKey:@"sections"];
        if (![sections isKindOfClass:[NSArray class]]) {
            return NO;
        }
        for (id section in (NSArray*)sections) {
            if (![section isKindOfClass:[NSArray class]]) {
                continue;
            }
            for (id entry in (NSArray*)section) {
                if (objc_getAssociatedObject(entry, SettingsEntryKey)) {
                    return YES;
                }
            }
        }
    } @catch (__unused NSException* exception) {
    }
    return NO;
}

@interface NFBFallbackEntryButton : UIControl
@property (nonatomic, weak) UIViewController* host;
@end

@implementation NFBFallbackEntryButton

- (void)endTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {
    BOOL inside = self.touchInside;
    [super endTrackingWithTouch:touch withEvent:event];
    self.alpha = 1.0;
    if (inside) {
        [self nfb_openSettings];
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {
    [super beginTrackingWithTouch:touch withEvent:event];
    self.alpha = 0.6;
    return YES;
}

- (void)nfb_openSettings {
    id account = nil;
    @try {
        account = [self.host valueForKey:@"account"];
    } @catch (__unused NSException* exception) {
    }
    UIViewController* settings = [BHTManager BHTSettingsWithAccount:account];
    if (settings == nil) {
        return;
    }
    if (self.host.navigationController != nil) {
        [self.host.navigationController pushViewController:settings animated:YES];
    } else {
        UINavigationController* nav =
            [[UINavigationController alloc] initWithRootViewController:settings];
        [self.host presentViewController:nav animated:YES completion:nil];
    }
}

@end

static const void* kNFBBarItemKey = &kNFBBarItemKey;
static const void* kNFBHostVCKey = &kNFBHostVCKey;

@interface NFBNavEntryProxy : NSObject
+ (instancetype)shared;
- (void)openSettings:(UIBarButtonItem*)item;
@end

@implementation NFBNavEntryProxy
+ (instancetype)shared {
    static NFBNavEntryProxy* proxy;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        proxy = [NFBNavEntryProxy new];
    });
    return proxy;
}
- (void)openSettingsFromControl:(UIControl*)control {
    UIViewController* host = objc_getAssociatedObject(control, kNFBHostVCKey);
    id account = nil;
    @try {
        account = [host valueForKey:@"account"];
    } @catch (__unused NSException* exception) {
    }
    UIViewController* settings = [BHTManager BHTSettingsWithAccount:account];
    if (settings == nil) {
        return;
    }
    if (host.navigationController != nil) {
        [host.navigationController pushViewController:settings animated:YES];
    } else {
        UINavigationController* nav =
            [[UINavigationController alloc] initWithRootViewController:settings];
        [host presentViewController:nav animated:YES completion:nil];
    }
}

- (void)openSettings:(UIBarButtonItem*)item {
    UIViewController* host = objc_getAssociatedObject(item, kNFBHostVCKey);
    id account = nil;
    @try {
        account = [host valueForKey:@"account"];
    } @catch (__unused NSException* exception) {
    }
    UIViewController* settings = [BHTManager BHTSettingsWithAccount:account];
    if (settings == nil) {
        return;
    }
    if (host.navigationController != nil) {
        [host.navigationController pushViewController:settings animated:YES];
    } else {
        UINavigationController* nav =
            [[UINavigationController alloc] initWithRootViewController:settings];
        [host presentViewController:nav animated:YES completion:nil];
    }
}
@end

// 设置页右上角放一个齿轮按钮：不遮挡内容、不残留到别的界面、观感跟原生一致。
static const void* kNFBGearPillKey = &kNFBGearPillKey;

// 导航栏不可用时的兜底：只在设置页右上角挂一个小圆齿轮（不会出现在播放器里）
static void NFBInstallGearPill(UIViewController* vc) {
    if (vc == nil || objc_getAssociatedObject(vc, kNFBGearPillKey) != nil) {
        return;
    }
    CGFloat size = 40.0;
    UIControl* control = [[UIControl alloc] initWithFrame:CGRectMake(
        vc.view.bounds.size.width - size - 16.0, 96.0, size, size)];
    control.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    control.backgroundColor = [UIColor secondarySystemBackgroundColor];
    control.layer.cornerRadius = size / 2.0;
    control.layer.shadowColor = [UIColor blackColor].CGColor;
    control.layer.shadowOpacity = 0.15;
    control.layer.shadowRadius = 6.0;
    control.layer.shadowOffset = CGSizeMake(0, 2);

    UIImageView* icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"gearshape.fill"
                                withConfiguration:[UIImageSymbolConfiguration
                                                      configurationWithPointSize:19.0]]];
    icon.tintColor = [UIColor labelColor];
    icon.frame = CGRectMake((size - 20.0) / 2.0, (size - 20.0) / 2.0, 20.0, 20.0);
    icon.userInteractionEnabled = NO;
    [control addSubview:icon];

    [control addTarget:[NFBNavEntryProxy shared]
                action:@selector(openSettingsFromControl:)
      forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(control, kNFBHostVCKey, vc, OBJC_ASSOCIATION_ASSIGN);

    [vc.view addSubview:control];
    objc_setAssociatedObject(vc, kNFBGearPillKey, control,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 设置页齿轮（无导航栏兜底）已挂上");
}

static void NFBInstallNavBarEntry(UIViewController* vc) {
    if (vc == nil || objc_getAssociatedObject(vc, kNFBBarItemKey) != nil) {
        return;
    }
    UINavigationController* navForBar = vc.navigationController;
    if (navForBar == nil || navForBar.isNavigationBarHidden) {
        NFBInstallGearPill(vc);
        return;
    }
    // 导航栏存在但可能是自绘的：齿轮 + 兜底小圆按钮都挂，保证一定看得见
    NFBInstallGearPill(vc);
    UIImage* gear = [UIImage systemImageNamed:@"gearshape.fill"];
    if (gear == nil) {
        gear = [UIImage systemImageNamed:@"gear"];
    }
    UIBarButtonItem* item =
        [[UIBarButtonItem alloc] initWithImage:gear
                                         style:UIBarButtonItemStylePlain
                                        target:[NFBNavEntryProxy shared]
                                        action:@selector(openSettings:)];
    item.accessibilityLabel = [[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"];
    objc_setAssociatedObject(item, kNFBHostVCKey, vc, OBJC_ASSOCIATION_ASSIGN);

    UINavigationItem* navItem = vc.navigationItem;
    NSMutableArray<UIBarButtonItem*>* items =
        [navItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    [items insertObject:item atIndex:0];
    navItem.rightBarButtonItems = items;

    objc_setAssociatedObject(vc, kNFBBarItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 设置页齿轮入口已挂上: %@", NSStringFromClass([vc class]));
}

// 设置页判定：页面里必须有「搜索设置」搜索框（播放器面板没有）
static BOOL NFBViewHasSettingsSearch(UIView* view, NSInteger depth) {
    if (view == nil || depth > 40) {
        return NO;
    }
    if ([view isKindOfClass:[UITextField class]]) {
        NSString* text = ((UITextField*)view).placeholder ?: ((UITextField*)view).text;
        if ([text containsString:@"搜索"] || [text.lowercaseString containsString:@"search"]) {
            return YES;
        }
    }
    if ([view isKindOfClass:[UISearchBar class]]) {
        NSString* text = ((UISearchBar*)view).placeholder;
        if ([text containsString:@"搜索"] || [text.lowercaseString containsString:@"search"]) {
            return YES;
        }
    }
    if ([view isKindOfClass:[UILabel class]]) {
        NSString* text = ((UILabel*)view).text;
        if ([text containsString:@"搜索设置"] ||
            [text.lowercaseString containsString:@"search settings"]) {
            return YES;
        }
    }
    for (UIView* subview in view.subviews) {
        if (NFBViewHasSettingsSearch(subview, depth + 1)) {
            return YES;
        }
    }
    return NO;
}

static void NFBCollectControllers(UIViewController* vc, NSMutableArray* out) {
    if (vc == nil || out.count > 80) {
        return;
    }
    [out addObject:vc];
    for (UIViewController* child in vc.childViewControllers) {
        NFBCollectControllers(child, out);
    }
    NFBCollectControllers(vc.presentedViewController, out);
}

static NSArray<UIViewController*>* NFBAllControllers(void) {
    NSMutableArray* out = [NSMutableArray array];
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* window in ((UIWindowScene*)scene).windows) {
            if (window.hidden || window.alpha < 0.01) {
                continue;
            }
            NFBCollectControllers(window.rootViewController, out);
        }
    }
    return out;
}

// 只认“真正在屏幕上、叶子级”的设置页；容器控制器 / 播放器面板一律跳过
static BOOL NFBIsLeafPage(UIViewController* vc) {
    if (vc.childViewControllers.count > 0) {
        return NO;
    }
    UIWindow* window = vc.view.window;
    if (window == nil) {
        return NO;
    }
    if (window.rootViewController == vc) {
        return NO;
    }
    UINavigationController* nav = vc.navigationController;
    if (nav != nil && nav.topViewController != vc) {
        return NO;
    }
    NSString* name = NSStringFromClass([vc class]);
    if ([name containsString:@"Video"] || [name containsString:@"Player"] ||
        [name containsString:@"Immersive"] || [name containsString:@"Media"] ||
        [name containsString:@"Sheet"]) {
        return NO;
    }
    return YES;
}

static BOOL NFBIsSettingsRootPage(UIViewController* vc) {
    if (!NFBIsLeafPage(vc)) {
        return NO;
    }
    NSString* name = NSStringFromClass([vc class]);
    // 播放器面板类名里也带 Settings，必须排除
    if ([name containsString:@"Video"] || [name containsString:@"Player"] ||
        [name containsString:@"Immersive"] || [name containsString:@"Media"] ||
        [name containsString:@"Sheet"] || [name containsString:@"Broadcast"]) {
        return NO;
    }
    UINavigationController* nav = vc.navigationController;
    if (nav != nil && nav.viewControllers.firstObject != vc) {
        return NO;
    }
    if ([name containsString:@"Setting"] || [name containsString:@"Preference"]) {
        return YES;
    }
    NSString* title = vc.navigationItem.title ?: @"";
    if ([title containsString:@"设置"] || [title.lowercaseString containsString:@"settings"]) {
        return YES;
    }
    return NFBViewHasSettingsSearch(vc.view, 0);
}

static void NFBInstallEntryIfNeeded(UIViewController* vc) {
    if (!NFBIsSettingsRootPage(vc)) {
        return;
    }
    NFBInstallNavBarEntry(vc);
}
static void NFBInstallSideMenuEntry(UIViewController* vc);
static void NFBInstallFloatingEntry(void);
static void NFBUpdateFloatingVisibility(void);
static void NFBInstallGlobalGesture(void);



static void NFBStartEntryWatcher(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimer* timer = [NSTimer
            scheduledTimerWithTimeInterval:1.0
                                   repeats:YES
                                     block:^(NSTimer* t) {
                                         if (UIApplication.sharedApplication.applicationState !=
                                             UIApplicationStateActive) {
                                             return;
                                         }
                                         NFBInstallGlobalGesture();
                                         NFBUpdateFloatingVisibility();
                                         for (UIViewController* vc in NFBAllControllers()) {
                                             NFBInstallEntryIfNeeded(vc);
                                             NFBInstallSideMenuEntry(vc);
                                         }
                                     }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

static NSString* NFBDescribeTopController(void) {
    UIViewController* top = topMostController();
    if (top == nil) {
        return @"顶层: (nil)";
    }
    NSString* name = NSStringFromClass([top class]);
    NSString* title = top.navigationItem.title ?: @"";
    NSString* looks = NFBLooksLikeSettingsScreen(top) ? @"是" : @"否";
    BOOL hasEntry = NFBSectionsHaveEntry(top);
    NSUInteger windows = 0;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            windows += ((UIWindowScene*)scene).windows.count;
        }
    }
    return [NSString stringWithFormat:@"顶层控制器: %@\n标题: %@\n判定为设置页: %@\n已有插件条目: %@\n窗口数: %lu\n控制器数: %lu",
                                      name, title, looks, hasEntry ? @"是" : @"否",
                                      (unsigned long)windows,
                                      (unsigned long)NFBAllControllers().count];
}

// 载入自检：证明 dylib 真的被注入并执行了；顺便可以点“检测当前界面”把类名报出来。

// 把运行时里所有“设置相关”的类名导出到剪贴板：不用你在设置页里点来点去，
// 我拿到这份清单就能确定 X 12.4x 用的是哪个类。
static NSString* NFBDumpSettingsClasses(void) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) {
        return @"(no classes)";
    }
    Class* classes = (Class*)malloc(sizeof(Class) * (size_t)count);
    if (classes == NULL) {
        return @"(alloc failed)";
    }
    count = objc_getClassList(classes, count);

    NSMutableArray<NSString*>* hits = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        const char* name = class_getName(classes[i]);
        if (name == NULL) {
            continue;
        }
        NSString* string = [NSString stringWithUTF8String:name];
        if ([string containsString:@"Setting"] || [string containsString:@"Preferences"] ||
            [string containsString:@"Preference"]) {
            [hits addObject:string];
        }
    }
    free(classes);

    [hits sortUsingSelector:@selector(compare:)];
    NSString* report = [NSString stringWithFormat:@"total classes: %d\nhits: %lu\n\n%@", count,
                                                  (unsigned long)hits.count,
                                                  [hits componentsJoinedByString:@"\n"]];
    UIPasteboard.generalPasteboard.string = report;
    NSLog(@"[NFB] settings classes dumped: %lu", (unsigned long)hits.count);
    return report;
}


// MARK: - 侧边栏入口（创作者工作室 与 设置和隐私 之间）

static const void* kNFBSideEntryKey = &kNFBSideEntryKey;

static BOOL NFBLabelMatches(UILabel* label, NSArray<NSString*>* titles) {
    NSString* text = label.attributedText.length ? label.attributedText.string : label.text;
    if (text.length == 0) {
        return NO;
    }
    NSString* trimmed =
        [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString* title in titles) {
        if ([trimmed isEqualToString:title]) {
            return YES;
        }
    }
    return NO;
}

static void NFBCollectAllLabels(UIView* view, NSMutableArray<UILabel*>* out, NSInteger depth) {
    if (view == nil || depth > 40 || view.hidden || view.alpha < 0.01) {
        return;
    }
    if ([view isKindOfClass:[UILabel class]]) {
        [out addObject:(UILabel*)view];
        return;
    }
    for (UIView* subview in view.subviews) {
        NFBCollectAllLabels(subview, out, depth + 1);
    }
}

static void NFBInstallSideMenuEntry(UIViewController* vc) {
    if (vc == nil || vc.view.window == nil) {
        return;
    }
    if (objc_getAssociatedObject(vc, kNFBSideEntryKey) != nil) {
        return;
    }

    NSMutableArray<UILabel*>* labels = [NSMutableArray array];
    NFBCollectAllLabels(vc.view, labels, 0);
    if (labels.count == 0) {
        return;
    }

    UILabel* privacy = nil;
    UILabel* help = nil;
    UILabel* creator = nil;
    for (UILabel* label in labels) {
        if (privacy == nil &&
            NFBLabelMatches(label, @[ @"设置和隐私", @"设置与隐私", @"Settings and privacy" ])) {
            privacy = label;
            continue;
        }
        if (help == nil && NFBLabelMatches(label, @[ @"帮助中心", @"Help Center" ])) {
            help = label;
            continue;
        }
        if (creator == nil && NFBLabelMatches(label, @[ @"创作者工作室", @"Creator Studio" ])) {
            creator = label;
        }
    }
    if (privacy == nil || help == nil) {
        return;
    }

    CGRect privacyRect = [privacy convertRect:privacy.bounds toView:vc.view];
    CGRect creatorRect = creator ? [creator convertRect:creator.bounds toView:vc.view] : CGRectZero;

    CGFloat gapTop = creator ? CGRectGetMaxY(creatorRect) : CGRectGetMinY(privacyRect) - 56.0;
    CGFloat gapBottom = CGRectGetMinY(privacyRect);
    CGFloat gapHeight = gapBottom - gapTop;
    if (gapHeight < 24.0) {
        gapHeight = 40.0;
        gapTop = gapBottom - gapHeight;
    }

    UIControl* row =
        [[UIControl alloc] initWithFrame:CGRectMake(0, gapTop, CGRectGetWidth(vc.view.bounds), gapHeight)];
    row.backgroundColor = [UIColor clearColor];

    UIImageView* icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"gearshape.fill"
                                withConfiguration:[UIImageSymbolConfiguration
                                                      configurationWithPointSize:19.0]]];
    icon.tintColor = [UIColor labelColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.frame = CGRectMake(24.0, (gapHeight - 20.0) / 2.0, 20.0, 20.0);
    icon.userInteractionEnabled = NO;
    [row addSubview:icon];

    UILabel* label =
        [[UILabel alloc] initWithFrame:CGRectMake(64.0, 0, CGRectGetWidth(vc.view.bounds) - 104.0, gapHeight)];
    NSString* title = [[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"];
    label.text = title.length ? title : @"NeoFreeBird";
    label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    label.textColor = [UIColor labelColor];
    label.userInteractionEnabled = NO;
    [row addSubview:label];

    [row addTarget:[NFBNavEntryProxy shared]
            action:@selector(openSettingsFromControl:)
  forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(row, kNFBHostVCKey, vc, OBJC_ASSOCIATION_ASSIGN);

    [vc.view addSubview:row];
    objc_setAssociatedObject(vc, kNFBSideEntryKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 侧边栏入口已插入 (h=%.0f)", gapHeight);
}



// MARK: - 百分百可见的悬浮入口（不看 X 的界面结构）

// X 12.4x 的设置页和侧边栏都是 SwiftUI 自绘，拿不到 UILabel / 设置类名，
// 所以再加一个完全由我们自己画的悬浮齿轮：只要进程活着就一定在。

static const void* kNFBFloatingKey = &kNFBFloatingKey;

@interface NFBFloatingEntry : UIControl
@end

@implementation NFBFloatingEntry

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.25;
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.alpha = 0.92;

        UIImageView* icon = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:@"gearshape.fill"
                                    withConfiguration:[UIImageSymbolConfiguration
                                                          configurationWithPointSize:20.0]]];
        icon.tintColor = [UIColor labelColor];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake((frame.size.width - 22.0) / 2.0,
                                (frame.size.height - 22.0) / 2.0, 22.0, 22.0);
        icon.userInteractionEnabled = NO;
        [self addSubview:icon];

        [self addTarget:[NFBNavEntryProxy shared]
                 action:@selector(openSettingsFromControl:)
       forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer* pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer*)pan {
    UIView* host = self.superview;
    if (host == nil) {
        return;
    }
    CGPoint translation = [pan translationInView:host];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    center.x = MAX(30.0, MIN(CGRectGetWidth(host.bounds) - 30.0, center.x));
    center.y = MAX(80.0, MIN(CGRectGetHeight(host.bounds) - 60.0, center.y));
    self.center = center;
    [pan setTranslation:CGPointZero inView:host];

    if (pan.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setDouble:center.x forKey:@"nfb_fab_x"];
        [[NSUserDefaults standardUserDefaults] setDouble:center.y forKey:@"nfb_fab_y"];
    }
}

@end

static void NFBInstallFloatingEntry(void) {
    UIWindow* window = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* candidate in ((UIWindowScene*)scene).windows) {
            if (!candidate.hidden && candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window != nil) {
            break;
        }
    }
    if (window == nil) {
        return;
    }
    if (objc_getAssociatedObject(window, kNFBFloatingKey) != nil) {
        return;
    }

    CGFloat size = 46.0;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    CGFloat x = [defaults doubleForKey:@"nfb_fab_x"];
    CGFloat y = [defaults doubleForKey:@"nfb_fab_y"];
    if (x <= 0 || y <= 0) {
        x = CGRectGetWidth(window.bounds) - size / 2.0 - 10.0;
        y = CGRectGetHeight(window.bounds) * 0.55;
    }

    NFBFloatingEntry* entry = [[NFBFloatingEntry alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    entry.center = CGPointMake(x, y);
    entry.autoresizingMask = UIViewAutoresizingNone;
    objc_setAssociatedObject(entry, kNFBHostVCKey, window.rootViewController,
                             OBJC_ASSOCIATION_ASSIGN);

    [window addSubview:entry];
    objc_setAssociatedObject(window, kNFBFloatingKey, entry,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 悬浮入口已挂上");
}



// MARK: - 只在“设置类界面”显示悬浮入口 + 三指双击兜底

static BOOL NFBAXLabelHit(id element, NSArray<NSString*>* needles) {
    @try {
        if ([element respondsToSelector:@selector(accessibilityLabel)]) {
            id label = [element accessibilityLabel];
            if ([label isKindOfClass:[NSString class]]) {
                for (NSString* needle in needles) {
                    if ([(NSString*)label containsString:needle]) {
                        return YES;
                    }
                }
            }
        }
    } @catch (__unused NSException* exception) {
    }
    return NO;
}

static void NFBCollectAX(id container, NSMutableArray* out, NSInteger depth) {
    if (container == nil || depth > 26 || out.count > 1200) {
        return;
    }
    if ([container respondsToSelector:@selector(accessibilityElementCount)]) {
        NSInteger count = [container accessibilityElementCount];
        if (count > 0 && count < 3000) {
            for (NSInteger i = 0; i < count; i++) {
                id element = [container accessibilityElementAtIndex:i];
                if (element != nil) {
                    [out addObject:element];
                }
            }
        }
    }
    if ([container respondsToSelector:@selector(accessibilityElements)]) {
        @try {
            id elements = [container accessibilityElements];
            if ([elements isKindOfClass:[NSArray class]]) {
                [out addObjectsFromArray:elements];
            }
        } @catch (__unused NSException* exception) {
        }
    }
    if ([container isKindOfClass:[UIView class]]) {
        for (UIView* subview in ((UIView*)container).subviews) {
            NFBCollectAX(subview, out, depth + 1);
        }
    }
}

// 12.4x 的设置/侧边栏都是 SwiftUI 自绘，控件层拿不到文字；
// 但无障碍树里有文案，用它的关键词判断“当前是不是设置类界面”。
static BOOL NFBIsSettingsLikeScreen(UIWindow* window) {
    if (window == nil) {
        return NO;
    }
    NSArray<NSString*>* needles = @[
        @"设置和隐私", @"设置与隐私", @"Settings and privacy",
        @"帮助中心", @"Help Center",
        @"安全和访问", @"Safety", @"隐私和安全", @"Privacy and safety",
        @"搜索设置", @"Search settings",
    ];
    NSMutableArray* elements = [NSMutableArray array];
    NFBCollectAX(window, elements, 0);
    for (id element in elements) {
        if (NFBAXLabelHit(element, needles)) {
            return YES;
        }
    }
    // 控件层再兜一次（老版本 X / 部分页面是 UIKit）
    return NFBViewHasSettingsSearch(window, 0);
}

static void NFBUpdateFloatingVisibility(void) {
    UIWindow* window = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* candidate in ((UIWindowScene*)scene).windows) {
            if (!candidate.hidden && candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window != nil) {
            break;
        }
    }
    if (window == nil) {
        return;
    }
    UIView* entry = objc_getAssociatedObject(window, kNFBFloatingKey);
    BOOL shouldShow = NFBIsSettingsLikeScreen(window);
    if (shouldShow && entry == nil) {
        NFBInstallFloatingEntry();
    } else if (!shouldShow && entry != nil) {
        [entry removeFromSuperview];
        objc_setAssociatedObject(window, kNFBFloatingKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// 兜底：三指双击屏幕任意位置，直接打开插件设置（不怕界面结构变化）
static const void* kNFBTripleTapKey = &kNFBTripleTapKey;

@interface NFBGlobalGestureTarget : NSObject
- (void)handleThreeFingerDoubleTap:(UITapGestureRecognizer*)gesture;
@end

@implementation NFBGlobalGestureTarget
- (void)handleThreeFingerDoubleTap:(UITapGestureRecognizer*)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    UIViewController* host = gesture.view.window.rootViewController;
    id account = nil;
    @try {
        account = [host valueForKey:@"account"];
    } @catch (__unused NSException* exception) {
    }
    UIViewController* settings = [BHTManager BHTSettingsWithAccount:account];
    if (settings == nil) {
        return;
    }
    UINavigationController* nav =
        [[UINavigationController alloc] initWithRootViewController:settings];
    [topMostController() presentViewController:nav animated:YES completion:nil];
}
@end

static void NFBInstallGlobalGesture(void) {
    UIWindow* window = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* candidate in ((UIWindowScene*)scene).windows) {
            if (!candidate.hidden && candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window != nil) {
            break;
        }
    }
    if (window == nil || objc_getAssociatedObject(window, kNFBTripleTapKey) != nil) {
        return;
    }
    static NFBGlobalGestureTarget* target;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        target = [NFBGlobalGestureTarget new];
    });
    UITapGestureRecognizer* tap =
        [[UITapGestureRecognizer alloc] initWithTarget:target
                                               action:@selector(handleThreeFingerDoubleTap:)];
    tap.numberOfTouchesRequired = 3;
    tap.numberOfTapsRequired = 2;
    tap.cancelsTouchesInView = NO;
    [window addGestureRecognizer:tap];
    objc_setAssociatedObject(window, kNFBTripleTapKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


%ctor {
    NFBStartEntryWatcher();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       NFBInstallGlobalGesture();
                       NFBUpdateFloatingVisibility();
                   });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
                       if ([defaults boolForKey:@"nfb_710_loaded_toast"]) {
                           return;
                       }
                       [defaults setBool:YES forKey:@"nfb_710_loaded_toast"];

                       UIAlertController* alert = [UIAlertController
                           alertControllerWithTitle:@"呱呱助手 · 载入自检"
                                            message:[NSString
                                                        stringWithFormat:@"v7.1.0 已注入并运行。\n%@",
                                                                         NFBDescribeTopController()]
                                     preferredStyle:UIAlertControllerStyleAlert];
                       [alert addAction:[UIAlertAction actionWithTitle:@"知道了"
                                                                style:UIAlertActionStyleCancel
                                                              handler:nil]];
                       [alert addAction:[UIAlertAction
                                            actionWithTitle:@"导出设置类名"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction* action) {
                                                        NSString* dump = NFBDumpSettingsClasses();
                                                        NSUInteger lines =
                                                            [[dump componentsSeparatedByString:@"\n"]
                                                                count];
                                                        UIAlertController* info = [UIAlertController
                                                            alertControllerWithTitle:@"已复制到剪贴板"
                                                                             message:[NSString
                                                                                         stringWithFormat:@"共导出 %lu 行，直接粘贴发我即可。",
                                                                                                          (unsigned long)lines]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                                                        [info addAction:[UIAlertAction
                                                                            actionWithTitle:@"好"
                                                                                      style:UIAlertActionStyleDefault
                                                                                    handler:nil]];
                                                        [topMostController()
                                                            presentViewController:info
                                                                         animated:YES
                                                                       completion:nil];
                                                    }]];
                       [alert addAction:[UIAlertAction
                                            actionWithTitle:@"检测当前界面"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction* action) {
                                                        NSString* info =
                                                            NFBDescribeTopController();
                                                        UIPasteboard.generalPasteboard.string =
                                                            info;
                                                        UIAlertController* second =
                                                            [UIAlertController
                                                                alertControllerWithTitle:
                                                                    @"当前界面"
                                                                                 message:info
                                                                          preferredStyle:
                                                                              UIAlertControllerStyleAlert];
                                                        [second
                                                            addAction:
                                                                [UIAlertAction
                                                                    actionWithTitle:@"好"
                                                                              style:
                                                                                  UIAlertActionStyleDefault
                                                                            handler:nil]];
                                                        [topMostController()
                                                            presentViewController:second
                                                                         animated:YES
                                                                       completion:nil];
                                                    }]];
                       [topMostController() presentViewController:alert
                                                        animated:YES
                                                      completion:nil];
                   });
}
