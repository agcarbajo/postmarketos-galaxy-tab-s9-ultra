#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
pmaports="$base/pmaports"

echo '=== pmaports revision ==='
git -C "$pmaports" rev-parse HEAD

echo '=== SM8550/Kalama references ==='
grep -RIlE 'SM8550|sm8550|kalama' \
    "$pmaports/device" "$pmaports/main" "$pmaports/community" \
    2>/dev/null | sort | head -300 || true

echo '=== Qualcomm generic/mainline kernels ==='
find "$pmaports" -type f -name APKBUILD -print0 | \
    xargs -0 grep -IlE 'linux-postmarketos-(mainline|qcom)|linux-edge|sm8550' \
    2>/dev/null | sort | head -200 || true

echo '=== likely device directories ==='
find "$pmaports/device" -maxdepth 3 -type d \
    \( -iname '*sm8550*' -o -iname '*kalama*' -o -iname '*oneplus*11*' \
       -o -iname '*xiaomi*13*' -o -iname '*samsung*dm*' \) \
    -print 2>/dev/null | sort || true
