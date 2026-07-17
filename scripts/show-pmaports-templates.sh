#!/bin/sh
set -eu

PMAPORTS=${PMAPORTS:-/root/pmos-gts9u/pmaports}

for file in \
	device/main/linux-postmarketos-mainline/APKBUILD \
	device/main/linux-postmarketos-mainline/config-postmarketos-qcom.aarch64 \
	device/testing/device-google-raven/APKBUILD \
	device/testing/device-google-raven/deviceinfo \
	device/testing/device-google-raven/kernel-cmdline.conf; do
	path=$PMAPORTS/$file
	if [ -f "$path" ]; then
		printf '\n===== %s =====\n' "$file"
		cat "$path"
	fi
done

printf '%s\n' '===== candidate Android v4 device packages ====='
grep -R -l -m1 'deviceinfo_header_version="4"' "$PMAPORTS/device" | head -10 || true
