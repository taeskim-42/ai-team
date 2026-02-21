#!/bin/bash
# setup.sh — Describe what you want to build, get a ready-to-go AI team.
#
# Interactive:
#   bash setup.sh
#
# Non-interactive:
#   bash setup.sh <project-path> "<description>"
#
# Resume from config:
#   bash setup.sh --config projects/foo/team.config.sh
#
# Examples:
#   bash setup.sh ~/my-app "Rails 8 backend + Swift iOS app"
#   bash setup.sh ~/dashboard "Next.js 14 + TypeScript dashboard"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ──
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRN=$'\033[32m'; _YEL=$'\033[33m'; _RED=$'\033[31m'; _GRY=$'\033[90m'; _WHT=$'\033[97m'
_s=$'\001'; _e=$'\002'

info()   { printf "  ${_GRN}✓${_R} %s\n" "$1"; }
warn()   { printf "  ${_YEL}→${_R} %s\n" "$1"; }
skip()   { printf "  ${_D}· %s${_R}\n" "$1"; }
err()    { printf "  ${_RED}✗${_R} %s\n" "$1"; }

# ── Projects directory ──
PROJECTS_DIR="$SCRIPT_DIR/projects"
mkdir -p "$PROJECTS_DIR"

# ══════════════════════════════════════════════════════════════
# i18n Language Packs
# ══════════════════════════════════════════════════════════════

_lang_en() {
  L_TITLE="AI Team Setup"
  L_SELECT="Select"
  L_YN="y/n"
  L_EXISTING="Existing projects:"
  L_NEW_PROJECT="+ New project"
  L_INVALID_CHOICE="Please select a valid number"
  L_DESCRIBE="What are you building?"
  L_DESC_HINT="e.g. Rails 8 backend + Swift iOS app. Fitness tracking service."
  L_DESC_REQUIRED="Project description is required"
  L_PATH="Project path"
  L_AI_SPIN="Generating AI team suggestion"
  L_AI_DONE="AI suggestion ready"
  L_AI_FALLBACK="Switching to keyword matching"
  L_TEAM_TITLE="Team"
  L_TEAM_ACCEPT="Enter=accept, e=edit"
  L_TEAM_EDIT_HINT="Enter persona numbers (comma-separated). Kent Beck (QA) is always included."
  L_INSTALL_TITLE="Install"
  L_DIR_CREATED="Directory created:"
  L_DIR_MISSING="Directory not found:"
  L_CREATE_Q="Create it?"
  L_DIR_CREATED_GIT="Created (git init)"
  L_GH_CREATE_Q="Create GitHub repo too?"
  L_GH_LOGIN="GitHub login required..."
  L_GH_NAME="GitHub repo name"
  L_GH_VIS="Visibility (public/private)"
  L_GH_OK="GitHub repo created"
  L_GH_FAIL="GitHub repo creation failed (local created)"
  L_NUM_RANGE="Enter a number between %d and %d"
  L_SPIN_SEC="s"
  L_CONFIG_SAVED="Config saved:"
  L_CLAUDEMD_TITLE="CLAUDE.md"
  L_CLAUDEMD_DONE="CLAUDE.md generated"
  L_DONE_TITLE="Done"
  L_DONE_MSG="Tell it what to build. The PM leads the team."
  L_PROJECT="Project:"
  L_PERSONAS_FMT="%d personas installed"
  L_HOOKS="Hooks (type check + test + file size enforcement)"
  L_HOOKS_LOCKED="Core hook files protected (read-only)"
  L_AGENT_TEAMS_ON="Agent Teams enabled"
  L_AGENT_TEAMS_ALREADY="Agent Teams already enabled"
  L_GIT_INIT="git init"
  L_EXT_AGENT="External agent:"
  L_EXT_NONE="No external agents (CLI/API not detected)"
  L_NO_MATCH="No matching keywords — installing all personas"
}

