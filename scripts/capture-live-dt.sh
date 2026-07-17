#!/bin/bash
set -euo pipefail

out=PostmarketOS/work
tree="$out/live-device-tree"
archive="$out/live-device-tree.tar"

mkdir -p "$tree"
bash port/scripts/ssh.sh \
    'tar -C /sys/firmware/devicetree/base -cf - .' > "$archive"
tar -xf "$archive" -C "$tree"

if command -v dtc >/dev/null 2>&1; then
    dtc -I fs -O dts -o "$out/live-device-tree.dts" "$tree"
    echo "generated $out/live-device-tree.dts"
else
    echo 'dtc is not installed; raw tree captured only'
fi

echo '=== useful live nodes/properties ==='
find "$tree" -maxdepth 4 \
    \( -iname '*splash*' -o -iname '*framebuffer*' -o -iname '*sdhc*' \
       -o -iname '*mmc*' -o -iname '*uart*' -o -iname '*serial*' \) \
    -print | sort | head -300
