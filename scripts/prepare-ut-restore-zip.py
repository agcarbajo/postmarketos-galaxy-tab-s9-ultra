#!/usr/bin/env python3
"""Create a boot-only Ubuntu Touch restore ZIP without copying super."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import zipfile
from pathlib import Path


EXPECTED = {
    "boot.img": 100663296,
    "init_boot.img": 8388608,
    "vendor_boot.img": 100663296,
    "dtbo.img": 16777216,
    "vbmeta.img": 65536,
}


def hash_stream(stream, pad_to: int | None = None) -> str:
    result = hashlib.sha256()
    size = 0
    for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
        result.update(block)
        size += len(block)
    if pad_to is not None:
        if size > pad_to:
            raise ValueError(f"source is {size} bytes, larger than {pad_to}")
        zero = b"\0" * (1024 * 1024)
        while size < pad_to:
            block = zero[: min(len(zero), pad_to - size)]
            result.update(block)
            size += len(block)
    return result.hexdigest()


def zip_info(name: str, mode: int = 0o644) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (stat.S_IFREG | mode) << 16
    return info


def copy_member(
    source: zipfile.ZipFile,
    target: zipfile.ZipFile,
    name: str,
    pad_to: int,
) -> None:
    with source.open(name) as src, target.open(zip_info(name), "w", force_zip64=True) as dst:
        size = 0
        for block in iter(lambda: src.read(8 * 1024 * 1024), b""):
            dst.write(block)
            size += len(block)
        zero = b"\0" * (1024 * 1024)
        while size < pad_to:
            block = zero[: min(len(zero), pad_to - size)]
            dst.write(block)
            size += len(block)


def copy_path(target: zipfile.ZipFile, source: Path, name: str, mode: int = 0o644) -> None:
    with source.open("rb") as src, target.open(
        zip_info(name, mode), "w", force_zip64=True
    ) as dst:
        shutil.copyfileobj(src, dst, length=8 * 1024 * 1024)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ut-zip", required=True, type=Path)
    parser.add_argument("--stock-dtbo", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    update_binary = args.project / "configs/twrp/mainline-update-binary"
    updater_script = args.project / "configs/twrp/updater-script"
    for path in (args.ut_zip, args.stock_dtbo, update_binary, updater_script):
        if not path.is_file():
            raise SystemExit(f"missing {path}")
    if args.stock_dtbo.stat().st_size != EXPECTED["dtbo.img"]:
        raise SystemExit("stock dtbo size mismatch")

    sums: dict[str, str] = {}
    with zipfile.ZipFile(args.ut_zip, "r") as source:
        for name in ("boot.img", "init_boot.img", "vendor_boot.img", "vbmeta.img"):
            size = source.getinfo(name).file_size
            if size > EXPECTED[name]:
                raise SystemExit(f"{name}: maximum {EXPECTED[name]}, got {size}")
            with source.open(name) as stream:
                sums[name] = hash_stream(stream, EXPECTED[name])
        with args.stock_dtbo.open("rb") as stream:
            sums["dtbo.img"] = hash_stream(stream)

        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(
            args.output,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=6,
            allowZip64=True,
        ) as target:
            for name in ("boot.img", "init_boot.img", "vendor_boot.img", "vbmeta.img"):
                copy_member(source, target, name, EXPECTED[name])
            copy_path(target, args.stock_dtbo, "dtbo.img")
            copy_path(
                target,
                update_binary,
                "META-INF/com/google/android/update-binary",
                0o755,
            )
            copy_path(
                target,
                updater_script,
                "META-INF/com/google/android/updater-script",
            )
            target.writestr(
                zip_info("BUNDLE-LABEL"),
                "Restore Ubuntu Touch v8 boot chain for SM-X910\n",
            )
            target.writestr(
                zip_info("SHA256SUMS"),
                "".join(f"{sums[name]}  {name}\n" for name in EXPECTED),
            )

    with args.output.open("rb") as stream:
        print(f"{hash_stream(stream)}  {args.output.name}")


if __name__ == "__main__":
    main()
