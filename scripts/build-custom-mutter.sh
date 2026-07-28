#!/bin/bash
set -euo pipefail

base=${PMOS_WORKDIR:-/root/pmos-gts9u}
project=${PROJECT_MNT:-'/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS'}
source_package="$project/pmaports/extra-repos/systemd/mutter"
target_package="$base/pmaports/extra-repos/systemd/mutter"

install -d "$target_package"
install -m 0644 "$source_package/APKBUILD" "$target_package/APKBUILD"
for patch in \
	fixudev-req.patch \
	pcversion.patch \
	fix-orientation-inhibit-underflow.patch; do
	install -m 0644 "$source_package/$patch" "$target_package/$patch"
done

"$base/pmbootstrap/pmbootstrap.py" --as-root \
	build --arch aarch64 --force mutter

apk="$base/pmbootstrap-work/packages/systemd-edge/aarch64/mutter-999950.2-r5.apk"
test -f "$apk"
printf '%s\n' "$apk"
