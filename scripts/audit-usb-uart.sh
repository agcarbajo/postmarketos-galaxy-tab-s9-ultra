#!/bin/sh
set -eu

KERNEL=${KERNEL:-/root/pmos-gts9u/linux-mainline}
QCOM=$KERNEL/arch/arm64/boot/dts/qcom
Q5Q=$QCOM/sm8550-samsung-q5q.dts
MTP=$QCOM/sm8550-mtp.dts

printf '%s\n' '===== Q5Q USB/PMIC references ====='
grep -n -E 'pmic_glink|eusb2|usb_dp|usb_1|typec|pm8550b' "$Q5Q" || true

printf '%s\n' '===== MTP PMIC GLINK / Type-C sections ====='
grep -n -E '^&pmic_glink|pmic_glink_hs_in|pmic_glink_ss_in|^&pm8550b_eusb2_repeater' "$MTP" || true

printf '%s\n' '===== UART7 definition and wrapper ====='
grep -n -A35 -B12 'uart7: serial@' "$QCOM/sm8550.dtsi" || true
grep -n -A15 -B8 '^&qupv3_id_1' "$MTP" || true

printf '%s\n' '===== USB controller definition ====='
grep -n -A90 -B10 'usb_1: usb@' "$QCOM/sm8550.dtsi" || true

printf '%s\n' '===== Samsung Q5Q PMIC regulator labels used by USB/SD ====='
grep -n -E 'vreg_l(1e|3e|3f|5b|8b|9b|15b)' "$Q5Q" || true
