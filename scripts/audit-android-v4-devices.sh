#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
p="$base/pmaports"

echo '=== devices declaring Android boot header v4/init_boot/vendor_boot ==='
grep -RIlE 'deviceinfo_bootimg_header_version="?4|deviceinfo_has_init_boot|init_boot|vendor_boot' \
    "$p/device" 2>/dev/null | sort | head -300 || true

echo '=== matching deviceinfo contents ==='
while IFS= read -r file; do
    echo "--- $file"
    grep -E '^(deviceinfo_(name|manufacturer|codename|arch|dtb|kernel|boot|generate|flash|rootfs|partition|header|has_init|prebuilt|uses|avb).*)' "$file" || true
done < <(grep -RIlE 'deviceinfo_bootimg_header_version="?4|deviceinfo_has_init_boot|init_boot|vendor_boot' \
    "$p/device" 2>/dev/null | sort | head -80)
