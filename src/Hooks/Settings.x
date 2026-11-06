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

%hook XDSButtonContentElement
+ (id)labelWithText:(id)text font:(id)font color:(id)color {
    id orig = %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"custom_fonts"]) {
        return orig;
    }

    BOOL isBold = [font containsString:@"Bold"] ||
                  [font containsString:@"Heavy"];

    NSString* customName = [[NSUserDefaults standardUserDefaults]
        objectForKey:isBold ? @"bhtwitter_font_2" : @"bhtwitter_font_1"];
    if (!customName) {
        return orig;
    }
    UIFont* customFont = [UIFont fontWithName:customName
                                         size:[(UIFont*)orig pointSize]];
    if (!customFont) {
        return orig;
    }

    return %orig(text, customFont, color);
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

static void NFBInstallFallbackEntry(UIViewController* vc) {
    UIView* host = vc.view;
    if (host == nil || objc_getAssociatedObject(vc, kNFBFallbackEntryKey) != nil) {
        return;
    }

    CGFloat width = 190.0;
    CGFloat height = 48.0;
    NFBFallbackEntryButton* button =
        [[NFBFallbackEntryButton alloc] initWithFrame:CGRectMake(
                                                    host.bounds.size.width - width - 18.0,
                                                    host.bounds.size.height - height - 110.0,
                                                    width, height)];
    button.host = vc;
    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    button.backgroundColor = [UIColor secondarySystemBackgroundColor];
    button.layer.cornerRadius = height / 2.0;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.18;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0, 2);

    UIImageView* icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"gearshape.fill"
                                withConfiguration:[UIImageSymbolConfiguration
                                                      configurationWithPointSize:18.0]]];
    icon.tintColor = [UIColor labelColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.frame = CGRectMake(16.0, (height - 20.0) / 2.0, 20.0, 20.0);
    icon.userInteractionEnabled = NO;
    [button addSubview:icon];

    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(44.0, 0.0, width - 58.0, height)];
    NSString* title = [[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"];
    label.text = title.length ? title : @"NeoFreeBird";
    label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor labelColor];
    label.userInteractionEnabled = NO;
    [button addSubview:label];

    [host addSubview:button];
    objc_setAssociatedObject(vc, kNFBFallbackEntryKey, button,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 设置页结构不匹配，已挂兜底入口");
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!NFBLooksLikeSettingsScreen(self)) {
        return;
    }
    // 只在设置首页挂兜底入口（子页面不动）
    UINavigationController* nav = self.navigationController;
    if (nav != nil && nav.viewControllers.firstObject != self) {
        return;
    }
    __weak UIViewController* weakVC = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       UIViewController* vc = weakVC;
                       if (vc == nil || vc.view.window == nil) {
                           return;
                       }
                       if (NFBSectionsHaveEntry(vc)) {
                           return;  // 原生插入成功，不用兜底
                       }
                       NFBInstallFallbackEntry(vc);
                   });
}

%end

// MARK: - 不依赖生命周期的入口安装器 + 载入自检

// 有些类的 viewDidAppear 不调用 super，所以不能只靠 hook 生命周期。
// 这里用 1 秒一次的轻量轮询：看当前最上层控制器是不是设置页，是就把入口补上。

// 扫所有窗口、所有子控制器/弹出控制器，避免 key window 判断在 Dash 分屏下失准
static void NFBCollectControllers(UIViewController* vc, NSMutableArray* out) {
    if (vc == nil || out.count > 60) {
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

static void NFBInstallEntryIfNeeded(UIViewController* vc) {
    if (vc == nil) {
        return;
    }
    if (!NFBLooksLikeSettingsScreen(vc)) {
        return;
    }
    if (NFBSectionsHaveEntry(vc)) {
        return;
    }
    // 结构对得上就按原生方式插一行
    if ([vc isKindOfClass:objc_getClass("TFNItemsDataViewController")]) {
        @try {
            insertNeoFreeBirdSettingsIfRoot((TFNItemsDataViewController*)vc);
        } @catch (__unused NSException* exception) {
        }
        if (NFBSectionsHaveEntry(vc)) {
            return;
        }
    }
    // 插不进去就挂悬浮入口（保证一定有东西可点）
    NFBInstallFallbackEntry(vc);
}

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
                                         for (UIViewController* vc in NFBAllControllers()) {
                                             NFBInstallEntryIfNeeded(vc);
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
%ctor {
    NFBStartEntryWatcher();

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
