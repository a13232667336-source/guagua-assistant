//
//  NFBProgressBar.h
//  呱呱助手
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 顶部细长进度条：替代原来的居中转圈 HUD，下载时显示百分比与进度。
@interface NFBProgressBar : NSObject

@property (nonatomic, copy, nullable) NSString* subtitlePrefix;

+ (instancetype)shared;

- (void)showWithTitle:(NSString*)title;
- (void)setProgress:(CGFloat)progress detail:(nullable NSString*)detail;
- (void)showSuccessWithText:(NSString*)text;
- (void)hide;

/// 在顶部胶囊下方显示队列：每项 @{@"title":…, @"status":…, @"progress":@(0..1)}
- (void)updateQueueRows:(NSArray<NSDictionary*>*)rows;

@end

NS_ASSUME_NONNULL_END
