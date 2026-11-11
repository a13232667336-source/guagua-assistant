//
//  NFBDownloadQueue.m
//  呱呱助手
//

#import "Download/NFBDownloadQueue.h"
#import "Download/NFBProgressBar.h"
#import "Download/NFBDownloadQueuePanel.h"
#import "Core/BHTBundle.h"
#import "Core/BHTSettings.h"
#import "Core/BHTManager.h"
#import "Headers/TWHeaders.h"

#import "FFmpegKit.h"

@implementation NFBDownloadTask @end

@interface NFBDownloadQueue ()
@property (nonatomic, strong) NSMutableArray<NFBDownloadTask*>* taskList;
@property (nonatomic, assign) NSInteger runningCount;
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
    if (handler == nil) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        handler();
        [[NFBDownloadQueuePanel shared] refresh];
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
            task.progress = task.durationMs > 0 ? MAX(0.0, MIN(1.0, processed / task.durationMs))
                                                : 0.0;
            [[NFBProgressBar shared] setProgress:task.progress
                                          detail:[NSByteCountFormatter
                                                     stringFromByteCount:bytes
                                                              countStyle:NSByteCountFormatterCountStyleFile]];
            [self notifyChange];
        }];
}

@end
