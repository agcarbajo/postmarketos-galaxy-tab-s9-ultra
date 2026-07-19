#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
vendor_image="${STOCK_VENDOR_IMAGE:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/port/firmware-extracted/super-parts/vendor.img}"
extracted="${STOCK_VENDOR_EXTRACTED:-$base/stock-vendor-extracted}"
target="$project/pmaports/device/testing/firmware-samsung-gts9uwifi"

if [ ! -f "$extracted/firmware/kiwi/amss20.bin" ]; then
	command -v fsck.erofs >/dev/null || {
		echo "fsck.erofs is required (Ubuntu package: erofs-utils)" >&2
		exit 2
	}
	test -f "$vendor_image"
	rm -rf -- "$extracted"
	mkdir -p "$extracted"
	fsck.erofs --extract="$extracted" "$vendor_image"
fi

mkdir -p "$target"
for file in amss20.bin phy_ucode20.elf bdwlan.elf regdb.bin; do
	install -m 0644 "$extracted/firmware/kiwi/$file" "$target/$file"
done

cd "$target"
sha256sum -c <<'EOF'
4529e42c3e6798db7060e16c646f6f81ecf463e44552115c6a91656cf4bf7915  amss20.bin
67396ffa89db6a1378c0d1d41362d33831dd6163d96849a4bcbd865b7cecda19  phy_ucode20.elf
9cade90ae22d7df1c44850bf55c6231bf99b4303f406eca9775d920bb6d4313e  bdwlan.elf
75cc107536d3bd03fa2e29f369a4e6d997d2cf090c50620424a9ab1a749c7546  regdb.bin
EOF
