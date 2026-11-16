//
//  Tweak.x
//  NoShotSound —— 屏蔽截屏/相机快门音（SystemSoundID 1108）
//
//  适用：iOS 15 / 16 / 17（越狱环境，注入 SpringBoard 与相机）
//  原理：在 AudioToolbox 层拦掉 1108 号系统音，截图与相机快门都静音。
//

#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>

// 1108 = 截屏 / 相机快门系统音
static BOOL NFBIsMutedSoundID(SystemSoundID soundID) {
    return soundID == 1108;
}

static void (*orig_AudioServicesPlaySystemSound)(SystemSoundID);
static void (*orig_AudioServicesPlaySystemSoundWithCompletion)(SystemSoundID, void (^)(void));

static void hook_AudioServicesPlaySystemSound(SystemSoundID soundID) {
    if (NFBIsMutedSoundID(soundID)) {
        return;
    }
    if (orig_AudioServicesPlaySystemSound) {
        orig_AudioServicesPlaySystemSound(soundID);
    }
}

static void hook_AudioServicesPlaySystemSoundWithCompletion(SystemSoundID soundID,
                                                            void (^completion)(void)) {
    if (NFBIsMutedSoundID(soundID)) {
        if (completion) {
            completion();
        }
        return;
    }
    if (orig_AudioServicesPlaySystemSoundWithCompletion) {
        orig_AudioServicesPlaySystemSoundWithCompletion(soundID, completion);
    }
}

// 有些系统版本走 AudioServicesPlayAlertSound 播放快门音
static void (*orig_AudioServicesPlayAlertSound)(SystemSoundID);

static void hook_AudioServicesPlayAlertSound(SystemSoundID soundID) {
    if (NFBIsMutedSoundID(soundID)) {
        return;
    }
    if (orig_AudioServicesPlayAlertSound) {
        orig_AudioServicesPlayAlertSound(soundID);
    }
}

%ctor {
    MSHookFunction((void *)AudioServicesPlaySystemSound,
                   (void *)hook_AudioServicesPlaySystemSound,
                   (void **)&orig_AudioServicesPlaySystemSound);

    MSHookFunction((void *)AudioServicesPlaySystemSoundWithCompletion,
                   (void *)hook_AudioServicesPlaySystemSoundWithCompletion,
                   (void **)&orig_AudioServicesPlaySystemSoundWithCompletion);

    MSHookFunction((void *)AudioServicesPlayAlertSound,
                   (void *)hook_AudioServicesPlayAlertSound,
                   (void **)&orig_AudioServicesPlayAlertSound);

    NSLog(@"[NoShotSound] 截屏音已屏蔽");
}
