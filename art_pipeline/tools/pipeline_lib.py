from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any, Iterable

PIPELINE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = PIPELINE_ROOT.parent
MANIFEST_ROOT = PIPELINE_ROOT / "manifests"

ASSET_ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]{2,63}$")
ALLOWED_KINDS = {
    "character",
    "environment",
    "prop",
    "weapon",
    "vfx",
    "ui",
    "audio",
}
ALLOWED_SOURCE_TYPES = {"blend", "blender_python", "kra", "psd", "svg", "wav"}


class PipelineError(RuntimeError):
    """Expected validation or build failure with an actionable message."""


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PipelineError(f"missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PipelineError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PipelineError(f"expected a JSON object in {path}")
    return value


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def iter_manifest_paths(root: Path = MANIFEST_ROOT) -> list[Path]:
    return sorted(path for path in root.rglob("*.json") if path.is_file())


def load_manifests(root: Path = MANIFEST_ROOT) -> list[tuple[Path, dict[str, Any]]]:
    paths = iter_manifest_paths(root)
    if not paths:
        raise PipelineError(f"no manifests found under {root}")
    return [(path, load_json(path)) for path in paths]


def repo_path(relative_path: str) -> Path:
    candidate = Path(relative_path)
    if candidate.is_absolute():
        raise PipelineError(f"repository path must be relative: {relative_path}")
    resolved = (REPO_ROOT / candidate).resolve()
    try:
        resolved.relative_to(REPO_ROOT.resolve())
    except ValueError as exc:
        raise PipelineError(f"repository path escapes root: {relative_path}") from exc
    return resolved


def require_mapping(value: Any, field: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{field} must be an object")
        return {}
    return value


def require_string(value: Any, field: str, errors: list[str]) -> str:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{field} must be a non-empty string")
        return ""
    return value.strip()


def require_int(value: Any, field: str, errors: list[str], minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        errors.append(f"{field} must be an integer >= {minimum}")
        return minimum
    return value


def validate_manifest(
    manifest: dict[str, Any],
    *,
    manifest_path: Path | None = None,
    check_source: bool = True,
    check_runtime: bool = False,
) -> list[str]:
    errors: list[str] = []
    prefix = f"{manifest_path}: " if manifest_path else ""

    if manifest.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    asset_id = require_string(manifest.get("id"), "id", errors)
    if asset_id and not ASSET_ID_PATTERN.fullmatch(asset_id):
        errors.append("id must match ^[a-z][a-z0-9_]{2,63}$")

    kind = require_string(manifest.get("kind"), "kind", errors)
    if kind and kind not in ALLOWED_KINDS:
        errors.append(f"kind must be one of {sorted(ALLOWED_KINDS)}")

    require_string(manifest.get("milestone"), "milestone", errors)

    source = require_mapping(manifest.get("source"), "source", errors)
    source_type = require_string(source.get("type"), "source.type", errors)
    source_path = require_string(source.get("path"), "source.path", errors)
    if source_type and source_type not in ALLOWED_SOURCE_TYPES:
        errors.append(f"source.type must be one of {sorted(ALLOWED_SOURCE_TYPES)}")
    if source_path:
        if not source_path.startswith("art_pipeline/source/"):
            errors.append("source.path must be under art_pipeline/source/")
        try:
            source_file = repo_path(source_path)
            if check_source and not source_file.is_file():
                errors.append(f"source file does not exist: {source_path}")
        except PipelineError as exc:
            errors.append(str(exc))
        suffix_by_type = {
            "blend": ".blend",
            "blender_python": ".py",
            "kra": ".kra",
            "psd": ".psd",
            "svg": ".svg",
            "wav": ".wav",
        }
        expected_suffix = suffix_by_type.get(source_type)
        if expected_suffix and not source_path.endswith(expected_suffix):
            errors.append(f"source.path must end with {expected_suffix} for {source_type}")

    runtime = require_mapping(manifest.get("runtime"), "runtime", errors)
    runtime_path = require_string(runtime.get("path"), "runtime.path", errors)
    if runtime_path:
        if not runtime_path.startswith("art_pipeline/runtime/"):
            errors.append("runtime.path must be under art_pipeline/runtime/")
        if not runtime_path.endswith((".glb", ".gltf", ".png", ".webp", ".ogg", ".svg")):
            errors.append("runtime.path uses an unsupported runtime extension")
        try:
            runtime_file = repo_path(runtime_path)
            if check_runtime and not runtime_file.is_file():
                errors.append(f"runtime file does not exist: {runtime_path}")
        except PipelineError as exc:
            errors.append(str(exc))

    preview = require_mapping(manifest.get("preview"), "preview", errors)
    preview_path = require_string(preview.get("path"), "preview.path", errors)
    if preview_path:
        if not preview_path.startswith("art_pipeline/reports/previews/"):
            errors.append("preview.path must be under art_pipeline/reports/previews/")
        if not preview_path.endswith((".png", ".webp")):
            errors.append("preview.path must be PNG or WebP")

    scale = require_mapping(manifest.get("scale"), "scale", errors)
    if scale.get("unit") != "meter":
        errors.append("scale.unit must be meter")
    expected_height = require_mapping(
        scale.get("expected_height_m"), "scale.expected_height_m", errors
    )
    min_height = expected_height.get("min")
    max_height = expected_height.get("max")
    if not isinstance(min_height, (int, float)) or min_height <= 0:
        errors.append("scale.expected_height_m.min must be > 0")
    if not isinstance(max_height, (int, float)) or max_height <= 0:
        errors.append("scale.expected_height_m.max must be > 0")
    if isinstance(min_height, (int, float)) and isinstance(max_height, (int, float)):
        if min_height > max_height:
            errors.append("scale.expected_height_m.min cannot exceed max")

    budget = require_mapping(manifest.get("budget"), "budget", errors)
    for key in (
        "triangles_lod0_max",
        "materials_max",
        "bones_max",
        "animations_max",
        "textures_max_size",
    ):
        require_int(budget.get(key), f"budget.{key}", errors)

    art = require_mapping(manifest.get("art"), "art", errors)
    require_string(art.get("palette"), "art.palette", errors)
    require_string(art.get("style"), "art.style", errors)
    require_string(art.get("realm"), "art.realm", errors)

    provenance = require_mapping(manifest.get("provenance"), "provenance", errors)
    require_string(provenance.get("type"), "provenance.type", errors)
    require_string(provenance.get("license"), "provenance.license", errors)

    return [prefix + error for error in errors]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_date_epoch() -> int:
    raw = os.environ.get("SOURCE_DATE_EPOCH", "0")
    try:
        return max(0, int(raw))
    except ValueError:
        return 0


def relative_to_repo(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()


def ensure_unique(values: Iterable[str], label: str) -> list[str]:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return [f"duplicate {label}: {value}" for value in sorted(duplicates)]
