#!/usr/bin/env python3
"""Install/check the exact official Godot release in toolchain.lock.json. Never fetch latest."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def lock():
    return json.loads((ROOT / "toolchain.lock.json").read_text())["godot"]


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_version(actual, expected):
    if not re.fullmatch(re.escape(expected) + r"\.stable(?:\.mono)?\.official\.[a-zA-Z0-9]+", actual.strip()):
        raise ValueError(f"Godot version mismatch: expected {expected} stable official, got {actual!r}")


def resolve_binary(explicit=None):
    candidates = [explicit, os.environ.get("GODOT_BIN"), str(ROOT / ".tools/godot/bin/godot")]
    if sys.platform == "darwin":
        candidates.append("/Applications/Godot_mono.app/Contents/MacOS/Godot")
    candidates.append(shutil.which("godot"))
    for candidate in candidates:
        if candidate:
            found = shutil.which(candidate)
            if found:
                # macOS mono locates GodotSharp relative to the real app executable.
                return Path(found).resolve()
            # An explicit override must fail closed, never silently fall back.
            if candidate == explicit or candidate == os.environ.get("GODOT_BIN"):
                raise ValueError(f"Godot executable not found: {candidate}")
    raise ValueError("Godot not installed. Run: python3 tools/godot_toolchain.py install")


def check_binary(binary):
    version = subprocess.check_output([str(binary), "--version"], text=True).strip()
    require_version(version, lock()["version"])
    return version


def template_root():
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/Godot/export_templates"
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates"


def check_templates(binary):
    actual = check_binary(binary)
    flavor = "mono" if ".mono." in actual else "standard"
    directory_name = lock()["version"] + ".stable" + (".mono" if flavor == "mono" else "")
    directory = template_root() / directory_name
    if not (directory / "version.txt").is_file() or (directory / "version.txt").read_text().strip() != directory_name:
        raise ValueError(f"Matching export templates missing: {directory}")
    required = ["macos.zip", "linux_release.x86_64", "linux_debug.x86_64"]
    if not all((directory / name).is_file() and (directory / name).stat().st_size > 0 for name in required):
        raise ValueError(f"Incomplete desktop export templates: {directory}")
    marker = directory / ".mortalpath-source-sha256"
    expected_hash = lock()["assets"]["templates_" + flavor]["sha256"]
    if not marker.is_file() or marker.read_text().strip() != expected_hash:
        raise ValueError("Templates are not verified against the pinned archive; install with --templates")
    return directory


def download(asset, cache):
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / asset["file"]
    if path.exists():
        if sha256(path) != asset["sha256"]:
            raise ValueError(f"Cached archive hash mismatch (preserved for inspection): {path}")
        return path
    partial = path.with_suffix(path.suffix + ".part")
    subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--connect-timeout", "30",
                    "--continue-at", "-", "--output", str(partial), asset["url"]], check=True)
    if sha256(partial) != asset["sha256"]:
        raise ValueError(f"Downloaded archive hash mismatch: {partial}")
    partial.replace(path)
    return path


def validate_archive(archive):
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in entry.filename:
                raise ValueError(f"Unsafe archive member: {entry.filename}")


def install(cache, destination, templates=False):
    config = lock()
    if sys.platform == "darwin":
        key, flavor = "macos_mono", "mono"
        relative_binary = "Godot_mono.app/Contents/MacOS/Godot"
    elif sys.platform.startswith("linux") and platform.machine() in {"x86_64", "AMD64"}:
        key, flavor = "linux_standard", "standard"
        relative_binary = f"Godot_v{config['version']}-stable_linux.x86_64"
    else:
        raise ValueError("Installer supports macOS universal and Linux x86_64; unsupported host fails closed")
    archive = download(config["assets"][key], cache)
    validate_archive(archive)
    editor_root = destination / config["release"]
    binary = editor_root / relative_binary
    if not binary.exists():
        if editor_root.exists():
            raise ValueError(f"Incomplete installation preserved; inspect {editor_root}")
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="godot-stage-", dir=destination) as temporary:
            stage = Path(temporary)
            if sys.platform == "darwin":
                subprocess.run(["ditto", "-x", "-k", str(archive), str(stage)], check=True)
            else:
                with zipfile.ZipFile(archive) as package:
                    package.extractall(stage)
                (stage / relative_binary).chmod(0o755)
            check_binary(stage / relative_binary)
            stage.rename(editor_root)
    check_binary(binary)
    bin_dir = destination / "bin"
    bin_dir.mkdir(exist_ok=True)
    link = bin_dir / "godot"
    if not link.is_symlink() and link.exists():
        raise ValueError(f"Refusing to replace non-symlink executable: {link}")
    if link.is_symlink():
        link.unlink()
    link.symlink_to(binary.resolve())

    if templates:
        asset = config["assets"]["templates_" + flavor]
        template_archive = download(asset, cache)
        validate_archive(template_archive)
        name = config["version"] + ".stable" + (".mono" if flavor == "mono" else "")
        root = template_root()
        root.mkdir(parents=True, exist_ok=True)
        target = root / name
        if target.exists():
            check_templates(binary)
        else:
            with tempfile.TemporaryDirectory(prefix="mortalpath-templates-", dir=root) as temporary:
                with zipfile.ZipFile(template_archive) as package:
                    package.extractall(temporary)
                unpacked = Path(temporary) / "templates"
                if (unpacked / "version.txt").read_text().strip() != name:
                    raise ValueError("Archive template version disagrees with toolchain lock")
                for executable in unpacked.glob("linux_*"):
                    executable.chmod(0o755)
                (unpacked / ".mortalpath-source-sha256").write_text(asset["sha256"] + "\n")
                unpacked.rename(target)
            check_templates(binary)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["install", "check", "path", "version"])
    parser.add_argument("--binary")
    parser.add_argument("--templates", action="store_true")
    parser.add_argument("--cache-dir", type=Path, default=ROOT / ".tools/downloads")
    parser.add_argument("--install-dir", type=Path, default=ROOT / ".tools/godot")
    parser.add_argument("--github", action="store_true", help="Expose verified executable to later CI steps")
    args = parser.parse_args()
    try:
        if args.command == "version":
            print(lock()["version"])
            return 0
        binary = (install(args.cache_dir, args.install_dir, args.templates)
                  if args.command == "install" else resolve_binary(args.binary))
        version = check_binary(binary)
        if args.templates:
            check_templates(binary)
        if args.github:
            with open(os.environ["GITHUB_PATH"], "a") as stream:
                stream.write(str(binary.parent) + "\n")
                if args.command == "install":
                    stream.write(str(args.install_dir.resolve() / "bin") + "\n")
            with open(os.environ["GITHUB_ENV"], "a") as stream:
                stream.write(f"GODOT_BIN={binary}\n")
        print(str(binary) if args.command == "path" else f"Godot verified: {version}")
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
