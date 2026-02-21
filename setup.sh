#!/bin/bash
# setup.sh — Describe what you want to build, get a ready-to-go AI team.
#
# Interactive:
#   bash setup.sh
#
# Non-interactive:
#   bash setup.sh <project-path> "<description>"
#
# Examples:
#   bash setup.sh ~/my-app "Rails 8 백엔드 + Swift iOS 앱"
#   bash setup.sh ~/dashboard "Next.js 14 + TypeScript 대시보드"
#   bash setup.sh ~/api "Go REST API with PostgreSQL"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ──
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRN=$'\033[32m'; _YEL=$'\033[33m'; _RED=$'\033[31m'; _GRY=$'\033[90m'
_s=$'\001'; _e=$'\002'

info()   { printf "  ${_GRN}✓${_R} %s\n" "$1"; }
warn()   { printf "  ${_YEL}→${_R} %s\n" "$1"; }
skip()   { printf "  ${_D}· %s${_R}\n" "$1"; }
err()    { printf "  ${_RED}✗${_R} %s\n" "$1"; }

# ── Input ──
PROJECT_PATH="${1:-}"
DESCRIPTION="${2:-}"

printf "\n${_B}🚀 AI Team Setup${_R}\n\n"

# Interactive: ask for path and description if not provided
if [[ -z "$PROJECT_PATH" ]]; then
  read -e -r -p "${_s}${_CYN}${_e}프로젝트 경로${_s}${_R}${_e}: " PROJECT_PATH
  if [[ -z "$PROJECT_PATH" ]]; then
    err "프로젝트 경로를 입력해주세요."; exit 1
  fi
fi

PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd || echo "$PROJECT_PATH")"
PROJECT_NAME="$(basename "$PROJECT_PATH")"

if [[ -z "$DESCRIPTION" ]]; then
  printf "\n  ${_D}예: Rails 8 백엔드 + Swift iOS 앱. 운동 추적 서비스.${_R}\n"
  read -e -r -p "${_s}${_CYN}${_e}무엇을 만들 건가요?${_s}${_R}${_e} " DESCRIPTION
  if [[ -z "$DESCRIPTION" ]]; then
    err "프로젝트 설명을 입력해주세요."; exit 1
  fi
fi

printf "\n  ${_D}%s — %s${_R}\n" "$PROJECT_NAME" "$DESCRIPTION"

# ══════════════════════════════════════════════════════════════
# 1. Match description → team
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ 팀 구성 ━━━${_R}\n\n"

# Try AI generation first (claude CLI), fallback to keyword matching
USE_AI=false
ai_personas=()
if command -v claude &>/dev/null && [[ -z "${2:-}" ]]; then
  # AI mode: claude generates team suggestions
  _ai_prompt='You suggest team members for a software project.
Output ONLY lines in this exact format (no quotes, no comments, no blank lines):
PERSONA=name
Where name is one of: dhh, chris-lattner, dan-abramov, guillermo-rauch, ryan-dahl, rob-pike, guido-van-rossum
Pick ONLY personas that match the tech stack. Always include kent-beck last for QA.
Output NOTHING else.'

  _ai_file=$(mktemp)
  printf "  ${_D}AI 팀 제안 생성 중...${_R}"
  if claude -p --output-format text \
    --append-system-prompt "$_ai_prompt" \
    "Suggest team for: ${DESCRIPTION}" > "$_ai_file" 2>/dev/null; then
    # Parse AI output
    while IFS='=' read -r key val; do
      [[ "$key" == "PERSONA" && -n "$val" ]] && ai_personas+=("$val")
    done < "$_ai_file"
    if [[ ${#ai_personas[@]} -gt 0 ]]; then
      USE_AI=true
      printf "\r  ${_GRN}✓ AI 제안 완료${_R}          \n"
    fi
  fi
  rm -f "$_ai_file"
  [[ "$USE_AI" == "false" ]] && printf "\r  ${_D}키워드 매칭으로 전환${_R}   \n"
fi

if [[ "$USE_AI" == "true" ]]; then
  selected_personas=("${ai_personas[@]}")
else
  # Keyword matching fallback
  DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')
  selected_personas=()

  match_persona() {
    local keywords="$1" persona="$2"
    for kw in $keywords; do
      if echo "$DESC_LOWER" | grep -qw "$kw"; then
        selected_personas+=("$persona")
        return 0
      fi
    done
    return 1
  }

  match_persona "rails ruby activerecord sidekiq rspec erb"              dhh              || true
  match_persona "swift ios swiftui xcode apple uikit cocoa"              chris-lattner    || true
  match_persona "react redux jsx tsx vite frontend"                      dan-abramov      || true
  match_persona "next nextjs vercel turborepo t3"                        guillermo-rauch  || true
  match_persona "node deno bun express koa hono"                         ryan-dahl        || true
  match_persona "go golang grpc protobuf kubernetes k8s"                 rob-pike         || true
  match_persona "python django flask fastapi pytorch tensorflow pandas"  guido-van-rossum || true

  # Always include QA
  selected_personas+=("kent-beck")
fi

# Deduplicate (bash 3.2 safe)
unique_personas=()
for p in "${selected_personas[@]}"; do
  dupe=false
  for u in "${unique_personas[@]+"${unique_personas[@]}"}"; do
    [[ "$u" == "$p" ]] && { dupe=true; break; }
  done
  [[ "$dupe" == "false" ]] && unique_personas+=("$p")
done
selected_personas=("${unique_personas[@]}")

# Display labels (bash 3.2 compatible)
persona_label() {
  case "$1" in
    dhh)              echo "DHH — Rails, Ruby" ;;
    chris-lattner)    echo "Chris Lattner — Swift, iOS" ;;
    dan-abramov)      echo "Dan Abramov — React, Frontend" ;;
    guillermo-rauch)  echo "Guillermo Rauch — Next.js, Vercel" ;;
    ryan-dahl)        echo "Ryan Dahl — Node, Deno, Bun" ;;
    rob-pike)         echo "Rob Pike — Go" ;;
    guido-van-rossum) echo "Guido van Rossum — Python" ;;
    kent-beck)        echo "Kent Beck — QA, TDD" ;;
    *)                echo "$1" ;;
  esac
}

