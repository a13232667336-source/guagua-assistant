//
//  PlayerDownloadMenu.x
//  呱呱助手 (Guagua Assistant)
//
//  全屏短视频（沉浸式播放器）的「⋯」设置面板里那一行官方「下载视频」：
//
//    1) 这层是 X 自绘的 SwiftUI 面板，不是 TFN 菜单，也不能用菜单项过滤；
//    2) 先用 UIKit 文本匹配（个别版本用的是 UILabel）：改名 + 透明按钮接管点击；
//    3) 匹配不到就走无障碍树（SwiftUI 的 Text 会暴露 accessibilityLabel）：
//       把官方那一行整行用快照盖住，贴上「下载视频（呱呱助手）」并接管点击，
//       这样官方那行既看不见、也点不到，我们的入口正好落在它原来的位置。
//
//  两种做法都只在「像设置面板 / 有全屏视频在播」时才启动，不拖慢时间线。
//

#import "HookHelpers.h"
#import <AVFoundation/AVFoundation.h>

@class GuaguaRowTapProxy;

#pragma mark - 字符串兜底

// 资源包万一没被注入器装进去，也不能让界面上出现 PLAYER_DOWNLOAD_TITLE 这种原始 key。
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

// 屏幕正在播放的那条视频：挑全屏、rate>0 的播放器，取 currentItem 的资源地址。
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

// 「质量」这一行：判定当前这层就是全屏播放器的设置面板。
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

// 官方「下载视频」行在各种语言里的写法。
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

#pragma mark - 方案 A：UIKit 标签（能改文字就改文字）

