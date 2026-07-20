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
if ! grep -q 'WLAN_EN cold reset value' \
	"$kernel_tree/drivers/power/sequencing/pwrseq-qcom-wcn.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/cold-reset-wcn7850-before-pcie-probe.patch"
fi
if ! grep -q 'rail %s enabled=%d voltage=%d uV' \
	"$kernel_tree/drivers/power/sequencing/pwrseq-qcom-wcn.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/diagnose-wcn7850-pcie-link.patch"
fi
if ! grep -q 'default y if ARCH_QCOM' \
	"$kernel_tree/drivers/pci/pwrctrl/Kconfig"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/build-wcn-pcie-providers-in.patch"
fi
if ! grep -q 'SM-X910 WCN diag: AOP pdc' \
	"$kernel_tree/drivers/power/sequencing/pwrseq-qcom-wcn.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/program-wcn7850-wlan-pdc-aop.patch"
fi
if ! grep -q 'SW_CTRL wlan=' \
	"$kernel_tree/drivers/power/sequencing/pwrseq-qcom-wcn.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/read-wcn7850-sw-ctrl-after-enable.patch"
fi
if ! grep -q 'pipe mux unpark' \
	"$kernel_tree/drivers/phy/qualcomm/phy-qcom-qmp-pcie.c"; then
	patch -d "$kernel_tree" -p1 \
		< "$package/unpark-pcie0-pipe-mux.patch"
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
		CONFIG_*=m)
			symbol=${setting%%=*}
			"$kernel_tree/scripts/config" --file "$build_dir/.config" \
				--module "${symbol#CONFIG_}"
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

if [ "${BUILD_WIFI_MODULES:-0}" = 1 ]; then
	modules_root="$out_dir/modules-root"
	case "$modules_root" in
		"$base"/out/*/modules-root) rm -rf -- "$modules_root" ;;
		*) echo "unsafe modules output path: $modules_root" >&2; exit 1 ;;
	esac

	# Building Image produces the complete built-in export table as
	# vmlinux.symvers.  An isolated in-tree M= build expects the same table
	# under the external-module name before it can resolve core symbols.
	cp "$build_dir/vmlinux.symvers" "$build_dir/Module.symvers"
	make -C "$kernel_tree" O="$build_dir" ARCH=arm64 LLVM=1 -j"$(nproc)" \
		M=drivers/net/wireless/ath/ath12k modules
	make -C "$kernel_tree" O="$build_dir" ARCH=arm64 LLVM=1 \
		M=drivers/net/wireless/ath/ath12k \
		INSTALL_MOD_PATH="$modules_root" INSTALL_MOD_STRIP=1 \
		DEPMOD=true modules_install

	release=$(make -s -C "$kernel_tree" O="$build_dir" ARCH=arm64 LLVM=1 kernelrelease)
	release_dir="$modules_root/lib/modules/$release"
	install -m 0644 "$build_dir/modules.builtin" \
		"$release_dir/modules.builtin"
	install -m 0644 "$build_dir/modules.builtin.modinfo" \
		"$release_dir/modules.builtin.modinfo"
	find "$release_dir/updates" -type f -name '*.ko*' -printf '%P\n' \
		| sed 's#^#updates/#' | sort > "$release_dir/modules.order"
	depmod -b "$modules_root" "$release"
	mkdir -p "$modules_root/usr/lib"
	mv "$modules_root/lib/modules" "$modules_root/usr/lib/modules"
	rmdir "$modules_root/lib"
	printf '%s\n' "$release" > "$out_dir/kernel.release"
fi

install -m 0644 "$build_dir/arch/arm64/boot/Image.gz" "$out_dir/Image.gz"
install -m 0644 \
	"$build_dir/arch/arm64/boot/dts/qcom/sm8550-samsung-gts9uwifi.dtb" \
	"$out_dir/sm8550-samsung-gts9uwifi.dtb"
install -m 0644 "$build_dir/.config" "$out_dir/config"

sha256sum "$out_dir/Image.gz" \
	"$out_dir/sm8550-samsung-gts9uwifi.dtb" \
	"$out_dir/config" > "$out_dir/SHA256SUMS"

cat "$out_dir/SHA256SUMS"