if [[ ${#selected_personas[@]} -le 1 ]]; then
  warn "매칭된 기술 키워드 없음 — 전체 페르소나 설치"
  selected_personas=()
  for f in "$SCRIPT_DIR"/personas/*.md; do
    [[ -f "$f" ]] || continue
    selected_personas+=("$(basename "$f" .md)")
  done
fi

for p in "${selected_personas[@]}"; do
  info "$(persona_label "$p")"
done

# ══════════════════════════════════════════════════════════════
# 2. Install everything
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ 설치 ━━━${_R}\n\n"

# Project directory
if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH"
  info "디렉토리 생성: $PROJECT_PATH"
  # git init if not a repo
  if [[ ! -d "$PROJECT_PATH/.git" ]]; then
    ( cd "$PROJECT_PATH" && git init -q )
    info "git init"
  fi
else
  info "프로젝트: $PROJECT_PATH"
fi

# Agent Teams
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
if [[ -f "$GLOBAL_SETTINGS" ]]; then
  HAS_TEAMS=$(python3 -c "
import json
with open('$GLOBAL_SETTINGS') as f: d = json.load(f)
print(d.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS',''))
" 2>/dev/null || echo "")
  if [[ "$HAS_TEAMS" != "1" ]]; then
    python3 -c "
import json
with open('$GLOBAL_SETTINGS') as f: d = json.load(f)
d.setdefault('env',{})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
with open('$GLOBAL_SETTINGS','w') as f: json.dump(d, f, indent=2); f.write('\n')
"
    info "Agent Teams 활성화"
  else
    skip "Agent Teams 이미 활성화됨"
  fi
else
  printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  }\n}\n' > "$GLOBAL_SETTINGS"
  info "Agent Teams 활성화"
fi

# Hooks
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$PROJECT_PATH/.claude/hooks"
PROJ_SETTINGS="$PROJECT_PATH/.claude/settings.json"

if [[ -d "$HOOKS_SRC" ]] && ls "$HOOKS_SRC"/*.sh &>/dev/null; then
  mkdir -p "$HOOKS_DST"
  cp "$HOOKS_SRC"/task-completed.sh "$HOOKS_SRC"/teammate-idle.sh "$HOOKS_DST/" 2>/dev/null || true
  chmod +x "$HOOKS_DST"/*.sh

  _PROJ_SETTINGS="$PROJ_SETTINGS" _HOOKS_DST="$HOOKS_DST" python3 << 'PYEOF'
import json, os
s = os.environ["_PROJ_SETTINGS"]
h = os.environ["_HOOKS_DST"]
d = json.load(open(s)) if os.path.exists(s) else {}
for name, event in {"task-completed.sh":"TaskCompleted","teammate-idle.sh":"TeammateIdle"}.items():
    path = os.path.join(h, name)
    if not os.path.exists(path): continue
    d.setdefault("hooks",{}).setdefault(event,[])
    if not any(e.get("command")==path for e in d["hooks"][event]):
        d["hooks"][event].append({"command": path})
os.makedirs(os.path.dirname(s), exist_ok=True)
with open(s,"w") as f: json.dump(d, f, indent=2); f.write("\n")
PYEOF
  info "Hooks (타입 체크 + 테스트 + 파일 크기 강제)"
fi

# External agents (auto-activate all detected)
EXT_DIR="$SCRIPT_DIR/external-agents"
EXAMPLES_DIR="$EXT_DIR/examples"

cli_to_agent() {
  case "$1" in
    gemini) echo "gemini-reviewer" ;;
    codex)  echo "codex-coder" ;;
    openai) echo "gpt-security" ;;
    *)      echo "" ;;
  esac
}

agent_activated=false
for cli in gemini codex openai; do
  if command -v "$cli" &>/dev/null; then
    example="$(cli_to_agent "$cli")"
    if [[ -n "$example" && -d "$EXAMPLES_DIR/$example" && ! -d "$EXT_DIR/$example" ]]; then
      cp -r "$EXAMPLES_DIR/$example" "$EXT_DIR/$example"
      info "외부 에이전트: $example ($cli CLI)"
      agent_activated=true
    fi
  fi
done

api_found=false
[[ -n "${OPENAI_API_KEY:-}" ]]    && api_found=true
[[ -n "${GEMINI_API_KEY:-}" ]]    && api_found=true
[[ -n "${ANTHROPIC_API_KEY:-}" ]] && api_found=true
if [[ "$api_found" == "true" ]]; then
  for api_agent in api-reviewer api-security; do
    if [[ -d "$EXAMPLES_DIR/$api_agent" && ! -d "$EXT_DIR/$api_agent" ]]; then
      cp -r "$EXAMPLES_DIR/$api_agent" "$EXT_DIR/$api_agent"
      info "외부 에이전트: $api_agent (API)"
      agent_activated=true
    fi
  done
fi
[[ "$agent_activated" == "false" ]] && skip "외부 에이전트 없음 (CLI/API 미감지)"

# Personas
PROJ_PERSONAS="$PROJECT_PATH/.claude/personas"
mkdir -p "$PROJ_PERSONAS"
copied=0
for persona in "${selected_personas[@]}"; do
  src="$SCRIPT_DIR/personas/$persona.md"
  [[ -f "$src" ]] && { cp "$src" "$PROJ_PERSONAS/"; copied=$((copied + 1)); }
done
info "페르소나 ${copied}개 설치"

# ══════════════════════════════════════════════════════════════
# 3. Generate CLAUDE.md
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ CLAUDE.md ━━━${_R}\n\n"

CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"

# Build team roster and spawn instructions
team_roster=""
persona_spawn=""
for p in "${selected_personas[@]}"; do
  label="$(persona_label "$p")"
  if [[ "$p" == "kent-beck" ]]; then
    team_roster="${team_roster}- @qa ($label)\n"
    persona_spawn="${persona_spawn}- **qa**: Assign persona from \`personas/kent-beck.md\`. Reviews all code.\n"
  else
    team_roster="${team_roster}- @${p}-dev ($label)\n"
    persona_spawn="${persona_spawn}- **${p}-dev**: Assign persona from \`personas/${p}.md\`.\n"
  fi
done

cat > "$CLAUDE_MD" << MDEOF
# $PROJECT_NAME

## Project
$DESCRIPTION

## Your Team
$(printf '%b' "$team_roster")

## Spawning Teammates

Use \`/teammates\` to configure:
$(printf '%b' "$persona_spawn")

## Process (follow this EXACTLY)

### Step 1: Quick Context (30 seconds max)
When user describes a task, read 2-3 KEY source files to understand current state.
- Use Read tool only (max 50 lines each with offset/limit)
- Focus on: the file(s) most likely to change, related tests if they exist
- Do NOT explore broadly — you're confirming structure, not analyzing

### Step 2: Write DETAILED Tasks
Each task MUST include:
- **What to change** — specific description of the fix/feature
- **Which files to modify** — exact file paths
- **How to change them** — describe the code changes needed
- **Expected behavior** — what should work differently after
- **Project path** — so the agent knows where to work

### Step 3: Dispatch to Teammates
Assign tasks to dev teammates. Do NOT assign to QA yet.

### Step 4: QA Review (ALWAYS after dev completes)
When dev teammates finish:
1. Review their output to confirm what changed
2. Assign a QA task with SPECIFIC review instructions:
   - What files were changed (from dev output)
   - What behaviors to verify
   - Which test commands to run

### Step 5: Act on QA Result
- **FAIL** (max 2 retries, then ask user): Read QA feedback → assign new dev tasks → re-dispatch
- **PASS**: Show summary → commit specific files only (never \`git add -A\`)

### Step 6: Commit Message Quality
- Explain WHY, not just WHAT changed
- Bad: "Update user.ts"
- Good: "사용자 세션 만료 시 자동 로그아웃 추가 — 보안 감사 지적 반영"

## Team Rules

### Testing
- Run tests after EVERY change — no exceptions
- If no test exists for your change, write one first (Red → Green → Refactor)

### Git
- NEVER use \`git add -A\` or \`git add .\` — always stage specific files
- One logical change per commit

### Code Style
- No function exceeds ~30 lines
- No file exceeds ~300 lines — split into focused modules
- No magic numbers or strings — use named constants
- Names are self-documenting
- Errors include context (not silently swallowed)
- Follow existing project conventions
MDEOF

info "CLAUDE.md 생성"

# ══════════════════════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ ✓ 완료 ━━━${_R}\n\n"
printf "  ${_CYN}cd${_R} %s\n" "$PROJECT_PATH"
printf "  ${_CYN}claude${_R}\n"
printf "  만들고 싶은 걸 말하세요. PM이 팀을 이끕니다.\n\n"
