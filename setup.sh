#!/bin/bash
# setup.sh — Describe what you want to build, get a ready-to-go AI team.
#
# Usage:
#   bash setup.sh <project-path> "<description>"
#
# Examples:
#   bash setup.sh ~/my-app "Rails 8 백엔드 + Swift iOS 앱. 운동 추적 서비스."
#   bash setup.sh ~/dashboard "Next.js 14 + TypeScript 대시보드. Tailwind, shadcn/ui."
#   bash setup.sh ~/api-server "Go REST API with PostgreSQL and Redis."
#   bash setup.sh ~/ml-project "Python FastAPI + PyTorch 추천 시스템."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ──
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRN=$'\033[32m'; _YEL=$'\033[33m'; _RED=$'\033[31m'

info()   { printf "  ${_GRN}✓${_R} %s\n" "$1"; }
warn()   { printf "  ${_YEL}→${_R} %s\n" "$1"; }
skip()   { printf "  ${_D}· %s${_R}\n" "$1"; }
err()    { printf "  ${_RED}✗${_R} %s\n" "$1"; }

# ── Args ──
if [[ $# -lt 2 ]]; then
  printf "\n${_B}사용법:${_R}\n"
  printf "  bash setup.sh <project-path> \"<프로젝트 설명>\"\n\n"
  printf "${_B}예시:${_R}\n"
  printf "  bash setup.sh ~/my-app \"Rails 8 백엔드 + Swift iOS 앱\"\n"
  printf "  bash setup.sh ~/dashboard \"Next.js + TypeScript 대시보드\"\n"
  printf "  bash setup.sh ~/api \"Go REST API with PostgreSQL\"\n\n"
  exit 1
fi

PROJECT_PATH="$1"
DESCRIPTION="$2"
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd || echo "$PROJECT_PATH")"
PROJECT_NAME="$(basename "$PROJECT_PATH")"

printf "\n${_B}🚀 AI Team Setup${_R}  %s\n" "$PROJECT_NAME"
printf "  ${_D}%s${_R}\n" "$DESCRIPTION"

# ══════════════════════════════════════════════════════════════
# 1. Match description → personas
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ 팀 구성 ━━━${_R}\n\n"

DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')
selected_personas=()
selected_labels=()

# Tech keyword → persona mapping (bash 3.2 compatible)
match_persona() {
  local keywords="$1" persona="$2" label="$3"
  for kw in $keywords; do
    if echo "$DESC_LOWER" | grep -qw "$kw"; then
      selected_personas+=("$persona")
      selected_labels+=("$label")
      return 0
    fi
  done
  return 1
}

match_persona "rails ruby activerecord sidekiq rspec erb"   dhh              "DHH — Rails, Ruby"                  || true
match_persona "swift ios swiftui xcode apple uikit cocoa"   chris-lattner    "Chris Lattner — Swift, iOS"           || true
match_persona "react redux jsx tsx vite frontend"           dan-abramov      "Dan Abramov — React, Frontend"        || true
match_persona "next nextjs vercel turborepo t3"             guillermo-rauch  "Guillermo Rauch — Next.js, Vercel"    || true
match_persona "node deno bun express koa hono"              ryan-dahl        "Ryan Dahl — Node, Deno, Bun"          || true
match_persona "go golang grpc protobuf kubernetes k8s"      rob-pike         "Rob Pike — Go"                        || true
match_persona "python django flask fastapi pytorch tensorflow pandas ml ai"  guido-van-rossum "Guido van Rossum — Python" || true

# Always include QA
selected_personas+=("kent-beck")
selected_labels+=("Kent Beck — QA, TDD")

# Deduplicate (bash 3.2 safe)
unique_personas=()
unique_labels=()
for i in "${!selected_personas[@]}"; do
  dupe=false
  for u in "${unique_personas[@]+"${unique_personas[@]}"}"; do
    [[ "$u" == "${selected_personas[$i]}" ]] && { dupe=true; break; }
  done
  [[ "$dupe" == "false" ]] && {
    unique_personas+=("${selected_personas[$i]}")
    unique_labels+=("${selected_labels[$i]}")
  }
done
selected_personas=("${unique_personas[@]}")
selected_labels=("${unique_labels[@]}")

for label in "${selected_labels[@]}"; do
  info "$label"
done

if [[ ${#selected_personas[@]} -le 1 ]]; then
  warn "기술 키워드 매칭 안됨 — 전체 페르소나 설치"
  # Fall back to all
  selected_personas=()
  selected_labels=()
  for f in "$SCRIPT_DIR"/personas/*.md; do
    [[ -f "$f" ]] || continue
    selected_personas+=("$(basename "$f" .md)")
  done
  selected_personas+=("kent-beck")
fi

# ══════════════════════════════════════════════════════════════
# 2. Create project + install everything
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ 설치 ━━━${_R}\n\n"

# Project directory
if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH"
  info "디렉토리 생성: $PROJECT_PATH"
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
  info "Hooks 설치 (task-completed, teammate-idle)"
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

for cli in gemini codex openai; do
  if command -v "$cli" &>/dev/null; then
    example="$(cli_to_agent "$cli")"
    if [[ -n "$example" && -d "$EXAMPLES_DIR/$example" && ! -d "$EXT_DIR/$example" ]]; then
      cp -r "$EXAMPLES_DIR/$example" "$EXT_DIR/$example"
      info "외부 에이전트: $example ($cli)"
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
    fi
  done
fi

# Personas
PROJ_PERSONAS="$PROJECT_PATH/.claude/personas"
mkdir -p "$PROJ_PERSONAS"
copied_names=()
for persona in "${selected_personas[@]}"; do
  src="$SCRIPT_DIR/personas/$persona.md"
  if [[ -f "$src" ]]; then
    cp "$src" "$PROJ_PERSONAS/"
    copied_names+=("$persona")
  fi
done
if [[ ${#copied_names[@]} -gt 0 ]]; then
  info "페르소나 ${#copied_names[@]}개: ${copied_names[*]}"
fi

# ══════════════════════════════════════════════════════════════
# 3. Generate CLAUDE.md
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ CLAUDE.md 생성 ━━━${_R}\n\n"

CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"

# Build team roster for CLAUDE.md
team_roster=""
for i in "${!selected_personas[@]}"; do
  p="${selected_personas[$i]}"
  if [[ "$p" == "kent-beck" ]]; then
    team_roster="${team_roster}- @qa (Kent Beck) — QA, TDD, Code Review\n"
  else
    # Derive role from label if available, otherwise from persona name
    label="${selected_labels[$i]:-$p}"
    team_roster="${team_roster}- @${p}-dev ($label)\n"
  fi
done

# Build persona assignment instructions
persona_assignments=""
for p in "${selected_personas[@]}"; do
  if [[ "$p" == "kent-beck" ]]; then
    persona_assignments="${persona_assignments}- **qa**: Assign persona from \`personas/kent-beck.md\`. Reviews all code.\n"
  else
    persona_assignments="${persona_assignments}- **${p}-dev**: Assign persona from \`personas/${p}.md\`.\n"
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
$(printf '%b' "$persona_assignments")

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
Assign tasks to dev teammates. Do NOT assign to QA yet — QA runs after dev completes.

### Step 4: QA Review (ALWAYS after dev completes)
When dev teammates finish:
1. Review their output to confirm what changed
2. Assign a QA task with SPECIFIC review instructions

### Step 5: Act on QA Result
- **FAIL** (max 2 retries, then ask user): Read QA feedback, assign new dev tasks, re-dispatch
- **PASS**: Show summary, commit specific files only

## Team Rules

### Testing
- Run tests after EVERY change — no exceptions
- If no test exists for your change, write one first

### Git
- NEVER use \`git add -A\` or \`git add .\` — always stage specific files
- Commit messages: explain WHY, not just WHAT
- One logical change per commit

### Code Style
- No function exceeds ~30 lines
- No file exceeds ~300 lines — split into focused modules
- No magic numbers or strings — use named constants
- Names are self-documenting
- Follow existing project conventions
MDEOF

info "CLAUDE.md 생성 완료"

# ══════════════════════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ ✓ 완료 ━━━${_R}\n\n"
printf "  ${_CYN}cd${_R} %s\n" "$PROJECT_PATH"
printf "  ${_CYN}claude${_R}\n"
printf "  그리고 만들고 싶은 걸 말하세요. PM이 팀을 이끕니다.\n\n"
