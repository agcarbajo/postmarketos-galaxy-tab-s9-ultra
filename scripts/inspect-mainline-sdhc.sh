#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
dtsi="$base/linux-mainline/arch/arm64/boot/dts/qcom/sm8550.dtsi"

echo '=== SDHC2 node ==='
sed -n '3570,3645p' "$dtsi"

echo '=== SDC2 pinctrl definitions/references ==='
grep -RInE 'sdc2|sdhc_2' \
    "$base/linux-mainline/arch/arm64/boot/dts/qcom" | head -300

echo '=== other SM8550 boards enabling SDHC2 ==='
for board in "$base"/linux-mainline/arch/arm64/boot/dts/qcom/sm8550-*.dts; do
    if grep -q '&sdhc_2' "$board"; then
        echo "--- $board"
        grep -n -A35 -B5 '&sdhc_2' "$board"
    fi
done
