#!/bin/bash
# Hook helper: Update ARCHITECTURE.md after task completion.
# Scans project source tree and generates a navigational map for LLMs.
#
# Gas Town 방식 차용: 에이전트에게 탐색시키지 말고, 지도를 줘라.
#
# Usage: update-architecture.sh <project-root>

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="$SCRIPT_DIR/scan-architecture.py"

if [ ! -f "$SCANNER" ]; then
  echo "WARNING: scan-architecture.py not found at $SCANNER" >&2
  exit 0
fi

python3 "$SCANNER" "$PROJECT_ROOT" 2>&1 || true
