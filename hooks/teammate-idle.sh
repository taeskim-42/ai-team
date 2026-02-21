#!/bin/bash
# Hook: teammate-idle
# Validates output format before a teammate goes idle.
# Ensures teammates follow the required reporting structure.
#
# Dev teammates: must include ## Changes Made, ## Decisions, and ## Tests
#   — blocks if any section is missing or has ≤1 line of content
# QA teammates: must include ## QA Report and PASS/FAIL verdict
#   — blocks if ### Comprehensibility or ### Decision Quality is empty
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

if ! command -v python3 &>/dev/null; then
  echo "FATAL: python3 is required but not found. Install Python 3 to enable hook enforcement." >&2
  exit 2
fi

# Read event JSON from stdin
input=$(cat)

teammate_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('teammate_name') or '')" 2>/dev/null || echo "")
last_message=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_message') or '')" 2>/dev/null || echo "")

# Detect actual JSON parsing failure vs empty content
if [ -z "$last_message" ] && [ -n "$input" ]; then
  # Distinguish: did python3 fail to parse, or was the field genuinely empty/null?
  if ! echo "$input" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "FATAL: Failed to parse event JSON. Check that python3 can parse the input." >&2
    exit 2
  fi
  # Valid JSON but last_message is empty/null/missing — nothing to validate
  exit 0
fi

# No input at all — pass through
if [ -z "$last_message" ]; then
  exit 0
fi

# Extract content under a markdown heading (code-block aware, handles EOF)
# Stops at same-level or higher-level headings (### stops at ## or ###, not ####)
# Usage: extract_section "$message" "## Changes Made"
#        extract_section "$message" "### Comprehensibility"
extract_section() {
  local message="$1" heading="$2"
  printf '%s\n' "$message" | awk -v target="$heading" '
    BEGIN {
      match(target, /^#+/)
      level = RLENGTH
    }
    { gsub(/\r/, "") }
    /^```/ { in_code=!in_code; next }
    in_code { next }
    !found && index($0, target) == 1 {
      _rest = substr($0, length(target) + 1)
      if (_rest == "" || _rest ~ /^[[:space:]]+$/) { found=1; next }
    }
    found && /^#/ {
      match($0, /^#+/)
      if (RLENGTH <= level) exit
    }
    found && NF { print }
  ' || true
}

count_lines() {
  if [ -z "$1" ]; then
    echo 0
    return
  fi
  printf '%s\n' "$1" | wc -l | tr -d ' '
}

# QA teammate: must have "## QA Report" and "PASS" or "FAIL"
if [[ "$teammate_name" =~ ^(qa|QA|kent-beck|Kent-Beck|kent_beck)$ ]] || [[ "$teammate_name" == *-qa ]] || [[ "$teammate_name" == *-QA ]]; then
  missing=()

  if ! echo "$last_message" | grep -qE "^## QA Report[[:space:]]*$"; then
    missing+=("## QA Report section")
  fi

  if ! echo "$last_message" | grep -qE "^(PASS|FAIL)[[:space:]]*$"; then
    missing+=("PASS or FAIL verdict (standalone line: PASS or FAIL)")
  fi

  if ! echo "$last_message" | grep -qE "^### Comprehensibility[[:space:]]*$"; then
    missing+=("### Comprehensibility section (file sizes, function lengths, magic values)")
  fi

  if ! echo "$last_message" | grep -qE "^### Decision Quality[[:space:]]*$"; then
    missing+=("### Decision Quality section (review dev's ## Decisions for substance)")
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

  # QA thickness: sub-sections must have actual content (not just a header)
  comp_section=$(extract_section "$last_message" "### Comprehensibility")
  comp_lines=$(count_lines "$comp_section")
  if [ "$comp_lines" -lt 1 ]; then
    echo "### Comprehensibility section is empty. Review file sizes, function lengths, magic values." >&2
    exit 2
  fi

  dq_section=$(extract_section "$last_message" "### Decision Quality")
  # Strip standalone PASS/FAIL verdicts (with optional punctuation/whitespace)
  dq_filtered=$(printf '%s\n' "$dq_section" | grep -vE '^[[:space:]]*(PASS|FAIL)[[:punct:]]*[[:space:]]*$' || true)
  dq_lines=$(count_lines "$dq_filtered")
  if [ "$dq_lines" -lt 1 ]; then
    echo "### Decision Quality section is empty. Review dev's ## Decisions for substance." >&2
    exit 2
  fi

  exit 0
fi

# Dev teammate: must have "## Changes Made", "## Decisions", and "## Tests"
missing=()

if ! echo "$last_message" | grep -qE "^## Changes Made[[:space:]]*$"; then
  missing+=("## Changes Made section")
fi

if ! echo "$last_message" | grep -qE "^## Decisions[[:space:]]*$"; then
  missing+=("## Decisions section — document WHY you made each choice, not just WHAT you changed")
fi

if ! echo "$last_message" | grep -qE "^## Tests[[:space:]]*$"; then
  missing+=("## Tests section")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo "Dev output format incomplete. Missing:" >&2
  for item in "${missing[@]}"; do
    echo "  - $item" >&2
  done
  echo "" >&2
  echo "Your response must end with ## Changes Made, ## Decisions, and ## Tests sections." >&2
  exit 2
fi

# Block if Changes Made section is too thin (1 line or less of actual content)
changes_section=$(extract_section "$last_message" "## Changes Made")
changes_line_count=$(count_lines "$changes_section")
if [ "$changes_line_count" -le 1 ]; then
  echo "Changes Made section is too thin. List every changed file with WHY it was changed." >&2
  exit 2
fi

# Block if Decisions section is too thin (1 line or less of actual content)
decisions_section=$(extract_section "$last_message" "## Decisions")
decisions_line_count=$(count_lines "$decisions_section")
if [ "$decisions_line_count" -le 1 ]; then
  echo "Decisions section is too thin. Explain WHY you chose this approach over alternatives." >&2
  echo "Example: 'Used X instead of Y because Z. Considered A but rejected due to B.'" >&2
  exit 2
fi

# Block if Tests section is empty (must have at least 1 line of actual test evidence)
tests_section=$(extract_section "$last_message" "## Tests")
tests_line_count=$(count_lines "$tests_section")
if [ "$tests_line_count" -lt 1 ]; then
  echo "Tests section is empty. Include the test command you ran and its result." >&2
  exit 2
fi

exit 0
