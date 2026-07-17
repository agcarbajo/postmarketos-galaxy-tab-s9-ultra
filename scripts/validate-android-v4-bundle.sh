#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
bundle="${BUNDLE_DIR:-$base/out/gts9uwifi-mainline-v0}"
rootfs_export="${ROOTFS_EXPORT_DIR:-$base/out/rootfs-gts9uwifi}"
rootfs_chroot="${ROOTFS_CHROOT_DIR:-$base/pmbootstrap-work/chroot_rootfs_samsung-gts9uwifi}"
package_zboot="${PACKAGE_ZBOOT:-$rootfs_chroot/boot/vmlinuz}"
package_config="${PACKAGE_CONFIG:-$rootfs_chroot/boot/config}"
package_dtb="${KERNEL_DTB:-$rootfs_chroot/boot/sm8550-samsung-gts9uwifi.dtb}"
tools_root="$base/pmbootstrap-work/chroot_rootfs_samsung-gts9uwifi/usr"
unpack="${UNPACK_BOOTIMG:-$tools_root/bin/unpack_bootimg}"
avbtool="${AVBTOOL:-$tools_root/bin/avbtool}"
tmp=$(mktemp -d "$base/build/validate-bundle.XXXXXX")

cleanup() {
	case "$tmp" in
		"$base"/build/validate-bundle.*) rm -rf -- "$tmp" ;;
	esac
}
trap cleanup EXIT

python3 "$project/scripts/extract-zboot-payload.py" \
	"$package_zboot" "$tmp/package-Image.gz"

for symbol in \
	CONFIG_DRM_SIMPLEDRM \
	CONFIG_MMC \
	CONFIG_MMC_SDHCI \
	CONFIG_MMC_SDHCI_MSM \
	CONFIG_EXT4_FS \
	CONFIG_USB_GADGET \
	CONFIG_USB_CONFIGFS \
	CONFIG_USB_CONFIGFS_NCM \
	CONFIG_SERIAL_QCOM_GENI \
	CONFIG_TOUCHSCREEN_GOODIX_BERLIN_CORE \
	CONFIG_PSTORE \
	CONFIG_PSTORE_RAM; do
	grep -qx "$symbol=y" "$package_config" || {
		echo "$symbol must be built-in" >&2
		exit 1
	}
done

release=$(cat "$rootfs_chroot/usr/share/kernel/samsung-gts9uwifi-mainline/kernel.release")
test -d "$rootfs_chroot/usr/lib/modules/$release"

for spec in \
	'boot.img:100663296' \
	'init_boot.img:8388608' \
	'vendor_boot.img:100663296' \
	'dtbo.img:16777216' \
	'vbmeta.img:65536'; do
	name=${spec%%:*}
	expected=${spec##*:}
	test "$(stat -c %s "$bundle/$name")" -eq "$expected"
done

(
	cd "$bundle"
	sha256sum -c SHA256SUMS
)

for image in boot init_boot vendor_boot; do
	mkdir -p "$tmp/$image"
	python3 "$unpack" --boot_img "$bundle/$image.img" \
		--out "$tmp/$image" --format=info > "$tmp/$image.info"
	grep -q 'header version: 4' "$tmp/$image.info"
done

cmp "$tmp/boot/kernel" "$tmp/package-Image.gz"
test ! -s "$tmp/boot/ramdisk"
test ! -s "$tmp/init_boot/kernel"
cmp "$tmp/init_boot/ramdisk" "$rootfs_export/initramfs"
cmp "$tmp/vendor_boot/dtb" "$package_dtb"
cmp "$tmp/vendor_boot/bootconfig" "$project/configs/vendor_boot/bootconfig.txt"
lz4 -t "$tmp/vendor_boot/vendor_ramdisk00" >/dev/null

grep -q '^page size: 0x00001000$' "$tmp/vendor_boot.info"
grep -q '^kernel load address: 0x80008000$' "$tmp/vendor_boot.info"
grep -q '^ramdisk load address: 0x82000000$' "$tmp/vendor_boot.info"
grep -q '^kernel tags load address: 0x81e00000$' "$tmp/vendor_boot.info"
grep -q '^dtb address: 0x0000000081f00000$' "$tmp/vendor_boot.info"

for image in boot init_boot vendor_boot dtbo; do
	python3 "$avbtool" verify_image --image "$bundle/$image.img"
	python3 "$avbtool" info_image --image "$bundle/$image.img" \
		> "$tmp/$image.avb"
	grep -q "Partition Name:        ${image}" "$tmp/$image.avb"
done
python3 "$avbtool" info_image --image "$bundle/vbmeta.img" > "$tmp/vbmeta.avb"
grep -q '^Flags:                    2$' "$tmp/vbmeta.avb"
grep -q '^Algorithm:                NONE$' "$tmp/vbmeta.avb"

python3 "$project/scripts/inspect-android-dtbo.py" "$bundle/dtbo.img" \
	> "$tmp/dtbo.txt"
grep -q '^total=.* entries=2 .* page=4096 version=0$' "$tmp/dtbo.txt"
grep -q "qcom,board-id = <0x10008 0x0>" "$tmp/dtbo.txt"
grep -q "qcom,board-id = <0x10008 0x3>" "$tmp/dtbo.txt"
grep -q 'dtbo-hw_rev_end = <0x20>' "$tmp/dtbo.txt"

echo 'Android v4 bundle validated byte-for-byte.'
cat "$bundle/SHA256SUMS"
