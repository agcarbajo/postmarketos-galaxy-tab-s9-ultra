#!/bin/bash
set -euo pipefail

base=${PMOS_WORKDIR:-/root/pmos-gts9u}
project=${PROJECT_MNT:-'/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS'}
version=${WIFI_BUILD_VERSION:-0.42}
kernel="$base/out/kernel-gts9uwifi-v${version/./}"
bundle="$base/out/gts9uwifi-mainline-v$version"
overlay="$base/out/rootfs-overlay-v$version"
artifact=${ARTIFACT:-"$project/artifacts/postmarketos-edge-xfce-mainline-v$version-wcn7850-pcie-cold-reset-sm-x910-twrp.zip"}
firmware="$project/pmaports/device/testing/firmware-samsung-gts9uwifi"

bash "$project/scripts/stage-gpu-firmware.sh"

KERNEL_OUT_DIR="$kernel" BUILD_WIFI_MODULES=1 \
	bash "$project/scripts/build-mainline-kernel.sh"

case "$overlay" in
	"$base"/out/rootfs-overlay-v*) rm -rf -- "$overlay" ;;
	*) echo "unsafe overlay path: $overlay" >&2; exit 1 ;;
esac
mkdir -p \
	"$overlay/etc/modules-load.d" \
	"$overlay/etc/modprobe.d" \
	"$overlay/etc/ssh/sshd_config.d" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0" \
	"$overlay/usr/lib/firmware/qcom" \
	"$overlay/usr/libexec" \
	"$overlay/usr/share/X11/xorg.conf.d"

cp -a "$kernel/modules-root/." "$overlay/"
install -m 0644 "$project/configs/wifi/ath12k.conf" \
	"$overlay/etc/modules-load.d/ath12k.conf"
# Adreno 740 GPU firmware under /lib/firmware/qcom (msm is built-in).
for f in a740_zap.mdt a740_zap.b00 a740_zap.b01 a740_zap.b02 a740_sqe.fw gmu_gen70200.bin; do
	install -m 0644 "$firmware/$f" "$overlay/usr/lib/firmware/qcom/$f"
done
install -m 0644 "$project/configs/development-ssh/00-gts9uwifi-development-key.conf" \
	"$overlay/etc/ssh/sshd_config.d/00-gts9uwifi-development-key.conf"
install -m 0644 "$project/configs/development-ssh/phablet.authorized_keys" \
	"$overlay/etc/ssh/gts9uwifi_authorized_keys"
install -m 0755 "$project/configs/display-baseline/gts9uwifi-display-handoff" \
	"$overlay/usr/libexec/gts9uwifi-display-handoff"
install -m 0644 "$project/configs/display-baseline/20-gts9uwifi-fbdev.conf" \
	"$overlay/usr/share/X11/xorg.conf.d/20-gts9uwifi-fbdev.conf"
# Official linux-firmware amss: Samsung's WLAN.HMT downstream amss never
# raises WMI ready under mainline ath12k because it expects the phy_ucode
# QMI download that only cnss2 implements.
install -m 0644 "$firmware/official-amss.bin" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0/amss.bin"
# Canonical linux-firmware M3 image; Samsung ships no m3 for kiwi and the
# earlier phy_ucode20.elf mapping fed the chip PHY microcode as M3.
install -m 0644 "$firmware/m3.bin" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0/m3.bin"
# Keep the official container first while the X910-specific Samsung BDF is
# being validated. It has no matching X910/board-id 255 entry, so ath12k falls
# back to the proven QRD ELF in board.bin.
install -m 0644 "$firmware/official-board-2.bin" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin"
install -m 0644 "$firmware/qrd-board.bin" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0/board.bin"
install -m 0644 "$firmware/regdb.bin" \
	"$overlay/usr/lib/firmware/ath12k/WCN7850/hw2.0/regdb.bin"

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
	--label "postmarketOS mainline v$version for SM-X910 (WCN7850 PCIe cold-reset bring-up, isolated ath12k)"

stat -c '%n %s bytes' "$artifact"
