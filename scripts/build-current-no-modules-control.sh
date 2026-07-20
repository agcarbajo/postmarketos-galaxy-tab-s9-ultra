#!/bin/bash
set -euo pipefail

base=${PMOS_WORKDIR:-/root/pmos-gts9u}
project=${PROJECT_MNT:-'/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS'}
kernel="$base/out/kernel-gts9uwifi-v031"
bundle="$base/out/gts9uwifi-mainline-v0.31"
overlay="$base/out/rootfs-overlay-v0.31"
artifact=${ARTIFACT:-"$project/artifacts/postmarketos-edge-xfce-mainline-v0.31-current-kernel-no-modules-sm-x910-twrp.zip"}

KERNEL_OUT_DIR="$kernel" bash "$project/scripts/build-mainline-kernel.sh"

case "$overlay" in
	"$base"/out/rootfs-overlay-v0.31) rm -rf -- "$overlay" ;;
	*) echo "unsafe overlay path: $overlay" >&2; exit 1 ;;
esac
mkdir -p "$overlay/usr/libexec" "$overlay/usr/share/X11/xorg.conf.d"
install -m 0755 "$project/configs/display-baseline/gts9uwifi-display-handoff" \
	"$overlay/usr/libexec/gts9uwifi-display-handoff"
install -m 0644 "$project/configs/display-baseline/20-gts9uwifi-fbdev.conf" \
	"$overlay/usr/share/X11/xorg.conf.d/20-gts9uwifi-fbdev.conf"

BUNDLE_OUT_DIR="$bundle" \
BUNDLE_EXPORT_DIR="$bundle/export" \
INITRAMFS="$base/out/rootfs-gts9uwifi/initramfs" \
KERNEL_IMAGE="$kernel/Image.gz" \
KERNEL_DTB="$kernel/sm8550-samsung-gts9uwifi.dtb" \
PACKAGE_CONFIG="$kernel/config" \
APPEND_DTB_TO_KERNEL=1 \
DISABLE_RUNTIME_DTBO=1 \
	bash "$project/scripts/build-android-v4-bundle.sh"

python3 "$project/scripts/make-twrp-zip.py" "$bundle" "$artifact" \
	--project "$project" \
	--rootfs-overlay "$overlay" \
	--label 'postmarketOS mainline v0.31 for SM-X910 (current kernel/DTS, no loadable modules)'

stat -c '%n %s bytes' "$artifact"
