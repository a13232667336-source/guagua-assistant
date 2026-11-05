"""呱呱助手 —— 一次性重写插件资源包里的本地化字符串。

做的事：
  1. 把所有语言里的旧名字（NeoFreeBird / BHTwitter）换成“呱呱助手”；
  2. 给简体中文补全每一个开关下面的解释（_DETAIL），英文补齐缺的解释；
  3. 新增播放器下载入口、开发者署名等新 key。
"""
import re
from pathlib import Path

ROOT = Path(
    r"C:\Users\Administrator\Desktop\GuaguaAssistant\layout\Library"
    r"\Application Support\Guagua\Guagua.bundle"
)

PAIR = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')

ZH_DETAILS = {
    # 常规
    "PADLOCK_DETAIL": "打开 X 之前先要求面容/触控 ID 或锁屏密码，别人拿到手机也打不开你的账号。",
    "HIDE_PROMOTED_DETAIL": "时间线、搜索、通知里的“推广”广告整条删掉，不留空位。",
    "HIDE_PREMIUM_OFFER_DETAIL": "隐藏“升级 Premium”“验证账号”这类付费推广横幅和按钮。",
    "NO_TAB_BAR_HIDING_DETAIL": "上下滚动时底部标签栏不再自动收起，随时都能切换页面。",
    "DISABLE_RTL_DETAIL": "强制界面按从左到右排版，适合用阿拉伯语/希伯来语系统但习惯 LTR 的人。",
    "NO_FOCUS_LOST_DETAIL": "切到别的 App 再切回来时不刷新时间线，阅读位置不会丢。",
    "SHOW_SCROLL_INDICATOR_DETAIL": "右侧常驻滚动条，随时知道自己滑到时间线的哪个位置。",
    # 外观
    "TAB_BAR_THEMING_DETAIL": "用你的主题色高亮当前选中的标签，恢复老版 Twitter 的观感。",
    "RESTORE_TAB_LABELS_DETAIL": "在底部图标下面显示文字（主页/搜索等），不再只有图标。",
    "ENABLE_DIM_THEME_DETAIL": "用深灰的“变暗”配色代替纯黑，夜间看屏幕更柔和。",
    "CUSTOM_FONTS_DETAIL": "给 X 换一套自定义字体（需要先在系统里安装字体文件）。",
    # 时间线
    "HIDE_WHO_TO_FOLLOW_DETAIL": "个人资料页里不再出现“推荐关注”列表。",
    "HIDE_TIMELINE_PROMPTS_DETAIL": "去掉“添加通讯录”“开启通知”这类横幅提示。",
    "HIDE_SPACES_DETAIL": "隐藏时间线顶部的 Spaces 音频条。",
    "HIDE_CUSTOM_TIMELINES_DETAIL": "首页标签里去掉“添加时间线”按钮，避免误触。",
    "HIDE_BLOCKED_RETWEETS_DETAIL": "不显示那些把您拉黑的账号所发的转推内容。",
    "HIDE_TWEET_BUTTON_DETAIL": "隐藏侧边栏/顶部的发推按钮，减少误触。",
    "HIDE_VERIFIED_TWEETS_DETAIL": "时间线里不显示带认证标记的推文。",
    "RESTORE_REFRESH_SOUNDS_DETAIL": "下拉刷新时播放老版 Twitter 的提示音。",
    # Grok
    "HIDE_GROK_ANALYZE_DETAIL": "隐藏推文下方“用 Grok 分析”的按钮。",
    "HIDE_GROK_SIDEBAR_DETAIL": "侧边栏里不显示 Grok 入口。",
    "HIDE_GROK_CREATE_DETAIL": "去掉用 Grok 生成或修改图片、视频的入口。",
    "DISABLE_AUTO_TRANSLATE_DETAIL": "不再自动翻译推文和简介，需要时手动点翻译。",
    # 媒体（一键总开关）
    "DOWNLOAD_VIDEOS_DETAIL": (
        "一键总开关：开启后推文菜单与播放器菜单都会出现下载入口，自动用最高画质并直接存进"
        "“照片”；关闭则这一整组下载功能全部关掉。"
    ),
    # 个人资料
    "FOLLOW_CONFIRM_DETAIL": "关注别人前先弹确认，避免手滑。",
    "COPY_PROFILE_INFO_DETAIL": "一键复制用户名、简介、位置等资料。",
    "FAST_BLOCK_DETAIL": "拉黑/静音不再弹二次确认，直接执行。",
    "DISABLE_ARTICLES_DETAIL": "个人资料里隐藏“文章”标签。",
    "DISABLE_HIGHLIGHTS_DETAIL": "个人资料里隐藏“精选”标签。",
    "HIDE_BLUE_VERIFIED_DETAIL": "推文里不显示付费认证的蓝标（品牌与政府账号不受影响）。",
    "HIDE_FOLLOW_BUTTON_DETAIL": "推文卡片上不显示关注按钮。",
    "SHOW_UNROUNDED_COUNTS_DETAIL": "粉丝、关注、推文数显示精确数字，不再四舍五入成“1.2万”。",
    "RESTORE_FOLLOW_BUTTON_DETAIL": "隐藏推文和个人资料里的“订阅”按钮。",
    "SQUARE_AVATARS_DETAIL": "所有人的头像都显示成方形，像老版 Twitter 的品牌账号那样。",
    # 聊天
    "HIDE_TYPING_INDICATOR_DETAIL": "聊天时不再向对方显示“正在输入…”。",
    "DOWNLOAD_VOICE_MESSAGES_DETAIL": "语音消息可以保存下来（双指长按那条语音即可下载）。",
    "BLOCK_SCREENSHOT_DETECTION_DETAIL": "“安全聊天”里截图不会被对方发现。",
    # 推文
    "TWEET_CONFIRM_DETAIL": "发推之前先确认，防止误发。",
    "LIKE_CONFIRM_DETAIL": "点赞之前弹确认，防止手滑点赞。",
    "TWEET_TO_IMAGE_DETAIL": "长按“分享”按钮，把整条推文导出成图片。",
    "HIDE_VIEW_COUNT_DETAIL": "推文下方不显示浏览量。",
    "HIDE_BOOKMARK_BUTTON_DETAIL": "去掉推文上的书签按钮。",
    "HIDE_DOWNVOTE_BUTTON_DETAIL": "去掉推文上的“踩”按钮。",
    "USE_TENOR_GIFS_DETAIL": "用 Tenor 的 GIF 库替代 X 自带的 GIPHY，素材更多。",
    "DISABLE_MEDIA_CAROUSEL_DETAIL": "多图推文恢复旧版排版，不再左右滑动轮播。",
    "DISABLE_SENSITIVE_TWEET_WARNINGS_DETAIL": "敏感内容不再弹警告遮罩，直接显示。",
    "SHOW_POLL_RESULTS_DETAIL": "投票之前就在选项后面显示当前结果。",
    "SHOW_ACCOUNT_LOCATION_DETAIL": "在推文底部显示发布账号的位置信息。",
    "UPLOAD_FULL_HD_VIDEOS_DETAIL": "上传视频时不压缩到 720p，尽量保留全高清画质。",
    "BYPASS_AGE_VERIFICATION_DETAIL": "跳过敏感内容的年龄验证流程。",
    "REPLY_SORTING_DETAIL": "关闭回复排序，按时间顺序显示回复。",
    "RESTORE_REPLY_CONTEXT_DETAIL": "在推文下方显示这条回复是回给谁的。",
    "RESTORE_TWEET_LABELS_DETAIL": "显示推文是从哪个客户端发出来的。",
    # 搜索
    "NO_HISTORY_DETAIL": "X 不再记录你搜过什么。",
    "HIDE_TRENDS_DETAIL": "“探索”页只保留搜索框，隐藏趋势、新闻和推荐页签。",
    "HIDE_TREND_VIDEOS_DETAIL": "搜索页不显示热门视频模块。",
    # 品牌
    "RESTORE_TWITTER_NAMES_DETAIL": "把界面里的“X”换回“Twitter”、“Post”换回“Tweet”等老叫法。",
    "REFRESH_PILL_LABEL_DETAIL": "有人发新推时，刷新提示条上重新显示文字标签。",
    "COLOR_TWITTER_ICON_IN_TOP_BAR_DETAIL": "顶栏的 Twitter 图标使用你的主题色。",
    "BLUE_LAUNCH_SCREEN_DETAIL": "启动画面恢复成老版蓝色 Twitter 图标。",
    # 实验室 / 网页 / 调试
    "REPLY_IN_WEBVIEW_DETAIL": "在网页视图里打开回复框，可绕开 attestation 限制。",
    "ALWAYS_OPEN_SAFARI_DETAIL": "链接一律用 Safari 或默认浏览器打开。",
    "NEW_INAPP_WEBVIEW_DETAIL": "用 X 新版应用内浏览器打开链接（LiveContainer 下默认关闭）。",
    "FLEX_TWITTER_DETAIL": "打开 FLEX 调试面板，排查界面问题时用。",
}

