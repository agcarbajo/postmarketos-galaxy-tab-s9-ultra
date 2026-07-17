#!/bin/sh
set -eu

KERNEL=${KERNEL:-/root/pmos-gts9u/linux-mainline}

show_context() {
	file=$1
	pattern=$2
	before=${3:-12}
	after=${4:-35}
	line=$(grep -n -m1 "$pattern" "$file" | cut -d: -f1)
	start=$((line - before))
	[ "$start" -gt 0 ] || start=1
	end=$((line + after))
	printf '\n===== %s :: %s =====\n' "$file" "$pattern"
	sed -n "${start},${end}p" "$file"
}

MTP=$KERNEL/arch/arm64/boot/dts/qcom/sm8550-mtp.dts
Q5Q=$KERNEL/arch/arm64/boot/dts/qcom/sm8550-samsung-q5q.dts
QRD=$KERNEL/arch/arm64/boot/dts/qcom/sm8550-qrd.dts
HDK=$KERNEL/arch/arm64/boot/dts/qcom/sm8550-hdk.dts

show_context "$MTP" 'sdc2_card_det_n' 10 25
show_context "$MTP" '^&sdhc_2' 8 35
show_context "$MTP" '^&usb_1' 8 45
show_context "$MTP" '^&uart7' 8 25 || true
show_context "$Q5Q" 'framebuffer:' 12 28
show_context "$Q5Q" '^&ufs_mem_hc' 8 35
show_context "$Q5Q" '^&uart7' 8 25 || true
show_context "$QRD" '^&usb_1' 8 45
show_context "$HDK" '^&usb_1' 8 45
