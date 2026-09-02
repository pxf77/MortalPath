#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${DOTNET_ROOT:-}" && -d "$HOME/.dotnet/host/fxr" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
fi
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
godot_bin="$(python3 tools/godot_toolchain.py path)"
python3 tools/godot_toolchain.py check --binary "$godot_bin" --templates
evidence_dir="build/m1-evidence/validation"
mkdir -p "$evidence_dir" build/exports/linux build/exports/macos

run_check() {
  local name="$1"
  shift
  "$@" 2>&1 | tee "$evidence_dir/$name.log"
  bash scripts/check-godot-log.sh "$evidence_dir/$name.log"
}

run_check export-linux "$godot_bin" --headless --path . --export-release Linux
if [[ "$(uname -s)" == "Darwin" ]]; then
  # Native Apple codesign is required for the macOS release gate.
  run_check export-macos "$godot_bin" --headless --path . --export-release macOS
  unpacked_dir="$(mktemp -d "$project_dir/build/exports/macos/run-XXXXXX")"
  ditto -x -k build/exports/macos/MortalPath.zip "$unpacked_dir"
  exported_bin="$unpacked_dir/MortalPath.app/Contents/MacOS/MortalPath"
  codesign --verify --deep --strict "$unpacked_dir/MortalPath.app"
else
  exported_bin="$project_dir/build/exports/linux/MortalPath.x86_64"
  chmod +x "$exported_bin"
fi
python3 tools/godot_toolchain.py check --binary "$exported_bin"
# Boot outside the source tree so missing packaged resources cannot fall back to it.
cd "$(dirname "$exported_bin")"
"$exported_bin" --headless --quit-after 60 2>&1 | tee "$project_dir/$evidence_dir/export-boot.log"
bash "$project_dir/scripts/check-godot-log.sh" "$project_dir/$evidence_dir/export-boot.log"
echo "Release exports and native packaged boot passed: $exported_bin"
