#!/bin/bash
set -euo pipefail

project="${PROJECT_MNT:-/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS}"
artifact_dir="$project/artifacts"
sd_name='postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst'
metadata='mainline-v0.2-build-info.txt'

python3 "$project/scripts/validate-test-artifacts.py" "$artifact_dir"
zstd -t "$artifact_dir/$sd_name"

expected=$(sed -n 's/^rootfs_uncompressed_sha256=//p' "$artifact_dir/$metadata")
actual=$(zstd -dc "$artifact_dir/$sd_name" | sha256sum | cut -d' ' -f1)
test -n "$expected"
test "$actual" = "$expected"

echo "Decompressed SD image SHA-256: $actual"
echo 'Compressed SD image stream: OK'
