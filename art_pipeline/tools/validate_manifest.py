#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from pipeline_lib import (
    PipelineError,
    ensure_unique,
    load_manifests,
    relative_to_repo,
    validate_manifest,
    write_json,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate MortalPath art manifests.")
    parser.add_argument(
        "--manifest-root",
        type=Path,
        default=None,
        help="Override manifest directory.",
    )
    parser.add_argument(
        "--check-runtime",
        action="store_true",
        help="Require generated runtime files to exist.",
    )
    parser.add_argument(
        "--check-preview",
        action="store_true",
        help="Require generated preview files to exist and be non-empty.",
    )
    parser.add_argument("--report", type=Path, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest_root = args.manifest_root
        manifests = load_manifests(manifest_root) if manifest_root else load_manifests()
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    errors: list[str] = []
    asset_ids: list[str] = []
    runtime_paths: list[str] = []

    for path, manifest in manifests:
        errors.extend(
            validate_manifest(
                manifest,
                manifest_path=path,
                check_source=True,
                check_runtime=args.check_runtime,
                check_preview=args.check_preview,
            )
        )
        asset_id = manifest.get("id")
        runtime_path = manifest.get("runtime", {}).get("path")
        if isinstance(asset_id, str):
            asset_ids.append(asset_id)
        if isinstance(runtime_path, str):
            runtime_paths.append(runtime_path)

    errors.extend(ensure_unique(asset_ids, "asset id"))
    errors.extend(ensure_unique(runtime_paths, "runtime path"))

    summary = {
        "schema_version": 1,
        "manifest_count": len(manifests),
        "asset_ids": sorted(asset_ids),
        "check_runtime": args.check_runtime,
        "check_preview": args.check_preview,
        "errors": errors,
        "ok": not errors,
        "manifests": [relative_to_repo(path) for path, _ in manifests],
    }

    if args.report:
        write_json(args.report, summary)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"validated {len(manifests)} art manifest(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
