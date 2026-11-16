DEBUG = 0
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoShotSound
NoShotSound_FILES = Tweak.x
NoShotSound_FRAMEWORKS = AudioToolbox Foundation UIKit
NoShotSound_LDFLAGS = -fuse-ld=lld -Wl,-undefined,dynamic_lookup

include $(THEOS)/makefiles/tweak.mk
