#!/bin/bash
# setup.sh — One-command setup wizard for AI Team + Claude Code Agent Teams
# Usage: bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors & helpers ──
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRN=$'\033[32m'; _YEL=$'\033[33m'; _RED=$'\033[31m'
_s=$'\001'; _e=$'\002'  # readline-safe ANSI (Korean input support)

info()   { printf "  ${_GRN}✓${_R} %s\n" "$1"; }
warn()   { printf "  ${_YEL}→${_R} %s\n" "$1"; }
skip()   { printf "  ${_D}· 스킵: %s${_R}\n" "$1"; }
err()    { printf "  ${_RED}✗${_R} %s\n" "$1"; }
header() { printf "\n${_B}${_CYN}━━━ %s ━━━${_R}\n\n" "$1"; }

SUMMARY=()
printf "\n${_B}🚀 AI Team Setup Wizard${_R}\n"

# ══════════════════════════════════════════════════════════════
# 1. Project path
# ══════════════════════════════════════════════════════════════
header "1. 프로젝트 경로"
read -e -r -p "${_s}${_CYN}${_e}개발할 프로젝트 경로${_s}${_R}${_e}: " PROJECT_PATH
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd || echo "$PROJECT_PATH")"

if [[ ! -d "$PROJECT_PATH" ]]; then
  read -e -r -p "  디렉토리가 없습니다. 생성할까요? (Y/n): " yn
  if [[ "${yn:-Y}" =~ ^[Yy]$ ]]; then
    mkdir -p "$PROJECT_PATH"
    info "디렉토리 생성: $PROJECT_PATH"
  else
    err "취소됨"; exit 1
  fi
fi
SUMMARY+=("프로젝트: $PROJECT_PATH")

# ══════════════════════════════════════════════════════════════
# 2. Agent Teams activation
# ══════════════════════════════════════════════════════════════
header "2. Agent Teams 활성화"
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
    info "~/.claude/settings.json에 Agent Teams 활성화"
    SUMMARY+=("Agent Teams: 활성화")
  fi
else
  printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  }\n}\n' > "$GLOBAL_SETTINGS"
  info "~/.claude/settings.json 생성 + Agent Teams 활성화"
  SUMMARY+=("Agent Teams: 신규 생성")
fi

# ══════════════════════════════════════════════════════════════
# 3. Hooks
# ══════════════════════════════════════════════════════════════
header "3. Hooks 설치"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$PROJECT_PATH/.claude/hooks"
PROJ_SETTINGS="$PROJECT_PATH/.claude/settings.json"

