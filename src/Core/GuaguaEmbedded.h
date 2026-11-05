//
//  GuaguaEmbedded.h
//  呱呱助手 (Guagua Assistant)
//
//  内嵌资源：资源包没被注入器装进去时，UI 仍然有完整中文文案 + 开发者头像。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 按系统语言优先查内嵌字符串表；查不到返回 nil（调用方再回落到 key）。
NSString* _Nullable GuaguaEmbeddedString(NSString* key);

/// 内嵌的开发者头像（Guagua.bundle/samuel.png 的 base64 版本）。
UIImage* _Nullable GuaguaEmbeddedAvatar(void);

NS_ASSUME_NONNULL_END
