# Firmware source

These proprietary files are staged from the SM-X910 X910XXS5CYG1 stock
`vendor.img` by `scripts/stage-stock-wifi-firmware.sh`; they are intentionally
not committed. The package renames Qualcomm's Android Kiwi v2 files to the
filenames requested by mainline ath12k WCN7850/hw2.0:

- `amss20.bin` -> `amss.bin`
- `phy_ucode20.elf` -> `m3.bin`
- `bdwlan.elf` -> `board.bin`
- `regdb.bin` -> `regdb.bin`