static void NFBCollectLabels(UIView* view,
                             NSMutableArray<UILabel*>* out,
                             NSInteger depth) {
    if (view == nil || depth > 48 || view.hidden || view.alpha < 0.01) {
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
    for (NSInteger i = 0; i < 8 && candidate != nil; i++) {
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
    for (NSInteger i = 0; i < 6 && row != nil; i++) {
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

// 返回：0 = 不是面板，1 = 是面板但没找到官方下载行，2 = 已接管
static NSInteger GuaguaProcessLabels(UIView* root) {
    NSMutableArray<UILabel*>* labels = [NSMutableArray array];
    NFBCollectLabels(root, labels, 0);
    if (labels.count == 0 || labels.count > 500) {
        return 0;
    }

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

    if (qualityLabel == nil) {
        return 0;
    }
    if (downloadLabel == nil) {
        return 1;
    }
    GuaguaTakeOverRow(downloadLabel, NFBRowContainerForLabel(downloadLabel));
    return 2;
}

#pragma mark - 方案 B：无障碍树（SwiftUI 的 Text 走这里）

static void NFBCollectAccessibilityElements(id container,
                                            NSMutableArray* out,
                                            NSInteger depth) {
    if (container == nil || depth > 26 || out.count > 800) {
        return;
    }
    if ([container respondsToSelector:@selector(accessibilityElementCount)]) {
        NSInteger count = [container accessibilityElementCount];
        if (count > 0 && count < 2000) {
            for (NSInteger i = 0; i < count; i++) {
                id element = [container accessibilityElementAtIndex:i];
                if (element != nil) {
                    [out addObject:element];
                }
            }
            return;
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

// 用窗口快照把官方那一行整行盖掉，贴上我们的名字并接管点击。
static const void* kGuaguaAXOverlayKey = &kGuaguaAXOverlayKey;

static UIView* GuaguaBuildAccessibilityRow(UIWindow* window, CGRect screenRect) {
    if (window == nil || screenRect.size.height < 20.0) {
        return nil;
    }

    UIView* container = [[UIView alloc] initWithFrame:screenRect];
    container.backgroundColor = [UIColor clearColor];
    container.clipsToBounds = YES;

    // 原行的快照（背景、图标、分隔线都是原生像素）
    UIView* snapshot = [window resizableSnapshotViewFromRect:screenRect
                                          afterScreenUpdates:NO
                                               withCapInsets:UIEdgeInsetsZero];
    if (snapshot != nil) {
        snapshot.frame = container.bounds;
        snapshot.userInteractionEnabled = NO;
        [container addSubview:snapshot];
    }

    // 取行内一块空白像素当底色，自动适配深/浅色模式
    CGRect sampleRect = CGRectMake(screenRect.origin.x + screenRect.size.width - 6.0,
                                   screenRect.origin.y + 3.0, 2.0, 2.0);
    UIView* colorStrip = [window resizableSnapshotViewFromRect:sampleRect
                                            afterScreenUpdates:NO
                                                 withCapInsets:UIEdgeInsetsZero];
    CGFloat textLeft = 52.0;
    CGFloat textRight = 52.0;
    UIView* cover = nil;
    if (colorStrip != nil && screenRect.size.width > textLeft + textRight + 40.0) {
        cover = [[UIView alloc] initWithFrame:CGRectMake(textLeft, 0.0,
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

// 返回：0 = 不是面板，1 = 是面板但没找到官方下载行，2 = 已接管
static NSInteger GuaguaProcessAccessibility(UIView* root) {
    UIWindow* window = root.window;
    if (window == nil) {
        return 0;
    }

    NSMutableArray* elements = [NSMutableArray array];
    NFBCollectAccessibilityElements(window, elements, 0);
    if (elements.count == 0) {
        return 0;
    }

    CGRect qualityFrame = CGRectZero;
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
            hasQuality = NFBAccessibilityFrame(element, &qualityFrame) || YES;
            continue;
        }
        if (CGRectIsEmpty(downloadFrame) &&
            ([NFBOfficialDownloadTitles() containsObject:normalized] || [label isEqualToString:ours])) {
            NFBAccessibilityFrame(element, &downloadFrame);
        }
    }

    if (!hasQuality) {
        return 0;
    }
    if (CGRectIsEmpty(downloadFrame)) {
        return 1;
    }

    UIView* existing = objc_getAssociatedObject(window, kGuaguaAXOverlayKey);
    if (existing != nil && CGRectEqualToRect(existing.frame, downloadFrame)) {
        [window bringSubviewToFront:existing];
        return 2;
    }
    [existing removeFromSuperview];

    UIView* container = GuaguaBuildAccessibilityRow(window, downloadFrame);
    if (container == nil) {
        return 1;
    }
    [window addSubview:container];
    objc_setAssociatedObject(window, kGuaguaAXOverlayKey, container,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return 2;
}

#pragma mark - 统一入口

static BOOL GuaguaProcessPlayerSheet(UIView* root) {
    if (root == nil) {
        return NO;
    }
    NSInteger labelsResult = GuaguaProcessLabels(root);
    if (labelsResult == 0) {
        NSInteger axResult = GuaguaProcessAccessibility(root);
        return axResult != 0;
    }
    return YES;
}

#pragma mark - 扫描调度

static const void* kGuaguaPlayerTimerKey = &kGuaguaPlayerTimerKey;
static const void* kGuaguaSheetActiveKey = &kGuaguaSheetActiveKey;

static void GuaguaStopTimer(UIViewController* vc) {
    NSTimer* timer = objc_getAssociatedObject(vc, kGuaguaPlayerTimerKey);
    if (timer != nil) {
        [timer invalidate];
        objc_setAssociatedObject(vc, kGuaguaPlayerTimerKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void GuaguaWatchForPlayerSheet(UIViewController* vc) {
    if (objc_getAssociatedObject(vc, kGuaguaPlayerTimerKey) != nil) {
        return;
    }
    __weak UIViewController* weakVC = vc;
    __block NSInteger ticks = 0;
    __block NSInteger hits = 0;
    NSTimer* timer = [NSTimer
        scheduledTimerWithTimeInterval:0.3
                               repeats:YES
                                 block:^(NSTimer* t) {
                                     UIViewController* strongVC = weakVC;
                                     if (strongVC == nil || ticks++ > 60) {
                                         [t invalidate];
                                         return;
                                     }
                                     if (GuaguaProcessPlayerSheet(strongVC.view)) {
                                         objc_setAssociatedObject(strongVC, kGuaguaSheetActiveKey,
                                                                  @YES,
                                                                  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                                         if (++hits >= 6) {  // SwiftUI 重绘窗口过了就停
                                             [t invalidate];
                                         }
                                     }
                                 }];
    objc_setAssociatedObject(vc, kGuaguaPlayerTimerKey, timer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL NFBClassLooksLikeSheet(UIViewController* vc) {
    NSString* name = NSStringFromClass([vc class]);
    return [name containsString:@"Sheet"] || [name containsString:@"Player"] ||
           [name containsString:@"Settings"] || [name containsString:@"Immersive"];
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (NFBClassLooksLikeSheet(self) || NFBHasPlayingVideo()) {
        GuaguaWatchForPlayerSheet(self);
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self, kGuaguaSheetActiveKey) != nil) {
        GuaguaProcessPlayerSheet(self.view);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    GuaguaStopTimer(self);
    objc_setAssociatedObject(self, kGuaguaSheetActiveKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIWindow* window = self.view.window;
    UIView* overlay = objc_getAssociatedObject(window, kGuaguaAXOverlayKey);
    [overlay removeFromSuperview];
    objc_setAssociatedObject(window, kGuaguaAXOverlayKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end
