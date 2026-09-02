#!/usr/bin/env bash
set -euo pipefail

# No version-specific exemptions. Keep raw logs and reject every engine/script error.
awk '
{
  line = $0
  gsub(/\033\[[0-9;]*m/, "", line)
  if (line ~ /SCRIPT ERROR|Failed to load script|(^|[[:space:]])ERROR:|ObjectDB instances.*leaked|resources still in use/) {
    print line
    failed = 1
  }
}
END { exit failed ? 1 : 0 }
' "$1"
