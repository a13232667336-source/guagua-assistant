//
//  VideoTimestamp.x
//  呱呱助手 (minimal build)
//
//  「视频时间戳」：沉浸式播放器里显示总时长，而不是剩余时间。
//  只保留这一个 hook，不涉及其它播放器逻辑，避免影响播放器稳定性。
//

#import "HookHelpers.h"

static const void* kNFBTimestampAppliedKey = &kNFBTimestampAppliedKey;

// VideoControlsView.ProgressLabelMode: 0 = 剩余时间, 1 = 总时长
enum {
    NFBProgressLabelModeRemaining = 0,
    NFBProgressLabelModeTotal = 1,
};

%hook _TtC14T1TwitterSwift17VideoControlsView

- (void)layoutSubviews {
    %orig;

    if (![BHTSettings boolForKey:@"restore_video_timestamp"] ||
        objc_getAssociatedObject(self, kNFBTimestampAppliedKey) != nil) {
        return;
    }

    Ivar modeIvar = class_getInstanceVariable([self class], "progressLabelMode");
    if (modeIvar == NULL) {
        return;
    }

    objc_setAssociatedObject(self, kNFBTimestampAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    uint8_t* mode = (uint8_t*)(__bridge void*)self + ivar_getOffset(modeIvar);
    *mode = NFBProgressLabelModeTotal;
}

%end
