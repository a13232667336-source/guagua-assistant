//
//  NFBProgressBar.m
//  呱呱助手
//
//  顶部深色细进度条：
//    · 宽 190pt、条高 3pt，不遮挡内容
//    · 左侧显示已下载体积（保证 "1234.5 MB" 完整显示），右侧显示百分比
//    · 拿到总时长时跑真实进度；拿不到时来回扫动（indeterminate），不会静止不动
//

#import "Download/NFBProgressBar.h"

@interface NFBProgressBar ()
@property (nonatomic, strong) UIView* container;
@property (nonatomic, strong) UILabel* sizeLabel;
@property (nonatomic, strong) UILabel* percentLabel;
@property (nonatomic, strong) UIProgressView* progressView;
@property (nonatomic, strong) NSTimer* sweepTimer;
@property (nonatomic, assign) CGFloat sweepValue;
@property (nonatomic, assign) BOOL sweeping;
@end

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
    CGFloat width = 210.0;
    CGFloat height = 34.0;

    UIView* container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    container.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
    container.layer.cornerRadius = 10.0;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.3;
    container.layer.shadowRadius = 6.0;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.alpha = 0.0;

    // 左侧：已下载体积（宽度给足，四位数字 + MB 也放得下）
    UILabel* size = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 5.0, 132.0, 14.0)];
    size.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    size.textColor = [UIColor whiteColor];
    size.text = @"0 MB";
    [container addSubview:size];

    // 右侧：百分比
    UILabel* percent = [[UILabel alloc] initWithFrame:CGRectMake(width - 58.0, 5.0, 48.0, 14.0)];
    percent.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    percent.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    percent.textAlignment = NSTextAlignmentRight;
    percent.text = @"0%";
    [container addSubview:percent];

    UIProgressView* bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    bar.frame = CGRectMake(10.0, 23.0, width - 20.0, 3.0);
    bar.progressTintColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    bar.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    bar.progress = 0.0;
    [container addSubview:bar];

    self.container = container;
    self.sizeLabel = size;
    self.percentLabel = percent;
    self.progressView = bar;
}

#pragma mark - 扫动动画（没有总时长时用）

- (void)startSweepIfNeeded {
    if (self.sweeping) {
        return;
    }
    self.sweeping = YES;
    self.sweepValue = 0.06;
    __weak NFBProgressBar* weakSelf = self;
    self.sweepTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                      repeats:YES
                                                        block:^(NSTimer* t) {
                                                            NFBProgressBar* strongSelf = weakSelf;
                                                            if (strongSelf == nil || !strongSelf.sweeping) {
                                                                [t invalidate];
                                                                return;
                                                            }
                                                            strongSelf.sweepValue += 0.02;
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

    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return;
    }
    if (self.container.superview != window) {
        [self.container removeFromSuperview];
        [window addSubview:self.container];
    }

    CGFloat topInset = window.safeAreaInsets.top;
    self.container.center = CGPointMake(CGRectGetWidth(window.bounds) / 2.0,
                                        topInset + 8.0 + CGRectGetHeight(self.container.bounds) / 2.0);
    self.container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleRightMargin |
                                      UIViewAutoresizingFlexibleTopMargin;

    self.sizeLabel.text = @"0 MB";
    self.percentLabel.text = @"0%";
    self.progressView.progress = 0.0;

    [window bringSubviewToFront:self.container];
    [UIView animateWithDuration:0.15
                     animations:^{
                         self.container.alpha = 1.0;
                     }];

    // 先扫动起来，拿到真实进度后自动切到真实值
    [self startSweepIfNeeded];
}

- (void)setProgress:(CGFloat)progress detail:(NSString*)detail {
    if (self.container == nil) {
        return;
    }
    CGFloat clamped = MAX(0.0, MIN(1.0, progress));

    dispatch_async(dispatch_get_main_queue(), ^{
        if (detail.length > 0) {
            self.sizeLabel.text = detail;
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

- (void)hide {
    if (self.container == nil) {
        return;
    }
    [self stopSweep];
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.container.alpha = 0.0;
                         }
                         completion:^(BOOL finished) {
                             [self.container removeFromSuperview];
                         }];
    });
}

@end
