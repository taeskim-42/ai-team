#!/bin/bash
# Hook: teammate-idle
# Validates output format before a teammate goes idle.
# Ensures teammates follow the required reporting structure.
#
# Exit codes:
#   0 — output format is valid
#   2 — output format is missing required sections (feedback sent via stderr)
#
# Usage in .claude/settings.json:
#   "hooks": {
#     "TeammateIdle": [{ "command": "/path/to/teammate-idle.sh" }]
#   }

set -euo pipefail

# Read event JSON from stdin
input=$(cat)

teammate_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('teammate_name',''))" 2>/dev/null || echo "")
last_message=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_message',''))" 2>/dev/null || echo "")

# If no message content, pass through
if [ -z "$last_message" ]; then
  exit 0
fi

# QA teammate: must have "## QA Report" and "PASS" or "FAIL"
if [[ "$teammate_name" =~ [Qq][Aa]|[Kk]ent|[Bb]eck|[Tt]est|[Rr]eview ]]; then
  missing=()

  if ! echo "$last_message" | grep -q "## QA Report"; then
    missing+=("## QA Report section")
  fi

  if ! echo "$last_message" | grep -qE "PASS|FAIL"; then
    missing+=("PASS or FAIL verdict")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo "QA output format incomplete. Missing:" >&2
    for item in "${missing[@]}"; do
      echo "  - $item" >&2
    done
    echo "" >&2
    echo "Your response must end with the ## QA Report format including a PASS/FAIL verdict." >&2
    exit 2
  fi

  exit 0
fi

# Dev teammate: must have "## Changes Made" and "## Tests"
missing=()

if ! echo "$last_message" | grep -q "## Changes Made"; then
  missing+=("## Changes Made section")
fi

if ! echo "$last_message" | grep -q "## Tests"; then
  missing+=("## Tests section")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo "Dev output format incomplete. Missing:" >&2
  for item in "${missing[@]}"; do
    echo "  - $item" >&2
  done
  echo "" >&2
  echo "Your response must end with ## Changes Made and ## Tests sections." >&2
  exit 2
fi

exit 0
