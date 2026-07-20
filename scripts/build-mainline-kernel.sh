#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
kernel_src="${KERNEL_SRC:-$base/linux-mainline}"
kernel_tree="${KERNEL_WORKTREE:-$base/build/linux-src-gts9uwifi}"
build_dir="${KERNEL_BUILD_DIR:-$base/build/linux-gts9uwifi}"
out_dir="${KERNEL_OUT_DIR:-$base/out/kernel-gts9uwifi}"
project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
package="$project/pmaports/device/testing/linux-samsung-gts9uwifi-mainline"

test -d "$kernel_src/.git"
test -f "$package/sm8550-samsung-gts9uwifi.dts"

mkdir -p "$(dirname "$kernel_tree")" "$build_dir" "$out_dir"
cd "$base"

if [ ! -e "$kernel_tree/.git" ]; then
	git -C "$kernel_src" worktree add --detach "$kernel_tree" HEAD
fi

# Keep the pinned upstream checkout pristine.  The board DTS is supplied by
# this project and the build output lives in a separate O= directory.
install -m 0644 "$package/sm8550-samsung-gts9uwifi.dts" \
	"$build_dir/sm8550-samsung-gts9uwifi.dts"

cp "$package/sm8550-samsung-gts9uwifi.dts" \
	"$kernel_tree/arch/arm64/boot/dts/qcom/sm8550-samsung-gts9uwifi.dts"

if ! grep -q 'sm8550-samsung-gts9uwifi.dtb' \
	"$kernel_tree/arch/arm64/boot/dts/qcom/Makefile"; then
	patch -d "$kernel_tree" -p1 < "$package/add-gts9uwifi-dtb.patch"
fi
if [ ! -f "$kernel_tree/drivers/soc/qcom/samsung-gts9uwifi-sec-log.c" ]; then
	patch -d "$kernel_tree" -p1 < "$package/add-samsung-sec-log-console.patch"
fi
if ! grep -q 'previous_index, index' \
	"$kernel_tree/drivers/soc/qcom/samsung-gts9uwifi-sec-log.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/keep-sec-log-previous-index-current.patch"
fi
if ! grep -q 'probing %s with driver %s' "$kernel_tree/drivers/base/dd.c"; then
	patch -d "$kernel_tree" -p1 < "$package/log-probe-entry-before-call.patch"
fi
if ! grep -q 'Match Samsung SM8550 sequencing' \
	"$kernel_tree/drivers/phy/phy-snps-eusb2.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/match-samsung-sm8550-eusb2-phy-init.patch"
fi
if ! grep -q 'forcing 16-byte Samsung events for firmware PID 6936' \
	"$kernel_tree/drivers/input/touchscreen/goodix_berlin_core.c"; then
	if grep -q 'GOODIX_BERLIN_SAMSUNG_EVENT_ID_MASK' \
		"$kernel_tree/drivers/input/touchscreen/goodix_berlin_core.c"; then
		patch -d "$kernel_tree" -p1 \
			< "$package/upgrade-partial-goodix-samsung-events.patch"
	else
		patch -d "$kernel_tree" -p1 \
			< "$package/support-samsung-goodix-16-byte-events.patch"
	fi
fi
if ! grep -q 'PTN3222_MAX_INIT_CELLS' \
	"$kernel_tree/drivers/phy/phy-nxp-ptn3222.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/configure-nxp-ptn3222-from-dt.patch"
fi
if ! grep -q 'delayed link state: reset' \
	"$kernel_tree/drivers/phy/phy-nxp-ptn3222.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/diagnose-sm8550-eusb2-link.patch"
fi
if ! grep -q 'SM-X910 diag pullup request' \
	"$kernel_tree/drivers/usb/dwc3/gadget.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/diagnose-dwc3-ep0-enumeration.patch"
fi
if grep -q 'SM-X910 diag event raw' \
	"$kernel_tree/drivers/usb/dwc3/gadget.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/remove-dwc3-hotpath-diagnostics.patch"
fi
if ! grep -q 'SM-X910 WCN diag: power sequencer registered' \
	"$kernel_tree/drivers/power/sequencing/pwrseq-qcom-wcn.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/diagnose-wcn7850-power-sequence.patch"
fi
if ! grep -q '^DTC_FLAGS_sm8550-samsung-gts9uwifi := -@$' \
	"$kernel_tree/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i '/sm8550-samsung-gts9uwifi\.dtb/a DTC_FLAGS_sm8550-samsung-gts9uwifi := -@' \
		"$kernel_tree/arch/arm64/boot/dts/qcom/Makefile"
fi

cp "$base/pmaports/device/main/linux-postmarketos-mainline/config-mainline.aarch64" \
	"$build_dir/.config"

while IFS= read -r setting; do
	case "$setting" in
		CONFIG_*=y)
			symbol=${setting%%=*}
			"$kernel_tree/scripts/config" --file "$build_dir/.config" \
				--enable "${symbol#CONFIG_}"
			;;
		'# CONFIG_'*' is not set')
			symbol=${setting#\# CONFIG_}
			symbol=${symbol% is not set}
			"$kernel_tree/scripts/config" --file "$build_dir/.config" \
				--disable "$symbol"
			;;
	esac
done < "$package/config-gts9uwifi.fragment"

make -C "$kernel_tree" O="$build_dir" ARCH=arm64 LLVM=1 olddefconfig
make -C "$kernel_tree" O="$build_dir" ARCH=arm64 LLVM=1 -j"$(nproc)" \
	Image.gz qcom/sm8550-samsung-gts9uwifi.dtb

install -m 0644 "$build_dir/arch/arm64/boot/Image.gz" "$out_dir/Image.gz"
install -m 0644 \
	"$build_dir/arch/arm64/boot/dts/qcom/sm8550-samsung-gts9uwifi.dtb" \
	"$out_dir/sm8550-samsung-gts9uwifi.dtb"
install -m 0644 "$build_dir/.config" "$out_dir/config"

sha256sum "$out_dir/Image.gz" \
	"$out_dir/sm8550-samsung-gts9uwifi.dtb" \
	"$out_dir/config" > "$out_dir/SHA256SUMS"

cat "$out_dir/SHA256SUMS"
