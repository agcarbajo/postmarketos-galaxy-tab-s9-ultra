#!/bin/sh
set -eu

CONFIG=${CONFIG:-/root/pmos-gts9u/pmaports/device/main/linux-postmarketos-mainline/config-mainline.aarch64}

for symbol in \
	ARCH_QCOM MMC_SDHCI_MSM MMC_BLOCK EXT4_FS DEVTMPFS BLK_DEV_INITRD \
	USB_CONFIGFS USB_CONFIGFS_NCM USB_CONFIGFS_ECM USB_DWC3 USB_DWC3_QCOM \
	PHY_QCOM_QMP_COMBO PHY_QCOM_SNPS_EUSB2 SYSFB_SIMPLEFB DRM_SIMPLEDRM \
	FB_SIMPLE DRM_MSM SERIAL_QCOM_GENI SCSI_UFS_QCOM EFI_PARTITION; do
	grep -E "^(CONFIG_${symbol}=|# CONFIG_${symbol} is not set)" "$CONFIG" || \
		printf 'CONFIG_%s is absent\n' "$symbol"
done
