#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
bundle="$base/out/gts9uwifi-mainline-v0"
rootfs_export="$base/out/rootfs-gts9uwifi"
rootfs=$(readlink -f "$rootfs_export/samsung-gts9uwifi.img")
artifact_dir="$project/artifacts"
sd_name='postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst'
zip_name='postmarketos-edge-xfce-mainline-v0.2-sm-x910-twrp.zip'
manifest='SHA256SUMS-mainline-v0.2.txt'
metadata='mainline-v0.2-build-info.txt'

test -s "$rootfs"
test -d "$bundle"
command -v zstd >/dev/null

bash "$project/scripts/validate-android-v4-bundle.sh"

mkdir -p "$artifact_dir"
zstd -T0 -10 --long=27 --force "$rootfs" -o "$artifact_dir/$sd_name"

python3 "$project/scripts/make-twrp-zip.py" \
	"$bundle" "$artifact_dir/$zip_name" --project "$project"

{
	printf 'device=Samsung Galaxy Tab S9 Ultra Wi-Fi (SM-X910, gts9uwifi)\n'
	printf 'channel=postmarketOS edge\n'
	printf 'ui=xfce4\n'
	printf 'service_manager=systemd\n'
	cat "$bundle/BUILD-METADATA.txt"
	printf 'pmaports_source=%s\n' "$(git -C "$base/pmaports" rev-parse HEAD)"
	printf 'rootfs_uncompressed_bytes=%s\n' "$(stat -c %s "$rootfs")"
	printf 'rootfs_uncompressed_sha256=%s\n' "$(sha256sum "$rootfs" | cut -d' ' -f1)"
	printf 'initramfs_extra_sha256=%s\n' "$(sha256sum "$rootfs_export/initramfs-extra" | cut -d' ' -f1)"
} > "$artifact_dir/$metadata"

(
	cd "$artifact_dir"
	sha256sum "$sd_name" "$zip_name" "$metadata" > "$manifest"
)

cat "$artifact_dir/$manifest"
