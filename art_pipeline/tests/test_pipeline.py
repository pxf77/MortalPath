from __future__ import annotations

import copy
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

from inspect_glb import compare_budget, parse_glb, scene_stats  # noqa: E402
from pipeline_lib import load_json, validate_manifest  # noqa: E402


class ManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest_path = (
            Path(__file__).resolve().parents[1]
            / "manifests"
            / "props"
            / "prop_pipeline_marker.json"
        )
        self.manifest = load_json(self.manifest_path)

    def test_bootstrap_manifest_is_valid(self) -> None:
        errors = validate_manifest(
            self.manifest,
            manifest_path=self.manifest_path,
            check_source=True,
            check_runtime=False,
        )
        self.assertEqual([], errors)

    def test_invalid_asset_id_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.manifest)
        invalid["id"] = "Final Final Asset"
        errors = validate_manifest(invalid, check_source=False)
        self.assertTrue(any("id must match" in error for error in errors))

    def test_runtime_cannot_escape_pipeline_directory(self) -> None:
        invalid = copy.deepcopy(self.manifest)
        invalid["runtime"]["path"] = "../build/asset.glb"
        errors = validate_manifest(invalid, check_source=False)
        self.assertTrue(any("runtime.path must be under" in error for error in errors))


class GlbInspectionTests(unittest.TestCase):
    @staticmethod
    def make_glb(path: Path) -> None:
        document = {
            "asset": {"version": "2.0", "generator": "unit-test"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"mesh": 0}],
            "meshes": [
                {
                    "primitives": [
                        {"attributes": {"POSITION": 0}, "mode": 4, "material": 0}
                    ]
                }
            ],
            "accessors": [
                {
                    "componentType": 5126,
                    "count": 3,
                    "type": "VEC3",
                    "min": [-0.5, 0.0, -0.5],
                    "max": [0.5, 1.5, 0.5],
                }
            ],
            "materials": [{}],
        }
        payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
        payload += b" " * ((4 - len(payload) % 4) % 4)
        total_length = 12 + 8 + len(payload)
        data = struct.pack("<4sII", b"glTF", 2, total_length)
        data += struct.pack("<II", len(payload), 0x4E4F534A)
        data += payload
        path.write_bytes(data)

    def test_glb_stats_and_budget(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.glb"
            self.make_glb(path)
            document = parse_glb(path)
            stats = scene_stats(document)
            self.assertEqual(1, stats["triangles"])
            self.assertEqual(1, stats["materials"])
            self.assertAlmostEqual(1.5, stats["bounds"]["height_m"])

            manifest = {
                "budget": {
                    "triangles_lod0_max": 4,
                    "materials_max": 1,
                    "bones_max": 0,
                    "animations_max": 0,
                },
                "scale": {"expected_height_m": {"min": 1.0, "max": 2.0}},
            }
            self.assertEqual([], compare_budget(manifest, stats))

    def test_truncated_glb_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "broken.glb"
            path.write_bytes(b"glTF")
            with self.assertRaises(Exception):
                parse_glb(path)


if __name__ == "__main__":
    unittest.main()
