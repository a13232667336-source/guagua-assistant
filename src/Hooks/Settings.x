//
//  Settings.x
//  呱呱助手 (minimal build)
//
//  只保留一个入口：三指长按屏幕任意位置 → 打开插件设置。
//  其余所有入口（设置页齿轮、侧边栏行、悬浮按钮、导航栏按钮）全部删除。
//

#import "HookHelpers.h"

#pragma mark - 三指长按入口

static const void* kNFBLongPressKey = &kNFBLongPressKey;

@interface NFBEntryGestureTarget : NSObject
- (void)handleThreeFingerLongPress:(UILongPressGestureRecognizer*)gesture;
@end

@implementation NFBEntryGestureTarget

- (void)handleThreeFingerLongPress:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    UIViewController* top = topMostController();
    id account = nil;
    @try {
        account = [top valueForKey:@"account"];
    } @catch (__unused NSException* exception) {
    }

    UIViewController* settings = [BHTManager BHTSettingsWithAccount:account];
    if (settings == nil) {
        return;
    }
    UINavigationController* nav =
        [[UINavigationController alloc] initWithRootViewController:settings];
    [top presentViewController:nav animated:YES completion:nil];
}

@end

static UIWindow* NFBKeyWindow(void) {
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* window in ((UIWindowScene*)scene).windows) {
            if (!window.hidden && window.isKeyWindow) {
                return window;
            }
        }
    }
    return nil;
}

static void NFBInstallEntryGesture(void) {
    UIWindow* window = NFBKeyWindow();
    if (window == nil || objc_getAssociatedObject(window, kNFBLongPressKey) != nil) {
        return;
    }

    static NFBEntryGestureTarget* target;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        target = [NFBEntryGestureTarget new];
    });

    UILongPressGestureRecognizer* press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:target
                                                     action:@selector(handleThreeFingerLongPress:)];
    press.numberOfTouchesRequired = 4;
    press.minimumPressDuration = 0.8;
    press.cancelsTouchesInView = NO;
    press.delaysTouchesBegan = NO;
    press.delaysTouchesEnded = NO;
    [window addGestureRecognizer:press];

    objc_setAssociatedObject(window, kNFBLongPressKey, press,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[NFB] 四指长按入口已挂上");
}

// 窗口/根控制器变化后手势会失效，低频补挂一次即可，不做任何界面扫描。
static void NFBStartGestureWatcher(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                         repeats:YES
                                                           block:^(NSTimer* t) {
                                                               if (UIApplication.sharedApplication
                                                                       .applicationState ==
                                                                   UIApplicationStateActive) {
                                                                   NFBInstallEntryGesture();
                                                               }
                                                           }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

%ctor {
    NFBStartGestureWatcher();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       NFBInstallEntryGesture();
                   });
}
