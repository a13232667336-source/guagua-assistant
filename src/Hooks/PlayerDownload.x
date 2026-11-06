//
//  PlayerDownloadMenu.x
//  呱呱助手 player download row (ported to NeoFreeBird v7.1.0)
//
//  全屏短视频的「⋯」设置面板里官方「下载视频」那一行：
//
//  诊断（用户抓回来的视图树）证明：这层面板不在播放器 VC 的视图树里，而且
//  播放器本身是 TFNNavigationController 承载的（T1TwitterSwift.ImmersiveCardView
//  + ImmersiveVideoPageView）。所以扫描必须从 **UIWindow** 出发，而不是从某个
//  VC 的 view 出发。
//
//  1) 标签路径：窗口里出现「质量」行 + 官方「下载视频」行（XDSButton 里的
//     UILabel）→ 原地改名 + 透明按钮接管点击；
//  2) 无障碍路径：找不到 UILabel（纯 SwiftUI 绘制）→ 按 accessibilityLabel
//     找到那一行，用窗口快照整行盖住，贴上「下载视频（呱呱助手）」并接管点击；
//  3) 两条都不成立但窗口里出现了名字带 Sheet 的视图 → 把窗口结构复制到剪贴板
//     并弹提示，方便继续适配。
//

#import "HookHelpers.h"
#import <AVFoundation/AVFoundation.h>

@class GuaguaRowTapProxy;

#pragma mark - 字符串兜底

static NSString* GuaguaPlayerDownloadTitle(void) {
    return @"下载视频（呱呱助手）";
}

// 前置声明：悬浮按钮要判断窗口里有没有播放器，具体实现在文件后半段
static BOOL NFBWindowHasImmersivePlayer(UIView* view, NSInteger depth);
static BOOL NFBWindowHasSheetClass(UIView* view, NSInteger depth);

#pragma mark - 正在播放的视频地址

static void NFBCollectPlayerLayers(CALayer* layer,
                                   NSMutableArray<AVPlayerLayer*>* out,
                                   NSInteger depth) {
    if (layer == nil || depth > 64) {
        return;
    }
    if ([layer isKindOfClass:[AVPlayerLayer class]]) {
        [out addObject:(AVPlayerLayer*)layer];
    }
    for (CALayer* sublayer in layer.sublayers) {
        NFBCollectPlayerLayers(sublayer, out, depth + 1);
    }
}

static NSArray<AVPlayerLayer*>* NFBVisiblePlayerLayers(void) {
    NSMutableArray<AVPlayerLayer*>* layers = [NSMutableArray array];
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* window in ((UIWindowScene*)scene).windows) {
            if (window.hidden || window.alpha < 0.01) {
                continue;
            }
            NFBCollectPlayerLayers(window.layer, layers, 0);
        }
    }
    return layers;
}

static NSURL* NFBCurrentlyPlayingVideoURL(void) {
    AVPlayerLayer* bestLayer = nil;
    CGFloat bestScore = -1.0;

    for (AVPlayerLayer* layer in NFBVisiblePlayerLayers()) {
        AVPlayer* player = layer.player;
        if (player == nil || player.currentItem == nil) {
            continue;
        }
        CGSize size = layer.bounds.size;
        if (size.width < 160.0 || size.height < 160.0) {
            continue;
        }
        BOOL playing = player.rate > 0.01 ||
                       player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
        CGFloat score = size.width * size.height + (playing ? 1.0e9 : 0.0);
        if (score > bestScore) {
            bestScore = score;
            bestLayer = layer;
        }
    }

    if (bestLayer == nil) {
        for (AVPlayerLayer* layer in NFBVisiblePlayerLayers()) {
            AVPlayer* player = layer.player;
            if (player.currentItem != nil && player.rate > 0.01) {
                bestLayer = layer;
                break;
            }
        }
    }

    AVAsset* asset = bestLayer.player.currentItem.asset;
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        return ((AVURLAsset*)asset).URL;
    }
    return nil;
}

