#!/usr/bin/env python3
"""Validate 30/60/120 FPS flying-sword trail reports as one regression gate."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

EXPECTED_FPS = {30, 60, 120}
MAX_WIDTH_ERROR_RATIO = 0.06
MAX_CROSS_FPS_WIDTH_SPREAD_RATIO = 0.06
MAX_OPACITY_SPREAD = 1e-4
MAX_DELTA_ERROR_RATIO = 0.02


def load_report(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"report must be a JSON object: {path}")
    return value


def finite_number(value: Any, field: str, path: Path) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{path}: {field} must be numeric")
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{path}: {field} must be finite")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    errors: list[str] = []
    by_fps: dict[int, dict[str, Any]] = {}
    path_by_fps: dict[int, Path] = {}
    for path in args.reports:
        try:
            report = load_report(path)
            fps = int(report.get("requested_fixed_fps", 0))
            if fps in by_fps:
                errors.append(f"duplicate fixed-FPS report: {fps}")
                continue
            by_fps[fps] = report
            path_by_fps[fps] = path
            if not report.get("ok"):
                errors.append(f"{path}: runner reported failures: {report.get('failures')}")
            if not report.get("shader_material"):
                errors.append(f"{path}: trail material is not ShaderMaterial")
            if not report.get("shader_has_core_edge_channels"):
                errors.append(f"{path}: shader core/edge contract is missing")
            delta_error = finite_number(report.get("delta_error_ratio"), "delta_error_ratio", path)
            if delta_error > MAX_DELTA_ERROR_RATIO:
                errors.append(
                    f"{path}: fixed-FPS delta error {delta_error:.2%} exceeds "
                    f"{MAX_DELTA_ERROR_RATIO:.2%}"
                )
            width_error = finite_number(report.get("width_error_ratio"), "width_error_ratio", path)
            if width_error > MAX_WIDTH_ERROR_RATIO:
                errors.append(
                    f"{path}: width error {width_error:.2%} exceeds "
                    f"{MAX_WIDTH_ERROR_RATIO:.2%}"
                )
            if int(report.get("peak_vertex_count", 0)) < 12:
                errors.append(f"{path}: insufficient ribbon geometry")
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))

    missing = EXPECTED_FPS - set(by_fps)
    unexpected = set(by_fps) - EXPECTED_FPS
    if missing:
        errors.append(f"missing fixed-FPS reports: {sorted(missing)}")
    if unexpected:
        errors.append(f"unexpected fixed-FPS reports: {sorted(unexpected)}")

    widths: list[float] = []
    opacities: list[float] = []
    for fps in sorted(EXPECTED_FPS & set(by_fps)):
        report = by_fps[fps]
        path = path_by_fps[fps]
        widths.append(
            finite_number(report.get("peak_rendered_width_m"), "peak_rendered_width_m", path)
        )
        opacities.append(
            finite_number(report.get("configured_opacity"), "configured_opacity", path)
        )

    width_spread_ratio = 0.0
    if widths:
        reference_width = max(max(widths), 1e-6)
        width_spread_ratio = (max(widths) - min(widths)) / reference_width
        if width_spread_ratio > MAX_CROSS_FPS_WIDTH_SPREAD_RATIO:
            errors.append(
                f"cross-FPS width spread {width_spread_ratio:.2%} exceeds "
                f"{MAX_CROSS_FPS_WIDTH_SPREAD_RATIO:.2%}"
            )

    opacity_spread = 0.0
    if opacities:
        opacity_spread = max(opacities) - min(opacities)
        if opacity_spread > MAX_OPACITY_SPREAD:
            errors.append(
                f"cross-FPS opacity spread {opacity_spread:.6f} exceeds "
                f"{MAX_OPACITY_SPREAD:.6f}"
            )

    summary = {
        "schema_version": 1,
        "expected_fps": sorted(EXPECTED_FPS),
        "reports": {str(fps): by_fps[fps] for fps in sorted(by_fps)},
        "cross_fps_width_spread_ratio": width_spread_ratio,
        "cross_fps_opacity_spread": opacity_spread,
        "errors": errors,
        "ok": not errors,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(
        "Trail FPS calibration passed: "
        f"width spread={width_spread_ratio:.2%}, "
        f"opacity spread={opacity_spread:.6f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
