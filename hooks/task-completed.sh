#!/bin/bash
# Hook: task-completed
# Runs when a teammate completes a task.
# QA teammates pass through; dev teammates trigger type check, tests, and size enforcement.
#
# Execution order:
#   1. Type check (tsc / mypy / go vet) — blocks on failure
#   2. Tests (auto-detected framework) — blocks on failure
#   3. File size check (>300 lines) — blocks on failure
#   4. External LLM agents — non-blocking
#
# Exit codes:
#   0 — success (proceed)
#   2 — type check, tests, or file size failed (feedback sent to teammate via stderr)
#
# Usage in .claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [{ "command": "/path/to/task-completed.sh" }]
#   }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 &>/dev/null; then
  echo "FATAL: python3 is required but not found. Install Python 3 to enable hook enforcement." >&2
  exit 2
fi

# Read event JSON from stdin
input=$(cat)

teammate_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('teammate_name') or '')" 2>/dev/null || echo "")
task_subject=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task_subject') or '')" 2>/dev/null || echo "")
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd') or '')" 2>/dev/null || echo "")

# QA teammates pass through — no tests to gate
if [[ "$teammate_name" =~ ^(qa|QA|kent-beck|Kent-Beck|kent_beck)$ ]] || [[ "$teammate_name" == *-qa ]] || [[ "$teammate_name" == *-QA ]]; then
  exit 0
fi

# Detect and run language-specific type checker
# Exits with 2 on failure (blocks task completion)
run_typecheck() {
  local dir="$1"
  if ! cd "$dir" 2>/dev/null; then
    echo "WARNING: Cannot access directory '$dir' — skipping type check" >&2
    return 0
  fi

  if [ -f "tsconfig.json" ]; then
    echo "Running: npx tsc --noEmit" >&2
    npx tsc --noEmit 2>&1
    return $?
  fi

  if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "mypy.ini" ] || [ -f ".mypy.ini" ]; then
    if command -v mypy &>/dev/null; then
      echo "Running: mypy ." >&2
      mypy . 2>&1
      return $?
    elif command -v pyright &>/dev/null; then
      echo "Running: pyright" >&2
      pyright 2>&1
      return $?
    fi
  fi

  if [ -f "go.mod" ]; then
    echo "Running: go vet ./..." >&2
    go vet ./... 2>&1
    return $?
  fi

  # No recognized type system — pass through
  return 0
}

# Block changed files exceeding line threshold
# Constraint breeds creativity — large files signal a design failure
check_file_sizes() {
  local dir="$1"
  local threshold="${FILE_SIZE_THRESHOLD:-300}"
  if ! cd "$dir" 2>/dev/null; then
    echo "WARNING: Cannot access directory '$dir' — skipping file size check" >&2
    return 0
  fi

  local large_files=()
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local lines
    lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$lines" -gt "$threshold" ]; then
      large_files+=("$file ($lines lines)")
    fi
  # Check both working tree changes and most recent commit (covers post-commit workflow)
  # --relative: paths relative to cwd, not repo root (fixes subdirectory file lookup)
  # -c core.quotePath=false: prevent octal-escaping of non-ASCII filenames
  done < <({
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      # No commits yet — check staged files (initial commit scenario)
      git -c core.quotePath=false diff --cached --name-only --relative 2>/dev/null || true
    else
      git -c core.quotePath=false diff --name-only --relative HEAD 2>/dev/null || true
      if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        git -c core.quotePath=false diff --name-only --relative HEAD~1..HEAD 2>/dev/null || true
      else
        # Root commit — best effort with --relative
        git -c core.quotePath=false show --pretty="" --name-only --relative HEAD 2>/dev/null || true
      fi
    fi
  } | sort -u)

  if [ ${#large_files[@]} -gt 0 ]; then
    echo "" >&2
    echo "BLOCKED: Files exceeding $threshold lines:" >&2
    for f in "${large_files[@]}"; do
      echo "  - $f" >&2
    done
    return 1
  fi
}

# Detect test framework and run tests
run_tests() {
  local dir="$1"
  if ! cd "$dir" 2>/dev/null; then
    echo "WARNING: Cannot access directory '$dir' — skipping tests" >&2
    return 0
  fi

  if [ -f "go.mod" ]; then
    echo "Running: go test ./..." >&2
    go test ./... 2>&1
    return $?
  fi

  if [ -f "Gemfile" ] && grep -q "rspec" Gemfile 2>/dev/null; then
    echo "Running: bundle exec rspec" >&2
    bundle exec rspec 2>&1
    return $?
  fi

  if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
    if command -v pytest &>/dev/null; then
      echo "Running: pytest" >&2
      pytest 2>&1
      return $?
    fi
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
  return 0
}

# Use cwd from event, fallback to current directory
test_dir="${cwd:-.}"

# Phase 1: Type check (blocks on failure)
tc_output=$(run_typecheck "$test_dir" 2>&1) || {
  echo "Type check FAILED for task: $task_subject" >&2
  echo "" >&2
  echo "$tc_output" >&2
  echo "" >&2
  echo "ACTION REQUIRED: Fix the type errors before completing this task." >&2
  echo "  1. Replace 'any' with the actual domain type." >&2
  echo "  2. Add explicit return types to exported functions." >&2
  echo "  3. If you introduced a new concept, create a named type for it." >&2
  echo "Types are how the next agent understands the domain without reading your code." >&2
  exit 2
}

# Phase 2: Tests (blocks on failure)
test_output=$(run_tests "$test_dir" 2>&1) || {
  echo "Tests FAILED for task: $task_subject" >&2
  echo "" >&2
  echo "$test_output" >&2
  echo "" >&2
  echo "ACTION REQUIRED: Fix the failing tests before completing this task." >&2
  echo "  1. Read the test failure output above — what behavior broke?" >&2
  echo "  2. If you changed a contract, update the test to match." >&2
  echo "  3. If the test reveals a design flaw, fix the code, not the test." >&2
  echo "Tests are how the next agent knows what's expected without asking you." >&2
  exit 2
}

# Phase 3: File size check (blocks on failure, runs in subshell to avoid cwd pollution)
size_output=$(check_file_sizes "$test_dir" 2>&1) || {
  echo "File size check FAILED for task: $task_subject" >&2
  echo "" >&2
  echo "$size_output" >&2
  echo "" >&2
  echo "ACTION REQUIRED: Decompose before completing this task." >&2
  echo "  1. Find the largest function in this file — extract it to a new module." >&2
  echo "  2. Name the new module after its single responsibility." >&2
  echo "  3. Connect via import/interface, not by splitting arbitrarily." >&2
  echo "Small files are how the next agent understands the system without your context." >&2
  exit 2
}

# Phase 4: Run external LLM agents (non-blocking, best-effort)
if [ -x "$SCRIPT_DIR/run-external-agents.sh" ]; then
  nohup "$SCRIPT_DIR/run-external-agents.sh" "task-completed" "$test_dir" >/dev/null 2>&1 &
  disown
fi

exit 0
