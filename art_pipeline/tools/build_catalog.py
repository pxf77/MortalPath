#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from pipeline_lib import PipelineError, load_json, load_manifests, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build runtime asset catalog.")
    parser.add_argument("--manifest-root", type=Path, default=None)
    parser.add_argument("--report-root", type=Path, default=Path("art_pipeline/reports/assets"))
    parser.add_argument(
        "--output", type=Path, default=Path("art_pipeline/reports/asset-catalog.json")
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifests = load_manifests(args.manifest_root) if args.manifest_root else load_manifests()
        assets = []
        for _, manifest in manifests:
            asset_id = manifest["id"]
            report_path = args.report_root / f"{asset_id}.json"
            report = load_json(report_path)
            if not report.get("ok"):
                raise PipelineError(f"asset report is not successful: {report_path}")
            assets.append(
                {
                    "id": asset_id,
                    "kind": manifest["kind"],
                    "milestone": manifest["milestone"],
                    "runtime_path": manifest["runtime"]["path"],
                    "preview_path": manifest["preview"]["path"],
                    "sha256": report["sha256"],
                    "file_size_bytes": report["file_size_bytes"],
                    "stats": report["stats"],
                    "art": manifest["art"],
                    "provenance": manifest["provenance"],
                }
            )

        catalog = {
            "schema_version": 1,
            "source_commit": os.environ.get("GITHUB_SHA", "local"),
            "asset_count": len(assets),
            "assets": sorted(assets, key=lambda item: item["id"]),
        }
        write_json(args.output, catalog)
    except (PipelineError, KeyError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"catalog contains {len(assets)} asset(s): {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
