//
//  NFBProgressBar.h
//  呱呱助手
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 顶部细长进度条：替代原来的居中转圈 HUD，下载时显示百分比与进度。
@interface NFBProgressBar : NSObject

+ (instancetype)shared;

- (void)showWithTitle:(NSString*)title;
- (void)setProgress:(CGFloat)progress detail:(nullable NSString*)detail;
- (void)hide;

@end

NS_ASSUME_NONNULL_END
