# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=mold
PKG_VERSION:=3.0.0
PKG_RELEASE:=1

# Generated from the GitHub archive via DownloadMethod/cargo-vendor-github, or
# regenerate manually with:
#   scripts/gen-cargo-vendor-tarball.sh github rui314/mold v3.0.0 mold 3.0.0 cli
# The generator makes the tarball independent of the cargo version.
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-vendor.tar.zst
PKG_SOURCE_URL:=@OPENWRT
PKG_SOURCE_PROTO:=cargo-vendor-github
PKG_VENDOR_REPO:=rui314/mold
PKG_VENDOR_TAG:=v$(PKG_VERSION)
PKG_VENDOR_FILE:=v$(PKG_VERSION).tar.gz
PKG_VENDOR_SUBDIR:=cli
PKG_VENDOR_HASH:=1dee837e227b0c3f2661def602ef8ddc0b889ae5b1d28c1ddec5f29e08e5ceb5
PKG_HASH:=b8518e133f1d7c319136be3d20a3e1b5cb27ce44eae440f91146a530a957dff7

HOST_MAKE_PATH:=cli

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/rust-host-build.mk

CARGO_HOST_VARS += ZSTD_SYS_USE_PKG_CONFIG=1

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOST)/bin
	$(INSTALL_BIN) $(HOST_INSTALL_DIR)/bin/mold $(STAGING_DIR_HOST)/bin/
endef

$(eval $(call HostBuild))
