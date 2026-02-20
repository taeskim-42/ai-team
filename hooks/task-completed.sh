#!/bin/bash
# Hook: task-completed
# Runs when a teammate completes a task.
# QA teammates pass through; dev teammates trigger automatic test runs.
#
# Exit codes:
#   0 — success (proceed)
#   2 — tests failed (feedback sent to teammate via stderr)
#
# Usage in .claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [{ "command": "/path/to/task-completed.sh" }]
#   }

set -euo pipefail

# Read event JSON from stdin
input=$(cat)

teammate_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('teammate_name',''))" 2>/dev/null || echo "")
task_subject=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task_subject',''))" 2>/dev/null || echo "")
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")

# QA teammates pass through — no tests to gate
if [[ "$teammate_name" =~ [Qq][Aa]|[Kk]ent|[Bb]eck|[Tt]est|[Rr]eview ]]; then
  exit 0
fi

# Detect test framework and run tests
run_tests() {
  local dir="$1"
  cd "$dir" || exit 0

  if [ -f "Gemfile" ] && grep -q "rspec" Gemfile 2>/dev/null; then
    echo "Running: bundle exec rspec" >&2
    bundle exec rspec 2>&1
    return $?
  fi

  if [ -f "package.json" ]; then
    echo "Running: npm test" >&2
    npm test 2>&1
    return $?
  fi

  if ls ./*.xcodeproj 1>/dev/null 2>&1 || ls ./*.xcworkspace 1>/dev/null 2>&1; then
    local scheme
    scheme=$(xcodebuild -list 2>/dev/null | awk '/Schemes:/{found=1;next} found && NF{print $1;exit}')
    if [ -n "$scheme" ]; then
      echo "Running: xcodebuild test -scheme $scheme" >&2
      xcodebuild test -scheme "$scheme" \
        -destination 'platform=iOS Simulator,name=iPhone 16' \
        -quiet 2>&1 | tail -20
      return ${PIPESTATUS[0]}
    fi
  fi

  # No recognized framework — pass through
  exit 0
}

# Use cwd from event, fallback to current directory
test_dir="${cwd:-.}"

output=$(run_tests "$test_dir" 2>&1) || {
  echo "Tests FAILED for task: $task_subject" >&2
  echo "" >&2
  echo "$output" >&2
  echo "" >&2
  echo "Fix the failing tests before marking the task as complete." >&2
  exit 2
}

# Run external LLM agents (non-blocking, best-effort)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/run-external-agents.sh" ]; then
  "$SCRIPT_DIR/run-external-agents.sh" "task-completed" "$test_dir" &
fi

exit 0