static BOOL NFBHasPlayingVideo(void) {
    for (AVPlayerLayer* layer in NFBVisiblePlayerLayers()) {
        AVPlayer* player = layer.player;
        if (player == nil || player.currentItem == nil) {
            continue;
        }
        CGSize size = layer.bounds.size;
        if (size.width >= 160.0 && size.height >= 160.0 && player.rate > 0.01) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - 文案匹配

static NSString* NFBTrimmedLowercase(NSString* text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        return @"";
    }
    NSString* trimmed =
        [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while (trimmed.length > 0 &&
           ([trimmed hasSuffix:@"…"] || [trimmed hasSuffix:@"..."] || [trimmed hasSuffix:@"."])) {
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    return trimmed.lowercaseString;
}

static NSSet<NSString*>* NFBQualityRowTitles(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"质量", @"畫質", @"画质", @"质量与音质", @"quality", @"video quality",
            @"qualität", @"calidad", @"qualité", @"качество",
        ]];
    });
    return set;
}

static NSSet<NSString*>* NFBOfficialDownloadTitles(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"下载视频", @"下載影片", @"下載視頻", @"视频下载", @"下载影片",
            @"download video", @"save video", @"video download",
            @"動画をダウンロード", @"동영상 다운로드", @"скачать видео",
            @"video herunterladen", @"descargar vídeo", @"télécharger la vidéo",
        ]];
    });
    return set;
}

// 面板里用来当“位置锚”的行：官方下载行就在这两行附近。
static NSSet<NSString*>* NFBOfflineRowTitles(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"添加到离线", @"加入离线", @"保存到离线", @"add to offline", @"save offline",
            @"offline", @"オフラインに追加", @"오프라인에 추가",
        ]];
    });
    return set;
}

static NSSet<NSString*>* NFBViewPostRowTitles(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"前往帖子", @"查看帖子", @"go to post", @"view post", @"to post",
            @"投稿へ移動", @"게시물로 이동",
        ]];
    });
    return set;
}

#pragma mark - 点击代理
@interface GuaguaRowTapProxy : NSObject
+ (instancetype)sharedProxy;
- (void)handleTap:(id)sender;
- (void)handleTouchDown:(id)sender;
- (void)handleTouchUp:(id)sender;
@end

@implementation GuaguaRowTapProxy
+ (instancetype)sharedProxy {
    static GuaguaRowTapProxy* proxy;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        proxy = [GuaguaRowTapProxy new];
    });
    return proxy;
}
- (void)handleTap:(id)sender {
    if ([sender isKindOfClass:[UIView class]]) {
        ((UIView*)sender).alpha = 1.0;
    }
    NSURL* url = NFBCurrentlyPlayingVideoURL();
    if (url == nil) {
        UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:@"没有正在播放的视频"
                             message:@"先播放你要下载的那条视频，再点这一项。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction
                             actionWithTitle:@"好"
                                       style:UIAlertActionStyleDefault
                                     handler:nil]];
        [topMostController() presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSLog(@"[Guagua] 下载当前正在播放的视频: %@", url);
    [BHTManager downloadVideoFromURL:url];
}
- (void)handleTouchDown:(id)sender {
    if ([sender isKindOfClass:[UIView class]]) {
        ((UIView*)sender).alpha = 0.55;
    }
}
- (void)handleTouchUp:(id)sender {
    if ([sender isKindOfClass:[UIView class]]) {
        ((UIView*)sender).alpha = 1.0;
    }
}
@end

#pragma mark - 视图树工具

static void NFBCollectLabels(UIView* view,
                             NSMutableArray<UILabel*>* out,
                             NSInteger depth) {
    if (view == nil || depth > 60 || view.hidden || view.alpha < 0.01) {
        return;
    }
    if ([view isKindOfClass:[UILabel class]]) {
        [out addObject:(UILabel*)view];
        return;
    }
    for (UIView* subview in view.subviews) {
        NFBCollectLabels(subview, out, depth + 1);
    }
}

