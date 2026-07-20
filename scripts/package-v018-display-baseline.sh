#!/bin/bash
set -euo pipefail

base=${PMOS_WORKDIR:-/root/pmos-gts9u}
project=${PROJECT_MNT:-'/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS'}
source_zip=${SOURCE_ZIP:-"$project/artifacts/postmarketos-edge-xfce-mainline-v0.18-dwc3-ep0-diagnostics-sm-x910-twrp.zip"}
bundle="$base/out/gts9uwifi-mainline-v0.30-v018-baseline"
overlay="$base/out/rootfs-overlay-v0.30"
artifact=${ARTIFACT:-"$project/artifacts/postmarketos-edge-xfce-mainline-v0.30-known-good-v018-display-sm-x910-twrp.zip"}

case "$bundle:$overlay" in
	"$base/out/gts9uwifi-mainline-v0.30-v018-baseline:$base/out/rootfs-overlay-v0.30")
		rm -rf -- "$bundle" "$overlay"
		;;
	*) echo "unsafe output paths" >&2; exit 1 ;;
esac
mkdir -p "$bundle" "$overlay/usr/libexec" \
	"$overlay/usr/share/X11/xorg.conf.d"

python3 - "$source_zip" "$bundle" <<'PY'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
members = ("boot.img", "init_boot.img", "vendor_boot.img", "dtbo.img", "vbmeta.img")
with zipfile.ZipFile(source) as archive:
    for member in members:
        data = archive.read(member)
        (destination / member).write_bytes(data)
PY

install -m 0755 "$project/configs/display-baseline/gts9uwifi-display-handoff" \
	"$overlay/usr/libexec/gts9uwifi-display-handoff"
install -m 0644 "$project/configs/display-baseline/20-gts9uwifi-fbdev.conf" \
	"$overlay/usr/share/X11/xorg.conf.d/20-gts9uwifi-fbdev.conf"

python3 "$project/scripts/make-twrp-zip.py" "$bundle" "$artifact" \
	--project "$project" \
	--rootfs-overlay "$overlay" \
	--label 'postmarketOS mainline v0.30 for SM-X910 (known-good v0.18 display baseline)'

stat -c '%n %s bytes' "$artifact"
