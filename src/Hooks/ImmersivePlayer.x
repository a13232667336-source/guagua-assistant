//
//  ImmersivePlayer.x
//  呱呱助手 (Guagua Assistant)
//
//  只保留“视频时间戳”：沉浸式播放器里显示总时长而不是剩余时间。
//  （原版里的“禁用视频流上下滑动 / 关闭视频停靠 / 轻点暂停视频”已按要求移除，
//   因此这里不再有对应开关与 hook。）
//

#import "HookHelpers.h"

// MARK: - Immersive Player Timestamp

// Field indexes in ImmersiveCardState's declaration order.
enum {
    CardStateFieldIsPanningBetweenCards = 19,
    CardStateFieldIsChromeFadedOutWhilePanning = 20,
};

static const uint8_t* immersiveCardStateMetadata(void) {
    static const uint8_t* metadata;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const void* (*getType)(const char*, size_t, const void*,
                               const void* const*) =
            dlsym(RTLD_DEFAULT, "swift_getTypeByMangledNameInEnvironment");
        if (getType) {
            const char* mangledName = "14T1TwitterSwift18ImmersiveCardStateV";
            metadata = getType(mangledName, strlen(mangledName), NULL, NULL);
        }
    });
    return metadata;
}

// Reads a Bool field through the struct's field offset vector, the same way the
// app's own compiled accesses do, so byte offsets never have to be hardcoded.
static BOOL cardStateBoolField(const uint8_t* state,
                               uint32_t fieldIndex,
                               BOOL* outValue) {
    const uint8_t* metadata = immersiveCardStateMetadata();
    if (!metadata) {
        return NO;
    }

    const uint8_t* descriptor = *(const uint8_t* const*)(metadata + 8);
    uint32_t numFields = *(const uint32_t*)(descriptor + 20);
    uint32_t offsetVectorOffset = *(const uint32_t*)(descriptor + 24);
    if (fieldIndex >= numFields || offsetVectorOffset == 0) {
        return NO;
    }

    const int32_t* fieldOffsets =
        (const int32_t*)(metadata + offsetVectorOffset * sizeof(void*));
    *outValue = state[fieldOffsets[fieldIndex]] & 1;
    return YES;
}

// displayMode is a Swift enum stored as an 8-byte case index followed by a
// discriminator tag (0 = the repliesPanning payload case, 1 = an empty case).
// Empty cases: regular = 0, repliesOpen = 1, repliesCompletelyOpen = 2,
// controlsHidden = 3, scrubbing = 4, statusExpanded = 5.
static BOOL progressLabelAlphaFromState(id pluginView, CGFloat* outAlpha) {
    Ivar stateIvar = class_getInstanceVariable([pluginView class], "state");
    if (!stateIvar) {
        return NO;
    }

    uint8_t* state =
        (uint8_t*)(__bridge void*)pluginView + ivar_getOffset(stateIvar);
    uint64_t displayModeCase = *(uint64_t*)state;
    uint8_t displayModeTag = state[8];

    BOOL visible =
        displayModeTag == 1 && (displayModeCase < 1 || displayModeCase > 3);

    if (visible) {
        BOOL panning = NO, chromeFaded = NO;
        if (cardStateBoolField(state, CardStateFieldIsPanningBetweenCards,
                               &panning) &&
            panning) {
            visible = NO;
        } else if (cardStateBoolField(state,
                                      CardStateFieldIsChromeFadedOutWhilePanning,
                                      &chromeFaded) &&
                   chromeFaded) {
            visible = NO;
        }
    }

    *outAlpha = visible ? 1.0 : 0.0;
    return YES;
}

static const void* kBHTRestoredTimestampKey = &kBHTRestoredTimestampKey;

// VideoControlsView.ProgressLabelMode, a payload-free Swift enum stored in a
// single byte. The timestamp button's tap handler just flips this and rebuilds
// its configuration, so writing it has the same effect as tapping the label.
enum {
    ProgressLabelModeRemaining = 0,
    ProgressLabelModeTotal = 1,
};

%hook _TtC14T1TwitterSwift17VideoControlsView

- (void)layoutSubviews {
    %orig;

    BHTApplyDimToVideoControls(self);

    if (![BHTSettings boolForKey:@"restore_video_timestamp"] ||
        objc_getAssociatedObject(self, kBHTRestoredTimestampKey)) {
        return;
    }

    Ivar modeIvar =
        class_getInstanceVariable([self class], "progressLabelMode");
    if (!modeIvar) {
        return;
    }

    objc_setAssociatedObject(self, kBHTRestoredTimestampKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Set once instead of on every layout so tapping the label still toggles
    // back to the remaining-time countdown.
    uint8_t* mode = (uint8_t*)(__bridge void*)self + ivar_getOffset(modeIvar);
    *mode = ProgressLabelModeTotal;
}

%end