static NSString* NFBLabelText(UILabel* label) {
    if (label.attributedText.length > 0) {
        return label.attributedText.string;
    }
    return label.text ?: @"";
}

static UIView* NFBRowContainerForLabel(UILabel* label) {
    UIView* candidate = label;
    for (NSInteger i = 0; i < 10 && candidate != nil; i++) {
        UIView* parent = candidate.superview;
        if (parent == nil) {
            break;
        }
        if ([parent isKindOfClass:[UIStackView class]]) {
            return candidate;
        }
        candidate = parent;
    }
    UIView* row = label.superview;
    UIView* best = row;
    CGFloat bestDelta = CGFLOAT_MAX;
    for (NSInteger i = 0; i < 8 && row != nil; i++) {
        CGFloat height = row.bounds.size.height;
        if (height >= 28.0 && height <= 96.0) {
            CGFloat delta = fabs(height - 44.0);
            if (delta < bestDelta) {
                bestDelta = delta;
                best = row;
            }
        }
        row = row.superview;
    }
    return best ?: label;
}

static const void* kGuaguaPlayerOverlayKey = &kGuaguaPlayerOverlayKey;

static void GuaguaTakeOverRow(UILabel* label, UIView* row) {
    if (label == nil || row == nil) {
        return;
    }

    NSString* title = GuaguaPlayerDownloadTitle();
    if (![NFBLabelText(label) isEqualToString:title]) {
        UIFont* font = label.font ?: [UIFont systemFontOfSize:17.0];
        UIColor* color = label.textColor ?: [UIColor labelColor];
        label.attributedText = [[NSAttributedString alloc] initWithString:title
                                                              attributes:@{
                                                                  NSFontAttributeName : font,
                                                                  NSForegroundColorAttributeName :
                                                                      color
                                                              }];
        label.text = title;
    }

    UIButton* overlay = objc_getAssociatedObject(row, kGuaguaPlayerOverlayKey);
    if (overlay == nil) {
        overlay = [UIButton buttonWithType:UIButtonTypeCustom];
        overlay.backgroundColor = [UIColor clearColor];
        overlay.frame = row.bounds;
        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        GuaguaRowTapProxy* proxy = [GuaguaRowTapProxy sharedProxy];
        [overlay addTarget:proxy
                    action:@selector(handleTap:)
          forControlEvents:UIControlEventTouchUpInside];
        [overlay addTarget:proxy
                    action:@selector(handleTouchDown:)
          forControlEvents:UIControlEventTouchDown];
        [overlay addTarget:proxy
                    action:@selector(handleTouchUp:)
          forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [row addSubview:overlay];
        objc_setAssociatedObject(row, kGuaguaPlayerOverlayKey, overlay,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    overlay.frame = row.bounds;
    [row bringSubviewToFront:overlay];
}

#pragma mark - 官方行整行移除 + 我们的行插到面板第一行

static const void* kGuaguaInjectedRowKey = &kGuaguaInjectedRowKey;

static UIControl* GuaguaBuildOurRow(CGFloat width, CGFloat height, UILabel* anchor) {
    UIControl* row = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    row.backgroundColor = [UIColor clearColor];

    CGFloat iconSize = 18.0;
    CGFloat iconX = 18.0;
    UIImage* image = [UIImage systemImageNamed:@"square.and.arrow.down"];
    UIImageView* icon = [[UIImageView alloc] initWithImage:image];
    icon.tintColor = anchor.textColor ?: [UIColor secondaryLabelColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.frame = CGRectMake(iconX, (height - iconSize) / 2.0, iconSize, iconSize);
    [row addSubview:icon];

    CGFloat textX = iconX + iconSize + 16.0;
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(textX, 0.0,
                                                              MAX(80.0, width - textX - 44.0),
                                                              height)];
    label.text = GuaguaPlayerDownloadTitle();
    label.font = anchor.font ?: [UIFont systemFontOfSize:16.0];
    label.textColor = anchor.textColor ?: [UIColor labelColor];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    [row addSubview:label];

    UIImageView* trailing =
        [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"arrow.down.circle"]];
    trailing.image = [UIImage systemImageNamed:@"arrow.down.circle"];
    trailing.tintColor = [UIColor secondaryLabelColor];
    trailing.contentMode = UIViewContentModeScaleAspectFit;
    trailing.frame = CGRectMake(width - 40.0, (height - 20.0) / 2.0, 20.0, 20.0);
    [row addSubview:trailing];

    GuaguaRowTapProxy* proxy = [GuaguaRowTapProxy sharedProxy];
    [row addTarget:proxy
            action:@selector(handleTap:)
          forControlEvents:UIControlEventTouchUpInside];
    [row addTarget:proxy
            action:@selector(handleTouchDown:)
          forControlEvents:UIControlEventTouchDown];
    [row addTarget:proxy
            action:@selector(handleTouchUp:)
          forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                          UIControlEventTouchCancel];
    return row;
}

// 官方那一行整行拿掉：从 stack 的 arrangedSubviews 里摘掉，再从视图树移除。
static void GuaguaRemoveRow(UIView* row) {
    if (row == nil) {
        return;
    }
    UIView* parent = row.superview;
    if ([parent isKindOfClass:[UIStackView class]]) {
        [(UIStackView*)parent removeArrangedSubview:row];
    }
    row.hidden = YES;
    row.alpha = 0.0;
    [row removeFromSuperview];
}

// 往上找最近的 UIStackView（X 每行外面常再包一层，直接父视图不一定是 stack）。
static UIStackView* GuaguaNearestStack(UIView* view, UIView** outChild) {
    UIView* cursor = view;
    for (NSInteger i = 0; i < 6 && cursor != nil; i++) {
        if ([cursor.superview isKindOfClass:[UIStackView class]]) {
            if (outChild != NULL) {
                *outChild = cursor;
            }
            return (UIStackView*)cursor.superview;
        }
        cursor = cursor.superview;
    }
    return nil;
}

// 把我们的行插到面板「第一行」——也就是「质量」那一行的上面。
static void GuaguaInsertOurRowAtTop(UIWindow* window, UILabel* topAnchor) {
    if (window == nil || topAnchor == nil) {
        return;
    }
    if (objc_getAssociatedObject(window, kGuaguaInjectedRowKey) != nil) {
        return;
    }

    UIView* anchorRow = NFBRowContainerForLabel(topAnchor);
    if (anchorRow == nil) {
        return;
    }

    CGFloat height = anchorRow.bounds.size.height;
    if (height < 20.0 || height > 120.0) {
        height = 44.0;
    }

    UIView* child = anchorRow;
    UIStackView* stack = GuaguaNearestStack(anchorRow, &child);

    if (stack != nil) {
        NSUInteger index = [stack.arrangedSubviews indexOfObject:child];
        if (index == NSNotFound) {
            index = 0;
        }
        CGFloat width = child.bounds.size.width > 40.0 ? child.bounds.size.width
                                                       : stack.bounds.size.width;
        UIControl* row = GuaguaBuildOurRow(width, height, topAnchor);
        [stack insertArrangedSubview:row atIndex:index];
        objc_setAssociatedObject(window, kGuaguaInjectedRowKey, row,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[Guagua] 下载行已插入面板第一位");
        return;
    }

    // 面板不是 stack 布局时的兜底：窗口里挂一个悬浮入口，保证能下载
    CGFloat width = 210.0;
    UIControl* pill = GuaguaBuildOurRow(width, 44.0, topAnchor);
    pill.backgroundColor = [UIColor secondarySystemBackgroundColor];
    pill.layer.cornerRadius = 22.0;
    pill.frame = CGRectMake(window.bounds.size.width - width - 20.0,
                            window.bounds.size.height - 170.0, width, 44.0);
    pill.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [window addSubview:pill];
    objc_setAssociatedObject(window, kGuaguaInjectedRowKey, pill,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[Guagua] 面板非 stack 布局，改用悬浮入口");
}

#pragma mark - 方案 B：无障碍树（SwiftUI 的 Text 走这里）

static void NFBCollectAccessibilityElements(id container,
                                            NSMutableArray* out,
                                            NSInteger depth) {
    if (container == nil || depth > 40 || out.count > 1500) {
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
            NFBCollectAccessibilityElements(subview, out, depth + 1);
        }
    }
}

static NSString* NFBAccessibilityLabel(id element) {
    @try {
        if ([element respondsToSelector:@selector(accessibilityLabel)]) {
            id label = [element accessibilityLabel];
            if ([label isKindOfClass:[NSString class]]) {
                return label;
            }
        }
    } @catch (__unused NSException* exception) {
    }
    return nil;
}

static BOOL NFBAccessibilityFrame(id element, CGRect* outFrame) {
    @try {
        if ([element respondsToSelector:@selector(accessibilityFrame)]) {
            CGRect frame = [element accessibilityFrame];
            if (frame.size.width > 40.0 && frame.size.height > 20.0) {
                *outFrame = frame;
                return YES;
            }
        }
    } @catch (__unused NSException* exception) {
    }
    return NO;
}

static const void* kGuaguaAXOverlayKey = &kGuaguaAXOverlayKey;

static UIView* GuaguaBuildAccessibilityRow(UIWindow* window, CGRect screenRect) {
    UIView* container = [[UIView alloc] initWithFrame:screenRect];
    container.backgroundColor = [UIColor clearColor];
    container.clipsToBounds = YES;

    UIView* snapshot = [window resizableSnapshotViewFromRect:screenRect
                                          afterScreenUpdates:NO
                                               withCapInsets:UIEdgeInsetsZero];
    if (snapshot != nil) {
        snapshot.frame = container.bounds;
        snapshot.userInteractionEnabled = NO;
        [container addSubview:snapshot];
    }

    // 取行内右侧空白像素当底色，自动适配深 / 浅色模式
    CGRect sampleRect = CGRectMake(screenRect.origin.x + screenRect.size.width - 6.0,
                                   screenRect.origin.y + 3.0, 2.0, 2.0);
    UIView* colorStrip = [window resizableSnapshotViewFromRect:sampleRect
                                            afterScreenUpdates:NO
                                                 withCapInsets:UIEdgeInsetsZero];
    CGFloat textLeft = 52.0;
    CGFloat textRight = 52.0;
    if (colorStrip != nil && screenRect.size.width > textLeft + textRight + 40.0) {
        UIView* cover = [[UIView alloc] initWithFrame:CGRectMake(textLeft, 0.0,
                                                                screenRect.size.width - textLeft -
                                                                    textRight,
                                                                screenRect.size.height)];
        colorStrip.frame = cover.bounds;
        colorStrip.userInteractionEnabled = NO;
        [cover addSubview:colorStrip];
        [container addSubview:cover];
    }

    UILabel* title = [[UILabel alloc] init];
    title.text = GuaguaPlayerDownloadTitle();
    title.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    title.textColor = [UIColor labelColor];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.8;
    title.frame = CGRectMake(textLeft + 2.0, 0.0,
                             MAX(60.0, screenRect.size.width - textLeft - textRight - 6.0),
                             screenRect.size.height);
    [container addSubview:title];

    container.userInteractionEnabled = YES;
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[GuaguaRowTapProxy sharedProxy]
                action:@selector(handleTap:)];
    [container addGestureRecognizer:tap];
    return container;
}

#pragma mark - 播放器里的悬浮下载按钮（官方行保持不动）


// 最上层控制器是不是沉浸式播放器（时间线、帖子详情都不算）
static BOOL NFBTopIsImmersivePlayer(void) {
    UIWindow* window = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow* candidate in ((UIWindowScene*)scene).windows) {
            if (!candidate.hidden && candidate.alpha > 0.01 && candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window != nil) {
            break;
        }
    }
    if (window == nil) {
        return NO;
    }
    UIViewController* vc = window.rootViewController;
    for (NSInteger i = 0; i < 8 && vc != nil; i++) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            vc = ((UINavigationController*)vc).visibleViewController;
            continue;
        }
        if ([vc isKindOfClass:[UITabBarController class]]) {
            vc = ((UITabBarController*)vc).selectedViewController;
            continue;
        }
        UIViewController* presented = vc.presentedViewController;
        if (presented != nil) {
            vc = presented;
            continue;
        }
        break;
    }
    if (vc == nil) {
        return NO;
    }
    NSString* name = NSStringFromClass([vc class]);
    return [name containsString:@"Immersive"] || [name isEqualToString:@"T1ImmersiveViewController"] ||
           [name isEqualToString:@"T1ImmersiveViewControllerV2"];
}

