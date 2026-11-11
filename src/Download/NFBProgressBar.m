//
//  NFBProgressBar.m
//  呱呱助手
//
//  下载队列卡片（扁平长条）：
//    视频①  ▓▓▓▓░░░░  12.3/45.6 MB   下载中
//    视频②  ░░░░░░░░░  45.6 MB       正在排队
//  只做展示，逻辑与队列无关。
//

#import "Download/NFBProgressBar.h"
#import <QuartzCore/QuartzCore.h>

static const NSInteger kTitleTag = 2001;
static const NSInteger kStatusTag = 2002;
static const NSInteger kTrackTag = 2003;
static const NSInteger kFillTag = 2004;
static const NSInteger kSizeTag = 2005;

@interface NFBProgressBar ()
@property (nonatomic, strong) UIView* card;
@property (nonatomic, strong) NSMutableArray<UIView*>* rows;
@end

@implementation NFBProgressBar

+ (instancetype)shared {
    static NFBProgressBar* bar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bar = [NFBProgressBar new];
        bar.rows = [NSMutableArray array];
    });
    return bar;
}

- (UIWindow*)keyWindow {
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

#pragma mark - 兼容旧接口（顶部胶囊已移除）

- (void)showWithTitle:(NSString*)title {
}

- (void)setProgress:(CGFloat)progress detail:(NSString*)detail {
}

- (void)showSuccessWithText:(NSString*)text {
}

- (void)hide {
    [self hideCard];
}

#pragma mark - 卡片

- (CGFloat)cardWidth {
    CGFloat screenWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    return MIN(screenWidth - 96.0, 360.0);
}

- (void)buildCardIfNeeded {
    if (self.card != nil) {
        return;
    }
    UIView* card = [[UIView alloc] initWithFrame:CGRectZero];
    card.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
    card.layer.cornerRadius = 16.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.32;
    card.layer.shadowRadius = 10.0;
    card.layer.shadowOffset = CGSizeMake(0, 3);
    card.alpha = 0.0;
    card.hidden = YES;
    self.card = card;
}

- (UIView*)rowAtIndex:(NSInteger)index width:(CGFloat)width {
    while ((NSInteger)self.rows.count <= index) {
        UIView* row = [[UIView alloc] initWithFrame:CGRectZero];
        row.backgroundColor = [UIColor clearColor];

        UILabel* title = [[UILabel alloc] initWithFrame:CGRectZero];
        title.tag = kTitleTag;
        title.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        title.textColor = [UIColor whiteColor];
        [row addSubview:title];

        UILabel* status = [[UILabel alloc] initWithFrame:CGRectZero];
        status.tag = kStatusTag;
        status.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
        status.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
        status.textAlignment = NSTextAlignmentRight;
        [row addSubview:status];

        UILabel* size = [[UILabel alloc] initWithFrame:CGRectZero];
        size.tag = kSizeTag;
        size.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
        size.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
        size.textAlignment = NSTextAlignmentRight;
        [row addSubview:size];

        UIView* track = [[UIView alloc] initWithFrame:CGRectZero];
        track.tag = kTrackTag;
        track.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
        track.layer.cornerRadius = 1.5;
        [row addSubview:track];

        UIView* fill = [[UIView alloc] initWithFrame:CGRectZero];
        fill.tag = kFillTag;
        fill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
        fill.layer.cornerRadius = 1.5;
        [track addSubview:fill];

        [self.card addSubview:row];
        [self.rows addObject:row];
    }
    return self.rows[index];
}

- (void)updateQueueRows:(NSArray<NSDictionary*>*)rows {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (rows.count == 0) {
            [self hideCard];
            return;
        }
        [self buildCardIfNeeded];

        // 多余的行先移除
        while ((NSInteger)self.rows.count > (NSInteger)rows.count) {
            UIView* last = self.rows.lastObject;
            [last removeFromSuperview];
            [self.rows removeLastObject];
        }

        CGFloat width = [self cardWidth];
        CGFloat rowHeight = 26.0;
        CGFloat topPadding = 6.0;

        for (NSInteger index = 0; index < (NSInteger)rows.count; index++) {
            NSDictionary* info = rows[index];
            UIView* row = [self rowAtIndex:index width:width];
            row.frame = CGRectMake(0, topPadding + index * rowHeight, width, rowHeight);

            UILabel* title = (UILabel*)[row viewWithTag:kTitleTag];
            UILabel* status = (UILabel*)[row viewWithTag:kStatusTag];
            UILabel* size = (UILabel*)[row viewWithTag:kSizeTag];
            UIView* track = [row viewWithTag:kTrackTag];
            UIView* fill = [row viewWithTag:kFillTag];

            // 一行：标题 ｜ 进度条 ｜ 大小 ｜ 状态
            CGFloat titleWidth = 56.0;
            CGFloat statusWidth = 52.0;
            CGFloat sizeWidth = 82.0;
            CGFloat leftInset = 10.0;
            CGFloat gap = 6.0;

            title.text = info[@"title"];
            title.frame = CGRectMake(leftInset, 0, titleWidth, rowHeight);

            CGFloat statusX = width - leftInset - statusWidth;
            status.text = info[@"status"];
            status.frame = CGRectMake(statusX, 0, statusWidth, rowHeight);

            size.text = info[@"size"];
            size.frame = CGRectMake(statusX - gap - sizeWidth, 0, sizeWidth, rowHeight);

            CGFloat trackX = leftInset + titleWidth + 8.0;
            CGFloat trackWidth = size.frame.origin.x - gap - trackX;
            if (trackWidth < 60.0) {
                trackWidth = 60.0;
            }
            track.frame = CGRectMake(trackX, (rowHeight - 4.0) / 2.0, trackWidth, 4.0);

            CGFloat progress = [info[@"progress"] doubleValue];
            NSString* statusText = info[@"status"] ?: @"";
            BOOL done = [statusText containsString:@"已完成"];
            CGFloat ratio = done ? 1.0 : MAX(0.0, MIN(1.0, progress));
            fill.frame = CGRectMake(0, 0, trackWidth * ratio, 4.0);
        }

        CGFloat height = topPadding * 2.0 + rows.count * rowHeight - 4.0;
        [self presentCardWithWidth:width height:height];
    });
}

- (void)presentCardWithWidth:(CGFloat)width height:(CGFloat)height {
    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return;
    }
    if (self.card.superview != window) {
        [self.card removeFromSuperview];
        [window addSubview:self.card];
    }

    CGFloat top = window.safeAreaInsets.top + 6.0;
    self.card.hidden = NO;
    self.card.frame = CGRectMake(CGRectGetMidX(window.bounds) - width / 2.0, top, width, height);
    self.card.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.card.bounds cornerRadius:16.0].CGPath;
    [window bringSubviewToFront:self.card];

    if (self.card.alpha < 0.99) {
        [UIView animateWithDuration:0.15
                         animations:^{
                             self.card.alpha = 1.0;
                         }];
    }
}

- (void)hideCard {
    if (self.card == nil || self.card.hidden) {
        return;
    }
    UIView* card = self.card;
    [UIView animateWithDuration:0.2
        animations:^{
            card.alpha = 0.0;
        }
        completion:^(BOOL finished) {
            card.hidden = YES;
            [card removeFromSuperview];
            for (UIView* row in self.rows) {
                [row removeFromSuperview];
            }
            [self.rows removeAllObjects];
        }];
}

@end
