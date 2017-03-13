#
# Copyright (C) 2017 SFR
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

define Profile/neufbox5
  NAME:=SFR Neufbox 5
  PACKAGES:= \
    kmod-fs-exfat \
    kmod-fs-vfat \
    kmod-fs-ntfs
endef

define Profile/neufbox5/Description
  Neufbox 5 OpenWRT support.
endef

$(eval $(call Profile,neufbox5))
