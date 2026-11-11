//
//  NFBProgressBar.m
//  呱呱助手
//
//  顶部深色进度提示：
//    下载中 ---- 左侧「正在下载 1234.5 MB」，右侧百分比，下方 3pt 细条
//    完成时   ---- 变成更大的一枚「✓ 下载完成」，绿色勾，停留 2.2 秒
//

#import "Download/NFBProgressBar.h"

@interface NFBProgressBar ()
@property (nonatomic, strong) UIView* container;
@property (nonatomic, strong) UIView* progressGroup;
@property (nonatomic, strong) UIView* successGroup;
@property (nonatomic, strong) UILabel* sizeLabel;
@property (nonatomic, strong) UILabel* percentLabel;
@property (nonatomic, strong) UIProgressView* progressView;
@property (nonatomic, strong) NSTimer* sweepTimer;
@property (nonatomic, assign) CGFloat sweepValue;
@property (nonatomic, assign) BOOL sweeping;
@property (nonatomic, strong) UIView* queueView;
@property (nonatomic, strong) NSMutableArray<UIView*>* queueRows;


@implementation NFBProgressBar

+ (instancetype)shared {
    static NFBProgressBar* bar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bar = [NFBProgressBar new];
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

- (void)buildIfNeeded {
    if (self.container != nil) {
        return;
    }
    CGFloat width = 240.0;

    UIView* container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 36.0)];
    container.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    container.layer.cornerRadius = 12.0;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.35;
    container.layer.shadowRadius = 8.0;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.alpha = 0.0;
    self.container = container;

    // ---- 进度组 ----
    UIView* progressGroup = [[UIView alloc] initWithFrame:container.bounds];
    progressGroup.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight;

    UILabel* size = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 5.0, 170.0, 15.0)];
    size.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    size.textColor = [UIColor whiteColor];
    size.text = @"正在下载 0 MB";
    [progressGroup addSubview:size];

    UILabel* percent = [[UILabel alloc] initWithFrame:CGRectMake(width - 62.0, 5.0, 50.0, 15.0)];
    percent.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    percent.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    percent.textAlignment = NSTextAlignmentRight;
    percent.text = @"0%";
    [progressGroup addSubview:percent];

    UIProgressView* bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    bar.frame = CGRectMake(12.0, 25.0, width - 24.0, 3.0);
    bar.progressTintColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    bar.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    bar.progress = 0.0;
    [progressGroup addSubview:bar];

    [container addSubview:progressGroup];

    // ---- 完成组 ----
    UIView* successGroup = [[UIView alloc] initWithFrame:container.bounds];
    successGroup.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight;
    successGroup.hidden = YES;

    UIImageView* tick = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"
                                withConfiguration:[UIImageSymbolConfiguration
                                                      configurationWithPointSize:20.0]]];
    tick.tintColor = [UIColor systemGreenColor];
    tick.frame = CGRectMake(16.0, 12.0, 20.0, 20.0);
    tick.contentMode = UIViewContentModeScaleAspectFit;
    [successGroup addSubview:tick];

    UILabel* done = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 200.0, 44.0)];
    done.text = @"下载完成";
    done.textAlignment = NSTextAlignmentCenter;
    done.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
    done.textColor = [UIColor whiteColor];
    [successGroup addSubview:done];

    [container addSubview:successGroup];

    self.progressGroup = progressGroup;
    self.successGroup = successGroup;
    self.sizeLabel = size;
    self.percentLabel = percent;
    self.progressView = bar;
}

- (BOOL)presentContainer {
    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return NO;
    }
    if (self.container.superview != window) {
        [self.container removeFromSuperview];
        [window addSubview:self.container];
    }
    CGFloat topInset = window.safeAreaInsets.top;
    self.container.center =
        CGPointMake(CGRectGetWidth(window.bounds) / 2.0,
                    topInset + 8.0 + CGRectGetHeight(self.container.bounds) / 2.0);
    self.container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleRightMargin |
                                      UIViewAutoresizingFlexibleTopMargin;
    [window bringSubviewToFront:self.container];
    [UIView animateWithDuration:0.15
                     animations:^{
                         self.container.alpha = 1.0;
                     }];
    return YES;
}

#pragma mark - 扫动动画

- (void)startSweepIfNeeded {
    if (self.sweeping) {
        return;
    }
    self.sweeping = YES;
    self.sweepValue = 0.06;
    __weak NFBProgressBar* weakSelf = self;
    self.sweepTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                      repeats:YES
                                                        block:^(NSTimer* timer) {
                                                            NFBProgressBar* strongSelf = weakSelf;
                                                            if (strongSelf == nil || !strongSelf.sweeping) {
                                                                [timer invalidate];
                                                                return;
                                                            }
                                                            strongSelf.sweepValue += 0.018;
                                                            if (strongSelf.sweepValue > 0.94) {
                                                                strongSelf.sweepValue = 0.06;
                                                            }
                                                            strongSelf.progressView.progress =
                                                                strongSelf.sweepValue;
                                                        }];
    [[NSRunLoop mainRunLoop] addTimer:self.sweepTimer forMode:NSRunLoopCommonModes];
}

- (void)stopSweep {
    self.sweeping = NO;
    [self.sweepTimer invalidate];
    self.sweepTimer = nil;
}

#pragma mark - Public

