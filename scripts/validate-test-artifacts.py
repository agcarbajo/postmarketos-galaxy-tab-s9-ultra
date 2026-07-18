#!/usr/bin/env python3
"""Validate the distributable SM-X910 mainline v0 artifacts."""

from __future__ import annotations

import argparse
import hashlib
import stat
import zipfile
from pathlib import Path


IMAGES = {
    "boot.img": 100663296,
    "init_boot.img": 8388608,
    "vendor_boot.img": 100663296,
    "dtbo.img": 16777216,
    "vbmeta.img": 131072,
}
SD_NAME = "postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst"
ZIP_NAME = "postmarketos-edge-xfce-mainline-v0.3-sm-x910-twrp.zip"
METADATA = "mainline-v0.3-build-info.txt"
MANIFEST = "SHA256SUMS-mainline-v0.3.txt"


def digest_stream(stream) -> str:
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return digest_stream(stream)


def parse_manifest(data: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in data.splitlines():
        checksum, name = line.split(maxsplit=1)
        result[name] = checksum
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact_dir", type=Path)
    args = parser.parse_args()

    outer = parse_manifest((args.artifact_dir / MANIFEST).read_text())
    for name in (SD_NAME, ZIP_NAME, METADATA):
        actual = digest(args.artifact_dir / name)
        if outer.get(name) != actual:
            raise SystemExit(f"outer manifest mismatch: {name}")

    expected_members = set(IMAGES) | {
        "META-INF/com/google/android/update-binary",
        "META-INF/com/google/android/updater-script",
        "BUNDLE-LABEL",
        "SHA256SUMS",
    }
    with zipfile.ZipFile(args.artifact_dir / ZIP_NAME) as archive:
        if archive.testzip() is not None:
            raise SystemExit("ZIP CRC validation failed")
        if set(archive.namelist()) != expected_members:
            raise SystemExit("unexpected ZIP member set")
        if any(info.date_time != (1980, 1, 1, 0, 0, 0) for info in archive.infolist()):
            raise SystemExit("ZIP contains a non-reproducible timestamp")

        update = archive.getinfo("META-INF/com/google/android/update-binary")
        mode = (update.external_attr >> 16) & 0o7777
        if mode != 0o755 or not stat.S_ISREG(update.external_attr >> 16):
            raise SystemExit(f"update-binary mode is {mode:o}, expected 755")

        inner = parse_manifest(archive.read("SHA256SUMS").decode())
        for name, expected_size in IMAGES.items():
            info = archive.getinfo(name)
            if info.file_size != expected_size:
                raise SystemExit(f"{name}: unexpected size {info.file_size}")
            with archive.open(name) as stream:
                actual = digest_stream(stream)
            if inner.get(name) != actual:
                raise SystemExit(f"inner manifest mismatch: {name}")

    print("Artifact manifest, ZIP CRC, modes, sizes and inner hashes: OK")


if __name__ == "__main__":
    main()
