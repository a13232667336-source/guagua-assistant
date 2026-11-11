//
//  NFBDownloadQueuePanel.m
//  呱呱助手
//
//  贴在屏幕右侧的小面板：只在「同时存在多个下载任务」或「已有任务在下载、你又点了新的」
//  时出现；任务是串行执行的（一条一条下），所以列表里只会有一条显示“下载中”，其余显示“排队中”。
//

#import "Download/NFBDownloadQueuePanel.h"
#import "Download/NFBDownloadQueue.h"
#import <QuartzCore/QuartzCore.h>

@interface NFBDownloadQueuePanel ()
@property (nonatomic, strong) UIView* container;
@property (nonatomic, strong) NSMutableArray<UIView*>* rows;
@end

@implementation NFBDownloadQueuePanel

+ (instancetype)shared {
    static NFBDownloadQueuePanel* panel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        panel = [NFBDownloadQueuePanel new];
        panel.rows = [NSMutableArray array];
    });
    return panel;
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
    UIView* container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 196, 60)];
    container.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    container.layer.cornerRadius = 14.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.35;
    container.layer.shadowRadius = 8.0;
    container.layer.shadowOffset = CGSizeMake(0, 3);
    container.alpha = 0.0;
    container.hidden = YES;
    self.container = container;
}

- (void)refresh {
    [self buildIfNeeded];

    NSArray<NFBDownloadTask*>* tasks = [[NFBDownloadQueue shared] tasks];
    // 只有一个任务时不打扰，直接从右侧收起
    if (tasks.count < 2) {
        [self hidePanel];
        return;
    }

    for (UIView* row in self.rows) {
        [row removeFromSuperview];
    }
    [self.rows removeAllObjects];

    NSInteger visible = MIN(tasks.count, 6);
    CGFloat rowHeight = 34.0;
    CGFloat top = 8.0;

    for (NSInteger index = 0; index < visible; index++) {
        NFBDownloadTask* task = tasks[index];
        UIView* row = [[UIView alloc] initWithFrame:CGRectMake(0, top, 196, rowHeight)];
        row.backgroundColor = [UIColor clearColor];

        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(12, 1, 120, 16)];
        title.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        title.textColor = [UIColor whiteColor];
        title.text = task.title;
        [row addSubview:title];

        UILabel* status = [[UILabel alloc] initWithFrame:CGRectMake(120, 1, 64, 16)];
        status.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightRegular];
        status.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        status.textAlignment = NSTextAlignmentRight;
        switch (task.state) {
            case NFBDownloadStateQueued:
                status.text = @"排队中";
                break;
            case NFBDownloadStateRunning:
                status.text = task.progress > 0.001
                                  ? [NSString stringWithFormat:@"%.0f%%", task.progress * 100]
                                  : @"下载中";
                break;
            case NFBDownloadStateDone:
                status.text = @"已完成";
                break;
            case NFBDownloadStateFailed:
                status.text = @"失败";
                break;
        }
        [row addSubview:status];

        UIView* track = [[UIView alloc] initWithFrame:CGRectMake(12, 22, 172, 2.0)];
        track.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        track.layer.cornerRadius = 1.0;
        [row addSubview:track];

        CGFloat width = task.state == NFBDownloadStateRunning
                            ? MAX(0.02, MIN(1.0, task.progress)) * 172.0
                            : (task.state == NFBDownloadStateDone ? 172.0 : 0.0);
        UIView* fill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 2.0)];
        fill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
        fill.layer.cornerRadius = 1.0;
        [track addSubview:fill];

        [self.container addSubview:row];
        [self.rows addObject:row];
        top += rowHeight;
    }

    if (tasks.count > 6) {
        UILabel* more = [[UILabel alloc] initWithFrame:CGRectMake(12, top, 172, 14)];
        more.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightRegular];
        more.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        more.text = [NSString stringWithFormat:@"还有 %ld 个排队中", (long)(tasks.count - 6)];
        [self.container addSubview:more];
        [self.rows addObject:more];
        top += 16.0;
    }

    [self showPanelWithHeight:top + 8.0];
}

- (void)showPanelWithHeight:(CGFloat)height {
    UIWindow* window = [self keyWindow];
    if (window == nil) {
        return;
    }
    if (self.container.superview != window) {
        [self.container removeFromSuperview];
        [window addSubview:self.container];
    }

    CGFloat width = 196.0;
    CGFloat centerY = CGRectGetHeight(window.bounds) * 0.42;
    self.container.hidden = NO;
    self.container.frame = CGRectMake(CGRectGetWidth(window.bounds) - width - 8.0,
                                      centerY - height / 2.0, width, height);
    self.container.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.container.bounds cornerRadius:14.0].CGPath;
    [window bringSubviewToFront:self.container];

    if (self.container.alpha < 0.99) {
        [UIView animateWithDuration:0.18
                         animations:^{
                             self.container.alpha = 1.0;
                         }];
    }
}

- (void)hidePanel {
    if (self.container == nil || self.container.hidden) {
        return;
    }
    UIView* container = self.container;
    [UIView animateWithDuration:0.18
        animations:^{
            container.alpha = 0.0;
        }
        completion:^(BOOL finished) {
            container.hidden = YES;
            [container removeFromSuperview];
        }];
}

@end