if [[ -d "$HOOKS_SRC" ]] && ls "$HOOKS_SRC"/*.sh &>/dev/null; then
  mkdir -p "$HOOKS_DST"
  cp "$HOOKS_SRC"/task-completed.sh "$HOOKS_SRC"/teammate-idle.sh "$HOOKS_DST/" 2>/dev/null || true
  chmod +x "$HOOKS_DST"/*.sh
  info "hooks → .claude/hooks/ 복사 완료"

  _PROJ_SETTINGS="$PROJ_SETTINGS" _HOOKS_DST="$HOOKS_DST" python3 << 'PYEOF'
import json, os, glob
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
  info "프로젝트 .claude/settings.json에 hooks 등록"
  SUMMARY+=("Hooks: task-completed, teammate-idle")
else
  warn "hooks/ 디렉토리 없음 — 스킵"
fi

# ══════════════════════════════════════════════════════════════
# 4. External Agents
# ══════════════════════════════════════════════════════════════
header "4. 외부 에이전트"
EXT_DIR="$SCRIPT_DIR/external-agents"
EXAMPLES_DIR="$EXT_DIR/examples"

# Map CLI name → agent directory (bash 3.2 compatible, no associative arrays)
cli_to_agent() {
  case "$1" in
    gemini) echo "gemini-reviewer" ;;
    codex)  echo "codex-coder" ;;
    openai) echo "gpt-security" ;;
    *)      echo "" ;;
  esac
}
detected=()
for cli in gemini codex openai ollama; do
  command -v "$cli" &>/dev/null && { detected+=("$cli"); info "$cli CLI 감지됨"; }
done

# Phase 1: CLI-based agents
if [[ ${#detected[@]} -gt 0 ]]; then
  for cli in "${detected[@]}"; do
    example="$(cli_to_agent "$cli")"
    if [[ -n "$example" && -d "$EXAMPLES_DIR/$example" ]]; then
      [[ -d "$EXT_DIR/$example" ]] && { skip "$example 이미 활성화됨"; continue; }
      read -e -r -p "  $cli → $example 활성화? (Y/n): " yn
      if [[ "${yn:-Y}" =~ ^[Yy]$ ]]; then
        cp -r "$EXAMPLES_DIR/$example" "$EXT_DIR/$example"
        info "$example → external-agents/ 활성화"
        SUMMARY+=("외부 에이전트: $example")
      fi
    elif [[ "$cli" == "ollama" ]]; then
      warn "ollama 감지됨 — external-agents/_template/에서 직접 만들어주세요"
    fi
  done
fi

# Phase 2: API-based agents (OpenAI-compatible endpoints)
api_detected=false
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  if [[ -n "${OPENAI_BASE_URL:-}" ]]; then
    info "OpenAI-compatible proxy 감지: $OPENAI_BASE_URL"
  else
    info "OpenAI API 키 감지됨"
  fi
  api_detected=true
fi
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  info "Gemini API 키 감지됨"
  api_detected=true
fi
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  info "Anthropic API 키 감지됨"
  api_detected=true
fi

if [[ "$api_detected" == "true" ]]; then
  echo ""
  echo "  API 기반 에이전트 (CLI 없이 API endpoint로 호출):"
  for api_agent in api-reviewer api-security; do
    if [[ -d "$EXAMPLES_DIR/$api_agent" ]]; then
      [[ -d "$EXT_DIR/$api_agent" ]] && { skip "$api_agent 이미 활성화됨"; continue; }
      read -e -r -p "  API → $api_agent 활성화? (Y/n): " yn
      if [[ "${yn:-Y}" =~ ^[Yy]$ ]]; then
        cp -r "$EXAMPLES_DIR/$api_agent" "$EXT_DIR/$api_agent"
        info "$api_agent → external-agents/ 활성화"
        SUMMARY+=("외부 에이전트(API): $api_agent")
      fi
    fi
  done
fi

if [[ ${#detected[@]} -eq 0 && "$api_detected" != "true" ]]; then
  warn "외부 LLM 감지 안됨 (CLI: gemini, codex, openai, ollama / API: OPENAI_API_KEY, GEMINI_API_KEY)"
fi

# ══════════════════════════════════════════════════════════════
# 5. Personas
# ══════════════════════════════════════════════════════════════
header "5. 페르소나 선택"
PERSONAS_SRC="$SCRIPT_DIR/personas"
PROJ_PERSONAS="$PROJECT_PATH/.claude/personas"
personas=()
if [[ -d "$PERSONAS_SRC" ]]; then
  while IFS= read -r f; do personas+=("$f"); done \
    < <(find "$PERSONAS_SRC" -maxdepth 1 -name "*.md" -type f | sort)
fi

if [[ ${#personas[@]} -gt 0 ]]; then
  echo "  사용 가능한 페르소나:"
  for i in "${!personas[@]}"; do
    printf "    ${_CYN}%d)${_R} %s\n" "$((i+1))" "$(basename "${personas[$i]}" .md)"
  done
  printf "    ${_D}0) 스킵${_R}\n\n"
  read -e -r -p "${_s}${_CYN}${_e}선택 (쉼표로 복수 선택, 예: 1,3)${_s}${_R}${_e}: " selection
  if [[ -n "$selection" && "$selection" != "0" ]]; then
    mkdir -p "$PROJ_PERSONAS"
    IFS=',' read -ra picks <<< "$selection"
    names=()
    for pick in "${picks[@]}"; do
      idx=$(( $(echo "$pick" | tr -d ' ') - 1 ))
      if [[ $idx -ge 0 && $idx -lt ${#personas[@]} ]]; then
        cp "${personas[$idx]}" "$PROJ_PERSONAS/"
        names+=("$(basename "${personas[$idx]}" .md)")
        info "${names[-1]} 복사"
      fi
    done
    [[ ${#names[@]} -gt 0 ]] && SUMMARY+=("페르소나: ${names[*]}")
  else
    skip "페르소나 선택 안함"
  fi
else
  warn "personas/ 디렉토리에 .md 파일 없음"
fi

# ══════════════════════════════════════════════════════════════
# 6. Summary
# ══════════════════════════════════════════════════════════════
header "✓ 설정 완료"
if [[ ${#SUMMARY[@]} -gt 0 ]]; then
  echo "  설정된 항목:"
  for item in "${SUMMARY[@]}"; do printf "    ${_GRN}•${_R} %s\n" "$item"; done
else
  echo "  변경 사항 없음 (모든 항목 이미 설정됨)"
fi
printf "\n  ${_B}다음 단계:${_R}\n"
printf "    ${_CYN}cd${_R} %s\n" "$PROJECT_PATH"
printf "    ${_CYN}claude${_R}\n"
printf "    ${_CYN}/teammates${_R} 로 팀 구성\n\n"
