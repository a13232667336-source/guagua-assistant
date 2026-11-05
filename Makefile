ARCHS = arm64
TARGET := iphone:clang:16.5:14.0
DEBUG = 0
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Guagua

NFB_NAME := $(shell sed -n 's/^Name: //p' control)
NFB_VERSION := $(shell sed -n 's/^Version: //p' control)
NFB_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo local)

Guagua_FILES = $(shell find src \( -name '*.x' -o -name '*.m' \) | sort)
Guagua_FRAMEWORKS = UIKit Foundation AVFoundation AVKit CoreMotion GameController VideoToolbox Accelerate CoreMedia CoreVideo CoreImage CoreGraphics ImageIO Photos CoreServices SystemConfiguration SafariServices Security QuartzCore WebKit SceneKit UniformTypeIdentifiers
Guagua_PRIVATE_FRAMEWORKS = Preferences
Guagua_OBJ_FILES = $(shell find deps/ffmpeg-kit-next/build/lib -name '*.a')
Guagua_CFLAGS = -Isrc -Ideps/ffmpeg-kit-next/build -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-unused-property-ivar -Wno-error -DNFB_VERSION_STRING='"$(NFB_NAME) v$(NFB_VERSION)"' -DNFB_COMMIT_STRING='"$(NFB_COMMIT)"'

include $(THEOS_MAKE_PATH)/tweak.mk

# TrollFools / TrollStore injection: no Cephei, no libbhFLEX subproject.
#   - Cephei: settings live in NSUserDefaults, HBPreferences is not used.
#   - FLEX: only powers the optional debug toggle and is looked up at runtime
#     (objc_getClass), so it is silently skipped when not injected.
# Build deps/flex yourself and inject libbhFLEX.dylib if you want that toggle.
