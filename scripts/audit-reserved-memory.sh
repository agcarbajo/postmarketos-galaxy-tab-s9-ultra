#!/bin/sh
set -eu

KERNEL=${KERNEL:-/root/pmos-gts9u/linux-mainline}
QCOM=$KERNEL/arch/arm64/boot/dts/qcom

printf '%s\n' '===== sm8550.dtsi reserved-memory labels and ranges ====='
sed -n '/reserved-memory {/,/^\t};/p' "$QCOM/sm8550.dtsi" | \
	grep -E '^\t\t[^[:space:]].*\{|reg =|size =|no-map|reusable' || true

printf '%s\n' '===== q5q delete/replacement reserved memory ====='
grep -n -E '^/delete-node/|reserved-memory|_mem:|splash.region' "$QCOM/sm8550-samsung-q5q.dts" || true
