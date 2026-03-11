#!/bin/bash
# Hook: PreToolUse (Edit, Write)
# Guards core enforcement hooks from unauthorized modification.
#
# Protected files (inside .claude/hooks/ or ai-team/hooks/):
#   - task-completed.sh   (type check + test + file size enforcement)
#   - teammate-idle.sh    (output format enforcement)
#   - guard-hooks.sh      (this guard itself)
#
# Modification flow:
#   1. Agent detects need to modify a protected file
#   2. Agent asks user for explicit approval
#   3. If approved, agent runs: touch /tmp/.ai-team-hook-edit-approved
#   4. Agent makes the edit (guard allows one-time pass)
#   5. Token is auto-consumed (deleted after one use)
#
# Exit codes:
#   0 — allowed (not a protected file, or approval token present)
#   2 — blocked (protected file, no approval token)

set -euo pipefail

input=$(cat)

# Extract file_path from tool_input
file_path=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('tool_input', {}).get('file_path', ''))
" <<< "$input" 2>/dev/null) || exit 0

# No file path → not a file operation → allow
[[ -z "$file_path" ]] && exit 0

# Check if target is a protected file by name
_base=$(basename "$file_path" 2>/dev/null || echo "")
case "$_base" in
  task-completed.sh|teammate-idle.sh|guard-hooks.sh) ;;
  *) exit 0 ;;
esac

# Must be inside a hooks directory (not some random file with same name)
case "$file_path" in
  */.claude/hooks/*|*/ai-team/hooks/*) ;;
  *) exit 0 ;;
esac

# One-time approval token — consumed on use
_token="/tmp/.ai-team-hook-edit-approved"
if [[ -f "$_token" ]]; then
  rm -f "$_token"
  exit 0
fi

# Block with clear message
cat >&2 << 'MSG'

⛔ PROTECTED FILE — 핵심 강제 장치 수정 차단

이 파일은 ai-team의 핵심 품질 강제 장치입니다:
  • task-completed.sh — 타입 체크, 테스트, 파일 크기 강제
  • teammate-idle.sh  — 출력 형식 강제
  • guard-hooks.sh    — 이 보호 장치 자체

수정하려면 사용자의 명시적 승인이 필요합니다.
사용자가 승인했다면 아래 명령 실행 후 다시 시도하세요:

  touch /tmp/.ai-team-hook-edit-approved

MSG
exit 2
