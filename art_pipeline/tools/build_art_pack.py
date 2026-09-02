#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
import zipfile
from pathlib import Path

from pipeline_lib import PipelineError, load_json, sha256_file

ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a deterministic MortalPath Art Pack.")
    parser.add_argument("--runtime-root", type=Path, default=Path("art_pipeline/runtime"))
    parser.add_argument("--manifest-root", type=Path, default=Path("art_pipeline/manifests"))
    parser.add_argument(
        "--catalog", type=Path, default=Path("art_pipeline/reports/asset-catalog.json")
    )
    parser.add_argument("--godot-report", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=Path("art_pipeline/dist"))
    parser.add_argument("--version", default=None)
    return parser.parse_args()


def add_file(archive: zipfile.ZipFile, path: Path, arcname: str) -> None:
    info = zipfile.ZipInfo(arcname.replace("\\", "/"), ZIP_TIMESTAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    archive.writestr(info, path.read_bytes())


def main() -> int:
    args = parse_args()
    try:
        catalog = load_json(args.catalog)
        version = args.version or os.environ.get("GITHUB_REF_NAME")
        if not version or not version.startswith("artpack-v"):
            sha = os.environ.get("GITHUB_SHA", "local")[:12]
            version = f"snapshot-{sha}"

        runtime_files = sorted(
            path for path in args.runtime_root.rglob("*") if path.is_file() and path.name != ".gitkeep"
        )
        manifest_files = sorted(path for path in args.manifest_root.rglob("*.json") if path.is_file())
        if not runtime_files:
            raise PipelineError(f"no runtime files found under {args.runtime_root}")
        if catalog.get("asset_count") != len(runtime_files):
            raise PipelineError(
                "catalog asset_count does not match runtime file count: "
                f"{catalog.get('asset_count')} != {len(runtime_files)}"
            )

        args.output_dir.mkdir(parents=True, exist_ok=True)
        archive_path = args.output_dir / f"mortalpath-artpack-{version}.zip"
        with zipfile.ZipFile(archive_path, "w") as archive:
            for path in runtime_files:
                relative = path.relative_to(args.runtime_root).as_posix()
                add_file(archive, path, f"runtime/{relative}")
            for path in manifest_files:
                relative = path.relative_to(args.manifest_root).as_posix()
                add_file(archive, path, f"manifests/{relative}")
            add_file(archive, args.catalog, "asset-catalog.json")
            if args.godot_report and args.godot_report.is_file():
                add_file(archive, args.godot_report, "reports/godot-smoke.json")

        checksum = sha256_file(archive_path)
        checksum_path = args.output_dir / "checksums.txt"
        checksum_path.write_text(f"{checksum}  {archive_path.name}\n", encoding="utf-8")
        metadata_path = args.output_dir / "art-pack.json"
        metadata_path.write_text(
            "{\n"
            f'  "version": "{version}",\n'
            f'  "source_commit": "{catalog.get("source_commit", "unknown")}",\n'
            f'  "asset_count": {catalog.get("asset_count", 0)},\n'
            f'  "archive": "{archive_path.name}",\n'
            f'  "sha256": "{checksum}"\n'
            "}\n",
            encoding="utf-8",
        )
    except (PipelineError, KeyError, OSError, zipfile.BadZipFile) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"built {archive_path} ({archive_path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
