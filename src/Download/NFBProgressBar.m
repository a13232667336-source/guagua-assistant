//
//  NFBProgressBar.m
//  呱呱助手
//
//  顶部居中的细进度条（宽 168pt、条高 3pt），不遮挡内容，也不用居中转圈。
//

#import "Download/NFBProgressBar.h"

@interface NFBProgressBar ()
@property (nonatomic, strong) UIView* container;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UILabel* percentLabel;
@property (nonatomic, strong) UIProgressView* progressView;
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
    CGFloat width = 168.0;
    CGFloat height = 34.0;

    UIView* container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    container.backgroundColor = [UIColor secondarySystemBackgroundColor];
    container.layer.cornerRadius = 10.0;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.15;
    container.layer.shadowRadius = 6.0;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.alpha = 0.0;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 4.0, width - 60.0, 14.0)];
    title.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    title.textColor = [UIColor labelColor];
    [container addSubview:title];

    UILabel* percent = [[UILabel alloc] initWithFrame:CGRectMake(width - 52.0, 4.0, 42.0, 14.0)];
    percent.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    percent.textColor = [UIColor secondaryLabelColor];
    percent.textAlignment = NSTextAlignmentRight;
    percent.text = @"0%";
    [container addSubview:percent];

    UIProgressView* bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    bar.frame = CGRectMake(10.0, 22.0, width - 20.0, 3.0);
    bar.progressTintColor = [UIColor systemBlueColor];
    bar.trackTintColor = [UIColor tertiarySystemFillColor];
    bar.progress = 0.0;
    [container addSubview:bar];

    self.container = container;
    self.titleLabel = title;
    self.percentLabel = percent;
    self.progressView = bar;
}

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

    CGFloat width = CGRectGetWidth(self.container.bounds);
    CGFloat topInset = window.safeAreaInsets.top;
    self.container.center = CGPointMake(CGRectGetWidth(window.bounds) / 2.0,
                                        topInset + 8.0 + CGRectGetHeight(self.container.bounds) / 2.0);
    self.container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleRightMargin |
                                      UIViewAutoresizingFlexibleTopMargin;
    self.titleLabel.text = title.length ? title : @"下载中";
    self.progressView.progress = 0.0;
    self.percentLabel.text = @"0%";

    [window bringSubviewToFront:self.container];
    [UIView animateWithDuration:0.15
                     animations:^{
                         self.container.alpha = 1.0;
                     }];
}

- (void)setProgress:(CGFloat)progress detail:(NSString*)detail {
    if (self.container == nil) {
        return;
    }
    CGFloat clamped = MAX(0.0, MIN(1.0, progress));
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = clamped;
        if (detail.length > 0) {
            self.percentLabel.text = detail;
        } else {
            self.percentLabel.text =
                [NSString stringWithFormat:@"%.0f%%", clamped * 100.0];
        }
    });
}

- (void)hide {
    if (self.container == nil) {
        return;
    }
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
