#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
target="$base/pmaports"

test -d "$target/.git"
test -d "$project/pmaports/device/testing"

for package in \
	device-samsung-gts9uwifi \
	linux-samsung-gts9uwifi-mainline; do
	mkdir -p "$target/device/testing/$package"
	cp -a "$project/pmaports/device/testing/$package/." \
		"$target/device/testing/$package/"
done

git -C "$target" status --short -- \
	device/testing/device-samsung-gts9uwifi \
	device/testing/linux-samsung-gts9uwifi-mainline
