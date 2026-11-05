//
//  PlayerDownloadMenu.x
//  呱呱助手 (Guagua Assistant)
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

static NSString* GuaguaString(NSString* key, NSString* fallback) {
    NSString* value = [[BHTBundle sharedBundle] localizedStringForKey:key];
    if (value.length == 0 || [value isEqualToString:key]) {
        return fallback;
    }
    return value;
}

static NSString* GuaguaPlayerDownloadTitle(void) {
    return GuaguaString(@"PLAYER_DOWNLOAD_TITLE", @"下载视频（呱呱助手）");
}

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
            alertControllerWithTitle:GuaguaString(@"PLAYER_DOWNLOAD_NO_VIDEO_TITLE",
                                                  @"没有正在播放的视频")
                             message:GuaguaString(@"PLAYER_DOWNLOAD_NO_VIDEO_MESSAGE",
                                                  @"先播放你要下载的那条视频，再点这一项。")
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction
                             actionWithTitle:GuaguaString(@"OK_ACTION_LABEL", @"好")
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

#pragma mark - 面板里没有官方下载行时：自己插一行

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
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(textX, 0.0, MAX(80.0, width - textX - 44.0),
                                                               height)];
    label.text = GuaguaPlayerDownloadTitle();
    label.font = anchor.font ?: [UIFont systemFontOfSize:16.0];
    label.textColor = anchor.textColor ?: [UIColor labelColor];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    [row addSubview:label];

    UIImage* trailing = [UIImage systemImageNamed:@"arrow.down.circle"];
    UIImageView* trailingView = [[UIImageView alloc] initWithImage:trailing];
    trailingView.tintColor = [UIColor secondaryLabelColor];
    trailingView.contentMode = UIViewContentModeScaleAspectFit;
    trailingView.frame = CGRectMake(width - 40.0, (height - 20.0) / 2.0, 20.0, 20.0);
    [row addSubview:trailingView];

    [row addTarget:[GuaguaRowTapProxy sharedProxy]
            action:@selector(handleTap:)
          forControlEvents:UIControlEventTouchUpInside];
    [row addTarget:[GuaguaRowTapProxy sharedProxy]
            action:@selector(handleTouchDown:)
          forControlEvents:UIControlEventTouchDown];
    [row addTarget:[GuaguaRowTapProxy sharedProxy]
            action:@selector(handleTouchUp:)
          forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                          UIControlEventTouchCancel];
    return row;
}

// 没有官方下载行时（X 对部分内容本身就不给下载），在「添加到离线 / 前往帖子」旁边插一行。
static void GuaguaInsertOurRow(UIWindow* window, NSArray<UILabel*>* labels) {
    if (objc_getAssociatedObject(window, kGuaguaInjectedRowKey) != nil) {
        return;
    }

    UILabel* anchor = nil;
    for (UILabel* label in labels) {
        NSString* normalized = NFBTrimmedLowercase(NFBLabelText(label));
        if (normalized.length > 0 && [NFBOfflineRowTitles() containsObject:normalized]) {
            anchor = label;
            break;
        }
    }
    if (anchor == nil) {
        for (UILabel* label in labels) {
            NSString* normalized = NFBTrimmedLowercase(NFBLabelText(label));
            if (normalized.length > 0 && [NFBViewPostRowTitles() containsObject:normalized]) {
                anchor = label;
                break;
            }
        }
    }
    if (anchor == nil) {
        return;
    }

    UIView* anchorRow = NFBRowContainerForLabel(anchor);
    UIView* parent = anchorRow.superview;
    if (parent == nil || ![parent isKindOfClass:[UIStackView class]]) {
        NSLog(@"[Guagua] 面板没有 stack 容器，跳过插入");
        return;
    }

    UIStackView* stack = (UIStackView*)parent;
    NSUInteger index = [stack.arrangedSubviews indexOfObject:anchorRow];
    if (index == NSNotFound) {
        index = 0;
    }
    CGFloat height = anchorRow.bounds.size.height;
    if (height < 20.0 || height > 120.0) {
        height = 44.0;
    }
    CGFloat width = anchorRow.bounds.size.width > 40.0 ? anchorRow.bounds.size.width
                                                       : stack.bounds.size.width;

    UIControl* row = GuaguaBuildOurRow(width, height, anchor);
    [stack insertArrangedSubview:row atIndex:index];
    objc_setAssociatedObject(window, kGuaguaInjectedRowKey, row,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[Guagua] 已插入下载行（无官方行版本）");
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

    // ---- 1) 标签路径 ----
    NSMutableArray<UILabel*>* labels = [NSMutableArray array];
    NFBCollectLabels(window, labels, 0);
    UILabel* qualityLabel = nil;
    UILabel* downloadLabel = nil;
    NSString* ours = GuaguaPlayerDownloadTitle();
    for (UILabel* label in labels) {
        NSString* raw = NFBLabelText(label);
        NSString* normalized = NFBTrimmedLowercase(raw);
        if (normalized.length == 0) {
            continue;
        }
        if (qualityLabel == nil && [NFBQualityRowTitles() containsObject:normalized]) {
            qualityLabel = label;
            continue;
        }
        if (downloadLabel == nil && ([NFBOfficialDownloadTitles() containsObject:normalized] ||
                                     [raw isEqualToString:ours])) {
            downloadLabel = label;
        }
    }
    if (qualityLabel != nil && downloadLabel != nil) {
        GuaguaTakeOverRow(downloadLabel, NFBRowContainerForLabel(downloadLabel));
        return YES;
    }
    if (qualityLabel != nil) {
        // 面板在，但这條视频 X 没给官方下载行（部分内容本来就不提供下载）→ 自己插一行
        GuaguaInsertOurRow(window, labels);
        return YES;
    }

    // 面板不在了：清掉之前插入的行
    UIView* injected = objc_getAssociatedObject(window, kGuaguaInjectedRowKey);
    if (injected != nil) {
        [injected removeFromSuperview];
        objc_setAssociatedObject(window, kGuaguaInjectedRowKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // ---- 2) 无障碍路径 ----
    NSMutableArray* elements = [NSMutableArray array];
    NFBCollectAccessibilityElements(window, elements, 0);
    CGRect downloadFrame = CGRectZero;
    BOOL hasQuality = NO;
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
                                     GuaguaScanWindow(strongWindow);
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
    if (NFBWindowHasImmersivePlayer(window, 0) || NFBWindowHasSheetClass(window, 0)) {
        GuaguaStartWatch(window);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    GuaguaStopWatch(self.view.window);
}

%end