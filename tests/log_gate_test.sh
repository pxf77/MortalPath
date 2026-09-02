#!/usr/bin/env bash
set -euo pipefail

expect() {
  local expected="$1" message="$2" actual=0
  printf '%b\n' "$message" | bash scripts/check-godot-log.sh /dev/stdin >/dev/null || actual=$?
  if [ "$actual" -ne "$expected" ]; then
    echo "Log gate test failed: expected $expected, got $actual" >&2
    exit 1
  fi
}

expect 0 'Tests passed.'
expect 0 '\033[1;32mTests passed.\033[0m'
expect 1 '\033[1;31mSCRIPT ERROR:\033[0m Invalid call'
expect 1 '\033[1;31mERROR:\033[0m Unexpected engine failure'
expect 1 'ERROR: Parameter "m" is null.\n   at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)'
expect 1 '  ERROR: an indented error'
expect 1 'Failed to load script res://missing.gd'
expect 1 'WARNING: 2 ObjectDB instances were leaked at exit'
expect 1 'ERROR: 13 resources still in use at exit'
echo 'Log gate tests: 9 passed.'
