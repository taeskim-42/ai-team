#!/bin/bash
# run-external-agents.sh — Generic multi-LLM dispatcher
#
# Scans external-agents/*/agent.sh for matching triggers,
# builds input, pipes persona + input to the LLM CLI,
# and saves output to .claude/external-reviews/.
#
# Usage:
#   ./run-external-agents.sh <trigger> [cwd]
#
# Arguments:
#   trigger   — task-completed | pre-commit | on-demand
#   cwd       — working directory (defaults to current)
#
# Exit codes:
#   0 — all agents completed (or no agents matched)
#   1 — one or more agents failed

set -euo pipefail

readonly TARGET_TRIGGER="${1:?Usage: run-external-agents.sh <trigger> [cwd]}"
CWD="${2:-.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/../external-agents" && pwd)"
OUTPUT_DIR="$CWD/.claude/external-reviews"

mkdir -p "$OUTPUT_DIR"

# Collect input based on mode
build_input() {
  local mode="$1"
  local dir="$2"

  case "$mode" in
    changed-files)
      local files
      files=$(cd "$dir" && git diff --name-only HEAD~1 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
      if [ -z "$files" ]; then
        echo "(no changed files detected)"
        return
      fi
      while IFS= read -r f; do
        if [ -f "$dir/$f" ]; then
          echo "=== $f ==="
          cat "$dir/$f"
          echo ""
        fi
      done <<< "$files"
      ;;
    full-diff)
      (cd "$dir" && git diff HEAD~1 2>/dev/null || git diff HEAD 2>/dev/null || echo "(no diff)")
      ;;
    staged)
      (cd "$dir" && git diff --cached 2>/dev/null || echo "(nothing staged)")
      ;;
    *)
      echo "(unknown input mode: $mode)"
      ;;
  esac
}

# Find and run matching agents
failed=0
found=0

for agent_dir in "$AGENTS_DIR"/*/; do
  # Skip _template and examples
  agent_name=$(basename "$agent_dir")
  [[ "$agent_name" == "_template" || "$agent_name" == "examples" ]] && continue

  config="$agent_dir/agent.sh"
  persona="$agent_dir/persona.md"

  [ -f "$config" ] || continue

  # Read config (in subshell-like isolation via temp vars)
  COMMAND=""
  TRIGGER=""
  INPUT=""
  source "$config"
  agent_command="$COMMAND"
  agent_trigger="$TRIGGER"
  agent_input="${INPUT:-changed-files}"

  if [ "$agent_trigger" != "$TARGET_TRIGGER" ]; then
    continue
  fi

  found=$((found + 1))

  if [ -z "$agent_command" ]; then
    echo "[warn] $agent_name: COMMAND is empty, skipping" >&2
    continue
  fi

  # Build input
  input_data=$(build_input "$agent_input" "$CWD")

  # Build prompt: persona + input
  prompt=""
  if [ -f "$persona" ]; then
    prompt="$(cat "$persona")"$'\n\n'
  fi
  prompt="${prompt}## Code to Review"$'\n'"${input_data}"

  # Run LLM and save output
  output_file="$OUTPUT_DIR/${agent_name}.md"
  echo "[run] $agent_name ($agent_command)..." >&2

  if echo "$prompt" | $agent_command > "$output_file" 2>&1; then
    echo "[done] $agent_name → $output_file" >&2
  else
    echo "[fail] $agent_name — see $output_file" >&2
    failed=$((failed + 1))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "[info] No external agents matched trigger '$TARGET_TRIGGER'" >&2
fi

exit $((failed > 0 ? 1 : 0))
