#!/bin/bash
# setup.sh — Non-interactive setup for AI Team + Claude Code Agent Teams
#
# Usage:
#   bash setup.sh <project-path> [options]
#
# Options:
#   --personas LIST   Comma-separated names (e.g., dhh,kent-beck) or "all"
#   --no-hooks        Skip hook installation
#   --no-agents       Skip external agent activation
#   --agents LIST     Comma-separated: cli, api, or "all" (default: all detected)
#
# Examples:
#   bash setup.sh ~/my-project
#   bash setup.sh ~/my-project --personas dhh,kent-beck,chris-lattner
#   bash setup.sh ~/my-project --personas all --no-agents
#   bash setup.sh ~/my-project --agents api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors & helpers ──
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRN=$'\033[32m'; _YEL=$'\033[33m'; _RED=$'\033[31m'

info()   { printf "  ${_GRN}✓${_R} %s\n" "$1"; }
warn()   { printf "  ${_YEL}→${_R} %s\n" "$1"; }
skip()   { printf "  ${_D}· %s${_R}\n" "$1"; }
err()    { printf "  ${_RED}✗${_R} %s\n" "$1"; }
header() { printf "\n${_B}${_CYN}━━━ %s ━━━${_R}\n\n" "$1"; }

# ── Parse arguments ──
PROJECT_PATH=""
OPT_PERSONAS="all"
OPT_HOOKS=true
OPT_AGENTS="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --personas)   OPT_PERSONAS="$2"; shift 2 ;;
    --no-hooks)   OPT_HOOKS=false; shift ;;
    --no-agents)  OPT_AGENTS="none"; shift ;;
    --agents)     OPT_AGENTS="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*)           err "알 수 없는 옵션: $1"; exit 1 ;;
    *)
      if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$1"
      else
        err "인자가 너무 많습니다: $1"; exit 1
      fi
      shift ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  err "사용법: bash setup.sh <project-path> [options]"
  err "  예: bash setup.sh ~/my-project --personas dhh,kent-beck"
  exit 1
fi

PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd || echo "$PROJECT_PATH")"

SUMMARY=()
printf "\n${_B}🚀 AI Team Setup${_R}\n"

# ══════════════════════════════════════════════════════════════
# 1. Project directory
# ══════════════════════════════════════════════════════════════
header "프로젝트"

if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH"
  info "디렉토리 생성: $PROJECT_PATH"
else
  info "프로젝트: $PROJECT_PATH"
fi
SUMMARY+=("프로젝트: $PROJECT_PATH")

# ══════════════════════════════════════════════════════════════
# 2. Agent Teams activation
# ══════════════════════════════════════════════════════════════
header "Agent Teams"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [[ -f "$GLOBAL_SETTINGS" ]]; then
  HAS_TEAMS=$(python3 -c "
import json
with open('$GLOBAL_SETTINGS') as f: d = json.load(f)
print(d.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS',''))
" 2>/dev/null || echo "")
  if [[ "$HAS_TEAMS" == "1" ]]; then
    skip "이미 활성화됨"
  else
    python3 -c "
import json
with open('$GLOBAL_SETTINGS') as f: d = json.load(f)
d.setdefault('env',{})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
with open('$GLOBAL_SETTINGS','w') as f: json.dump(d, f, indent=2); f.write('\n')
"
    info "Agent Teams 활성화"
    SUMMARY+=("Agent Teams: 활성화")
  fi
else
  printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  }\n}\n' > "$GLOBAL_SETTINGS"
  info "Agent Teams 활성화 (settings.json 생성)"
  SUMMARY+=("Agent Teams: 신규 생성")
fi

# ══════════════════════════════════════════════════════════════
# 3. Hooks
# ══════════════════════════════════════════════════════════════
header "Hooks"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$PROJECT_PATH/.claude/hooks"
PROJ_SETTINGS="$PROJECT_PATH/.claude/settings.json"

if [[ "$OPT_HOOKS" != "true" ]]; then
  skip "스킵 (--no-hooks)"
