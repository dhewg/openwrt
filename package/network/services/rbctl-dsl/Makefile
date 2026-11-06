# SPDX-License-Identifier: GPL-2.0-only
#
# rbctl-dsl — EcoNet xDSL board configuration daemon (Rust).
# Phase 0: builds the gate binary that proves UCI + uloop + ubus link/load.

include $(TOPDIR)/rules.mk

PKG_NAME:=rbctl-dsl
PKG_VERSION:=0.5.1
PKG_RELEASE:=2

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-vendor.tar.zst
PKG_SOURCE_URL:=@OPENWRT
PKG_SOURCE_PROTO:=cargo-vendor-github
PKG_VENDOR_REPO:=dhewg/openwrt_tplink_vx830v_rbctrl-dsl
PKG_VENDOR_TAG:=v$(PKG_VERSION)
PKG_VENDOR_FILE:=v$(PKG_VERSION).tar.gz
PKG_VENDOR_SUBDIR:=rbctl-feed/rbctl-dsl/crates/rbctl_dsl
PKG_VENDOR_HASH:=8b6a3e538163e80b6d72ddf433745a68baf1541b3fbd112a501031e5fddf0df2
PKG_HASH:=f4dac1290fa4c9765249f9980b7214e5b0e50852f9979a2b00c782b7b3a72380

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=rbctl-dsl contributors

PKG_BUILD_PARALLEL:=1
MAKE_PATH:=$(PKG_VENDOR_SUBDIR)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/rust-package.mk

# Steer the vendored -sys crates at the SDK target staging so they link the
# staged libuci / libubox / libnl-tiny (UCI_DIR / LIBUBOX_DIR / LIBNL_TINY_DIR
# are honoured by libuci-sys, libubox-sys, and tinylibnl_sys respectively).
export UCI_DIR:=$(STAGING_DIR)/usr
export LIBNL_TINY_DIR:=$(STAGING_DIR)/usr

# libuci-sys runs bindgen at build time, which invokes libclang. Without
# cross-compile hints, libclang parses the host's glibc headers (x86) and
# trips on __float128. Steer it at the musl toolchain headers instead:
# --target selects the aarch64-musl ABI (no __float128), -isystem points at
# the musl stdint.h / bits/*.h in the SDK toolchain.
export BINDGEN_EXTRA_CLANG_ARGS:=--target=$(RUSTC_TARGET_ARCH) -isystem $(TOOLCHAIN_DIR)/include

define Package/rbctl-dsl
  SECTION:=net
  CATEGORY:=Network
  TITLE:=EcoNet xDSL board configuration daemon
  DEPENDS:=$(RUST_PKG_DEPENDS) +libuci +libnl-tiny
  # No +libubus here: ubus-zero is pure Rust and links no shared library.
endef

define Package/rbctl-dsl/description
  Configures the EcoNet xDSL board over the proprietary 0x88B5 Ethernet
  protocol and exposes line state over ubus. Replaces the proprietary
  remote_board + libcmm.so stack on mainline OpenWrt.
endef

# RustBinPackage provides Build/Compile + a default install for the binary.
# We override Package/install to also ship the init script and notify script.
define Package/rbctl-dsl/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/rbctl-dsl $(1)/usr/sbin/
	# init script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dsl_control $(1)/etc/init.d/dsl_control
	# notify script (fork+exec'd by the daemon on every state transition)
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) ./files/dsl_notify.sh $(1)/sbin/dsl_notify.sh
	# LED hotplug handler — drives the led_dsl UCI LED on HANDSHAKE/TRAINING/UP/DOWN
	$(INSTALL_DIR) $(1)/etc/hotplug.d/dsl
	$(INSTALL_BIN) ./files/led_dsl.sh $(1)/etc/hotplug.d/dsl/led_dsl.sh
	# first-boot UCI defaults — enriches network.dsl from board.json
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/dsl_defaults $(1)/etc/uci-defaults/dsl_defaults
	# board.json hook — declares dsl.modem (generic) + dsl.rbctl (ours)
	# at first boot / config regeneration via /bin/board_detect
	$(INSTALL_DIR) $(1)/etc/board.d
	$(INSTALL_DATA) ./files/board.d/10-rbctl-dsl $(1)/etc/board.d/10-rbctl-dsl
	# package-provided ucidef helpers, sourced by our board.d script
	$(INSTALL_DIR) $(1)/usr/share/rbctl
	$(INSTALL_DATA) ./files/ucidef.sh $(1)/usr/share/rbctl/ucidef.sh
endef

$(eval $(call RustBinPackage,rbctl-dsl))
$(eval $(call BuildPackage,rbctl-dsl))
