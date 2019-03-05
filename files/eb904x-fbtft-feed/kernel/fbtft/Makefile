#
# Copyright (C) 2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=fb-tft-ili9341-eb904
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

VIDEO_MENU:=Video Support

define KernelPackage/fb-tft-ili9341-eb904
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=$(VIDEO_MENU)
  TITLE:=EasyBox 904 display support
  DEPENDS:=@(TARGET_lantiq_xrx200_DEVICE_lantiq_vgv952cjw33-e-ir) +kmod-fb-tft
  FILES:=\
	$(PKG_BUILD_DIR)/fb_ili9341_eb904.ko
# Not really needed, because the device is initialized via DTS
#	$(LINUX_DIR)/drivers/staging/fbtft/fbtft_device.ko
  AUTOLOAD:=$(call AutoLoad,09,fb_ili9341_eb904)
endef

define KernelPackage/fb-tft-ili9341-eb904/description
 FB driver for the special ILI9341 LCD Controller inside EasyBox 904
endef

MAKE_KMOD := $(MAKE) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
                PATH="$(TARGET_PATH)" \
                SUBDIRS="$(PKG_BUILD_DIR)/kmod"

define Build/Prepare
	$(call Build/Prepare/Default)
endef

define Build/Compile
	# Compile the kernel part
	$(MAKE_KMOD) \
		SUBDIRS="$(PKG_BUILD_DIR)" \
		MODFLAGS="-DMODULE -mlong-calls" \
		modules
endef
$(eval $(call KernelPackage,fb-tft-ili9341-eb904))