_lang_ko() {
  L_TITLE="AI Team Setup"
  L_SELECT="선택"
  L_YN="y/n"
  L_EXISTING="기존 프로젝트:"
  L_NEW_PROJECT="+ 새 프로젝트"
  L_INVALID_CHOICE="올바른 번호를 선택해주세요"
  L_DESCRIBE="무엇을 만들 건가요?"
  L_DESC_HINT="예: Rails 8 백엔드 + Swift iOS 앱. 운동 추적 서비스."
  L_DESC_REQUIRED="프로젝트 설명을 입력해주세요"
  L_PATH="프로젝트 경로"
  L_AI_SPIN="AI 팀 제안 생성 중"
  L_AI_DONE="AI 제안 완료"
  L_AI_FALLBACK="키워드 매칭으로 전환"
  L_TEAM_TITLE="팀 구성"
  L_TEAM_ACCEPT="Enter=수락, e=편집"
  L_TEAM_EDIT_HINT="페르소나 번호를 입력하세요 (쉼표 구분). Kent Beck(QA)은 항상 포함됩니다."
  L_INSTALL_TITLE="설치"
  L_DIR_CREATED="디렉토리 생성:"
  L_DIR_MISSING="디렉토리 없음:"
  L_CREATE_Q="생성할까요?"
  L_DIR_CREATED_GIT="생성 완료 (git init)"
  L_GH_CREATE_Q="GitHub 리포도 생성할까요?"
  L_GH_LOGIN="GitHub 로그인이 필요합니다..."
  L_GH_NAME="GitHub repo 이름"
  L_GH_VIS="공개 범위 (public/private)"
  L_GH_OK="GitHub 리포 생성 완료"
  L_GH_FAIL="GitHub 리포 생성 실패 (로컬은 생성됨)"
  L_NUM_RANGE="%d에서 %d 사이의 숫자를 입력해주세요"
  L_SPIN_SEC="초"
  L_CONFIG_SAVED="Config 저장 완료:"
  L_CLAUDEMD_TITLE="CLAUDE.md"
  L_CLAUDEMD_DONE="CLAUDE.md 생성"
  L_DONE_TITLE="완료"
  L_DONE_MSG="만들고 싶은 걸 말하세요. PM이 팀을 이끕니다."
  L_PROJECT="프로젝트:"
  L_PERSONAS_FMT="페르소나 %d개 설치"
  L_HOOKS="Hooks (타입 체크 + 테스트 + 파일 크기 강제)"
  L_HOOKS_LOCKED="핵심 Hook 파일 보호 (read-only)"
  L_AGENT_TEAMS_ON="Agent Teams 활성화"
  L_AGENT_TEAMS_ALREADY="Agent Teams 이미 활성화됨"
  L_GIT_INIT="git init"
  L_EXT_AGENT="외부 에이전트:"
  L_EXT_NONE="외부 에이전트 없음 (CLI/API 미감지)"
  L_NO_MATCH="매칭된 기술 키워드 없음 — 전체 페르소나 설치"
}

# Load saved language preference
_lang_file="$SCRIPT_DIR/.ai-team-lang"
_need_lang_select=false
if [ -f "$_lang_file" ]; then
  LANG_CODE=$(cat "$_lang_file")
  _lang_"$LANG_CODE" 2>/dev/null || { LANG_CODE="en"; _lang_en; }
else
  _need_lang_select=true
  LANG_CODE="en"
  _lang_en
fi

# ══════════════════════════════════════════════════════════════
# Input Helpers
# ══════════════════════════════════════════════════════════════

_ask() {
  local prompt="$1" default="$2" var="$3"
  local rl_prompt
  if [ -n "$default" ]; then
    rl_prompt="  ${_s}${_CYN}${_e}${prompt}${_s}${_R}${_e} ${_s}${_GRY}${_e}[${default}]${_s}${_R}${_e}: "
  else
    rl_prompt="  ${_s}${_CYN}${_e}${prompt}${_s}${_R}${_e}: "
  fi
  read -e -r -p "$rl_prompt" val
  eval "$var=\"\${val:-\$default}\""
}

