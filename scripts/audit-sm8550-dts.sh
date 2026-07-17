#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
q="$base/linux-mainline/arch/arm64/boot/dts/qcom"

echo '=== file sizes ==='
wc -l "$q"/sm8550*.dts "$q"/sm8550.dtsi

echo '=== Samsung q5q DTS ==='
sed -n '1,1200p' "$q/sm8550-samsung-q5q.dts"

echo '=== SM8550 storage/display/GPU nodes ==='
grep -nE '(^[[:space:]]*[a-zA-Z0-9_]+:.*(mmc|sdhc|ufs|gpu|display|mdss|dsi|uart|serial)|compatible = .*sdhci|mmc@|ufs@|gpu@|display-subsystem|dsi@)' \
    "$q/sm8550.dtsi" | head -300 || true

echo '=== SM8550 DT Makefile entries ==='
grep -n 'sm8550' "$q/Makefile"

echo '=== panel compatibles used by q5q ==='
grep -nE 'panel|dsi|display|compatible' "$q/sm8550-samsung-q5q.dts" | head -300
