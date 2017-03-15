#
# Copyright (C) 2014 OpenWrt.org
#

platform_get_rootfs() {
	local rootfsdev

	if read cmdline < /proc/cmdline; then
		case "$cmdline" in
			*block2mtd=*)
				rootfsdev="${cmdline##*block2mtd=}"
				rootfsdev="${rootfsdev%%,*}"
			;;
			*root=*)
				rootfsdev="${cmdline##*root=}"
				rootfsdev="${rootfsdev%% *}"
			;;
		esac

		echo "${rootfsdev}"
	fi
}

platform_copy_config() {
	local board="$(cat /tmp/sysinfo/board_name)"

	case "$board" in
	erlite)
		mount -t vfat /dev/sda1 /mnt
		cp -af "$CONF_TAR" /mnt/
		umount /mnt
		;;
	esac
}

platform_do_flash() {
	local tar_file=$1
	local board=$2
	local kernel=$3
	local rootfs=$4

	case "$board" in
	er | \
	erlite)
		mkdir -p /boot
		mount -t vfat /dev/$kernel /boot

		[ -f /boot/vmlinux.64 -a ! -L /boot/vmlinux.64 ] && {
			mv /boot/vmlinux.64 /boot/vmlinux.64.previous
			mv /boot/vmlinux.64.md5 /boot/vmlinux.64.md5.previous
		}
		
		echo "flashing kernel to /dev/$kernel"
		tar xf $tar_file sysupgrade-$board/kernel -O > /boot/vmlinux.64
		md5sum /boot/vmlinux.64 | cut -f1 -d " " > /boot/vmlinux.64.md5
		echo "flashing rootfs to ${rootfs}"
		tar xf $tar_file sysupgrade-$board/root -O | dd of="${rootfs}" bs=4096
		sync
		umount /boot
		;;
		
	neufbox5)
		echo "flashing kernel to /dev/$kernel"
		tar xf $tar_file sysupgrade-$board/kernel -O > /tmp/kernel.tmp
		mtd write /tmp/kernel.tmp /dev/$kernel
		# Free some RAM
		rm /tmp/kernel.tmp
		
		echo "flashing rootfs to ${rootfs}"
		tar xf $tar_file sysupgrade-$board/root -O > /tmp/root.tmp
		mtd write /tmp/root.tmp ${rootfs}
		# Free some more RAM
		rm /tmp/root.tmp
		;;
	esac
}

platform_do_upgrade() {
	local tar_file="$1"
	local board=$(cat /tmp/sysinfo/board_name)
	local rootfs="$(platform_get_rootfs)"
	local kernel=

	[ -b "${rootfs}" ] || return 1
	case "$board" in
	erlite)
		kernel=sda1
		;;
	er)
		kernel=mmcblk0p1
		;;
	neufbox5)
		kernel=mtd2
		rootfs="/dev/mtd3"
		;;
	*)
		return 1
	esac

	platform_do_flash $tar_file $board $kernel $rootfs

	return 0
	
}

platform_check_image() {
	local board=$(cat /tmp/sysinfo/board_name)

	case "$board" in
	erlite | \
	er | \
	neufbox5)
		local tar_file="$1"
		local kernel_length=`(tar xf $tar_file sysupgrade-$board/kernel -O | wc -c) 2> /dev/null`
		local rootfs_length=`(tar xf $tar_file sysupgrade-$board/root -O | wc -c) 2> /dev/null`
		[ "$kernel_length" = 0 -o "$rootfs_length" = 0 ] && {
			echo "The upgarde image is corrupt."
			return 1
		}
		return 0
		;;
	esac

	echo "Sysupgrade is not yet supported on $board."
	return 1
}