- (void)showWithTitle:(NSString*)title {
    [self buildIfNeeded];
    [self stopSweep];

    self.progressGroup.hidden = NO;
    self.successGroup.hidden = YES;

    NSString* prefix = title.length ? title : @"正在下载";
    self.subtitlePrefix = prefix;
    self.sizeLabel.text = [NSString stringWithFormat:@"%@ 0 MB", prefix];
    self.percentLabel.text = @"0%";
    self.percentLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    self.progressView.progress = 0.0;

    if (![self presentContainer]) {
        return;
    }
    [self startSweepIfNeeded];
}

- (void)setProgress:(CGFloat)progress detail:(NSString*)detail {
    if (self.container == nil) {
        return;
    }
    CGFloat clamped = MAX(0.0, MIN(1.0, progress));

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.successGroup.hidden == NO) {
            return;  // 已完成，别再被进度覆盖
        }
        if (detail.length > 0) {
            NSString* prefix = self.subtitlePrefix.length ? self.subtitlePrefix : @"正在下载";
            self.sizeLabel.text = [NSString stringWithFormat:@"%@ %@", prefix, detail];
        }
        if (clamped > 0.001) {
            [self stopSweep];
            self.progressView.progress = clamped;
            self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", clamped * 100.0];
        } else if (!self.sweeping) {
            [self startSweepIfNeeded];
            self.percentLabel.text = @"…";
        }
    });
}

- (void)showSuccessWithText:(NSString*)text {
    [self buildIfNeeded];
    [self stopSweep];

    // 换成大一号的“完成”样式
    self.container.bounds = CGRectMake(0, 0, 236.0, 46.0);
    self.container.layer.cornerRadius = 14.0;
    self.progressGroup.hidden = YES;
    self.successGroup.hidden = NO;
    CGFloat capsuleWidth = CGRectGetWidth(self.container.bounds);
    for (UIView* sub in self.successGroup.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            ((UILabel*)sub).text = text.length ? text : @"下载完成";
            ((UILabel*)sub).textAlignment = NSTextAlignmentCenter;
            sub.frame = CGRectMake(0.0, 0.0, capsuleWidth, 46.0);
        } else {
            sub.frame = CGRectMake(14.0, 12.0, 20.0, 20.0);
        }
    }

    if (![self presentContainer]) {
        return;
    }

    __weak NFBProgressBar* weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       [weakSelf hide];
                   });
}

- (void)hide {
    if (self.container == nil) {
        return;
    }
    [self stopSweep];
    __weak NFBProgressBar* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2
                         animations:^{
                             weakSelf.container.alpha = 0.0;
                         }
                         completion:^(BOOL finished) {
                             [weakSelf.container removeFromSuperview];
                             weakSelf.container.bounds = CGRectMake(0, 0, 240.0, 36.0);
                             weakSelf.container.layer.cornerRadius = 12.0;
                             weakSelf.progressGroup.hidden = NO;
                             weakSelf.successGroup.hidden = YES;
                         }];
    });
}

#pragma mark - 队列列表（贴在顶部胶囊下方）

- (void)updateQueueRows:(NSArray<NSDictionary*>*)rows {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (rows.count < 2) {
            [self hideQueueView];
            return;
        }
        [self buildQueueViewIfNeeded];

        for (UIView* view in self.queueRows) {
            [view removeFromSuperview];
        }
        [self.queueRows removeAllObjects];

        CGFloat width = 240.0;
        CGFloat rowHeight = 28.0;
        NSInteger visible = MIN(rows.count, 4);
        CGFloat height = visible * rowHeight + 10.0;

        for (NSInteger index = 0; index < visible; index++) {
            NSDictionary* info = rows[index];
            UIView* row = [[UIView alloc] initWithFrame:CGRectMake(0, 5.0 + index * rowHeight, width, rowHeight)];
            row.backgroundColor = [UIColor clearColor];

            UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 120, rowHeight)];
            title.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
            title.textColor = [UIColor whiteColor];
            title.text = info[@"title"];
            [row addSubview:title];

            UILabel* status = [[UILabel alloc] initWithFrame:CGRectMake(width - 104, 0, 90, rowHeight)];
            status.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular];
            status.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
            status.textAlignment = NSTextAlignmentRight;
            status.text = info[@"status"];
            [row addSubview:status];

            [self.queueView addSubview:row];
            [self.queueRows addObject:row];
        }

        self.queueView.hidden = NO;
        [self layoutQueueViewWithHeight:height];
    });
}

- (void)buildQueueViewIfNeeded {
    if (self.queueView != nil) {
        return;
    }
    UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 60)];
    view.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.94];
    view.layer.cornerRadius = 12.0;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.3;
    view.layer.shadowRadius = 8.0;
    view.layer.shadowOffset = CGSizeMake(0, 3);
    view.hidden = YES;
    self.queueView = view;
    self.queueRows = [NSMutableArray array];
}

- (void)layoutQueueViewWithHeight:(CGFloat)height {
    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return;
    }
    if (self.queueView.superview != window) {
        [self.queueView removeFromSuperview];
        [window addSubview:self.queueView];
    }
    CGFloat width = 240.0;
    CGFloat top = CGRectGetMaxY(self.container.frame) + 6.0;
    if (top < 60.0) {
        top = window.safeAreaInsets.top + 50.0;
    }
    self.queueView.frame = CGRectMake(CGRectGetMidX(window.bounds) - width / 2.0, top, width, height);
    [window bringSubviewToFront:self.queueView];
    [window bringSubviewToFront:self.container];
}

- (void)hideQueueView {
    if (self.queueView == nil || self.queueView.hidden) {
        return;
    }
    self.queueView.hidden = YES;
    [self.queueView removeFromSuperview];
}

@end

@end