_ask_path() {
  local prompt="$1" default="$2" var="$3"
  while true; do
    _ask "$prompt" "$default" "$var"
    local p="${!var}"
    p="${p/#\~/$HOME}"
    eval "$var=\"$p\""
    [ -d "$p" ] && break

    printf "  ${_YEL}⚠ %s %s${_R}\n" "$L_DIR_MISSING" "$p"
    _ask "$L_CREATE_Q ($L_YN)" "y" "_create_dir"
    if [[ "$_create_dir" =~ ^[yY] ]]; then
      mkdir -p "$p"
      ( cd "$p" && git init -q )
      printf "  ${_GRN}✓ %s${_R}\n" "$L_DIR_CREATED_GIT"

      # Offer GitHub repo creation if gh is available
      if command -v gh &>/dev/null; then
        _ask "$L_GH_CREATE_Q ($L_YN)" "n" "_create_gh"
        if [[ "$_create_gh" =~ ^[yY] ]]; then
          if ! gh auth status &>/dev/null 2>&1; then
            printf "  ${_GRY}%s${_R}\n" "$L_GH_LOGIN"
            gh auth login
          fi
          local _gh_name
          _gh_name=$(basename "$p")
          _ask "$L_GH_NAME" "$_gh_name" "_gh_name"
          _ask "$L_GH_VIS" "private" "_gh_vis"
          if ( cd "$p" && gh repo create "$_gh_name" --"$_gh_vis" --source=. ) 2>&1; then
            printf "  ${_GRN}✓ %s${_R}\n" "$L_GH_OK"
          else
            printf "  ${_YEL}⚠ %s${_R}\n" "$L_GH_FAIL"
          fi
        fi
      fi
      break
    fi
    # User said no — loop back to ask path again
  done
}

_ask_int() {
  local prompt="$1" default="$2" var="$3" min="${4:-1}" max="${5:-99}"
  while true; do
    _ask "$prompt" "$default" "$var"
    local v="${!var}"
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$min" ] && [ "$v" -le "$max" ]; then
      break
    fi
    printf "  ${_RED}✗ $(printf "$L_NUM_RANGE" "$min" "$max")${_R}\n"
  done
}

# ── Spinner (background process with elapsed time) ──
_spinner_pid=""
_spin_start() {
  local msg="$1"
  {
    local spn="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" i=0
    while true; do
      printf "\r  %s ${_GRY}%s %d%s${_R}  " "${spn:$((i % 10)):1}" "$msg" "$((i / 5))" "$L_SPIN_SEC"
      sleep 0.2
      i=$((i + 1))
    done
  } &
  _spinner_pid=$!
}
_spin_stop() {
  if [ -n "$_spinner_pid" ]; then
    kill "$_spinner_pid" 2>/dev/null; wait "$_spinner_pid" 2>/dev/null || true
    _spinner_pid=""
    printf "\r\033[K"
  fi
}
trap '_spin_stop' EXIT

# ── Persona helpers ──
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

# ── Config save ──
_save_config() {
  local slug
  slug=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  [[ -z "$slug" ]] && slug="my-project"
  local cfg_dir="$PROJECTS_DIR/$slug"
  mkdir -p "$cfg_dir"
  local cfg_file="$cfg_dir/team.config.sh"
  {
    printf '# AI Team — setup.sh config\n'
    printf 'PROJECT_NAME="%s"\n' "$PROJECT_NAME"
    printf 'PROJECT_PATH="%s"\n' "$PROJECT_PATH"
    printf 'DESCRIPTION="%s"\n' "$DESCRIPTION"
    printf 'LANG_CODE="%s"\n' "$LANG_CODE"
    printf 'PERSONA_COUNT=%d\n' "${#selected_personas[@]}"
    local i=1
    for p in ${selected_personas[@]+"${selected_personas[@]}"}; do
      printf 'PERSONA_%d="%s"\n' "$i" "$p"
      i=$((i + 1))
    done
  } > "$cfg_file"
  info "$L_CONFIG_SAVED $cfg_file"
}

