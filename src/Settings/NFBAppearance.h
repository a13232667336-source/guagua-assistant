//
//  NFBAppearance.h
//  呱呱助手 —— 仅用于设置界面的视觉样式，不涉及任何功能逻辑。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 把 cell 变成“卡片”：清空底色、加圆角卡片背景、按压高亮色。
void NFBPrepareCardCell(UITableViewCell* cell);

/// 在 cell 布局时把卡片背景内缩，形成左右留白的悬浮卡片。
void NFBLayoutCardCell(UITableViewCell* cell);

/// 给容器铺一层柔和的竖向渐变（浅灰 → 背景色），深色模式自动适配。
void NFBInstallGradientBackground(UIView* host);

NS_ASSUME_NONNULL_END
