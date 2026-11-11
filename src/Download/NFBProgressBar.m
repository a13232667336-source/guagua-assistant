//
//  NFBProgressBar.m
//  呱呱助手
//
//  下载只用一个「队列卡片」显示（不再有顶部胶囊）：
//    视频①              下载中
//    ▓▓▓▓▓░░░░░░░░░░░░░░░░░░
//    视频②              排队中
//    ░░░░░░░░░░░░░░░░░░░░░░
//  全部任务结束后卡片自动消失。
//

#import "Download/NFBProgressBar.h"
#import <QuartzCore/QuartzCore.h>

@interface NFBProgressBar ()
@property (nonatomic, strong) UIView* card;
@property (nonatomic, strong) NSMutableArray<UIView*>* rows;
@property (nonatomic, strong) NSMutableArray<UIView*>* fills;
@property (nonatomic, strong) NSMutableArray<UILabel*>* statusLabels;
@end

@implementation NFBProgressBar

+ (instancetype)shared {
    static NFBProgressBar* bar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bar = [NFBProgressBar new];
        bar.rows = [NSMutableArray array];
        bar.fills = [NSMutableArray array];
        bar.statusLabels = [NSMutableArray array];
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

#pragma mark - 兼容旧接口（胶囊已移除）

- (void)showWithTitle:(NSString*)title {
    // 顶部胶囊已按需求移除，进度统一由队列卡片展示
}

- (void)setProgress:(CGFloat)progress detail:(NSString*)detail {
    // 同上：进度由 updateQueueRows 驱动
}

- (void)showSuccessWithText:(NSString*)text {
    // 完成状态在队列卡片里以“已完成”显示，不再弹胶囊
}

- (void)hide {
    [self hideCard];
}

#pragma mark - 队列卡片

- (void)buildCardIfNeeded {
    if (self.card != nil) {
        return;
    }
    UIView* card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 80)];
    card.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
    card.layer.cornerRadius = 14.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.35;
    card.layer.shadowRadius = 10.0;
    card.layer.shadowOffset = CGSizeMake(0, 3);
    card.alpha = 0.0;
    card.hidden = YES;
    self.card = card;
}

- (void)updateQueueRows:(NSArray<NSDictionary*>*)rows {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (rows.count == 0) {
            [self hideCard];
            return;
        }
        [self buildCardIfNeeded];

        // 复用已有行，避免每帧重建导致闪烁
        while ((NSInteger)self.rows.count > (NSInteger)rows.count) {
            UIView* last = self.rows.lastObject;
            [last removeFromSuperview];
            [self.rows removeLastObject];
            if (self.fills.count > 0) {
                [self.fills removeLastObject];
            }
            if (self.statusLabels.count > 0) {
                [self.statusLabels removeLastObject];
            }
        }

        CGFloat width = 240.0;
        CGFloat rowHeight = 42.0;
        CGFloat padding = 10.0;

        for (NSInteger index = 0; index < (NSInteger)rows.count; index++) {
            NSDictionary* info = rows[index];

            UIView* row = nil;
            if (index < (NSInteger)self.rows.count) {
                row = self.rows[index];
            } else {
                row = [[UIView alloc] initWithFrame:CGRectZero];
                row.backgroundColor = [UIColor clearColor];

                UILabel* title = [[UILabel alloc] initWithFrame:CGRectZero];
                title.tag = 1001;
                title.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
                title.textColor = [UIColor whiteColor];
                [row addSubview:title];

                UILabel* status = [[UILabel alloc] initWithFrame:CGRectZero];
                status.tag = 1002;
                status.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
                status.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
                status.textAlignment = NSTextAlignmentRight;
                [row addSubview:status];

                UIView* track = [[UIView alloc] initWithFrame:CGRectZero];
                track.tag = 1003;
                track.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
                track.layer.cornerRadius = 1.0;
                [row addSubview:track];

                UIView* fill = [[UIView alloc] initWithFrame:CGRectZero];
                fill.tag = 1004;
                fill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
                fill.layer.cornerRadius = 1.0;
                [track addSubview:fill];

                [self.card addSubview:row];
                [self.rows addObject:row];
                [self.fills addObject:fill];
                [self.statusLabels addObject:status];
            }

            CGFloat top = padding + index * rowHeight;
            row.frame = CGRectMake(0, top, width, rowHeight);

            UILabel* title = (UILabel*)[row viewWithTag:1001];
            UILabel* status = (UILabel*)[row viewWithTag:1002];
            UIView* track = [row viewWithTag:1003];
            UIView* fill = [row viewWithTag:1004];

            title.text = info[@"title"];
            title.frame = CGRectMake(16, 6, 150, 18);
            status.text = info[@"status"];
            status.frame = CGRectMake(width - 110, 7, 94, 16);

            CGFloat progress = [info[@"progress"] doubleValue];
            NSString* statusText = info[@"status"] ?: @"";
            BOOL done = [statusText containsString:@"已完成"];
            CGFloat ratio = done ? 1.0 : MAX(0.0, MIN(1.0, progress));

            track.frame = CGRectMake(16, 32, width - 32, 2.0);
            fill.frame = CGRectMake(0, 0, (width - 32) * ratio, 2.0);
        }

        CGFloat height = padding * 2.0 + rows.count * rowHeight;
        [self presentCardWithHeight:height];
    });
}

- (void)presentCardWithHeight:(CGFloat)height {
    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return;
    }
    if (self.card.superview != window) {
        [self.card removeFromSuperview];
        [window addSubview:self.card];
    }

    CGFloat width = 240.0;
    CGFloat top = window.safeAreaInsets.top + 8.0;
    self.card.hidden = NO;
    self.card.frame = CGRectMake(CGRectGetMidX(window.bounds) - width / 2.0, top, width, height);
    self.card.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.card.bounds cornerRadius:14.0].CGPath;
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
            [self.fills removeAllObjects];
            [self.statusLabels removeAllObjects];
        }];
}

@end
