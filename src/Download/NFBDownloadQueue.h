//
//  NFBDownloadQueue.h
//  呱呱助手 —— 下载队列：允许多个推文的视频同时排队下载，并在右侧显示排队列表。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NFBDownloadState) {
    NFBDownloadStateQueued = 0,
    NFBDownloadStateRunning,
    NFBDownloadStateDone,
    NFBDownloadStateFailed,
};

@interface NFBDownloadTask : NSObject
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* args;
@property (nonatomic, copy) NSString* ext;
@property (nonatomic, assign) double durationMs;
@property (nonatomic, assign) NFBDownloadState state;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) long long bytes;
@end

@interface NFBDownloadQueue : NSObject

+ (instancetype)shared;

/// 加入一个下载任务（同一时间最多并发 2 个）
- (void)enqueueTitle:(NSString*)title
                args:(NSString*)args
                 ext:(NSString*)ext
            duration:(double)durationMs;

/// 当前所有任务（按加入顺序）
- (NSArray<NFBDownloadTask*>*)tasks;

/// 队列变化回调（任务增加/状态变化/进度变化都会触发）
@property (nonatomic, copy, nullable) void (^changeHandler)(void);

@end

NS_ASSUME_NONNULL_END
