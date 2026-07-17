#!/usr/bin/env python3
"""Package an already validated five-image bundle as a manual TWRP ZIP."""

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
    "vbmeta.img": 65536,
}


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def add_executable(zf: zipfile.ZipFile, source: Path, arcname: str) -> None:
    info = zipfile.ZipInfo.from_file(source, arcname)
    info.external_attr = (stat.S_IFREG | 0o755) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    with source.open("rb") as stream:
        zf.writestr(info, stream.read(), compresslevel=9)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    for name, expected_size in IMAGES.items():
        path = args.bundle / name
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        actual_size = path.stat().st_size
        if actual_size != expected_size:
            raise SystemExit(f"{name}: expected {expected_size}, got {actual_size}")

    update_binary = args.project / "configs/twrp/mainline-update-binary"
    updater_script = args.project / "configs/twrp/updater-script"
    if not update_binary.is_file() or not updater_script.is_file():
        raise SystemExit("TWRP installer sources are missing")

    manifest = "".join(
        f"{digest(args.bundle / name)}  {name}\n" for name in IMAGES
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
    ) as zf:
        for name in IMAGES:
            zf.write(args.bundle / name, name)
        add_executable(
            zf,
            update_binary,
            "META-INF/com/google/android/update-binary",
        )
        zf.write(
            updater_script,
            "META-INF/com/google/android/updater-script",
        )
        zf.writestr(
            "BUNDLE-LABEL",
            "postmarketOS mainline v0 for SM-X910 (rootfs on microSD)\n",
        )
        zf.writestr("SHA256SUMS", manifest)

    print(f"{digest(args.output)}  {args.output.name}")


if __name__ == "__main__":
    main()
