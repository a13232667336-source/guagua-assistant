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

    BOOL hasPending = NO;
    @synchronized(self) {
        for (NFBDownloadTask* task in self.taskList) {
            if (task.state == NFBDownloadStateQueued || task.state == NFBDownloadStateRunning) {
                hasPending = YES;
                break;
            }
        }
        if (!hasPending && self.taskList.count > 0) {
            // 全部结束：让“已完成”停留 3 秒，然后清空列表并收起卡片
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                               @synchronized(self) {
                                   [self.taskList removeAllObjects];
                               }
                               [self notifyChange];
                           });
        }
    }
}

- (void)runTask:(NFBDownloadTask*)task {
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

// 直链 mp4 可以通过 HEAD 拿到文件总大小，HLS 拿不到就只显示已下载
- (void)fetchTotalSizeForTask:(NFBDownloadTask*)task {
    if (task.totalBytes > 0) {
        return;
    }
    NSArray<NSString*>* tokens = [task.args componentsSeparatedByString:@" "];
    NSString* urlString = nil;
    for (NSUInteger i = 0; i + 1 < tokens.count; i++) {
        if ([tokens[i] isEqualToString:@"-i"]) {
            urlString = tokens[i + 1];
            break;
        }
    }
    if (urlString.length == 0 ||
        [urlString containsString:@".m3u8"] ||
        ![urlString hasPrefix:@"http"]) {
        return;
    }
    NSURL* url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return;
    }
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 10.0;
    __weak NFBDownloadQueue* weakSelf = self;
    NSURLSessionDataTask* dataTask =
        [NSURLSession.sharedSession dataTaskWithRequest:request
        completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                long long length = ((NSHTTPURLResponse*)response).expectedContentLength;
                if (length > 0) {
                    task.totalBytes = length;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf notifyChange];
                    });
                }
            }
        }];
    [dataTask resume];
}

- (void)startSessionForTask:(NFBDownloadTask*)task duration:(double)durationMs {
    [self fetchTotalSizeForTask:task];

    NSURL* outFile = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString,
                                                               task.ext]];

    [FFmpegKit
        executeAsync:[NSString stringWithFormat:@"%@ %@", task.args, outFile.path]
        withCompleteCallback:^(FFmpegSession* session) {
            ReturnCode* returnCode = [session getReturnCode];
            BOOL success = [ReturnCode isSuccess:returnCode];

            // 保存相册放到串行后台队列：避免连下多条时重复占用相册数据库导致卡死
            static dispatch_queue_t saveQueue;
            static dispatch_once_t saveOnce;
            dispatch_once(&saveOnce, ^{
                saveQueue = dispatch_queue_create("com.guagua.save", DISPATCH_QUEUE_SERIAL);
            });

            dispatch_async(saveQueue, ^{
                if (success) {
                    if ([task.ext isEqualToString:@"gif"]) {
                        [BHTManager saveGIF:outFile];
                    } else {
                        [BHTManager save:outFile];
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    UINotificationFeedbackGenerator* feedback =
                        [UINotificationFeedbackGenerator new];
                    [feedback prepare];

                    if (success) {
                        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                        task.state = NFBDownloadStateDone;
                        task.progress = 1.0;
                    } else {
                        [feedback notificationOccurred:UINotificationFeedbackTypeError];
                        task.state = NFBDownloadStateFailed;
                    }
                    [self notifyChange];

                    // 完成的任务留在列表里（显示“已完成”），只释放并发位，立刻开始下一条
                    @synchronized(self) {
                        self.runningCount = MAX(0, self.runningCount - 1);
                    }
                    [self pump];
                    [self notifyChange];
                });
            });
        }
        withLogCallback:nil
        withStatisticsCallback:^(Statistics* statistics) {
            double processed = [statistics getTime];
            long long bytes = [statistics getSize];
            task.bytes = bytes;
            task.progress = durationMs > 0 ? MAX(0.0, MIN(1.0, processed / durationMs)) : 0.0;
            static double lastReported = 0;
            if (fabs(task.progress - lastReported) > 0.02 || task.progress >= 0.999) {
                lastReported = task.progress;
                [self notifyChange];
            }
        }];
}


- (NSArray<NSDictionary*>*)queueRows {
    NSMutableArray* rows = [NSMutableArray array];
    @synchronized(self) {
        for (NFBDownloadTask* task in self.taskList) {
            NSString* status = @"正在排队";
            if (task.state == NFBDownloadStateRunning) {
                status = task.progress > 0.001
                             ? [NSString stringWithFormat:@"下载中 %.0f%%", task.progress * 100]
                             : @"下载中";
            } else if (task.state == NFBDownloadStateDone) {
                status = @"已完成";
            } else if (task.state == NFBDownloadStateFailed) {
                status = @"下载失败";
            }
            NSString* sizeText = @"";
            if (task.bytes > 0) {
                NSString* got = [NSByteCountFormatter stringFromByteCount:task.bytes
                                                               countStyle:NSByteCountFormatterCountStyleFile];
                if (task.totalBytes > task.bytes) {
                    NSString* all = [NSByteCountFormatter stringFromByteCount:task.totalBytes
                                                                   countStyle:NSByteCountFormatterCountStyleFile];
                    sizeText = [NSString stringWithFormat:@"%@ / %@", got, all];
                } else {
                    sizeText = got;
                }
            } else if (task.totalBytes > 0) {
                sizeText = [NSByteCountFormatter stringFromByteCount:task.totalBytes
                                                          countStyle:NSByteCountFormatterCountStyleFile];
            }
            [rows addObject:@{
                @"title" : task.title ?: @"视频",
                @"status" : status,
                @"size" : sizeText,
                @"progress" : @(task.progress)
            }];
        }
    }
    return rows;
}

@end
