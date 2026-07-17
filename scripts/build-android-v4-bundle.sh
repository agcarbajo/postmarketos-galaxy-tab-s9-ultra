#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
kernel_dir="${KERNEL_OUT_DIR:-$base/out/kernel-gts9uwifi}"
initramfs="${INITRAMFS:?Set INITRAMFS to the exported postmarketOS initramfs}"
linux_out="${BUNDLE_OUT_DIR:-$base/out/gts9uwifi-mainline-v0}"
export_out="${BUNDLE_EXPORT_DIR:-$project/artifacts/gts9uwifi-mainline-v0}"

boot_size=100663296
init_boot_size=8388608
vendor_boot_size=100663296
dtbo_size=16777216
vbmeta_size=65536

find_tool() {
	for candidate in "$@"; do
		if [ -f "$candidate" ]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	return 1
}

mkbootimg=${MKBOOTIMG:-$(find_tool \
	/root/mkbootimg/mkbootimg.py \
	"$base/mkbootimg/mkbootimg.py")}
mkdtimg=${MKDTIMG:-$(find_tool \
	/root/mkbootimg/mkdtimg.py \
	"$base/mkbootimg/mkdtimg.py")}
avbtool=${AVBTOOL:-$(find_tool \
	/root/avb/avbtool.py \
	/root/avb/avbtool \
	/root/avbtool/avbtool.py \
	/root/avbtool/avbtool)}

dtb="$kernel_dir/sm8550-samsung-gts9uwifi.dtb"
image="$kernel_dir/Image.gz"
cmdline_file="$project/configs/vendor_boot/cmdline.txt"
bootconfig="$project/configs/vendor_boot/bootconfig.txt"
dtbo_configs="$project/configs/dtbo"

for file in "$mkbootimg" "$mkdtimg" "$avbtool" "$dtb" "$image" \
	"$initramfs" "$cmdline_file" "$bootconfig"; do
	test -f "$file" || { echo "missing input: $file" >&2; exit 1; }
done

mkdir -p "$base/build" "$linux_out" "$export_out"
tmp=$(mktemp -d "$base/build/boot-bundle.XXXXXX")
cleanup() {
	case "$tmp" in
		"$base"/build/boot-bundle.*) rm -rf -- "$tmp" ;;
	esac
}
trap cleanup EXIT

cmdline=$(tr '\n' ' ' < "$cmdline_file" | sed 's/[[:space:]]*$//')

# Android boot header v4: kernel only.  X910 ABL obtains the generic ramdisk
# from init_boot and the DTB/vendor cmdline from vendor_boot.
python3 "$mkbootimg" \
	--kernel "$image" \
	--cmdline '' \
	--header_version 4 \
	--os_version 13 \
	--os_patch_level 2025-07 \
	-o "$linux_out/boot.img"
python3 "$avbtool" add_hash_footer \
	--image "$linux_out/boot.img" \
	--partition_name boot \
	--partition_size "$boot_size"

python3 "$mkbootimg" \
	--ramdisk "$initramfs" \
	--header_version 4 \
	-o "$linux_out/init_boot.img"
python3 "$avbtool" add_hash_footer \
	--image "$linux_out/init_boot.img" \
	--partition_name init_boot \
	--partition_size "$init_boot_size"

mkdir -p "$tmp/empty-vendor-ramdisk"
(
	cd "$tmp/empty-vendor-ramdisk"
	find . -print0 | cpio --null -o --format=newc 2>/dev/null
) | lz4 -l -12 - "$tmp/vendor_ramdisk.lz4" >/dev/null

python3 "$mkbootimg" \
	--ramdisk_type platform \
	--ramdisk_name '' \
	--vendor_ramdisk_fragment "$tmp/vendor_ramdisk.lz4" \
	--dtb "$dtb" \
	--vendor_cmdline "$cmdline" \
	--header_version 4 \
	--vendor_boot "$linux_out/vendor_boot.img" \
	--base 0x80000000 \
	--kernel_offset 0x8000 \
	--ramdisk_offset 0x02000000 \
	--tags_offset 0x01e00000 \
	--pagesize 4096 \
	--dtb_offset 0x1f00000 \
	--vendor_bootconfig "$bootconfig"
python3 "$avbtool" add_hash_footer \
	--image "$linux_out/vendor_boot.img" \
	--partition_name vendor_boot \
	--partition_size "$vendor_boot_size"

dtc -@ -I dts -O dtb \
	-o "$tmp/board00.dtbo" "$dtbo_configs/gts9uwifi-board00-noop.dts"
dtc -@ -I dts -O dtb \
	-o "$tmp/board03.dtbo" "$dtbo_configs/gts9uwifi-board03-noop.dts"
python3 "$mkdtimg" create "$linux_out/dtbo.img" \
	--page_size=4096 "$tmp/board00.dtbo" "$tmp/board03.dtbo"
python3 "$avbtool" add_hash_footer \
	--image "$linux_out/dtbo.img" \
	--partition_name dtbo \
	--partition_size "$dtbo_size"

python3 "$avbtool" make_vbmeta_image \
	--output "$linux_out/vbmeta.img" \
	--flags 2 \
	--padding_size "$vbmeta_size"

for spec in \
	"boot.img:$boot_size" \
	"init_boot.img:$init_boot_size" \
	"vendor_boot.img:$vendor_boot_size" \
	"dtbo.img:$dtbo_size" \
	"vbmeta.img:$vbmeta_size"; do
	name=${spec%%:*}
	expected=${spec##*:}
	actual=$(stat -c %s "$linux_out/$name")
	[ "$actual" -eq "$expected" ] || {
		echo "$name: expected $expected bytes, got $actual" >&2
		exit 1
	}
done

sha256sum "$linux_out"/*.img > "$linux_out/SHA256SUMS"
{
	printf 'kernel_source=%s\n' "$(git -C "$base/linux-mainline" rev-parse HEAD)"
	printf 'kernel_config_sha256=%s\n' "$(sha256sum "$kernel_dir/config" | cut -d' ' -f1)"
	printf 'initramfs_sha256=%s\n' "$(sha256sum "$initramfs" | cut -d' ' -f1)"
} > "$linux_out/BUILD-METADATA.txt"

install -m 0644 "$linux_out"/*.img "$export_out/"
install -m 0644 "$linux_out/SHA256SUMS" "$linux_out/BUILD-METADATA.txt" \
	"$export_out/"

cat "$linux_out/SHA256SUMS"
