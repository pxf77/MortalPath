#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path
from typing import Any

from pipeline_lib import PipelineError, load_json, repo_path, sha256_file, write_json

GLB_MAGIC = b"glTF"
JSON_CHUNK_TYPE = 0x4E4F534A


def parse_glb(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 20:
        raise PipelineError(f"GLB is too small: {path}")

    magic, version, declared_length = struct.unpack_from("<4sII", data, 0)
    if magic != GLB_MAGIC:
        raise PipelineError(f"invalid GLB magic in {path}")
    if version != 2:
        raise PipelineError(f"unsupported GLB version {version} in {path}")
    if declared_length != len(data):
        raise PipelineError(
            f"GLB length mismatch in {path}: header={declared_length}, actual={len(data)}"
        )

    offset = 12
    json_chunk: bytes | None = None
    while offset + 8 <= len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + chunk_length
        if end > len(data):
            raise PipelineError(f"truncated GLB chunk in {path}")
        if chunk_type == JSON_CHUNK_TYPE and json_chunk is None:
            json_chunk = data[offset:end]
        offset = end

    if json_chunk is None:
        raise PipelineError(f"GLB has no JSON chunk: {path}")

    try:
        document = json.loads(json_chunk.rstrip(b" \t\r\n\x00").decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PipelineError(f"invalid GLB JSON chunk in {path}: {exc}") from exc
    if not isinstance(document, dict):
        raise PipelineError(f"GLB JSON root must be an object: {path}")
    return document


def accessor_count(document: dict[str, Any], index: int | None) -> int:
    if index is None:
        return 0
    accessors = document.get("accessors", [])
    if not isinstance(accessors, list) or not 0 <= index < len(accessors):
        return 0
    accessor = accessors[index]
    if not isinstance(accessor, dict):
        return 0
    count = accessor.get("count", 0)
    return count if isinstance(count, int) and count >= 0 else 0


def primitive_triangle_count(document: dict[str, Any], primitive: dict[str, Any]) -> int:
    mode = primitive.get("mode", 4)
    count = accessor_count(document, primitive.get("indices"))
    if count == 0:
        attributes = primitive.get("attributes", {})
        if isinstance(attributes, dict):
            count = accessor_count(document, attributes.get("POSITION"))

    if mode == 4:
        return count // 3
    if mode in (5, 6):
        return max(0, count - 2)
    return 0


def scene_stats(document: dict[str, Any]) -> dict[str, Any]:
    meshes = document.get("meshes", [])
    materials = document.get("materials", [])
    skins = document.get("skins", [])
    animations = document.get("animations", [])
    images = document.get("images", [])
    textures = document.get("textures", [])
    nodes = document.get("nodes", [])

    triangle_count = 0
    primitive_count = 0
    if isinstance(meshes, list):
        for mesh in meshes:
            if not isinstance(mesh, dict):
                continue
            primitives = mesh.get("primitives", [])
            if not isinstance(primitives, list):
                continue
            primitive_count += len(primitives)
            for primitive in primitives:
                if isinstance(primitive, dict):
                    triangle_count += primitive_triangle_count(document, primitive)

    bone_count = 0
    if isinstance(skins, list):
        joints: set[int] = set()
        for skin in skins:
            if isinstance(skin, dict) and isinstance(skin.get("joints"), list):
                joints.update(item for item in skin["joints"] if isinstance(item, int))
        bone_count = len(joints)

    bounds = position_bounds(document)
    return {
        "nodes": len(nodes) if isinstance(nodes, list) else 0,
        "meshes": len(meshes) if isinstance(meshes, list) else 0,
        "primitives": primitive_count,
        "triangles": triangle_count,
        "materials": len(materials) if isinstance(materials, list) else 0,
        "skins": len(skins) if isinstance(skins, list) else 0,
        "bones": bone_count,
        "animations": len(animations) if isinstance(animations, list) else 0,
        "images": len(images) if isinstance(images, list) else 0,
        "textures": len(textures) if isinstance(textures, list) else 0,
        "bounds": bounds,
    }


def position_bounds(document: dict[str, Any]) -> dict[str, Any] | None:
    accessors = document.get("accessors", [])
    meshes = document.get("meshes", [])
    if not isinstance(accessors, list) or not isinstance(meshes, list):
        return None

    mins: list[list[float]] = []
    maxs: list[list[float]] = []
    for mesh in meshes:
        if not isinstance(mesh, dict):
            continue
        for primitive in mesh.get("primitives", []):
            if not isinstance(primitive, dict):
                continue
            attributes = primitive.get("attributes", {})
            if not isinstance(attributes, dict):
                continue
            index = attributes.get("POSITION")
            if not isinstance(index, int) or not 0 <= index < len(accessors):
                continue
            accessor = accessors[index]
            if not isinstance(accessor, dict):
                continue
            minimum = accessor.get("min")
            maximum = accessor.get("max")
            if (
                isinstance(minimum, list)
                and isinstance(maximum, list)
                and len(minimum) == 3
                and len(maximum) == 3
                and all(isinstance(value, (int, float)) for value in minimum + maximum)
            ):
                mins.append([float(value) for value in minimum])
                maxs.append([float(value) for value in maximum])

    if not mins:
        return None

    minimum = [min(values) for values in zip(*mins)]
    maximum = [max(values) for values in zip(*maxs)]
    size = [maximum[index] - minimum[index] for index in range(3)]
    return {"min": minimum, "max": maximum, "size": size, "height_m": size[1]}


def compare_budget(manifest: dict[str, Any], stats: dict[str, Any]) -> list[str]:
    budget = manifest["budget"]
    checks = {
        "triangles": "triangles_lod0_max",
        "materials": "materials_max",
        "bones": "bones_max",
        "animations": "animations_max",
    }
    errors: list[str] = []
    for stat_key, budget_key in checks.items():
        actual = stats[stat_key]
        maximum = budget[budget_key]
        if actual > maximum:
            errors.append(f"{stat_key}={actual} exceeds {budget_key}={maximum}")

    bounds = stats.get("bounds")
    expected_height = manifest["scale"]["expected_height_m"]
    if isinstance(bounds, dict):
        height = bounds.get("height_m")
        if isinstance(height, (int, float)):
            if not expected_height["min"] <= height <= expected_height["max"]:
                errors.append(
                    f"height_m={height:.3f} outside "
                    f"[{expected_height['min']}, {expected_height['max']}]"
                )
    else:
        errors.append("POSITION accessors do not expose min/max bounds")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inspect a GLB and enforce asset budget.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = load_json(args.manifest)
        runtime_path = repo_path(manifest["runtime"]["path"])
        document = parse_glb(runtime_path)
        stats = scene_stats(document)
        errors = compare_budget(manifest, stats)
        report = {
            "schema_version": 1,
            "asset_id": manifest["id"],
            "runtime_path": manifest["runtime"]["path"],
            "sha256": sha256_file(runtime_path),
            "file_size_bytes": runtime_path.stat().st_size,
            "generator": document.get("asset", {}).get("generator"),
            "stats": stats,
            "budget": manifest["budget"],
            "errors": errors,
            "ok": not errors,
        }
        write_json(args.output, report)
    except (PipelineError, KeyError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
