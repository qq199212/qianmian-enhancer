ARCHS = arm64 arm64e
TARGET = iphone:clang:16.2:15.0
INSTALL_TARGET_PROCESSES = SpringBoard mediaserverd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QianmianEnhancer

QianmianEnhancer_FILES = Tweak.xm QMEnhancerView.m
QianmianEnhancer_FRAMEWORKS = UIKit CoreGraphics CoreImage CoreVideo QuartzColor
QianmianEnhancer_PRIVATE_FRAMEWORKS = 
QianmianEnhancer_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