# ── Deduplicate helper ──
_dedup_personas() {
  unique_personas=()
  for p in ${selected_personas[@]+"${selected_personas[@]}"}; do
    dupe=false
    for u in ${unique_personas[@]+"${unique_personas[@]}"}; do
      [[ "$u" == "$p" ]] && { dupe=true; break; }
    done
    [[ "$dupe" == "false" ]] && unique_personas+=("$p")
  done
  selected_personas=(${unique_personas[@]+"${unique_personas[@]}"})
}

# ══════════════════════════════════════════════════════════════
# Argument Parsing (3 entry paths)
# ══════════════════════════════════════════════════════════════

MODE=""
CONFIG_FILE=""
PROJECT_PATH=""
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      [[ -z "$CONFIG_FILE" ]] && { err "--config requires a path"; exit 1; }
      [[ "$CONFIG_FILE" != /* ]] && CONFIG_FILE="$SCRIPT_DIR/$CONFIG_FILE"
      [[ ! -f "$CONFIG_FILE" ]] && { err "Config not found: $CONFIG_FILE"; exit 1; }
      MODE="config"
      shift 2
      ;;
    -*)
      err "Unknown option: $1"; exit 1
      ;;
    *)
      if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$1"
      elif [[ -z "$DESCRIPTION" ]]; then
        DESCRIPTION="$1"
      fi
      shift
      ;;
  esac
done

# Determine mode
if [[ "$MODE" == "config" ]]; then
  : # Already set
elif [[ -n "$PROJECT_PATH" && -n "$DESCRIPTION" ]]; then
  MODE="noninteractive"
elif [[ -n "$PROJECT_PATH" ]]; then
  MODE="semi-interactive"
else
  MODE="interactive"
fi

# ══════════════════════════════════════════════════════════════
# Language Selection (interactive only)
# ══════════════════════════════════════════════════════════════

if [[ "$_need_lang_select" == "true" && "$MODE" != "noninteractive" && "$MODE" != "config" ]]; then
  printf "\n  ${_WHT}Language:${_R} 1) English  2) 한국어\n"
  read -e -r -p "  ${L_SELECT} [1]: " _lang_choice
  _lang_choice="${_lang_choice:-1}"
  case "$_lang_choice" in
    2) LANG_CODE="ko" ;;
    *) LANG_CODE="en" ;;
  esac
  echo "$LANG_CODE" > "$_lang_file"
  _lang_"$LANG_CODE"
fi

printf "\n${_B}🚀 ${L_TITLE}${_R}\n"

# ══════════════════════════════════════════════════════════════
# Config Mode → load and jump to install
# ══════════════════════════════════════════════════════════════

selected_personas=()

_load_config_personas() {
  local cfg="$1"
  source "$cfg"
  [[ -z "${PROJECT_PATH:-}" ]] && { err "Config missing PROJECT_PATH"; exit 1; }
  [[ -z "${DESCRIPTION:-}" ]] && { err "Config missing DESCRIPTION"; exit 1; }
  PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_PATH")}"
  # Load language from config
  if [[ -n "${LANG_CODE:-}" ]]; then
    _lang_"$LANG_CODE" 2>/dev/null || _lang_en
  fi
  # Reconstruct personas from PERSONA_1, PERSONA_2, ...
  selected_personas=()
  _pi=1
  while true; do
    eval "_pval=\${PERSONA_${_pi}:-}"
    [[ -z "$_pval" ]] && break
    selected_personas+=("$_pval")
    _pi=$((_pi + 1))
  done
  # Fallback if no personas in config
  if [[ ${#selected_personas[@]} -eq 0 ]]; then
    for f in "$SCRIPT_DIR"/personas/*.md; do
      [[ -f "$f" ]] || continue
      selected_personas+=("$(basename "$f" .md)")
    done
  fi
}

if [[ "$MODE" == "config" ]]; then
  _load_config_personas "$CONFIG_FILE"
  printf "\n  ${_D}%s %s — %s${_R}\n" "$L_PROJECT" "$PROJECT_NAME" "$DESCRIPTION"

# ══════════════════════════════════════════════════════════════
# Project Selector (interactive, no args)
# ══════════════════════════════════════════════════════════════

elif [[ "$MODE" == "interactive" ]]; then
  # Scan for setup.sh configs (must have PROJECT_PATH field)
  _proj_configs=()
  _proj_names=()
  _proj_paths=()
  for _cfg in "$PROJECTS_DIR"/*/team.config.sh; do
    [[ -f "$_cfg" ]] || continue
    grep -q '^PROJECT_PATH=' "$_cfg" 2>/dev/null || continue
    _proj_configs+=("$_cfg")
    _pn=$(grep '^PROJECT_NAME=' "$_cfg" | head -1 | sed 's/^PROJECT_NAME=//;s/^"//;s/"$//')
    _pp=$(grep '^PROJECT_PATH=' "$_cfg" | head -1 | sed 's/^PROJECT_PATH=//;s/^"//;s/"$//')
    _proj_names+=("${_pn:-unknown}")
    _proj_paths+=("${_pp:-unknown}")
  done

  if [[ ${#_proj_configs[@]} -gt 0 ]]; then
    printf "\n  ${_B}${L_EXISTING}${_R}\n"
    _idx=1
    for _i in $(seq 0 $((${#_proj_configs[@]} - 1))); do
      _display_path="${_proj_paths[$_i]/#$HOME/\~}"
      printf "    ${_CYN}%d)${_R} %s ${_GRY}— %s${_R}\n" "$_idx" "${_proj_names[$_i]}" "$_display_path"
      _idx=$((_idx + 1))
    done
    printf "    ${_CYN}%d)${_R} ${_GRN}%s${_R}\n" "$_idx" "$L_NEW_PROJECT"

    _max=$_idx
    read -e -r -p "  ${_s}${_CYN}${_e}${L_SELECT}${_s}${_R}${_e} ${_s}${_GRY}${_e}[1]${_s}${_R}${_e}: " _choice
    _choice="${_choice:-1}"

    if [[ "$_choice" =~ ^[0-9]+$ ]] && [ "$_choice" -ge 1 ] && [ "$_choice" -le "$_max" ]; then
      if [ "$_choice" -lt "$_max" ]; then
        # Existing project selected → load config, skip wizard
        _sel_idx=$((_choice - 1))
        _load_config_personas "${_proj_configs[$_sel_idx]}"
        printf "\n  ${_D}%s %s — %s${_R}\n" "$L_PROJECT" "$PROJECT_NAME" "$DESCRIPTION"
        MODE="config"
      fi
      # else: _choice == _max → new project, fall through to wizard
    else
      err "$L_INVALID_CHOICE"; exit 1
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# Interactive Wizard (new project)
# ══════════════════════════════════════════════════════════════

if [[ "$MODE" != "config" ]]; then

  # ── Get description ──
  if [[ -z "$DESCRIPTION" ]]; then
    printf "\n  ${_D}${L_DESC_HINT}${_R}\n"
    _ask "$L_DESCRIBE" "" "DESCRIPTION"
    [[ -z "$DESCRIPTION" ]] && { err "$L_DESC_REQUIRED"; exit 1; }
  fi

  # ── Get project path ──
  if [[ -z "$PROJECT_PATH" ]]; then
    _suggested=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9 ]//g' | awk '{print $1}' | head -c 30)
    _suggested="${_suggested:-my-project}"
    _default_path="$HOME/Projects/$_suggested"
    printf "\n"
    _ask_path "$L_PATH" "$_default_path" "PROJECT_PATH"
  else
    # Resolve provided path
    PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
    if [[ -d "$PROJECT_PATH" ]]; then
      PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
    elif [[ "$PROJECT_PATH" != /* ]]; then
      PROJECT_PATH="$(pwd)/$PROJECT_PATH"
    fi
  fi

  PROJECT_NAME="$(basename "$PROJECT_PATH")"
  printf "\n  ${_D}%s %s — %s${_R}\n" "$L_PROJECT" "$PROJECT_NAME" "$DESCRIPTION"

  # ══════════════════════════════════════════════════════════════
  # Team Selection: AI suggestion or keyword matching
  # ══════════════════════════════════════════════════════════════
  printf "\n${_B}${_CYN}━━━ ${L_TEAM_TITLE} ━━━${_R}\n\n"

  USE_AI=false
  ai_personas=()

  # Try AI generation (skip in non-interactive for speed)
  if command -v claude &>/dev/null && [[ "$MODE" != "noninteractive" ]]; then
    _ai_prompt='You suggest team members for a software project.
Output ONLY lines in this exact format (no quotes, no comments, no blank lines):
PERSONA=name
Where name is one of: dhh, chris-lattner, dan-abramov, guillermo-rauch, ryan-dahl, rob-pike, guido-van-rossum
Rules:
- Pick 1-3 personas MAX. Be selective — only the BEST matches for the CORE tech stack.
- A native iOS app does NOT need React or Node personas.
- A web app does NOT need Swift personas.
- Do NOT guess — if a technology is not mentioned or clearly implied, skip that persona.
- Always include kent-beck last for QA.
Output NOTHING else.'

    _ai_file=$(mktemp)
    _spin_start "$L_AI_SPIN"
    if claude -p --output-format text \
      --append-system-prompt "$_ai_prompt" \
      "Suggest team for: ${DESCRIPTION}" > "$_ai_file" 2>/dev/null; then
      while IFS='=' read -r key val; do
        [[ "$key" == "PERSONA" && -n "$val" ]] && ai_personas+=("$val")
      done < "$_ai_file"
      [[ ${#ai_personas[@]} -gt 0 ]] && USE_AI=true
    fi
    _spin_stop
    rm -f "$_ai_file"

    if [[ "$USE_AI" == "true" ]]; then
      info "$L_AI_DONE"
    else
      warn "$L_AI_FALLBACK"
    fi
  fi

  if [[ "$USE_AI" == "true" ]]; then
    selected_personas=("${ai_personas[@]}")
  else
    # Keyword matching fallback
    DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')
    selected_personas=()
    match_persona "rails ruby activerecord sidekiq rspec erb"              dhh              || true
    match_persona "swift ios swiftui xcode apple uikit cocoa"              chris-lattner    || true
    match_persona "react redux jsx tsx vite frontend"                      dan-abramov      || true
    match_persona "next nextjs vercel turborepo t3"                        guillermo-rauch  || true
    match_persona "node deno bun express koa hono"                         ryan-dahl        || true
    match_persona "go golang grpc protobuf kubernetes k8s"                 rob-pike         || true
    match_persona "python django flask fastapi pytorch tensorflow pandas"  guido-van-rossum || true
    selected_personas+=("kent-beck")
  fi

  # Deduplicate
  _dedup_personas

  # Fallback: if only kent-beck or empty, use all
  if [[ ${#selected_personas[@]} -le 1 ]]; then
    warn "$L_NO_MATCH"
    selected_personas=()
    for f in "$SCRIPT_DIR"/personas/*.md; do
      [[ -f "$f" ]] || continue
      selected_personas+=("$(basename "$f" .md)")
    done
  fi

  # Display suggestion
  for p in "${selected_personas[@]}"; do
    info "$(persona_label "$p")"
  done

  # ── User confirmation (interactive modes only) ──
  if [[ "$MODE" != "noninteractive" ]]; then
    printf "\n  ${_D}${L_TEAM_ACCEPT}${_R}\n"
    read -e -r -p "  > " _team_action
    _team_action="${_team_action:-}"

    if [[ "$_team_action" == "e" || "$_team_action" == "E" ]]; then
      # Edit mode: show all personas except kent-beck (always included)
      all_personas=()
      for f in "$SCRIPT_DIR"/personas/*.md; do
        [[ -f "$f" ]] || continue
        _name="$(basename "$f" .md)"
        [[ "$_name" == "kent-beck" ]] && continue
        all_personas+=("$_name")
      done

      printf "\n"
      _idx=1
      for _ap in "${all_personas[@]}"; do
        # Mark currently selected with *
        _mark=" "
        for _sp in ${selected_personas[@]+"${selected_personas[@]}"}; do
          [[ "$_sp" == "$_ap" ]] && { _mark="*"; break; }
        done
        printf "    ${_CYN}%d)${_R} [%s] %s\n" "$_idx" "$_mark" "$(persona_label "$_ap")"
        _idx=$((_idx + 1))
      done
      printf "    ${_GRN}✓)${_R} %s\n" "$(persona_label kent-beck)"
      printf "\n  ${_D}%s${_R}\n" "$L_TEAM_EDIT_HINT"
      read -e -r -p "  > " _edit_nums

      # Parse comma-separated numbers
      selected_personas=()
      IFS=',' read -ra _nums <<< "$_edit_nums"
      for _n in "${_nums[@]}"; do
        _n=$(echo "$_n" | tr -d ' ')
        if [[ "$_n" =~ ^[0-9]+$ ]] && [ "$_n" -ge 1 ] && [ "$_n" -le ${#all_personas[@]} ]; then
          selected_personas+=("${all_personas[$((_n - 1))]}")
        fi
      done
      # Always add kent-beck
      selected_personas+=("kent-beck")

      # Deduplicate
      _dedup_personas

      # Fallback if empty selection (only kent-beck)
      if [[ ${#selected_personas[@]} -le 1 ]]; then
        warn "$L_NO_MATCH"
        selected_personas=()
        for f in "$SCRIPT_DIR"/personas/*.md; do
          [[ -f "$f" ]] || continue
          selected_personas+=("$(basename "$f" .md)")
        done
      fi

      printf "\n"
      for p in "${selected_personas[@]}"; do
        info "$(persona_label "$p")"
      done
    fi
    # else: Enter = accept current selection
  fi

  # ── Save config ──
  _save_config
fi

# ══════════════════════════════════════════════════════════════
# Install
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ ${L_INSTALL_TITLE} ━━━${_R}\n\n"

# Project directory
if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH"
  info "$L_DIR_CREATED $PROJECT_PATH"
  if [[ ! -d "$PROJECT_PATH/.git" ]]; then
    ( cd "$PROJECT_PATH" && git init -q )
    info "$L_GIT_INIT"
  fi
else
  info "$L_PROJECT $PROJECT_PATH"
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
    info "$L_AGENT_TEAMS_ON"
  else
    skip "$L_AGENT_TEAMS_ALREADY"
  fi
else
  printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  }\n}\n' > "$GLOBAL_SETTINGS"
  info "$L_AGENT_TEAMS_ON"
fi

# Hooks
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$PROJECT_PATH/.claude/hooks"
PROJ_SETTINGS="$PROJECT_PATH/.claude/settings.json"

if [[ -d "$HOOKS_SRC" ]] && ls "$HOOKS_SRC"/*.sh &>/dev/null; then
  mkdir -p "$HOOKS_DST"
  cp "$HOOKS_SRC"/task-completed.sh "$HOOKS_SRC"/teammate-idle.sh "$HOOKS_SRC"/guard-hooks.sh "$HOOKS_DST/" 2>/dev/null || true
  chmod +x "$HOOKS_DST"/*.sh

  _PROJ_SETTINGS="$PROJ_SETTINGS" _HOOKS_DST="$HOOKS_DST" python3 << 'PYEOF'
import json, os
s = os.environ["_PROJ_SETTINGS"]
h = os.environ["_HOOKS_DST"]
d = json.load(open(s)) if os.path.exists(s) else {}

# TaskCompleted, TeammateIdle hooks
for name, event in {"task-completed.sh":"TaskCompleted","teammate-idle.sh":"TeammateIdle"}.items():
    path = os.path.join(h, name)
    if not os.path.exists(path): continue
    d.setdefault("hooks",{}).setdefault(event,[])
    if not any(e.get("command")==path for e in d["hooks"][event]):
        d["hooks"][event].append({"command": path})

# PreToolUse guard — blocks unauthorized edits to protected hooks
guard = os.path.join(h, "guard-hooks.sh")
if os.path.exists(guard):
    d.setdefault("hooks",{}).setdefault("PreToolUse",[])
    if not any(e.get("command")==guard for e in d["hooks"]["PreToolUse"]):
        d["hooks"]["PreToolUse"].append({"matcher": "Edit|Write", "command": guard})

os.makedirs(os.path.dirname(s), exist_ok=True)
with open(s,"w") as f: json.dump(d, f, indent=2); f.write("\n")
PYEOF
  info "$L_HOOKS"

  # Lock core enforcement hooks — read-only (chmod 444)
  chmod 444 "$HOOKS_DST"/task-completed.sh "$HOOKS_DST"/teammate-idle.sh "$HOOKS_DST"/guard-hooks.sh
  info "$L_HOOKS_LOCKED"
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
      info "$L_EXT_AGENT $example ($cli CLI)"
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
      info "$L_EXT_AGENT $api_agent (API)"
      agent_activated=true
    fi
  done
fi
[[ "$agent_activated" == "false" ]] && skip "$L_EXT_NONE"

# Personas
PROJ_PERSONAS="$PROJECT_PATH/.claude/personas"
mkdir -p "$PROJ_PERSONAS"
copied=0
for persona in "${selected_personas[@]}"; do
  src="$SCRIPT_DIR/personas/$persona.md"
  [[ -f "$src" ]] && { cp "$src" "$PROJ_PERSONAS/"; copied=$((copied + 1)); }
done
info "$(printf "$L_PERSONAS_FMT" "$copied")"

# ══════════════════════════════════════════════════════════════
# Generate CLAUDE.md
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ ${L_CLAUDEMD_TITLE} ━━━${_R}\n\n"

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

### Protected Files (DO NOT MODIFY)
The following files enforce code quality and MUST NOT be modified without explicit user approval:
- \`.claude/hooks/task-completed.sh\` — Type check + test + file size enforcement
- \`.claude/hooks/teammate-idle.sh\` — Output format enforcement
- \`.claude/hooks/guard-hooks.sh\` — This protection mechanism

These files are read-only (chmod 444) and guarded by a PreToolUse hook.
If modification is genuinely needed:
1. Explain WHY to the user and get explicit approval
2. Run: \`chmod 644 <file>\` then \`touch /tmp/.ai-team-hook-edit-approved\`
3. Make the edit (one-time pass, token auto-consumed)
4. Run: \`chmod 444 <file>\` to re-lock

### Code Style
- No function exceeds ~30 lines
- No file exceeds ~300 lines — split into focused modules
- No magic numbers or strings — use named constants
- Names are self-documenting
- Errors include context (not silently swallowed)
- Follow existing project conventions
MDEOF

info "$L_CLAUDEMD_DONE"

# ══════════════════════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════════════════════
printf "\n${_B}${_CYN}━━━ ✓ ${L_DONE_TITLE} ━━━${_R}\n\n"
printf "  ${_CYN}cd${_R} %s\n" "$PROJECT_PATH"
printf "  ${_CYN}claude${_R}\n"
printf "  %s\n\n" "$L_DONE_MSG"
