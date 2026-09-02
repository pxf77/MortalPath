#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${DOTNET_ROOT:-}" && -d "$HOME/.dotnet/host/fxr" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
fi
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="$(python3 "$project_dir/tools/godot_toolchain.py" path)"
exec "$godot_bin" --path "$project_dir" "$@"
