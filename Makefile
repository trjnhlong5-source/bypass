export THEOS ?= $(HOME)/theos
export THEOS_MAKE_PATH ?= $(THEOS)/makefiles

TARGET := iphone:clang:latest:14.0
ARCHS  := arm64

include $(THEOS_MAKE_PATH)/common.mk

DYLIB_NAME := FreeFireBypass

FreeFireBypass_FILES    := src/main.mm
FreeFireBypass_CFLAGS   := -fobjc-arc
FreeFireBypass_CCFLAGS  := -std=c++17 -fobjc-arc
FreeFireBypass_LIBRARIES := substrate

include $(THEOS_MAKE_PATH)/dylib.mk