EN_DETAILS = {
    "SHOW_SCROLL_INDICATOR_DETAIL": "Keep the scroll bar visible so you always know where you are in the timeline.",
    "HIDE_SPACES_DETAIL": "Hide the Spaces bar at the top of the timeline.",
    "RESTORE_REFRESH_SOUNDS_DETAIL": "Play the classic Twitter sound when you pull to refresh.",
    "HIDE_GROK_ANALYZE_DETAIL": "Hide the 'Analyze with Grok' button under Tweets.",
    "HIDE_GROK_SIDEBAR_DETAIL": "Remove the Grok entry from the sidebar.",
    "DISABLE_SENSITIVE_TWEET_WARNINGS_DETAIL": "Show sensitive media right away instead of behind a warning.",
    "DOWNLOAD_HIGHEST_QUALITY_DETAIL": "Skip the quality picker and always save the highest quality MP4.",
    "DOWNLOAD_VIDEOS_DETAIL": (
        "One switch for the whole download stack: the Tweet and player menus get a download entry, "
        "always in the highest quality, saved straight to Photos. Turn it off and all of it goes away."
    ),
}

ZH_CN = dict(ZH_DETAILS)
ZH_CN.update({
    # 原来只有英文标题的开关，这里补上中文标题
    "NO_FOCUS_LOST_TITLE": "切后台不刷新",
    "ENABLE_DIM_THEME_TITLE": "变暗主题",
    "HIDE_BLOCKED_RETWEETS_TITLE": "隐藏拉黑者的转推",
    "HIDE_TWEET_BUTTON_TITLE": "隐藏发推按钮",
    "HIDE_VERIFIED_TWEETS_TITLE": "隐藏认证推文",
    "FAST_BLOCK_TITLE": "快速拉黑/静音",
    "SHOW_UNROUNDED_COUNTS_TITLE": "显示精确数字",
    "HIDE_TYPING_INDICATOR_TITLE": "隐藏“正在输入”",
    "DOWNLOAD_VOICE_MESSAGES_TITLE": "下载语音消息",
    "BLOCK_SCREENSHOT_DETECTION_TITLE": "阻止截图检测",
    "USE_TENOR_GIFS_TITLE": "使用 Tenor GIF",
    "DISABLE_MEDIA_CAROUSEL_TITLE": "关闭多图轮播",
    "SHOW_POLL_RESULTS_TITLE": "投票前显示结果",
    "SHOW_ACCOUNT_LOCATION_TITLE": "显示账号位置",
    "UPLOAD_FULL_HD_VIDEOS_TITLE": "上传全高清视频",
    "BLUE_LAUNCH_SCREEN_TITLE": "蓝色启动画面",
    "NFB_SETTINGS_DETAIL": "呱呱助手：让 X 更好用——一键下载、去广告、界面修复。",
    "MODERN_SETTINGS_MEDIA_TITLE": "照片与视频",
    "MODERN_SETTINGS_MEDIA_SUBTITLE": "一键下载视频与 GIF：最高画质，直接存进“照片”。",
    "PLAYER_DOWNLOAD_TITLE": "下载视频（呱呱助手）",
    "PLAYER_DOWNLOAD_NO_VIDEO_TITLE": "没有正在播放的视频",
    "PLAYER_DOWNLOAD_NO_VIDEO_MESSAGE": "先播放你要下载的那条视频，再点这一项。",
    "DEVELOPER_ROLE_TITLE": "开发者",
    "YES_ACTION_LABEL": "确定",
    "NO_ACTION_LABEL": "取消",
    "OK_ACTION_LABEL": "好",
})

