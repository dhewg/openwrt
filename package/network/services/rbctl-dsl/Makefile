# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=rbctl-dsl
PKG_SOURCE_DATE:=2026-08-31
PKG_SOURCE_VERSION:=5670764d49c0305fe76d5b454c24a9189f29bea1
PKG_RELEASE:=1

PKG_SOURCE_URL:=@OPENWRT
PKG_SOURCE_PROTO:=cargo-vendor-github
PKG_VENDOR_REPO:=hitech95/openwrt_tplink_vx830v_rbctrl-dsl
PKG_VENDOR_TAG:=$(PKG_SOURCE_VERSION)
PKG_VENDOR_SUBDIR:=rbctl-feed/rbctl-dsl/crates/rbctl_dsl
PKG_VENDOR_HASH:=e3ba76ba3ea0acdbf88d496af6a5ccc65223a69f41848840876561dd70de347c
PKG_HASH:=9e32bd82fa2754ab787aacaf3ad61874f9e1fd1bee5d560b0a1e3ce8bd516e67

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=rbctl-dsl contributors

PKG_BUILD_PARALLEL:=1
MAKE_PATH:=$(PKG_VENDOR_SUBDIR)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/rust-package.mk

# Steer the vendored -sys crates at the SDK target staging so they link the
# staged libuci / libubox / libnl-tiny (UCI_DIR / LIBUBOX_DIR / LIBNL_TINY_DIR
# are honoured by libuci-sys, libubox-sys, and tinylibnl_sys respectively).

# libuci-sys runs bindgen at build time, which invokes libclang. Without
# cross-compile hints, libclang parses the host's glibc headers (x86) and
# trips on __float128. Use --sysroot to steer it at the musl toolchain instead.
CARGO_PKG_VARS+= \
	UCI_DIR="$(STAGING_DIR)/usr" \
	LIBNL_TINY_DIR="$(STAGING_DIR)/usr" \
	BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$(TOOLCHAIN_ROOT_DIR)"

# No +libubus here: ubus-zero is pure Rust and links no shared library.
define Package/rbctl-dsl
  SECTION:=net
  CATEGORY:=Network
  TITLE:=EcoNet xDSL board configuration daemon
  DEPENDS:=$(RUST_PKG_DEPENDS) +libuci +libnl-tiny
endef

define Package/rbctl-dsl/description
  Configures the EcoNet xDSL board over the proprietary 0x88B5 Ethernet
  protocol and exposes line state over ubus. Replaces the proprietary
  remote_board + libcmm.so stack on mainline OpenWrt.
endef

define Package/rbctl-dsl/install
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/rbctl-dsl $(1)/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dsl_control $(1)/etc/init.d/dsl_control
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) ./files/dsl_notify.sh $(1)/sbin/dsl_notify.sh
	$(INSTALL_DIR) $(1)/etc/hotplug.d/dsl
	$(INSTALL_BIN) ./files/led_dsl.sh $(1)/etc/hotplug.d/dsl/led_dsl.sh
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/dsl_defaults $(1)/etc/uci-defaults/dsl_defaults
	$(INSTALL_DIR) $(1)/etc/board.d
	$(INSTALL_DATA) ./files/board.d/10-rbctl-dsl $(1)/etc/board.d/10-rbctl-dsl
endef

$(eval $(call RustBinPackage,rbctl-dsl))
$(eval $(call BuildPackage,rbctl-dsl))
