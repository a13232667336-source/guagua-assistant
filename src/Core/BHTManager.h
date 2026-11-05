//
//  BHTdownloadManager.h
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "Headers/TWHeaders.h"

@interface BHTManager : NSObject
+ (void)cleanCache;
+ (NSString*)getVideoQuality:(NSString*)url;
+ (id)sharedFontGroup;
+ (UIFont*)menuTitleFont;
+ (BOOL)doesContainDigitsOnly:(NSString*)string;
+ (UIViewController*)BHTSettingsWithAccount:(TFNTwitterAccount*)twAccount;
+ (void)showSaveVC:(NSURL*)url;
+ (void)save:(NSURL*)url;
+ (void)saveGIF:(NSURL*)url;
// 直接用插件自己的（FFmpeg）下载通道抓一个视频地址：HLS 会按最高码率
// 自动选流，普通 mp4 走流拷贝，结束后按总开关的设定存进“照片”。
+ (void)downloadVideoFromURL:(NSURL*)url;
+ (MediaInformation*)getM3U8Information:(NSURL*)mediaURL;
+ (NSString*)getDownloadingPercent:(float)progress;

+ (BOOL)isTwitterBranded;
+ (BOOL)isLiveContainer;

@end
