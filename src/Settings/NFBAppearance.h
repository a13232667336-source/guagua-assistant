//
//  NFBAppearance.h
//  呱呱助手 —— 设置界面视觉样式（v2 鲜艳版）。只做外观，不涉及功能。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 每个页面/条目用的强调色
UIColor* NFBAccentColor(void);
UIColor* NFBAccentForPage(NSString* _Nullable pageKey);

/// 卡片：白底 + 大圆角 + 彩色投影
void NFBPrepareCardCell(UITableViewCell* cell);
void NFBLayoutCardCell(UITableViewCell* cell);

/// 鲜艳渐变背景（按强调色生成三色渐变）
void NFBInstallVividGradient(UIView* host, UIColor* accent);

/// 把图标做成彩色圆角底片
void NFBStyleIconChip(UIImageView* iconView, UIColor* accent);

NS_ASSUME_NONNULL_END
