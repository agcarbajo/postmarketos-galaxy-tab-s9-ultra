#!/usr/bin/env python3
"""Validate the boot-only Ubuntu Touch rollback ZIP."""

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


def digest_stream(stream) -> str:
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("zip", type=Path)
    args = parser.parse_args()

    expected_members = set(IMAGES) | {
        "META-INF/com/google/android/update-binary",
        "META-INF/com/google/android/updater-script",
        "BUNDLE-LABEL",
        "SHA256SUMS",
    }
    with zipfile.ZipFile(args.zip) as archive:
        broken = archive.testzip()
        if broken is not None:
            raise SystemExit(f"ZIP CRC validation failed at {broken}")
        if set(archive.namelist()) != expected_members:
            raise SystemExit("unexpected ZIP member set")
        if any(info.date_time != (1980, 1, 1, 0, 0, 0) for info in archive.infolist()):
            raise SystemExit("ZIP contains a non-reproducible timestamp")

        update = archive.getinfo("META-INF/com/google/android/update-binary")
        mode = (update.external_attr >> 16) & 0o7777
        if mode != 0o755 or not stat.S_ISREG(update.external_attr >> 16):
            raise SystemExit(f"update-binary mode is {mode:o}, expected 755")

        manifest = {}
        for line in archive.read("SHA256SUMS").decode().splitlines():
            checksum, name = line.split(maxsplit=1)
            manifest[name] = checksum
        for name, expected_size in IMAGES.items():
            info = archive.getinfo(name)
            if info.file_size != expected_size:
                raise SystemExit(f"{name}: unexpected size {info.file_size}")
            with archive.open(name) as stream:
                actual = digest_stream(stream)
            if manifest.get(name) != actual:
                raise SystemExit(f"inner manifest mismatch: {name}")

    with args.zip.open("rb") as stream:
        outer = digest_stream(stream)
    print(f"Rollback ZIP CRC, modes, sizes and hashes: OK\n{outer}  {args.zip.name}")


if __name__ == "__main__":
    main()
