THEOS_DEVICE_IP ?= localhost
TARGET := iphone:clang:latest:14.0
ARCHS  := arm64

include $(THEOS)/makefiles/common.mk

DYLIB_NAME := FreeFireBypass

FreeFireBypass_FILES    := main.mm
FreeFireBypass_CFLAGS   := -fobjc-arc
FreeFireBypass_CCFLAGS  := -std=c++17 -fobjc-arc
FreeFireBypass_LIBRARIES := substrate

include $(THEOS)/makefiles/dylib.mk
