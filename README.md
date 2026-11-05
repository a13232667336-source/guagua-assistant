# 呱呱助手（Guagua Assistant）

基于 NeoFreeBird-BHTwitter **v6.7.0（df7fbc8）** 改的 X（Twitter）增强插件，面向 iOS 巨魔（TrollStore / TrollFools 注入）用户，适配 **X 12.26**。

- 插件名：**呱呱助手**
- 版本：**1.0.0**（源自 v6.7.0）
- 开发者：**Samuel**
- 包名：`com.samuel.guagua`

## 这一版改了什么

| # | 改动 | 说明 |
|---|---|---|
| 1 | 全量改名 | 设置页名字、设置入口、版本页、资源包路径、deb 包信息里的旧名字（NeoFreeBird / BHTwitter）全部换成「呱呱助手」 |
| 2 | 每个开关都有说明 | 68 个开关全部补上 `_DETAIL` 说明（简体中文完整重写，英文补齐），设置页每行标题下面都写清楚它是干什么的 |
| 3 | 「下载媒体」一键式 | 原来分散的 **始终下载最高画质 / 保存到照片 / 高画质媒体 / 视频时间戳** 全部并入「下载媒体」：打开总开关 → 这四项全部自动打开；关闭 → 全部关闭。设置页里不再单独出现这四行 |
| 4 | 删掉这几项功能 | **不显示视频字幕、大图显示、禁用视频流上下滑动、关闭视频停靠、轻点暂停视频**：设置项和对应 hook 一并移除 |
| 5 | 隐藏官方下载 | 播放器「⋯」菜单里 X 自带的 **下载视频** 行，装上插件即隐藏（无开关）。TFN 菜单按菜单项过滤，非 TFN 菜单用视图级兜底隐藏 |
| 6 | 播放器里加自己的下载 | 在原来「下载视频」的位置插入 **下载视频（来自呱呱助手）**，走插件自己的 FFmpeg 下载通道，画质策略同「下载媒体」；并且**永远下载当前正在播放的那一条**（读 `AVPlayerLayer.currentItem` 的资源地址，不会串片） |
| 7 | 只留一位开发者 | 删掉原作者 / 酷小孩 / 特别鸣谢 / 贡献者 / 官方账号全部条目，只保留 **Samuel**，头像用内置图片 `Guagua.bundle/samuel.png` |
| 8 | 注入格式 | 产出 `Guagua.dylib`、`Guagua-TrollFools.zip`（dylib + 资源包）、`.deb`，TrollFools / TrollStore 可直接注入 |

## 目录结构（关键部分）

```
control                          # 包信息（名字/版本/包名）
Makefile                         # TWEAK_NAME = Guagua
Guagua.plist                     # 注入目标：com.atebits.Tweetie2
build-trollfools.sh              # 一键产出 TrollFools 用的 dylib / zip / deb
src/
  Core/BHTSettings.m             # 设置注册表 + 下载总开关联动
  Core/BHTBundle.m               # 资源包查找（Guagua.bundle 优先）
  Download/DownloadInlineButton.m# 推文里的画质选择 + FFmpeg 下载
  Hooks/PlayerDownloadMenu.x     # ★ 播放器菜单：隐藏官方下载 + 插入呱呱助手下载
  Hooks/MediaDownloads.x         # 推文/私信视频下载入口
  Hooks/ImmersivePlayer.x        # 只保留「视频时间戳」
  Settings/ModernSettingsViewController.m   # 设置首页 + 唯一的开发者条目
layout/Library/Application Support/Guagua/Guagua.bundle/
  zh_CN.lproj/Localizable.strings # 全量中文标题 + 解释
  samuel.png                      # 开发者头像
tools/rewrite_strings.py          # 生成/校对上面这些字符串
```

## 怎么拿到可注入的文件

### 方式 A：本机 / CI 编译（推荐）

```bash
export THEOS=~/theos          # 先装好 Theos + ldid + dpkg
./build-trollfools.sh
```

产物在 `packages/`：

- `Guagua.dylib` —— TrollFools 里选「注入 dylib」直接选它
- `呱呱助手-TrollFools.zip` —— 推荐，dylib + 资源包一次装好（TrollFools 会把 `Guagua.bundle` 放进 app 根目录）
- `com.samuel.guagua_1.0.0_iphoneos-arm.deb` —— 越狱或 TrollFools 的 deb 注入

仓库里已经配好 `.github/workflows/build.yml`：把它推到 GitHub，Actions 跑完在 artifact 里就能直接下载上面三个文件，不需要 Mac。

### 方式 B：TrollFools 注入步骤

TrollFools（巨魔注入器）支持的输入是 **`.dylib` / `.deb` / `.zip`** 三种，本例三种都给：

1. 打开 TrollFools → 选 X（12.26）→ 注入
2. **推荐**选 `呱呱助手-TrollFools.zip`：里面是 `Guagua.dylib` + `Guagua.bundle`（资源包），一次装全，中文字符串和头像都在
3. 只选 `Guagua.dylib` 也能跑，但资源包需要你自己放进 `Twitter.app/Guagua.bundle`，否则设置页会显示成字符串 key、头像显示占位符
4. 越狱用户直接装 `.deb`
5. 重启 X → 设置 → 呱呱助手

> 注意区分两件事：**TrollStore** 本身只装 `.tipa`/`.ipa`（已签名的 app），它不认识 dylib；**注入器**（TrollFools / zxPluginsInject / ESign）才是把 dylib 塞进已安装 app 的工具。这个插件给的是后者要的文件。

### 运行期依赖

- **不需要 Cephei**：设置全部走 `NSUserDefaults`，`HBPreferences` 相关链接依赖已删除（原来那条 `HBForceCepheiPrefs` hook 也一起删了，避免注入环境里 dyld 找不到 Cephei）。
- **不需要 libbhFLEX**：确认弹窗改成系统 `UIAlertController`；只有「调试模式」这个开关在运行期查 `FLEXManager`，没注入 FLEX 就静默不弹面板。

## 兼容性说明（X 12.26）

- hook 目标类名沿用 12.2x 的 `T1/TFN/TFS` 体系，关键调用都做了 `respondsToSelector` / `objc_getClass` 判空，类不存在时该功能静默跳过而不是崩。
- 播放器菜单这块是最容易随版本变动的地方：`PlayerDownloadMenu.x` 先用「菜单项标题过滤 + 在原位置插入」处理 TFN 菜单，再用视图级兜底把官方下载行藏掉；两种都失效时最多是「官方下载行没藏住」，不会影响其它功能。
- 若某版本 X 把菜单改成完全自绘且标题不是「下载视频」，改 `NFBofficialDownloadTitles()` 里的标题表即可。

## 构建依赖

- Theos（`$THEOS`）、ldid、dpkg/zip
- FFmpeg 静态库：`deps/ffmpeg-kit-next/build/lib`（`build-trollfools.sh` 检测不到会自动从源码编，第一次比较久）
- 越狱 deb 依赖 `mobilesubstrate`

## 许可

上游 NeoFreeBird / BHTwitter 为 GPL/AGPL 系授权，本修改版沿用同一许可，第三方组件声明见 `Guagua.bundle/Acknowledgements.rtf`。