elif [[ -d "$HOOKS_SRC" ]] && ls "$HOOKS_SRC"/*.sh &>/dev/null; then
  mkdir -p "$HOOKS_DST"
  cp "$HOOKS_SRC"/task-completed.sh "$HOOKS_SRC"/teammate-idle.sh "$HOOKS_DST/" 2>/dev/null || true
  chmod +x "$HOOKS_DST"/*.sh
  info "task-completed.sh, teammate-idle.sh → .claude/hooks/"

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
  info "settings.json에 hooks 등록"
  SUMMARY+=("Hooks: task-completed, teammate-idle")
else
  warn "hooks/ 디렉토리 없음"
fi

# ══════════════════════════════════════════════════════════════
# 4. External Agents
# ══════════════════════════════════════════════════════════════
header "외부 에이전트"
EXT_DIR="$SCRIPT_DIR/external-agents"
EXAMPLES_DIR="$EXT_DIR/examples"

# Map CLI name → agent directory (bash 3.2 compatible)
cli_to_agent() {
  case "$1" in
    gemini) echo "gemini-reviewer" ;;
    codex)  echo "codex-coder" ;;
    openai) echo "gpt-security" ;;
    *)      echo "" ;;
  esac
}

if [[ "$OPT_AGENTS" == "none" ]]; then
  skip "스킵 (--no-agents)"
else
  # CLI-based agents
  if [[ "$OPT_AGENTS" == "all" || "$OPT_AGENTS" == *"cli"* ]]; then
    for cli in gemini codex openai ollama; do
      if command -v "$cli" &>/dev/null; then
        example="$(cli_to_agent "$cli")"
        if [[ -n "$example" && -d "$EXAMPLES_DIR/$example" ]]; then
          if [[ -d "$EXT_DIR/$example" ]]; then
            skip "$example 이미 활성화됨"
          else
            cp -r "$EXAMPLES_DIR/$example" "$EXT_DIR/$example"
            info "$cli → $example 활성화"
            SUMMARY+=("에이전트(CLI): $example")
          fi
        elif [[ "$cli" == "ollama" ]]; then
          info "ollama 감지됨 (직접 구성: external-agents/_template/)"
        fi
      fi
    done
  fi

  # API-based agents
  if [[ "$OPT_AGENTS" == "all" || "$OPT_AGENTS" == *"api"* ]]; then
    api_found=false
    [[ -n "${OPENAI_API_KEY:-}" ]]    && { info "OPENAI_API_KEY 감지"; api_found=true; }
    [[ -n "${GEMINI_API_KEY:-}" ]]    && { info "GEMINI_API_KEY 감지"; api_found=true; }
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && { info "ANTHROPIC_API_KEY 감지"; api_found=true; }
    [[ -n "${OPENAI_BASE_URL:-}" ]]   && info "Proxy: $OPENAI_BASE_URL"

    if [[ "$api_found" == "true" ]]; then
      for api_agent in api-reviewer api-security; do
        if [[ -d "$EXAMPLES_DIR/$api_agent" ]]; then
          if [[ -d "$EXT_DIR/$api_agent" ]]; then
            skip "$api_agent 이미 활성화됨"
          else
            cp -r "$EXAMPLES_DIR/$api_agent" "$EXT_DIR/$api_agent"
            info "$api_agent 활성화"
            SUMMARY+=("에이전트(API): $api_agent")
          fi
        fi
      done
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# 5. Personas
# ══════════════════════════════════════════════════════════════
header "페르소나"
PERSONAS_SRC="$SCRIPT_DIR/personas"
PROJ_PERSONAS="$PROJECT_PATH/.claude/personas"

if [[ "$OPT_PERSONAS" == "none" ]]; then
  skip "스킵"
elif [[ -d "$PERSONAS_SRC" ]]; then
  # Build available persona list
  personas=()
  while IFS= read -r f; do personas+=("$f"); done \
    < <(find "$PERSONAS_SRC" -maxdepth 1 -name "*.md" -type f | sort)

  if [[ ${#personas[@]} -eq 0 ]]; then
    warn "personas/ 디렉토리에 .md 파일 없음"
  else
    mkdir -p "$PROJ_PERSONAS"
    names=()

    if [[ "$OPT_PERSONAS" == "all" ]]; then
      # Copy all personas
      for p in "${personas[@]}"; do
        _name="$(basename "$p" .md)"
        cp "$p" "$PROJ_PERSONAS/"
        names+=("$_name")
      done
    else
      # Copy selected personas by name
      IFS=',' read -ra picks <<< "$OPT_PERSONAS"
      for pick in "${picks[@]}"; do
        pick=$(echo "$pick" | tr -d ' ')
        matched=false
        for p in "${personas[@]}"; do
          _name="$(basename "$p" .md)"
          if [[ "$_name" == "$pick" ]]; then
            cp "$p" "$PROJ_PERSONAS/"
            names+=("$_name")
            matched=true
            break
          fi
        done
        if [[ "$matched" != "true" ]]; then
          warn "페르소나 '$pick' 없음 (사용 가능: $(for p in "${personas[@]}"; do printf "%s " "$(basename "$p" .md)"; done))"
        fi
      done
    fi

    if [[ ${#names[@]} -gt 0 ]]; then
      info "${#names[@]}개 페르소나: ${names[*]}"
      SUMMARY+=("페르소나: ${names[*]}")
    fi
  fi
else
  warn "personas/ 디렉토리 없음"
fi

# ══════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════
header "✓ 설정 완료"
if [[ ${#SUMMARY[@]} -gt 0 ]]; then
  for item in "${SUMMARY[@]}"; do printf "  ${_GRN}•${_R} %s\n" "$item"; done
fi
printf "\n  ${_B}다음 단계:${_R}\n"
printf "    ${_CYN}cd${_R} %s\n" "$PROJECT_PATH"
printf "    ${_CYN}claude${_R}\n"
printf "    ${_CYN}/teammates${_R} 로 팀 구성\n\n"
