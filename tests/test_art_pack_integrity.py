from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path, PurePosixPath
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
ART_PACK_ROOT = REPO_ROOT / "assets" / "artpacks"
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"expected JSON object: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_pack_path(pack_root: Path, relative: str, required_prefix: str) -> Path:
    if not isinstance(relative, str):
        raise AssertionError("locked path must be a string")
    pure = PurePosixPath(relative)
    if pure.is_absolute() or ".." in pure.parts or not pure.parts:
        raise AssertionError(f"unsafe Art Pack path: {relative}")
    if pure.parts[0] != required_prefix:
        raise AssertionError(
            f"Art Pack path must be under {required_prefix}/: {relative}"
        )
    candidate = (pack_root / Path(*pure.parts)).resolve()
    candidate.relative_to(pack_root.resolve())
    return candidate


class ArtPackIntegrityTests(unittest.TestCase):
    def assert_locked_file(
        self,
        pack_root: Path,
        entry: dict[str, Any],
        required_prefix: str,
    ) -> Path:
        path = safe_pack_path(pack_root, entry.get("path", ""), required_prefix)
        self.assertTrue(path.is_file(), f"missing locked Art Pack file: {path}")
        self.assertIsInstance(entry.get("size_bytes"), int)
        self.assertEqual(path.stat().st_size, entry["size_bytes"], path)
        expected_hash = entry.get("sha256", "")
        self.assertRegex(expected_hash, SHA256_PATTERN)
        self.assertEqual(sha256_file(path), expected_hash, path)
        return path

    def test_qinglan_catalog_matches_promoted_runtime(self) -> None:
        pack_root = ART_PACK_ROOT / "qinglan_v0_2"
        lock = load_object(pack_root / "art-pack.lock.json")
        catalog = load_object(pack_root / "asset-catalog.json")
        assets = catalog.get("assets")
        self.assertIsInstance(assets, list)
        self.assertEqual(lock.get("version"), "artpack-v0.2.0-qinglan-valley")
        self.assertEqual(lock.get("asset_count"), catalog.get("asset_count"))
        self.assertEqual(catalog.get("asset_count"), len(assets))

        asset_ids: set[str] = set()
        expected_paths: set[Path] = set()
        for asset in assets:
            self.assertIsInstance(asset, dict)
            asset_id = asset.get("id")
            self.assertIsInstance(asset_id, str)
            self.assertNotIn(asset_id, asset_ids)
            asset_ids.add(asset_id)
            entry = {
                "path": asset.get("runtime_path"),
                "size_bytes": asset.get("file_size_bytes"),
                "sha256": asset.get("sha256"),
            }
            path = self.assert_locked_file(pack_root, entry, "runtime")
            self.assertNotIn(path, expected_paths)
            expected_paths.add(path)

        actual_paths = {
            path.resolve() for path in (pack_root / "runtime").rglob("*.glb")
        }
        self.assertEqual(actual_paths, expected_paths)

    def test_player_polish_release_manifest_and_runtime_are_exact(self) -> None:
        pack_root = ART_PACK_ROOT / "player_polish_v0_4"
        lock = load_object(pack_root / "art-pack.lock.json")
        self.assertEqual(lock.get("version"), "artpack-v0.4.0-player-polish")
        archive = lock.get("release_archive")
        self.assertIsInstance(archive, dict)
        self.assertRegex(archive.get("sha256", ""), SHA256_PATTERN)

        expected_by_prefix: dict[str, set[Path]] = {
            "runtime": set(),
            "manifests": set(),
        }
        for field, prefix in (
            ("runtime_assets", "runtime"),
            ("manifest_assets", "manifests"),
        ):
            entries = lock.get(field)
            self.assertIsInstance(entries, list)
            self.assertGreater(len(entries), 0)
            asset_ids: set[str] = set()
            for entry in entries:
                self.assertIsInstance(entry, dict)
                asset_id = entry.get("asset_id")
                self.assertIsInstance(asset_id, str)
                self.assertNotIn(asset_id, asset_ids)
                asset_ids.add(asset_id)
                path = self.assert_locked_file(pack_root, entry, prefix)
                self.assertNotIn(path, expected_by_prefix[prefix])
                expected_by_prefix[prefix].add(path)

        actual_runtime = {
            path.resolve() for path in (pack_root / "runtime").rglob("*.glb")
        }
        actual_manifests = {
            path.resolve() for path in (pack_root / "manifests").rglob("*.json")
        }
        self.assertEqual(actual_runtime, expected_by_prefix["runtime"])
        self.assertEqual(actual_manifests, expected_by_prefix["manifests"])


if __name__ == "__main__":
    unittest.main()
