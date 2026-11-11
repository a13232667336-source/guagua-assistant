//
//  NFBDownloadQueuePanel.h
//  呱呱助手 —— 右侧排队列表：多个下载任务时显示，一条一条下载。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFBDownloadQueuePanel : NSObject

+ (instancetype)shared;

/// 条数变化 / 状态变化后调用，自动决定显示还是收起
- (void)refresh;

@end

NS_ASSUME_NONNULL_END