// 播放器设置面板是否已经打开（打开时收起胶囊，避免盖住面板）
static BOOL NFBPlayerPanelIsOpen(UIWindow* window) {
    NSMutableArray<UILabel*>* labels = [NSMutableArray array];
    NFBCollectLabels(window, labels, 0);
    for (UILabel* label in labels) {
        if ([NFBQualityRowTitles() containsObject:NFBTrimmedLowercase(NFBLabelText(label))]) {
            return YES;
        }
    }
    return NO;
}

static const void* kGuaguaPlayerPillKey = &kGuaguaPlayerPillKey;

static void GuaguaUpdatePlayerDownloadPill(UIWindow* window) {
    if (window == nil) {
        return;
    }
    BOOL need = NFBTopIsImmersivePlayer() && !NFBPlayerPanelIsOpen(window);
    UIView* existing = objc_getAssociatedObject(window, kGuaguaPlayerPillKey);
    if (!need) {
        if (existing != nil) {
            [existing removeFromSuperview];
            objc_setAssociatedObject(window, kGuaguaPlayerPillKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (existing != nil) {
        [window bringSubviewToFront:existing];
        return;
    }

    CGFloat width = 232.0;
    CGFloat height = 46.0;
    UIControl* pill = GuaguaBuildOurRow(width, height, nil);
    pill.backgroundColor = [UIColor secondarySystemBackgroundColor];
    pill.layer.cornerRadius = height / 2.0;
    pill.layer.shadowColor = [UIColor blackColor].CGColor;
    pill.layer.shadowOpacity = 0.22;
    pill.layer.shadowRadius = 10.0;
    pill.layer.shadowOffset = CGSizeMake(0, 3);
    pill.frame = CGRectMake(window.bounds.size.width - width - 18.0,
                            window.bounds.size.height - height - 132.0, width, height);
    pill.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [window addSubview:pill];
    objc_setAssociatedObject(window, kGuaguaPlayerPillKey, pill,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 诊断转储

static void NFBDumpView(UIView* view, NSInteger depth, NSMutableString* out) {
    if (view == nil || depth > 18) {
        return;
    }
    NSMutableString* indent = [NSMutableString string];
    for (NSInteger i = 0; i < depth; i++) {
        [indent appendString:@"  "];
    }
    NSString* extra = @"";
    if ([view isKindOfClass:[UILabel class]]) {
        extra = [NSString stringWithFormat:@" text=\"%@\"", NFBLabelText((UILabel*)view)];
    }
    [out appendFormat:@"%@%@ %@%@\n", indent, NSStringFromClass([view class]),
                       NSStringFromCGRect(view.frame), extra];
    for (UIView* subview in view.subviews) {
        NFBDumpView(subview, depth + 1, out);
    }
}

// 只在「窗口里出现了名字带 Sheet 的视图」时抓一次：那才是玩家设置面板。
static void GuaguaDumpWindow(UIWindow* window) {
    static BOOL dumped = NO;
    if (dumped || window == nil) {
        return;
    }
    dumped = YES;

    NSMutableString* report = [NSMutableString string];
    [report appendString:@"== Guagua window diag v2 ==\n"];
    UIViewController* root = window.rootViewController;
    NSMutableString* chain = [NSMutableString string];
    UIViewController* cursor = root;
    for (NSInteger i = 0; i < 8 && cursor != nil; i++) {
        [chain appendFormat:@"%@ > ", NSStringFromClass([cursor class])];
        cursor = cursor.presentedViewController;
    }
    [report appendFormat:@"VC chain: %@\n\n", chain];
    NFBDumpView(window, 0, report);

    [report appendString:@"\n-- accessibility --\n"];
    NSMutableArray* elements = [NSMutableArray array];
    NFBCollectAccessibilityElements(window, elements, 0);
    for (id element in elements) {
        CGRect frame = CGRectZero;
        NFBAccessibilityFrame(element, &frame);
        [report appendFormat:@"%@ %@ label=%@\n", NSStringFromClass([element class]),
                              NSStringFromCGRect(frame), NFBAccessibilityLabel(element) ?: @"(nil)"];
    }

    UIPasteboard.generalPasteboard.string = report;
    NSLog(@"[Guagua] window diag copied (%lu chars)", (unsigned long)report.length);

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:@"呱呱助手"
                         message:@"设置面板结构已复制到剪贴板，请发给开发者。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [topMostController() presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 统一扫描（窗口级）

static BOOL NFBWindowHasImmersivePlayer(UIView* view, NSInteger depth) {
    if (view == nil || depth > 40) {
        return NO;
    }
    NSString* name = NSStringFromClass([view class]);
    if ([name containsString:@"ImmersiveVideoPageView"] ||
        [name containsString:@"ImmersiveCardView"]) {
        return YES;
    }
    for (UIView* subview in view.subviews) {
        if (NFBWindowHasImmersivePlayer(subview, depth + 1)) {
            return YES;
        }
    }
    return NO;
}

static BOOL NFBWindowHasSheetClass(UIView* view, NSInteger depth) {    if (view == nil || depth > 40) {
        return NO;
    }
    NSString* name = NSStringFromClass([view class]);
    if ([name containsString:@"Sheet"] || [name containsString:@"VideoSettings"] ||
        [name containsString:@"PlayerSettings"]) {
        if (view.bounds.size.height > 120.0) {
            return YES;
        }
    }
    for (UIView* subview in view.subviews) {
        if (NFBWindowHasSheetClass(subview, depth + 1)) {
            return YES;
        }
    }
    return NO;
}

// 返回 YES = 已经接管过（或确实处理过面板）
static BOOL GuaguaScanWindow(UIWindow* window) {
    if (window == nil) {
        return NO;
    }

    UIView* injected = objc_getAssociatedObject(window, kGuaguaInjectedRowKey);

    // ---- 1) 标签路径 ----
    NSMutableArray<UILabel*>* labels = [NSMutableArray array];
    NFBCollectLabels(window, labels, 0);

    UILabel* qualityLabel = nil;
    UILabel* downloadLabel = nil;
    for (UILabel* label in labels) {
        // 跳过我们自己插的那一行，别把它当成官方行
        if (injected != nil && [label isDescendantOfView:injected]) {
            continue;
        }
        NSString* normalized = NFBTrimmedLowercase(NFBLabelText(label));
        if (normalized.length == 0) {
            continue;
        }
        if (qualityLabel == nil && [NFBQualityRowTitles() containsObject:normalized]) {
            qualityLabel = label;
            continue;
        }
        if (downloadLabel == nil && [NFBOfficialDownloadTitles() containsObject:normalized]) {
            downloadLabel = label;
        }
    }

    if (qualityLabel != nil) {
        // 官方「下载视频」行保留原样；我们的入口用右下角悬浮按钮，不动面板结构
        return YES;
    }

    // ---- 2) 无障碍路径（纯 SwiftUI 面板的兜底）----
    NSMutableArray* elements = [NSMutableArray array];
    NFBCollectAccessibilityElements(window, elements, 0);
    CGRect downloadFrame = CGRectZero;
    BOOL hasQuality = NO;
    NSString* ours = GuaguaPlayerDownloadTitle();
    for (id element in elements) {
        NSString* label = NFBAccessibilityLabel(element);
        NSString* normalized = NFBTrimmedLowercase(label);
        if (normalized.length == 0) {
            continue;
        }
        if (!hasQuality && [NFBQualityRowTitles() containsObject:normalized]) {
            hasQuality = YES;
            continue;
        }
        if (CGRectIsEmpty(downloadFrame) &&
            ([NFBOfficialDownloadTitles() containsObject:normalized] ||
             [label isEqualToString:ours])) {
            NFBAccessibilityFrame(element, &downloadFrame);
        }
    }
    if (hasQuality && !CGRectIsEmpty(downloadFrame)) {
        UIView* existing = objc_getAssociatedObject(window, kGuaguaAXOverlayKey);
        if (existing != nil && CGRectEqualToRect(existing.frame, downloadFrame)) {
            [window bringSubviewToFront:existing];
            return YES;
        }
        [existing removeFromSuperview];
        UIView* container = GuaguaBuildAccessibilityRow(window, downloadFrame);
        if (container != nil) {
            [window addSubview:container];
            objc_setAssociatedObject(window, kGuaguaAXOverlayKey, container,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
    }

    // ---- 3) 面板出现了却认不出来 → 抓结构（只在真的在放视频时）----
    if (NFBHasPlayingVideo() && NFBWindowHasSheetClass(window, 0)) {
        GuaguaDumpWindow(window);
    }
    return NO;
}

#pragma mark - 扫描调度

static const void* kGuaguaWatchTimerKey = &kGuaguaWatchTimerKey;

static void GuaguaStopWatch(UIWindow* window) {
    NSTimer* timer = objc_getAssociatedObject(window, kGuaguaWatchTimerKey);
    if (timer != nil) {
        [timer invalidate];
        objc_setAssociatedObject(window, kGuaguaWatchTimerKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// 只在「播放器开着 / 面板刚出现」的短窗口里轮询，避免全时段拖性能。
static void GuaguaStartWatch(UIWindow* window) {
    if (window == nil || objc_getAssociatedObject(window, kGuaguaWatchTimerKey) != nil) {
        return;
    }
    __weak UIWindow* weakWindow = window;
    __block NSInteger ticks = 0;
    __block NSInteger hits = 0;
    NSTimer* timer = [NSTimer
        scheduledTimerWithTimeInterval:0.8
                               repeats:YES
                                 block:^(NSTimer* t) {
                                     UIWindow* strongWindow = weakWindow;
                                     if (strongWindow == nil || ticks++ > 900) {
                                         [t invalidate];
                                         return;
                                     }
                                     BOOL playerAlive = NFBWindowHasImmersivePlayer(strongWindow, 0);
                                     BOOL panelAlive = NFBWindowHasSheetClass(strongWindow, 0);
                                     if (!playerAlive && !panelAlive && ticks > 4) {
                                         [t invalidate];
                                         return;
                                     }
                                     GuaguaScanWindow(strongWindow);
                                     GuaguaUpdatePlayerDownloadPill(strongWindow);
                                     hits++;
                                 }];
    objc_setAssociatedObject(window, kGuaguaWatchTimerKey, timer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL NFBClassLooksLikeSheet(NSString* className) {
    return [className containsString:@"Sheet"] || [className containsString:@"VideoSettings"] ||
           [className containsString:@"PlayerSettings"];
}

%hook UIWindow

- (void)didAddSubview:(UIView*)subview {
    %orig;
    // 面板出现 = 窗口里多了个带 Sheet 的视图；只有这种时候才开始轮询。
    if (NFBClassLooksLikeSheet(NSStringFromClass([subview class]))) {
        GuaguaStartWatch(self);
    }
}

%end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIWindow* window = self.view.window;
    if (window == nil) {
        return;
    }
    GuaguaUpdatePlayerDownloadPill(window);
    if (NFBWindowHasImmersivePlayer(window, 0) || NFBWindowHasSheetClass(window, 0)) {
        GuaguaStartWatch(window);
    }
}


%end