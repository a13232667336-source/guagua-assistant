//
//  PlayerDownloadMenu.x
//  呱呱助手 (Guagua Assistant)
//
//  沉浸式播放器（图三/图四那层菜单）里的“下载视频”改造：
//   1. 官方自带的“下载视频”行永久隐藏（装上插件即生效，无开关）；
//   2. 在同一位置插入“下载视频（来自呱呱助手）”，走插件自己的 FFmpeg 下载通道，
//      并且永远下载“当前正在播放的那一条视频”（读取 AVPlayerLayer 的
//      currentItem 资源地址），不会串到别的视频上。
//

#import "HookHelpers.h"
#import <AVFoundation/AVFoundation.h>

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

// 取“当前正在播放”的视频资源地址：优先全屏、正在播放（rate > 0）的播放器，
// 这样点下载拿到的永远是屏幕上那一条视频。
static NSURL* NFBCurrentlyPlayingVideoURL(void) {
    AVPlayerLayer* bestLayer = nil;
    CGFloat bestScore = -1.0;

    for (AVPlayerLayer* layer in NFBVisiblePlayerLayers()) {
        AVPlayer* player = layer.player;
        AVPlayerItem* item = player.currentItem;
        if (player == nil || item == nil) {
            continue;
        }

        CGSize size = layer.bounds.size;
        if (size.width < 160.0 || size.height < 160.0) {
            continue;  // 头像、缩略图之类的迷你播放器不算
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
        // 没有全屏播放器时退一步：任何还在播的播放器都算。
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

#pragma mark - 菜单项的识别与改造

// 官方“下载视频”行在各国语言里的写法（X 用的是自己的本地化字符串）。
// 只在“确实有视频正在播放”的菜单里生效，所以不会误伤别的菜单。
static NSSet<NSString*>* NFBofficialDownloadTitles(void) {
    static NSSet<NSString*>* titles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        titles = [NSSet setWithArray:@[
            @"下载视频", @"下載影片", @"下載視頻", @"视频下载", @"下载影片",
            @"download video", @"download", @"video download", @"save video",
            @"動画をダウンロード", @"동영상 다운로드", @"видео скачать",
        ]];
    });
    return titles;
}

static NSString* NFBNormalizedMenuTitle(NSString* title) {
    if (![title isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString* trimmed = [title
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 去掉 “…” / “...” 后缀，X 会在需要弹二级页的项后面加省略号。
    while (trimmed.length > 0 &&
           ([trimmed hasSuffix:@"…"] || [trimmed hasSuffix:@"..."])) {
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    if (trimmed.length > 0 && [trimmed hasSuffix:@"."]) {
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    return trimmed.lowercaseString;
}

static NSString* NFBMenuItemTitle(id item) {
    if (![item isKindOfClass:[NSObject class]]) {
        return nil;
    }
    for (NSString* key in @[ @"title", @"_title", @"text" ]) {
        @try {
            if ([item respondsToSelector:NSSelectorFromString(key)]) {
                id value = [item valueForKey:key];
                if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
                    return value;
                }
            }
        } @catch (__unused NSException* exception) {
        }
    }
    return nil;
}

static BOOL NFBIsOfficialDownloadItem(id item) {
    NSString* normalized = NFBNormalizedMenuTitle(NFBMenuItemTitle(item));
    if (normalized.length == 0) {
        return NO;
    }
    return [NFBofficialDownloadTitles() containsObject:normalized];
}

static BOOL NFBIsGuaguaDownloadItem(id item) {
    NSString* title = NFBMenuItemTitle(item);
    NSString* ours = [[BHTBundle sharedBundle] localizedStringForKey:@"PLAYER_DOWNLOAD_TITLE"];
    return title.length > 0 && [title isEqualToString:ours];
}

static NSString* NFBPlayerDownloadTitle(void) {
    return [[BHTBundle sharedBundle] localizedStringForKey:@"PLAYER_DOWNLOAD_TITLE"];
}

static id NFBMakeGuaguaDownloadItem(void) {
    return [objc_getClass("TFNActionItem")
        actionItemWithTitle:NFBPlayerDownloadTitle()
                  imageName:@"arrow_down_circle_stroke"
                     action:^{
                         NSURL* url = NFBCurrentlyPlayingVideoURL();
                         if (url == nil) {
                             UIAlertController* alert = [UIAlertController
                                 alertControllerWithTitle:[[BHTBundle sharedBundle]
                                                              localizedStringForKey:
                                                                  @"PLAYER_DOWNLOAD_NO_VIDEO_TITLE"]
                                                  message:[[BHTBundle sharedBundle]
                                                              localizedStringForKey:
                                                                  @"PLAYER_DOWNLOAD_NO_VIDEO_MESSAGE"]
                                           preferredStyle:UIAlertControllerStyleAlert];
                             [alert addAction:
                                        [UIAlertAction
                                            actionWithTitle:[[BHTBundle sharedBundle]
                                                                localizedTwitterStringForKey:
                                                                    @"OK_ACTION_LABEL"]
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
                             [topMostController() presentViewController:alert
                                                               animated:YES
                                                             completion:nil];
                             return;
                         }
                         NSLog(@"[Guagua] downloading current video: %@", url);
                         [BHTManager downloadVideoFromURL:url];
                     }];
}

// 返回改造后的菜单项数组：删掉官方下载行，在原位置插入呱呱助手的下载行。
static NSArray* NFBTransformMenuItems(NSArray* items) {
    if (![items isKindOfClass:[NSArray class]] || items.count == 0) {
        return items;
    }
    if (![BHTSettings boolForKey:@"download_videos"]) {
        // 总开关关着 = 下载能力整体关闭，只做“隐藏官方下载”这一件事。
        NSMutableArray* hidden = [NSMutableArray array];
        for (id item in items) {
            if (NFBIsOfficialDownloadItem(item)) {
                continue;
            }
            [hidden addObject:item];
        }
        return hidden.copy;
    }

    NSURL* playingURL = NFBCurrentlyPlayingVideoURL();
    if (playingURL == nil) {
        // 不在视频播放场景（比如普通分享菜单），原样返回。
        return items;
    }

    NSMutableArray* result = [NSMutableArray array];
    NSInteger insertIndex = -1;
    for (id item in items) {
        if (NFBIsOfficialDownloadItem(item) || NFBIsGuaguaDownloadItem(item)) {
            if (insertIndex < 0) {
                insertIndex = (NSInteger)result.count;
            }
            continue;
        }
        [result addObject:item];
    }

    if (insertIndex < 0) {
        // 这个版本的 X 没有官方下载行：就插在“前往帖子”那一类信息行之后，
        // 也就是原来的第 5 行附近。
        insertIndex = MIN((NSInteger)4, (NSInteger)result.count);
    }

    [result insertObject:NFBMakeGuaguaDownloadItem() atIndex:(NSUInteger)insertIndex];
    return result.copy;
}

static NSArray* NFBTransformMenuSections(NSArray* sections) {
    if (![sections isKindOfClass:[NSArray class]]) {
        return sections;
    }
    NSMutableArray* result = [NSMutableArray array];
    for (id section in sections) {
        if ([section isKindOfClass:[NSArray class]]) {
            [result addObject:NFBTransformMenuItems((NSArray*)section)];
        } else {
            [result addObject:section];
        }
    }
    return result.copy;
}

#pragma mark - 兜底：非 TFN 菜单也把官方下载行藏起来

// 有些版本的播放器菜单不是 TFNActionItem 拼的，而是自绘行。给这种菜单加一层
// 视图级兜底：抛出后再把文字命中的行整行藏掉。
static void NFBHideMatchingRows(UIView* view, NSSet<NSString*>* titles, NSInteger depth) {
    if (view == nil || depth > 40 || view.hidden) {
        return;
    }
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel* label = (UILabel*)view;
        NSString* normalized = NFBNormalizedMenuTitle(label.text);
        if (normalized.length > 0 && [titles containsObject:normalized]) {
            // 找到承载这一行的容器（cell / 按钮 / 直接父视图）整行隐藏。
            UIView* row = label.superview;
            for (NSInteger i = 0; i < 4 && row != nil; i++) {
                NSString* className = NSStringFromClass([row class]);
                if ([row isKindOfClass:[UITableViewCell class]] ||
                    [row isKindOfClass:[UICollectionViewCell class]] ||
                    [row isKindOfClass:[UIControl class]] ||
                    [className containsString:@"Row"] ||
                    [className containsString:@"Cell"]) {
                    break;
                }
                row = row.superview;
            }
            (row ?: label).hidden = YES;
            (row ?: label).alpha = 0.0;
        }
    }
    for (UIView* subview in view.subviews) {
        NFBHideMatchingRows(subview, titles, depth + 1);
    }
}

static NSMutableSet<NSString*>* NFBHiddenContainers(void) {
    static NSMutableSet<NSString*>* set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

%hook TFNMenuSheetViewController

- (instancetype)initWithActionItems:(NSArray*)actionItems {
    return %orig((NSArray*)NFBTransformMenuItems(actionItems));
}

- (instancetype)initWithTitle:(NSString*)sheetTitle actionItems:(NSArray*)actionItems {
    return %orig(sheetTitle, (NSArray*)NFBTransformMenuItems(actionItems));
}

- (instancetype)initWithTitle:(NSString*)sheetTitle
                   titleStyle:(long long)sheetTitleStyle
                      message:(NSString*)sheetMessage
              messageIconName:(id)sheetMessageIconName
           actionItemSections:(NSArray*)actionItemSections {
    return %orig(sheetTitle, sheetTitleStyle, sheetMessage, sheetMessageIconName,
                 (NSArray*)NFBTransformMenuSections(actionItemSections));
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // 已经和视频播放无关的菜单不做任何处理，避免影响其它界面。
    if (NFBCurrentlyPlayingVideoURL() == nil) {
        return;
    }
    NSMutableSet<NSString*>* done = NFBHiddenContainers();
    NSString* key = [NSString stringWithFormat:@"%p", self];
    if ([done containsObject:key]) {
        return;
    }
    [done addObject:key];

    NSMutableSet<NSString*>* titles = [NSMutableSet setWithSet:NFBofficialDownloadTitles()];
    // 只藏官方那一行；呱呱助手的行必须留着。
    [titles removeObject:NFBNormalizedMenuTitle(NFBPlayerDownloadTitle())];
    NFBHideMatchingRows(self.view, titles, 0);
}

%end
