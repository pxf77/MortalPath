#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${DOTNET_ROOT:-}" && -d "$HOME/.dotnet/host/fxr" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
godot_bin="$(python3 tools/godot_toolchain.py path)"
python3 tools/godot_toolchain.py check --binary "$godot_bin"
python3 -m unittest discover -s tests -p 'test_*.py' -v
evidence_dir="build/m1-evidence/validation"
mkdir -p "$evidence_dir"
bash tests/log_gate_test.sh

run_check() {
  local check_name="$1"
  shift
  "$godot_bin" "$@" 2>&1 | tee "$evidence_dir/$check_name.log"
  if ! bash scripts/check-godot-log.sh "$evidence_dir/$check_name.log"; then
    echo "Validation failed: $check_name" >&2
    return 1
  fi
}

run_check import --headless --path . --import
run_check smoke --headless --path . --quit-after 30
run_check rules --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
run_check flow --headless --path . --fixed-fps 60 --script res://tests/demo_scene_runner.gd
run_check artpack --headless --path . --fixed-fps 60 --script res://tests/qinglan_art_pack_runner.gd
run_check player-motion --headless --path . --fixed-fps 60 --script res://tests/player_motion_runner.gd
run_check enemy-motion --headless --path . --fixed-fps 60 --script res://tests/enemy_motion_runner.gd
run_check feedback --headless --path . --fixed-fps 60 --script res://tests/combat_feedback_runner.gd
run_check input --headless --path . --fixed-fps 60 --script res://tests/demo_input_runner.gd -- "--output=res://$evidence_dir"
echo "Demo validation passed; evidence: $evidence_dir"
