//
//  NFBDownloadQueue.m
//  呱呱助手
//

#import "Download/NFBDownloadQueue.h"
#import "Download/NFBProgressBar.h"
#import "Core/BHTBundle.h"
#import "Core/BHTSettings.h"
#import "Core/BHTManager.h"
#import "Headers/TWHeaders.h"

#import "FFmpegKit.h"

@implementation NFBDownloadTask @end

@interface NFBDownloadQueue ()
@property (nonatomic, strong) NSMutableArray<NFBDownloadTask*>* taskList;
@property (nonatomic, assign) NSInteger runningCount;
- (NSArray<NSDictionary*>*)queueRows;
@end

@implementation NFBDownloadQueue

+ (instancetype)shared {
    static NFBDownloadQueue* queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [NFBDownloadQueue new];
        queue.taskList = [NSMutableArray array];
    });
    return queue;
}

- (NSArray<NFBDownloadTask*>*)tasks {
    @synchronized(self) {
        return self.taskList.copy;
    }
}

- (void)notifyChange {
    void (^handler)(void) = self.changeHandler;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (handler != nil) {
            handler();
        }
        [[NFBProgressBar shared] updateQueueRows:[self queueRows]];
    });
}

- (void)enqueueTitle:(NSString*)title
                args:(NSString*)args
                 ext:(NSString*)ext
            duration:(double)durationMs {
    NFBDownloadTask* task = [NFBDownloadTask new];
    task.title = title.length ? title : @"视频";
    task.args = args;
    task.ext = ext;
    task.durationMs = durationMs;
    task.state = NFBDownloadStateQueued;

    @synchronized(self) {
        [self.taskList addObject:task];
    }
    [self notifyChange];
    [self pump];
}

- (void)pump {
    NSMutableArray<NFBDownloadTask*>* toStart = [NSMutableArray array];
    @synchronized(self) {
        while (self.runningCount < 1) {
            NFBDownloadTask* next = nil;
            for (NFBDownloadTask* task in self.taskList) {
                if (task.state == NFBDownloadStateQueued) {
                    next = task;
                    break;
                }
            }
            if (next == nil) {
                break;
            }
            next.state = NFBDownloadStateRunning;
            self.runningCount += 1;
            [toStart addObject:next];
        }
    }
    for (NFBDownloadTask* task in toStart) {
        [self runTask:task];
    }
    [self notifyChange];
}

- (void)runTask:(NFBDownloadTask*)task {
    // 顶部胶囊只显示“当前最早”的那条
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* runTitle = [task.title hasPrefix:@"正在下载"]
                                 ? task.title
                                 : [NSString stringWithFormat:@"正在下载%@", task.title];
        [[NFBProgressBar shared] showWithTitle:runTitle];
    });

    if (task.durationMs > 0) {
        [self startSessionForTask:task duration:task.durationMs];
        return;
    }

    // 没有时长：先从参数里取出源地址，探测一次（否则百分比永远是 …）
    NSString* sourceURLString = nil;
    NSArray<NSString*>* tokens = [task.args componentsSeparatedByString:@" "];
    for (NSUInteger i = 0; i + 1 < tokens.count; i++) {
        if ([tokens[i] isEqualToString:@"-i"]) {
            sourceURLString = tokens[i + 1];
            break;
        }
    }
    NSURL* probeURL = sourceURLString.length ? [NSURL URLWithString:sourceURLString] : nil;
    if (probeURL == nil) {
        [self startSessionForTask:task duration:0];
        return;
    }

    __weak NFBDownloadQueue* weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        double resolved = 0;
        @try {
            MediaInformation* info = [BHTManager getM3U8Information:probeURL];
            resolved = [info getDuration].doubleValue * 1000.0;
        } @catch (__unused NSException* exception) {
        }
        task.durationMs = resolved;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startSessionForTask:task duration:resolved];
        });
    });
}

- (void)startSessionForTask:(NFBDownloadTask*)task duration:(double)durationMs {

    NSURL* outFile = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString,
                                                               task.ext]];

    [FFmpegKit
        executeAsync:[NSString stringWithFormat:@"%@ %@", task.args, outFile.path]
        withCompleteCallback:^(FFmpegSession* session) {
            ReturnCode* returnCode = [session getReturnCode];
            BOOL success = [ReturnCode isSuccess:returnCode];

            dispatch_async(dispatch_get_main_queue(), ^{
                UINotificationFeedbackGenerator* feedback = [UINotificationFeedbackGenerator new];
                [feedback prepare];

                if (success) {
                    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                    if ([task.ext isEqualToString:@"gif"]) {
                        [BHTManager saveGIF:outFile];
                    } else {
                        [BHTManager save:outFile];
                    }
                    [[NFBProgressBar shared]
                        showSuccessWithText:[NSString stringWithFormat:@"%@ 下载已完成", task.title]];
                    task.state = NFBDownloadStateDone;
                    task.progress = 1.0;
                } else {
                    [feedback notificationOccurred:UINotificationFeedbackTypeError];
                    task.state = NFBDownloadStateFailed;
                    [[NFBProgressBar shared]
                        showSuccessWithText:[NSString stringWithFormat:@"%@ 下载失败", task.title]];
                }

                @synchronized(self) {
                    self.runningCount = MAX(0, self.runningCount - 1);
                    [self.taskList removeObject:task];
                }
                [self notifyChange];
                [self pump];
            });
        }
        withLogCallback:nil
        withStatisticsCallback:^(Statistics* statistics) {
            double processed = [statistics getTime];
            long long bytes = [statistics getSize];
            task.bytes = bytes;
            task.progress = durationMs > 0 ? MAX(0.0, MIN(1.0, processed / durationMs)) : 0.0;
            [[NFBProgressBar shared] setProgress:task.progress
                                          detail:[NSByteCountFormatter
                                                     stringFromByteCount:bytes
                                                              countStyle:NSByteCountFormatterCountStyleFile]];
            [self notifyChange];
        }];
}

@end
