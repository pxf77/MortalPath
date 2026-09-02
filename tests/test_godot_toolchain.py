from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import godot_toolchain as toolchain


class GodotToolchainTests(unittest.TestCase):
    def test_exact_stable_official_builds(self):
        version = toolchain.lock()["version"]
        for suffix in (".stable.official.abcdef123", ".stable.mono.official.abcdef123"):
            toolchain.require_version(version + suffix, version)

    def test_wrong_patch_preview_and_custom_builds_fail(self):
        version = toolchain.lock()["version"]
        for actual in ("4.3.stable.official.hash", "4.7.stable.official.hash",
                       "4.7.1.stable.official.hash", "4.7.20.stable.official.hash",
                       "4.7.2.rc1.official.hash", "4.8.dev4.official.hash",
                       "4.7.2.stable.custom_build.hash"):
            with self.assertRaises(ValueError):
                toolchain.require_version(actual, version)

    def test_assets_are_immutable_release_urls_with_hashes(self):
        policy = toolchain.lock()
        self.assertEqual(policy["release"], policy["version"] + "-stable")
        for asset in policy["assets"].values():
            self.assertIn("/releases/download/" + policy["release"] + "/", asset["url"])
            self.assertNotIn("/latest/", asset["url"])
            self.assertRegex(asset["sha256"], r"^[0-9a-f]{64}$")

    def test_unsafe_archive_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "bad.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("../escape", b"bad")
            with self.assertRaises(ValueError):
                toolchain.validate_archive(path)

    def test_ci_installs_from_lock_instead_of_image_version(self):
        for workflow in (ROOT / ".github/workflows").glob("*.yml"):
            text = workflow.read_text()
            self.assertNotIn("barichello/godot-ci:", text, workflow.name)
            self.assertNotIn("Godot 4.3 import", text, workflow.name)

    def test_local_binary_override_does_not_silently_fall_back(self):
        with self.assertRaises(ValueError):
            toolchain.resolve_binary("/missing/mortalpath-godot")

    def test_symlink_resolves_to_real_bundle_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            binary = Path(temporary) / "Godot"
            binary.write_text("fixture")
            binary.chmod(0o755)
            alias = Path(temporary) / "godot-link"
            alias.symlink_to(binary)
            self.assertEqual(toolchain.resolve_binary(str(alias)), binary.resolve())


if __name__ == "__main__":
    unittest.main()