ZH_HANT = {
    "NFB_SETTINGS_DETAIL": "呱呱助手：讓 X 更好用——一鍵下載、去廣告、介面修復。",
    "MODERN_SETTINGS_MEDIA_TITLE": "照片與影片",
    "MODERN_SETTINGS_MEDIA_SUBTITLE": "一鍵下載影片與 GIF：最高畫質，直接存進「照片」。",
    "PLAYER_DOWNLOAD_TITLE": "下載影片（呱呱助手）",
    "PLAYER_DOWNLOAD_NO_VIDEO_TITLE": "沒有正在播放的影片",
    "PLAYER_DOWNLOAD_NO_VIDEO_MESSAGE": "先播放你要下載的那條影片，再點這一項。",
    "DEVELOPER_ROLE_TITLE": "開發者",
    "DOWNLOAD_VIDEOS_DETAIL": "一鍵總開關：開啟後推文選單與播放器選單都會出現下載入口，自動最高畫質並直接存進「照片」；關閉則整組下載功能一起關掉。",
}

EN = dict(EN_DETAILS)
EN.update({
    "NFB_SETTINGS_DETAIL": "Guagua Assistant — one-tap downloads, no ads, and UI fixes for X.",
    "MODERN_SETTINGS_MEDIA_TITLE": "Photos and videos",
    "MODERN_SETTINGS_MEDIA_SUBTITLE": "One switch for downloads: highest quality, straight to Photos.",
    "PLAYER_DOWNLOAD_TITLE": "Download video (Guagua Assistant)",
    "PLAYER_DOWNLOAD_NO_VIDEO_TITLE": "No video is playing",
    "PLAYER_DOWNLOAD_NO_VIDEO_MESSAGE": "Start playing the video you want, then tap this again.",
    "DEVELOPER_ROLE_TITLE": "Developer",
})

