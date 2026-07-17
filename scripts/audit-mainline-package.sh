#!/bin/bash
set -euo pipefail

base="${PMOS_WORKDIR:-/root/pmos-gts9u}"
p="$base/pmaports"

echo '=== linux-postmarketos-mainline ==='
sed -n '1,240p' "$p/device/main/linux-postmarketos-mainline/APKBUILD"

echo '=== SM8550 occurrences with context ==='
grep -RInE 'SM8550|sm8550|kalama' \
    "$p/device" "$p/main" "$p/community" 2>/dev/null | head -500 || true

echo '=== generic aarch64 config: Qualcomm essentials ==='
grep -E '^(CONFIG_(ARCH_QCOM|ARM64|PCI|PCIE_QCOM|SCSI_UFS_QCOM|MMC|MMC_SDHCI|MMC_SDHCI_MSM|SERIAL_MSM|SERIAL_QCOM_GENI|DRM|DRM_MSM|QCOM_SCM|QCOM_RPMH|QCOM_COMMAND_DB|QCOM_AOSS_QMP|QCOM_Q6V5_PAS|QCOM_WCNSS_PIL|ATH12K|TYPEC|PHY_QCOM)=)' \
    "$p/device/main/linux-postmarketos-mainline/config-mainline.aarch64" || true

echo '=== nearby recent Qualcomm devices ==='
for d in \
    "$p/device/testing/device-ayaneo-pocket-s2" \
    "$p/device/testing/device-hp-elitebook-ultra-g1q" \
    "$p/device/testing/device-postmarketos-trailblazer"; do
    [ -d "$d" ] || continue
    echo "--- $d"
    find "$d" -maxdepth 2 -type f -print -exec sed -n '1,180p' {} \;
done
