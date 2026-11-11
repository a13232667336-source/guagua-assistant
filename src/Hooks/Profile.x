//
//  Profile.x
//  呱呱助手 —— 只保留“不显示 Twitter Blue 提示”需要的那一个 hook。
//

#import "HookHelpers.h"

// MARK: - Hide premium offer

%hook T1ProfileSummaryView

- (BOOL)shouldShowGetVerifiedButton {
    return [BHTSettings boolForKey:@"hide_premium_offer"] ? NO : %orig;
}

%end