# 所有语言共用：插件名 + 清掉原来的作者区块标题
COMMON = {
    "NFB_SETTINGS_TITLE": "呱呱助手",
    "COOL_KIDS_SECTION_HEADER_TITLE": "",
    "SPECIAL_THANKS_SECTION_HEADER_TITLE": "",
    "CONTRIBUTOR_PAGE_SECTION_HEADER_TITLE": "",
    "FOLLOW_OFFICIAL_PAGE_SECTION_HEADER_TITLE": "",
}


def unescape(value):
    out = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def parse(text):
    return {key: unescape(value) for key, value in PAIR.findall(text)}


def escape(value):
    return (
        value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    )


def render(pairs, lang):
    lines = ["/*", f"  Language: {lang}", "  呱呱助手 (Guagua Assistant)", "*/", ""]
    for key, value in pairs.items():
        lines.append(f'"{key}" = "{escape(value)}";')
    return "\n".join(lines) + "\n"


def overrides_for(lang):
    table = dict(COMMON)
    if lang == "zh_CN.lproj":
        table.update(ZH_CN)
    elif lang == "zh-Hant.lproj":
        table.update(ZH_HANT)
    else:
        # en 以及其它语言：品牌相关的 key 用英文，缺失的解释回落到英文
        table.update(EN)
    return table


def rewrite(path, overrides):
    pairs = parse(path.read_text(encoding="utf-8"))
    for key in list(pairs):
        value = pairs[key]
        for old in ("NeoFreeBird", "BHTwitter"):
            if old in value:
                value = value.replace(old, "呱呱助手")
        pairs[key] = value
    for key, value in overrides.items():
        pairs[key] = value
    lang = path.parent.name.replace(".lproj", "")
    path.write_text(render(pairs, lang), encoding="utf-8")


def main():
    files = sorted(ROOT.glob("*.lproj/Localizable.strings"))
    for path in files:
        rewrite(path, overrides_for(path.parent.name))
        print(f"  ok  {path.parent.name}")
    print(f"{len(files)} files rewritten")


if __name__ == "__main__":
    main()
