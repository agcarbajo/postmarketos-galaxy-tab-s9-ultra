#!/bin/sh
set -eu

project=${PROJECT_ROOT:-"/mnt/c/Users/agcar/Desktop/Aplicaciones/Custom Roms/GALAXY TAB S9 ULTRA/Ubuntu Touch/PostmarketOS"}
target="$project/pmaports/device/testing/firmware-samsung-gts9uwifi"
output="$target/Samsung-Galaxy-Tab-S9-Ultra-tplg.bin"
repo=https://gitlab.com/kernel-firmware/linux-firmware.git
commit=18cf97993f06c0a28d88cee30b7b646807642acd
expected=d41185a9c905571f7c234ff8caf6e6d24870161a5e6ef0316bb997bfd26cee871a483287308a0af177d39a81b256def4cfa99b0f2594b364ba7ef1104dd9caca

verify()
{
	[ -f "$output" ] || return 1
	actual=$(sha512sum "$output" | awk '{print $1}')
	[ "$actual" = "$expected" ]
}

if verify; then
	echo "Pinned SM8550 AudioReach topology already verified."
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fetch only the pinned linux-firmware tree and materialize the SM8550
# directory. The binary is the BSD-3-Clause linux-msm/audioreach-topology
# v1.0.4 output; pinning both commit and hash makes the staging reproducible.
git -C "$tmp" init -q
git -C "$tmp" remote add origin "$repo"
git -C "$tmp" -c protocol.version=2 fetch -q --depth=1 --filter=blob:none origin "$commit"
git -C "$tmp" sparse-checkout init --cone
git -C "$tmp" sparse-checkout set qcom/sm8550
git -C "$tmp" checkout -q --detach FETCH_HEAD

install -m 0644 "$tmp/qcom/sm8550/SM8550-HDK-tplg.bin" "$output"
verify || {
	echo "AudioReach topology SHA-512 mismatch" >&2
	exit 1
}

echo "Staged and verified the pinned SM8550 AudioReach topology."
