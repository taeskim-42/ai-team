#!/bin/bash
# ai-team.sh — Dynamic AI Team Launcher
# Usage: bash ai-team.sh [project-name]
#
# Projects stored in: ./projects/<name>/team.config.sh
# No args → list existing projects or create new

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
mkdir -p "$PROJECTS_DIR"

# Resolve CONFIG from argument
if [ -n "${1:-}" ]; then
  # Arg can be: project name, project dir, or full config path
  if [ -f "$1" ]; then
    CONFIG="$1"
  elif [ -f "$PROJECTS_DIR/$1/team.config.sh" ]; then
    CONFIG="$PROJECTS_DIR/$1/team.config.sh"
  elif [ -f "$1/team.config.sh" ]; then
    CONFIG="$1/team.config.sh"
  else
    echo "ERROR: Project '$1' not found"
    exit 1
  fi
else
  CONFIG=""  # will be resolved by project selector
fi

# ══════════════════════════════════════════════════════════════
# Interactive Setup Wizard
# ══════════════════════════════════════════════════════════════

# Colors for wizard UI
_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRY=$'\033[90m'; _RED=$'\033[31m'
_GRN=$'\033[32m'; _YEL=$'\033[33m'; _WHT=$'\033[97m'

# ── i18n Language Packs ──
_lang_en() {
  L_SELECT="Select"; L_YN="y/n"
  L_EXISTING="Existing projects:"; L_NEW_PROJECT="+ New project"
  L_INVALID_CHOICE="Please select a valid number"
  L_SETUP_TITLE="AI Team Setup"
  L_MODE_AI="AI auto setup — describe your project"
  L_MODE_MANUAL="Manual setup — configure each item"
  L_CLAUDE_MISSING="(claude CLI not found → manual mode)"
  L_DESCRIBE="Describe your project:"
  L_DESC_REQUIRED="Description is required"
  L_AI_SPIN="Generating AI suggestions"; L_AI_FAIL="AI generation failed"
  L_AI_DONE="AI suggestions ready — Enter to accept, type to change"
  L_PROJ_NAME="Project name"; L_PROJ_REQUIRED="Project name is required"
  L_SESSION_HINT="tmux session name (alphanumeric, hyphens only)"
  L_SESSION_NAME="Session name"; L_SESSION_INVALID="Only alphanumeric, underscore, hyphen allowed"
  L_REPOS="Repositories"; L_HOW_MANY_REPOS="How many repos?"
  L_AGENTS="Agents"; L_HOW_MANY_AGENTS="How many agents?"
  L_OPTIONAL="Optional"
  L_DEPLOY="Deploy command (enter to skip)"
  L_FEEDBACK="Enable feedback pipeline?"
  L_PROMPT_FILE="prompt file (enter to skip)"
  L_DIR_MISSING="Directory not found:"; L_CREATE_Q="Create it?"
  L_DIR_CREATED="Created (git init)"
  L_GH_CREATE_Q="Create GitHub repo too?"; L_GH_LOGIN="GitHub login required..."
  L_GH_NAME="GitHub repo name"; L_GH_VIS="Visibility (public/private)"
  L_GH_OK="GitHub repo created"; L_GH_FAIL="GitHub repo creation failed (local created)"
  L_NUM_RANGE="Enter a number between %d and %d"
  L_COLOR_INVALID="Choose from: RED GRN YEL BLU MAG CYN WHT GRY"
  L_FILE_MISSING="File not found: %s (will be skipped)"
  L_SAVED="Config saved:"; L_STARTING="Starting AI Team..."
  L_SPIN_SEC="s"
}

_lang_ko() {
  L_SELECT="선택"; L_YN="y/n"
  L_EXISTING="기존 프로젝트:"; L_NEW_PROJECT="+ 새 프로젝트"
  L_INVALID_CHOICE="올바른 번호를 선택해주세요"
  L_SETUP_TITLE="AI Team Setup"
  L_MODE_AI="AI 자동 설정 — 프로젝트 설명만 입력"
  L_MODE_MANUAL="수동 설정 — 항목별 직접 입력"
  L_CLAUDE_MISSING="(claude CLI 없음 → 수동 설정 모드)"
  L_DESCRIBE="프로젝트를 설명해주세요:"
  L_DESC_REQUIRED="설명을 입력해주세요"
  L_AI_SPIN="AI 제안 생성 중"; L_AI_FAIL="AI 생성 실패"
  L_AI_DONE="AI 제안 완료 — Enter로 수락, 직접 입력으로 수정"
  L_PROJ_NAME="Project name"; L_PROJ_REQUIRED="Project name을 입력해주세요"
  L_SESSION_HINT="tmux 창 이름 (영문·숫자·하이픈만)"
  L_SESSION_NAME="Session name"; L_SESSION_INVALID="영문, 숫자, 하이픈만 사용 가능"
  L_REPOS="Repositories"; L_HOW_MANY_REPOS="리포 몇 개?"
  L_AGENTS="Agents"; L_HOW_MANY_AGENTS="에이전트 몇 명?"
  L_OPTIONAL="선택사항"
  L_DEPLOY="배포 명령어 (엔터로 건너뛰기)"
  L_FEEDBACK="피드백 파이프라인 활성화?"
  L_PROMPT_FILE="프롬프트 파일 (엔터로 건너뛰기)"
  L_DIR_MISSING="디렉토리 없음:"; L_CREATE_Q="생성할까요?"
  L_DIR_CREATED="생성 완료 (git init)"
  L_GH_CREATE_Q="GitHub 리포도 생성할까요?"; L_GH_LOGIN="GitHub 로그인이 필요합니다..."
  L_GH_NAME="GitHub repo 이름"; L_GH_VIS="공개 범위 (public/private)"
  L_GH_OK="GitHub 리포 생성 완료"; L_GH_FAIL="GitHub 리포 생성 실패 (로컬은 생성됨)"
  L_NUM_RANGE="%d에서 %d 사이의 숫자를 입력해주세요"
  L_COLOR_INVALID="선택 가능: RED GRN YEL BLU MAG CYN WHT GRY"
  L_FILE_MISSING="파일 없음: %s (건너뜀)"
  L_SAVED="Config 저장 완료:"; L_STARTING="AI Team 시작 중..."
  L_SPIN_SEC="초"
}

# Load saved language or select
_lang_file="$SCRIPT_DIR/.ai-team-lang"
if [ -n "$CONFIG" ]; then
  # Direct project run — use saved lang or default to en
  LANG_CODE="en"
  [ -f "$_lang_file" ] && LANG_CODE=$(cat "$_lang_file")
  _lang_"$LANG_CODE"
else
  if [ -f "$_lang_file" ]; then
    LANG_CODE=$(cat "$_lang_file")
    _lang_"$LANG_CODE"
  else
    printf "\n  ${_WHT}Language:${_R} 1) English  2) 한국어\n"
    read -e -r -p "  Select [1]: " _lang_choice
    _lang_choice="${_lang_choice:-1}"
    case "$_lang_choice" in
      2) LANG_CODE="ko" ;;
      *) LANG_CODE="en" ;;
    esac
    echo "$LANG_CODE" > "$_lang_file"
    _lang_"$LANG_CODE"
  fi
fi

_ask() {
  local prompt="$1" default="$2" var="$3"
  # \001/\002 = readline markers for non-printing chars
  local _s=$'\001' _e=$'\002'
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

    # Directory doesn't exist — offer to create
    printf "  ${_YEL}⚠ %s %s${_R}\n" "$L_DIR_MISSING" "$p"
    _ask "$L_CREATE_Q ($L_YN)" "y" "_create_dir"
    if [[ "$_create_dir" =~ ^[yY] ]]; then
      mkdir -p "$p"
      ( cd "$p" && git init -q )
      printf "  ${_GRN}✓ %s${_R}\n" "$L_DIR_CREATED"

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

_ask_session_name() {
  local prompt="$1" default="$2" var="$3"
  while true; do
    _ask "$prompt" "$default" "$var"
    local v="${!var}"
    if [[ "$v" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    fi
    printf "  ${_RED}✗ %s${_R}\n" "$L_SESSION_INVALID"
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
    printf "  ${_RED}✗ ${L_NUM_RANGE}${_R}\n" "$min" "$max"
  done
}

_ask_color() {
  local prompt="$1" default="$2" var="$3"
  while true; do
    _ask "$prompt" "$default" "$var"
    local v="${!var}"
    v=$(echo "$v" | tr '[:lower:]' '[:upper:]')
    eval "$var=\"$v\""
    case "$v" in
      RED|GRN|YEL|BLU|MAG|CYN|WHT|GRY) break ;;
      *) printf "  ${_RED}✗ %s${_R}\n" "$L_COLOR_INVALID" ;;
    esac
  done
}

_ask_repo_index() {
  local prompt="$1" default="$2" var="$3" max="$4"
  while true; do
    _ask "$prompt" "$default" "$var"
    local v="${!var}"
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ]; then
      break
    fi
    printf "  ${_RED}✗ ${L_NUM_RANGE}${_R}\n" 1 "$max"
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
  [ -n "$_spinner_pid" ] && { kill "$_spinner_pid" 2>/dev/null; wait "$_spinner_pid" 2>/dev/null || true; }
  _spinner_pid=""
  printf "\r\033[K"
}

# ── Config file writer (shared by manual_setup and ai_setup) ──
# Reads: _proj_name, _session_name, _repo_count, _repo_paths[], _repo_labels[],
#        _repo_stacks[], _agent_count, _agent_ids[], _agent_personas[],
#        _agent_subtitles[], _agent_techs[], _agent_colors[], _agent_repos[],
#        _agent_prompt_files[], _deploy_cmd, _feedback_enabled
_write_config() {
  # Create project directory and set CONFIG path
  local _proj_dir="$PROJECTS_DIR/$_session_name"
  mkdir -p "$_proj_dir"
  CONFIG="$_proj_dir/team.config.sh"

  echo ""
  printf "  ${_GRY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_R}\n"

  {
    cat << CFGHEADER
#!/bin/bash
# ══════════════════════════════════════════════════════════════
# AI Team — Project Configuration
# ══════════════════════════════════════════════════════════════
# Generated by interactive setup wizard
# Edit values below, then run:  bash ai-team.sh
# ══════════════════════════════════════════════════════════════

# ── Project ──────────────────────────────────────────────────
CFGHEADER

    printf 'PROJECT_NAME="%s"\n' "$_proj_name"
    printf 'SESSION_NAME="%s"\n' "$_session_name"

    printf '\n# ── Repositories (1~N) ───────────────────────────────────────\n'
    printf '# Each repo: PATH (absolute), LABEL (display name), STACK (tech summary)\n'
    printf 'REPO_COUNT=%d\n' "$_repo_count"

    for ri in $(seq 1 "$_repo_count"); do
      printf '\nREPO_%d_PATH="%s"\n' "$ri" "${_repo_paths[$ri]}"
      printf 'REPO_%d_LABEL="%s"\n' "$ri" "${_repo_labels[$ri]}"
      printf 'REPO_%d_STACK="%s"\n' "$ri" "${_repo_stacks[$ri]}"
    done

    printf '\n# ── Agents (1~N) ─────────────────────────────────────────────\n'
    printf '# Each agent: ID, PERSONA, SUBTITLE, TECH, COLOR, REPO (index), PROMPT\n'
    printf '# COLOR: RED, GRN, YEL, CYN, MAG, WHT, GRY\n'
    printf 'AGENT_COUNT=%d\n' "$_agent_count"

    for ai in $(seq 1 "$_agent_count"); do
      printf '\n# --- Agent %d: %s ---\n' "$ai" "${_agent_ids[$ai]}"
      printf 'AGENT_%d_ID="%s"\n' "$ai" "${_agent_ids[$ai]}"
      printf 'AGENT_%d_PERSONA="%s"\n' "$ai" "${_agent_personas[$ai]}"
      printf 'AGENT_%d_SUBTITLE="%s"\n' "$ai" "${_agent_subtitles[$ai]}"
      printf 'AGENT_%d_TECH="%s"\n' "$ai" "${_agent_techs[$ai]}"
      printf 'AGENT_%d_COLOR="%s"\n' "$ai" "${_agent_colors[$ai]}"
      printf 'AGENT_%d_REPO=%d\n' "$ai" "${_agent_repos[$ai]}"

      if [ -n "${_agent_prompt_files[$ai]}" ]; then
        printf 'AGENT_%d_PROMPT_FILE="%s"\n' "$ai" "${_agent_prompt_files[$ai]}"
      fi
    done

    printf '\n# ── PM Settings ──────────────────────────────────────────────\n'
    if [ -n "$_deploy_cmd" ]; then
      printf 'PM_DEPLOY_COMMAND="%s"\n' "$_deploy_cmd"
    else
      printf 'PM_DEPLOY_COMMAND=""\n'
    fi

    printf '\n# ── Feedback Pipeline (optional) ────────────────────────────\n'
    printf 'FEEDBACK_ENABLED=%s\n' "$_feedback_enabled"
  } > "$CONFIG"

  printf "  ${_GRN}✓ %s %s${_R}\n" "$L_SAVED" "$CONFIG"
  printf "  ${_GRY}%s${_R}\n" "$L_STARTING"
  echo ""
}

manual_setup() {
  local DEFAULT_COLORS=(YEL CYN MAG GRN BLU RED WHT GRY)

  # ── Project ──
  _ask "$L_PROJ_NAME" "" _proj_name
  while [ -z "$_proj_name" ]; do
    printf "  ${_RED}✗ %s${_R}\n" "$L_PROJ_REQUIRED"
    _ask "$L_PROJ_NAME" "" _proj_name
  done

  local _default_session
  _default_session=$(echo "$_proj_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9_-]//g')
  _default_session="${_default_session}-team"
  printf "  ${_GRY}%s${_R}\n" "$L_SESSION_HINT"
  _ask_session_name "$L_SESSION_NAME" "$_default_session" _session_name

  # ── Repositories ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_REPOS"
  _ask_int "$L_HOW_MANY_REPOS" "1" _repo_count 1 10

  declare -a _repo_paths _repo_labels _repo_stacks
  for ri in $(seq 1 "$_repo_count"); do
    echo ""
    _ask_path "Repo $ri path" "" "_rp"
    _repo_paths[$ri]="$_rp"

    local _default_label
    _default_label=$(basename "$_rp")
    _ask "Repo $ri label" "$_default_label" "_rl"
    _repo_labels[$ri]="$_rl"

    _ask "Repo $ri stack" "" "_rs"
    _repo_stacks[$ri]="$_rs"
  done

  # ── Agents ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_AGENTS"
  _ask_int "$L_HOW_MANY_AGENTS" "2" _agent_count 1 10

  declare -a _agent_ids _agent_personas _agent_subtitles _agent_techs
  declare -a _agent_colors _agent_repos _agent_prompt_files
  for ai in $(seq 1 "$_agent_count"); do
    echo ""
    local _def_id _def_persona _def_subtitle
    if [ "$ai" -eq "$_agent_count" ] && [ "$_agent_count" -ge 2 ]; then
      _def_id="qa"; _def_persona="Kent Beck"; _def_subtitle="Creator of TDD & XP"
    elif [ "$ai" -eq 1 ]; then
      _def_id="dev-1"; _def_persona=""; _def_subtitle=""
    else
      _def_id="dev-$ai"; _def_persona=""; _def_subtitle=""
    fi

    _ask "Agent $ai ID" "$_def_id" "_aid"
    _agent_ids[$ai]="$_aid"
    _ask "Agent $ai persona" "$_def_persona" "_ap"
    _agent_personas[$ai]="$_ap"
    _ask "Agent $ai subtitle" "$_def_subtitle" "_asub"
    _agent_subtitles[$ai]="$_asub"

    local _def_repo="1"
    [ "$ai" -le "$_repo_count" ] && _def_repo="$ai"
    [ "$ai" -gt "$_repo_count" ] && _def_repo="1"
    local _def_tech="${_repo_stacks[$_def_repo]}"
    _ask "Agent $ai tech" "$_def_tech" "_atech"
    _agent_techs[$ai]="$_atech"

    local _color_idx=$(( (ai - 1) % ${#DEFAULT_COLORS[@]} ))
    _ask_color "Agent $ai color (RED/GRN/YEL/BLU/MAG/CYN)" "${DEFAULT_COLORS[$_color_idx]}" "_acolor"
    _agent_colors[$ai]="$_acolor"

    if [ "$_repo_count" -eq 1 ]; then
      _agent_repos[$ai]=1
    else
      _ask_repo_index "Agent $ai repo" "$_def_repo" "_arepo" "$_repo_count"
      _agent_repos[$ai]="$_arepo"
    fi

    _ask "Agent $ai $L_PROMPT_FILE" "" "_apf"
    if [ -n "$_apf" ]; then
      _apf="${_apf/#\~/$HOME}"
      if [ ! -f "$_apf" ]; then
        printf "  ${_YEL}⚠ ${L_FILE_MISSING}${_R}\n" "$_apf"
        _apf=""
      fi
    fi
    _agent_prompt_files[$ai]="$_apf"
  done

  # ── Optional ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_OPTIONAL"
  _ask "$L_DEPLOY" "" _deploy_cmd
  _ask "$L_FEEDBACK ($L_YN)" "n" _feedback
  local _feedback_enabled="false"
  [[ "$_feedback" =~ ^[yY] ]] && _feedback_enabled="true"

  _write_config
}

# ── AI Auto Setup — AI suggests defaults, user confirms each item ──
ai_setup() {
  local DEFAULT_COLORS=(YEL CYN MAG GRN BLU RED WHT GRY)

  echo ""
  printf "  ${_CYN}%s${_R}\n" "$L_DESCRIBE"
  read -e -r -p "  > " user_desc
  if [ -z "$user_desc" ]; then
    printf "  ${_RED}✗ %s${_R}\n" "$L_DESC_REQUIRED"
    ai_setup; return
  fi

  # ── AI generates lightweight suggestions ──
  local ai_prompt
  read -r -d '' ai_prompt << 'SYSPROMPT' || true
You generate team setup suggestions. Output ONLY key=value lines. No quotes, no comments, no blank lines, no explanations.

Format:
PROJECT_NAME=value
SESSION_NAME=value-team
REPO_COUNT=N
REPO_1_PATH=$HOME/path/to/repo
REPO_1_LABEL=Short Label
REPO_1_STACK=Tech, Framework, DB
AGENT_COUNT=N
AGENT_1_ID=short-id
AGENT_1_PERSONA=Famous Developer
AGENT_1_SUBTITLE=Known for X
AGENT_1_TECH=Tech · Stack
AGENT_1_COLOR=YEL
AGENT_1_REPO=1

Rules:
- Choose well-known developer personas fitting each tech stack (e.g. DHH for Rails, Chris Lattner for Swift, Linus Torvalds for C/Linux, Dan Abramov for React)
- Last agent MUST be QA with Kent Beck persona
- Colors: YEL, CYN, MAG, GRN, BLU, RED (in order, no repeats)
- Repo paths: use $HOME prefix. ~/foo → $HOME/foo
- SESSION_NAME: lowercase, hyphens, end with -team
- Output NOTHING except key=value lines
SYSPROMPT

  _spin_start "$L_AI_SPIN"

  local _ai_file
  _ai_file=$(mktemp)

  claude -p --append-system-prompt "$ai_prompt" \
    "Generate config suggestions for: ${user_desc}" > "$_ai_file" 2>/dev/null
  local _ai_exit=$?

  _spin_stop

  if [ "$_ai_exit" -ne 0 ] || [ ! -s "$_ai_file" ]; then
    rm -f "$_ai_file"
    printf "  ${_RED}✗ %s${_R}\n" "$L_AI_FAIL"
    ai_setup; return
  fi

  # Parse helper
  _ai_val() { grep "^$1=" "$_ai_file" 2>/dev/null | head -1 | cut -d= -f2-; }

  printf "  ${_GRN}✓ %s${_R} ${_GRY}— %s${_R}\n" "$L_AI_DONE" ""

  # ── Project ──
  echo ""
  _ask "$L_PROJ_NAME" "$(_ai_val PROJECT_NAME)" _proj_name
  while [ -z "$_proj_name" ]; do
    printf "  ${_RED}✗ %s${_R}\n" "$L_PROJ_REQUIRED"
    _ask "$L_PROJ_NAME" "$(_ai_val PROJECT_NAME)" _proj_name
  done

  local _ai_session
  _ai_session=$(_ai_val SESSION_NAME)
  if [ -z "$_ai_session" ]; then
    _ai_session=$(echo "$_proj_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9_-]//g')
    _ai_session="${_ai_session}-team"
  fi
  printf "  ${_GRY}%s${_R}\n" "$L_SESSION_HINT"
  _ask_session_name "$L_SESSION_NAME" "$_ai_session" _session_name

  # ── Repositories ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_REPOS"
  _ask_int "$L_HOW_MANY_REPOS" "$(_ai_val REPO_COUNT)" _repo_count 1 10

  declare -a _repo_paths _repo_labels _repo_stacks
  for ri in $(seq 1 "$_repo_count"); do
    echo ""
    local _ai_rp
    _ai_rp=$(_ai_val "REPO_${ri}_PATH")
    _ai_rp="${_ai_rp/\$HOME/$HOME}"
    _ask_path "Repo $ri path" "$_ai_rp" "_rp"
    _repo_paths[$ri]="$_rp"

    local _ai_rl
    _ai_rl=$(_ai_val "REPO_${ri}_LABEL")
    _ask "Repo $ri label" "${_ai_rl:-$(basename "$_rp")}" "_rl"
    _repo_labels[$ri]="$_rl"

    _ask "Repo $ri stack" "$(_ai_val "REPO_${ri}_STACK")" "_rs"
    _repo_stacks[$ri]="$_rs"
  done

  # ── Agents ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_AGENTS"
  _ask_int "$L_HOW_MANY_AGENTS" "$(_ai_val AGENT_COUNT)" _agent_count 1 10

  declare -a _agent_ids _agent_personas _agent_subtitles _agent_techs
  declare -a _agent_colors _agent_repos _agent_prompt_files
  for ai in $(seq 1 "$_agent_count"); do
    echo ""
    _ask "Agent $ai ID" "$(_ai_val "AGENT_${ai}_ID")" "_aid"
    _agent_ids[$ai]="$_aid"
    _ask "Agent $ai persona" "$(_ai_val "AGENT_${ai}_PERSONA")" "_ap"
    _agent_personas[$ai]="$_ap"
    _ask "Agent $ai subtitle" "$(_ai_val "AGENT_${ai}_SUBTITLE")" "_asub"
    _agent_subtitles[$ai]="$_asub"
    _ask "Agent $ai tech" "$(_ai_val "AGENT_${ai}_TECH")" "_atech"
    _agent_techs[$ai]="$_atech"

    local _ai_color
    _ai_color=$(_ai_val "AGENT_${ai}_COLOR")
    local _color_idx=$(( (ai - 1) % ${#DEFAULT_COLORS[@]} ))
    _ask_color "Agent $ai color (RED/GRN/YEL/BLU/MAG/CYN)" "${_ai_color:-${DEFAULT_COLORS[$_color_idx]}}" "_acolor"
    _agent_colors[$ai]="$_acolor"

    if [ "$_repo_count" -eq 1 ]; then
      _agent_repos[$ai]=1
    else
      local _ai_arepo
      _ai_arepo=$(_ai_val "AGENT_${ai}_REPO")
      _ask_repo_index "Agent $ai repo" "${_ai_arepo:-1}" "_arepo" "$_repo_count"
      _agent_repos[$ai]="$_arepo"
    fi

    _agent_prompt_files[$ai]=""
  done

  # ── Optional ──
  echo ""
  printf "  ${_WHT}── %s ──${_R}\n" "$L_OPTIONAL"
  _ask "$L_DEPLOY" "" _deploy_cmd
  _ask "$L_FEEDBACK ($L_YN)" "n" _feedback
  local _feedback_enabled="false"
  [[ "$_feedback" =~ ^[yY] ]] && _feedback_enabled="true"

  rm -f "$_ai_file"
  _write_config
}

# ── Mode Selection Entry Point ──
interactive_setup() {
  clear
  echo ""
  printf "  ${_CYN}${_B}🚀 AI Team Setup${_R}\n"
  printf "  ${_GRY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_R}\n"
  echo ""

  # Check if claude CLI is available
  if ! command -v claude &>/dev/null; then
    printf "  ${_GRY}%s${_R}\n" "$L_CLAUDE_MISSING"
    echo ""
    manual_setup
    return
  fi

  printf "  ${_WHT}1)${_R} %s\n" "$L_MODE_AI"
  printf "  ${_WHT}2)${_R} %s\n" "$L_MODE_MANUAL"
  echo ""
  _ask "$L_SELECT" "1" _setup_mode

  case "$_setup_mode" in
    1) ai_setup ;;
    2) manual_setup ;;
    *)
      printf "  ${_RED}✗ 1 또는 2를 선택해주세요${_R}\n"
      interactive_setup
      ;;
  esac
}

# ══════════════════════════════════════════════════════════════
# Project Selection / Config Loading
# ══════════════════════════════════════════════════════════════

if [ -z "$CONFIG" ]; then
  # No argument — show project selector
  _project_dirs=()
  _project_names=()
  while IFS= read -r _cfg; do
    _pdir=$(dirname "$_cfg")
    _pname=$(grep '^PROJECT_NAME=' "$_cfg" 2>/dev/null | head -1 | cut -d'"' -f2)
    _project_dirs+=("$_pdir")
    _project_names+=("${_pname:-$(basename "$_pdir")}")
  done < <(find "$PROJECTS_DIR" -maxdepth 2 -name 'team.config.sh' -type f 2>/dev/null | sort)

  if [ ${#_project_dirs[@]} -eq 0 ]; then
    # No projects — go straight to setup
    interactive_setup
  else
    echo ""
    printf "  ${_CYN}${_B}🚀 AI Team${_R}\n"
    printf "  ${_GRY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_R}\n"
    echo ""
    printf "  ${_WHT}%s${_R}\n" "$L_EXISTING"
    for _i in "${!_project_dirs[@]}"; do
      _dirname=$(basename "${_project_dirs[$_i]}")
      printf "    ${_WHT}%d)${_R} %s ${_GRY}(%s)${_R}\n" "$((_i + 1))" "${_project_names[$_i]}" "$_dirname"
    done
    _new_idx=$(( ${#_project_dirs[@]} + 1 ))
    printf "    ${_GRN}%d)${_R} ${_GRN}%s${_R}\n" "$_new_idx" "$L_NEW_PROJECT"
    echo ""
    _ask "$L_SELECT" "1" _proj_choice

    if [ "$_proj_choice" -eq "$_new_idx" ] 2>/dev/null; then
      interactive_setup
    elif [ "$_proj_choice" -ge 1 ] && [ "$_proj_choice" -le "${#_project_dirs[@]}" ] 2>/dev/null; then
      CONFIG="${_project_dirs[$((_proj_choice - 1))]}/team.config.sh"
    else
      printf "  ${_RED}✗ %s${_R}\n" "$L_INVALID_CHOICE"
      exit 1
    fi
  fi
fi

# Source config (set +e because read -d '' in heredoc-style prompts returns 1)
set +e
source "$CONFIG"
set -e

# Source .env for secrets
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# ══════════════════════════════════════════════════════════════
# Config Validation
# ══════════════════════════════════════════════════════════════

validate_config() {
  local errors=0

  [ -z "${PROJECT_NAME:-}" ] && echo "ERROR: PROJECT_NAME not set" && errors=$((errors+1))
  [ -z "${SESSION_NAME:-}" ] && echo "ERROR: SESSION_NAME not set" && errors=$((errors+1))

  # SESSION_NAME must be safe for tmux and filesystem
  if [ -n "${SESSION_NAME:-}" ] && [[ ! "$SESSION_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: SESSION_NAME must contain only alphanumeric, underscore, or hyphen"
    errors=$((errors+1))
  fi

  if [ -z "${REPO_COUNT:-}" ] || [ "$REPO_COUNT" -lt 1 ] 2>/dev/null; then
    echo "ERROR: REPO_COUNT must be >= 1"
    errors=$((errors+1))
  fi
  if [ -z "${AGENT_COUNT:-}" ] || [ "$AGENT_COUNT" -lt 1 ] 2>/dev/null; then
    echo "ERROR: AGENT_COUNT must be >= 1"
    errors=$((errors+1))
  fi

  # Validate repos
  for i in $(seq 1 "${REPO_COUNT:-0}"); do
    local path_var="REPO_${i}_PATH"
    local path="${!path_var:-}"
    if [ -z "$path" ]; then
      echo "ERROR: ${path_var} not set"
      errors=$((errors+1))
    elif [ ! -d "$path" ]; then
      echo "ERROR: ${path_var}='${path}' directory does not exist"
      errors=$((errors+1))
    fi
  done

  # Validate agents
  for i in $(seq 1 "${AGENT_COUNT:-0}"); do
    local id_var="AGENT_${i}_ID"
    local repo_var="AGENT_${i}_REPO"
    local repo_idx="${!repo_var:-}"
    [ -z "${!id_var:-}" ] && echo "ERROR: ${id_var} not set" && errors=$((errors+1))
    [ -z "$repo_idx" ] && echo "ERROR: ${repo_var} not set" && errors=$((errors+1))
    if [ -n "$repo_idx" ] && [ "$repo_idx" -gt "${REPO_COUNT:-0}" ] 2>/dev/null; then
      echo "ERROR: ${repo_var}=${repo_idx} exceeds REPO_COUNT=${REPO_COUNT}"
      errors=$((errors+1))
    fi
    # Warn if prompt file is set but missing
    local pf_var="AGENT_${i}_PROMPT_FILE"
    local pf="${!pf_var:-}"
    if [ -n "$pf" ] && [ ! -f "$pf" ]; then
      echo "ERROR: ${pf_var}='${pf}' file does not exist"
      errors=$((errors+1))
    fi
  done

  # Warn about feedback tokens
  if [ "${FEEDBACK_ENABLED:-false}" = "true" ]; then
    if [ -z "${FEEDBACK_ADMIN_TOKEN:-}" ]; then
      echo "WARNING: FEEDBACK_ENABLED=true but FEEDBACK_ADMIN_TOKEN not set in .env"
    fi
  fi

  # Check required commands
  for cmd in tmux claude; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: '$cmd' not found in PATH"
      errors=$((errors+1))
    fi
  done

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "Config validation failed with $errors error(s)."
    exit 1
  fi
}

validate_config

# ══════════════════════════════════════════════════════════════
# Workspace Setup
# ══════════════════════════════════════════════════════════════

WORKSPACE="/tmp/${SESSION_NAME}"
mkdir -p "$WORKSPACE"
rm -f "$WORKSPACE"/*.md "$WORKSPACE"/*-status.txt "$WORKSPACE"/*-task-input.txt \
      "$WORKSPACE"/current-*.txt "$WORKSPACE"/agents.list \
      "$WORKSPACE"/*-persona.sh "$WORKSPACE"/*-sys.txt \
      "$WORKSPACE"/agents-display.sh "$WORKSPACE"/project-name.txt 2>/dev/null

echo "$PROJECT_NAME" > "$WORKSPACE/project-name.txt"
echo "${FEEDBACK_ENABLED:-false}" > "$WORKSPACE/feedback-enabled.txt"

# Detect AI model
MODEL="unknown"
if command -v python3 &>/dev/null && [ -f "$HOME/.claude/settings.json" ]; then
  MODEL=$(python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json')).get('model','default'))" 2>/dev/null || echo "default")
fi
echo "$MODEL" > "$WORKSPACE/model.txt"

# Default repo (for PM pane working directory)
DEFAULT_REPO_PATH="${REPO_1_PATH}"

# ══════════════════════════════════════════════════════════════
# Generate Agent Files
# ══════════════════════════════════════════════════════════════

# agents.list — one ID per line
for i in $(seq 1 "$AGENT_COUNT"); do
  local_id_var="AGENT_${i}_ID"
  echo "${!local_id_var}" >> "$WORKSPACE/agents.list"
done

# agents-display.sh — bash arrays for status monitor
{
  echo "# Auto-generated by ai-team.sh — do not edit"
  printf 'AGENT_IDS=('
  for i in $(seq 1 "$AGENT_COUNT"); do
    local_id_var="AGENT_${i}_ID"
    printf '"%s" ' "${!local_id_var}"
  done
  echo ')'

  printf 'AGENT_NAMES=('
  for i in $(seq 1 "$AGENT_COUNT"); do
    local_name_var="AGENT_${i}_NAME"
    local_id_var="AGENT_${i}_ID"
    printf '"%s" ' "${!local_name_var:-${!local_id_var}}"
  done
  echo ')'

  printf 'AGENT_COLORS=('
  for i in $(seq 1 "$AGENT_COUNT"); do
    local_color_var="AGENT_${i}_COLOR"
    printf '"%s" ' "${!local_color_var:-GRY}"
  done
  echo ')'

  printf 'AGENT_LABELS=('
  for i in $(seq 1 "$AGENT_COUNT"); do
    local_name_var="AGENT_${i}_NAME"
    local_id_var="AGENT_${i}_ID"
    printf '"%s" ' "${!local_name_var:-${!local_id_var}}"
  done
  echo ')'

  echo "AGENT_COUNT=$AGENT_COUNT"
} > "$WORKSPACE/agents-display.sh"

# Helper: escape sed replacement special chars (| & \)
_esc() { printf '%s' "$1" | sed 's/[|&\\]/\\&/g'; }

# Per-agent: persona.sh + sys.txt
for i in $(seq 1 "$AGENT_COUNT"); do
  id_var="AGENT_${i}_ID";           id="${!id_var}"
  name_var="AGENT_${i}_NAME";       name="${!name_var:-$id}"
  persona_var="AGENT_${i}_PERSONA"; persona="${!persona_var:-Agent $i}"
  subtitle_var="AGENT_${i}_SUBTITLE"; subtitle="${!subtitle_var:-}"
  tech_var="AGENT_${i}_TECH";       tech="${!tech_var:-}"
  color_var="AGENT_${i}_COLOR";     color="${!color_var:-GRY}"
  repo_var="AGENT_${i}_REPO";       repo_idx="${!repo_var:-1}"
  prompt_var="AGENT_${i}_PROMPT";   prompt="${!prompt_var:-}"
  prompt_file_var="AGENT_${i}_PROMPT_FILE"; prompt_file="${!prompt_file_var:-}"

  # Resolve repo
  repo_path_var="REPO_${repo_idx}_PATH";   project_path="${!repo_path_var:-}"
  repo_stack_var="REPO_${repo_idx}_STACK"; project_stack="${!repo_stack_var:-}"

  # Write persona.sh (display variables) — use printf %q to safely escape special chars
  cat > "$WORKSPACE/${id}-persona.sh" <<PERSONA_EOF
AGENT_NAME=$(printf '%q' "$name")
PERSONA=$(printf '%q' "$persona")
SUBTITLE=$(printf '%q' "$subtitle")
TECH=$(printf '%q' "$tech")
COLOR_CODE=$(printf '%q' "$color")
ICON="◆"
PROJECT=$(printf '%q' "$project_path")
PERSONA_EOF

  # Build substitution sed expression for prompt variables
  SED_EXPR="s|\\\$PROJECT_PATH|$(_esc "$project_path")|g; s|\\\$PROJECT_STACK|$(_esc "$project_stack")|g"
  for ri in $(seq 1 "$REPO_COUNT"); do
    rp_var="REPO_${ri}_PATH";  rp="${!rp_var:-}"
    rs_var="REPO_${ri}_STACK"; rs="${!rs_var:-}"
    rl_var="REPO_${ri}_LABEL"; rl="${!rl_var:-}"
    SED_EXPR="${SED_EXPR}; s|\\\$REPO_${ri}_PATH|$(_esc "$rp")|g"
    SED_EXPR="${SED_EXPR}; s|\\\$REPO_${ri}_STACK|$(_esc "$rs")|g"
    SED_EXPR="${SED_EXPR}; s|\\\$REPO_${ri}_LABEL|$(_esc "$rl")|g"
  done

  # Write sys.txt (system prompt with variables substituted)
  if [ -n "$prompt_file" ] && [ -f "$prompt_file" ]; then
    sed "$SED_EXPR" "$prompt_file" > "$WORKSPACE/${id}-sys.txt"
  elif [ -n "$prompt" ]; then
    printf '%s' "$prompt" | sed "$SED_EXPR" > "$WORKSPACE/${id}-sys.txt"
  else
    echo "You are ${persona}. Work in ${project_path} (${project_stack})." > "$WORKSPACE/${id}-sys.txt"
  fi
done

# ══════════════════════════════════════════════════════════════
# 1. run-claude.sh — reads task from FILE, passes as ARGUMENT
# ══════════════════════════════════════════════════════════════

cat > "$WORKSPACE/run-claude.sh" << 'RUNNER'
#!/bin/bash
TASK_FILE="$1"
SYS_FILE="$2"
TASK="$(cat "$TASK_FILE")"
SYS="$(cat "$SYS_FILE")"
exec claude -p --dangerously-skip-permissions --append-system-prompt "$SYS" "$TASK"
RUNNER
chmod +x "$WORKSPACE/run-claude.sh"

# ══════════════════════════════════════════════════════════════
# 2. agent-viewer.sh — watches for task file → runs agent
#    ★ case block removed: sources persona.sh + reads sys.txt
# ══════════════════════════════════════════════════════════════

cat > "$WORKSPACE/agent-viewer.sh" << 'AGENTVIEWER'
#!/bin/bash
# Usage: agent-viewer.sh <agent-id> <workspace-path>

AGENT="$1"
TEAM="$2"
TASK_FILE="$TEAM/${AGENT}-task.md"
RESULT_FILE="$TEAM/${AGENT}-result.md"
STATUS_FILE="$TEAM/${AGENT}-status.txt"
SYS_FILE="$TEAM/${AGENT}-sys.txt"

# ── Load persona (replaces 180-line case block) ──
source "$TEAM/${AGENT}-persona.sh"
NAME="$AGENT_NAME"
SUB="$SUBTITLE"

# Colors
R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'; MAG=$'\033[35m'
RED=$'\033[31m'; WHT=$'\033[97m'; GRY=$'\033[90m'

# Map COLOR_CODE to ANSI
case "$COLOR_CODE" in
  RED) CLR=$RED ;; GRN) CLR=$GRN ;; YEL) CLR=$YEL ;;
  BLU) CLR=$'\033[34m' ;; MAG) CLR=$MAG ;; CYN) CLR=$CYN ;;
  WHT) CLR=$WHT ;; *) CLR=$GRY ;;
esac

sep() { printf '─%.0s' $(seq 1 $(($(tput cols) - 2))); }

draw_header() {
  echo ""
  printf " ${CLR}${B}${ICON} ${NAME}${R}  ${D}${PERSONA}${R}\n"
  printf " ${GRY}${SUB}${R}\n"
  printf " ${GRY}${TECH}${R}\n"
  printf " ${GRY}$(sep)${R}\n"
}

show_idle() {
  clear
  draw_header
  echo ""
  printf " ${GRY}Waiting for task...${R}\n"
  echo ""
}

echo "idle" > "$STATUS_FILE"
trap 'echo "idle" > "$STATUS_FILE"; tput cnorm; exit' INT TERM
show_idle

while true; do
  if [ -f "$TASK_FILE" ]; then
    TASK_INPUT="$TEAM/${AGENT}-task-input.txt"
    cp "$TASK_FILE" "$TASK_INPUT"
    rm -f "$TASK_FILE"
    rm -f "$RESULT_FILE"
    echo "working" > "$STATUS_FILE"

    TASK_PREVIEW=$(head -3 "$TASK_INPUT" | cut -c1-70 | tr '\n' ' ')
    START_TIME=$(date '+%H:%M:%S')

    clear
    draw_header
    echo ""
    printf " ${CLR}▶ Working${R}\n"
    printf " ${D}${TASK_PREVIEW}${R}\n"
    printf " ${GRY}${START_TIME} Started${R}\n"
    echo ""
    printf " ${GRY}$(sep)${R}\n"
    echo ""

    cd "$PROJECT"

    # run-claude.sh reads task from file → passes as argument
    # script -q provides PTY → real-time streaming + captures to file
    if [[ "$(uname)" == "Darwin" ]]; then
      script -q "$RESULT_FILE" "$TEAM/run-claude.sh" "$TASK_INPUT" "$SYS_FILE"
    else
      script -q -c "'$TEAM/run-claude.sh' '$TASK_INPUT' '$SYS_FILE'" "$RESULT_FILE"
    fi

    # Strip ANSI codes from result file so PM can read cleanly
    if [ -f "$RESULT_FILE" ]; then
      LC_ALL=C sed $'s/\033\[[0-9;]*[a-zA-Z]//g; s/\r//g' "$RESULT_FILE" > "$RESULT_FILE.tmp" 2>/dev/null
      mv "$RESULT_FILE.tmp" "$RESULT_FILE" 2>/dev/null
    fi

    # Extract test stats for Status Board tracking
    TEST_STATS_FILE="$TEAM/${AGENT}-test-stats.txt"
    if [ -f "$RESULT_FILE" ]; then
      test_section=$(sed -n '/^## Tests/,/^## /p' "$RESULT_FILE" | head -10)
      if [ -z "$test_section" ]; then
        test_section=$(sed -n '/^### Tests/,/^### /p' "$RESULT_FILE" | head -10)
      fi
      if [ -n "$test_section" ]; then
        pass=$(echo "$test_section" | grep -oE '[0-9]+ (passed|examples|pass)' | head -1 | grep -oE '[0-9]+')
        fail=$(echo "$test_section" | grep -oE '[0-9]+ (failed|failures|fail)' | head -1 | grep -oE '[0-9]+')
        pass=${pass:-0}; fail=${fail:-0}
        total=$((pass + fail))
        if [ "$total" -gt 0 ]; then
          pct=$((pass * 100 / total))
          echo "${pct}% (${pass}/${total})" > "$TEST_STATS_FILE"
        else
          echo "$test_section" | grep -E 'PASS|FAIL|BUILD' | head -3 > "$TEST_STATS_FILE"
        fi
      fi
    fi

    END_TIME=$(date '+%H:%M:%S')

    clear
    draw_header
    echo ""
    printf " ${GRN}${B}✓ Done${R} ${GRY}${START_TIME} → ${END_TIME}${R}\n"
    echo ""
    printf " ${GRY}$(sep)${R}\n"
    echo ""
    if [ -f "$RESULT_FILE" ]; then
      summary=$(grep -A 30 "^## Changes Made\|^## QA Result\|^## QA Report" "$RESULT_FILE" | head -20)
      if [ -n "$summary" ]; then
        printf " ${WHT}%s${R}\n" "Summary:"
        echo "$summary" | while IFS= read -r line; do
          printf " ${D}%s${R}\n" "$line"
        done
      else
        grep -v '^$' "$RESULT_FILE" | tail -10 | while IFS= read -r line; do
          printf " ${D}%s${R}\n" "$line"
        done
      fi
    fi
    echo ""

    echo "done" > "$STATUS_FILE"
    # Stay "done" for 10 seconds so PM can read status, then return to idle
    sleep 10
    echo "idle" > "$STATUS_FILE"
    show_idle
  fi
  sleep 1
done
AGENTVIEWER
chmod +x "$WORKSPACE/agent-viewer.sh"

# ══════════════════════════════════════════════════════════════
# 3. status-monitor.sh — dynamic dashboard (N agents)
#    ★ hardcoded 3 agents → agents-display.sh 기반 동적 렌더링
# ══════════════════════════════════════════════════════════════

cat > "$WORKSPACE/status-monitor.sh" << 'MONITOR'
#!/bin/bash
# Usage: status-monitor.sh <workspace-path>

TEAM="$1"

R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'
MAG=$'\033[35m'; WHT=$'\033[97m'; GRY=$'\033[90m'
RED=$'\033[31m'; BLU=$'\033[34m'; REV=$'\033[7m'

# Load agent display info
if [ ! -f "$TEAM/agents-display.sh" ]; then
  echo "ERROR: $TEAM/agents-display.sh not found"; exit 1
fi
source "$TEAM/agents-display.sh"
if [ -z "$AGENT_COUNT" ] || [ "$AGENT_COUNT" -lt 1 ] 2>/dev/null; then
  echo "ERROR: AGENT_COUNT invalid in agents-display.sh"; exit 1
fi

# Load project name
PROJECT_NAME="AI Team"
[ -f "$TEAM/project-name.txt" ] && PROJECT_NAME=$(cat "$TEAM/project-name.txt" 2>/dev/null)

# Load feedback flag
FEEDBACK_ON=false
[ -f "$TEAM/feedback-enabled.txt" ] && FEEDBACK_ON=$(cat "$TEAM/feedback-enabled.txt" 2>/dev/null)

# Color code → ANSI mapping
color_ansi() {
  case "$1" in
    RED) printf '%s' "$RED" ;; GRN) printf '%s' "$GRN" ;; YEL) printf '%s' "$YEL" ;;
    BLU) printf '%s' "$BLU" ;; MAG) printf '%s' "$MAG" ;; CYN) printf '%s' "$CYN" ;;
    WHT) printf '%s' "$WHT" ;; *) printf '%s' "$GRY" ;;
  esac
}

# Display-width-aware truncation (CJK = 2 cols, ASCII = 1 col)
_trunc_dw() {
  local s="$1" max="$2" out="" dw=0 i=0 len=${#1} cw
  while [ $i -lt $len ]; do
    c="${s:$i:1}"
    case "$c" in [[:ascii:]]) cw=1 ;; *) cw=2 ;; esac
    [ $((dw + cw)) -gt $max ] && break
    out="${out}${c}"; dw=$((dw + cw)); i=$((i + 1))
  done
  printf '%s\n%d' "$out" "$dw"
}

# Alternate screen buffer
printf '\033[?1049h'
tput civis
trap 'tput cnorm; printf "\033[?1049l"; exit' INT TERM

frame=0

while true; do
  # Read all agent statuses
  STATUS_VALS=()
  results=0
  for id in "${AGENT_IDS[@]}"; do
    s="idle"
    [ -f "$TEAM/${id}-status.txt" ] && s=$(cat "$TEAM/${id}-status.txt" 2>/dev/null)
    STATUS_VALS+=("$s")
    [ "$s" = "done" ] && results=$((results+1))
  done

  task="(waiting)"
  phase="idle"
  [ -f "$TEAM/current-task.txt" ] && task=$(cat "$TEAM/current-task.txt")
  [ -f "$TEAM/current-phase.txt" ] && phase=$(cat "$TEAM/current-phase.txt")

  spn="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  sc=${spn:$((frame % 10)):1}
  frame=$((frame + 1))

  pc="$GRY"
  case "$phase" in
    planning)       pc="$CYN" ;;
    implementing)   pc="$YEL" ;;
    qa-review)      pc="$MAG" ;;
    review)         pc="$WHT" ;;
    deploying|done) pc="$GRN" ;;
  esac

  model="default"
  [ -f "$TEAM/model.txt" ] && model=$(cat "$TEAM/model.txt" 2>/dev/null)

  w=$(tput cols)
  h=$(tput lines)
  bw=$((w - 2))
  [ "$bw" -lt 8 ] && bw=8

  # Progress bar
  pbar_w=$((bw / 2))
  [ "$pbar_w" -gt 20 ] && pbar_w=20
  [ "$pbar_w" -lt 3 ] && pbar_w=3
  filled=$((results * pbar_w / AGENT_COUNT))
  pbar=""
  for pi in $(seq 1 $pbar_w); do
    if [ $pi -le $filled ]; then pbar="${pbar}${GRN}▓${R}"
    else pbar="${pbar}${GRY}░${R}"; fi
  done

  clock=$(date '+%H:%M:%S')

  buf="$TEAM/.sb"
  {
    # Header box
    ibw=$((bw - 2)); [ "$ibw" -lt 6 ] && ibw=6
    printf " ${CYN}╭"; printf '─%.0s' $(seq 1 $ibw); printf "╮${R}\n"
    hdr="${PROJECT_NAME}  Team"
    gap=$((ibw - ${#hdr} - ${#clock} - 2)); [ "$gap" -lt 1 ] && gap=1
    printf " ${CYN}│${R} ${B}${CYN}%s${R}  ${D}Team${R}%*s${GRY}%s${R} ${CYN}│${R}\n" "$PROJECT_NAME" "$gap" "" "$clock"
    ml=$((ibw - ${#phase} - 4)); [ "$ml" -lt 3 ] && ml=3
    mod_t=$(printf '%s' "$model" | cut -c1-$ml)
    g2=$((ibw - ${#mod_t} - ${#phase} - 2)); [ "$g2" -lt 1 ] && g2=1
    printf " ${CYN}│${R} ${GRY}%s${R}%*s${pc}${B}%s${R} ${CYN}│${R}\n" "$mod_t" "$g2" "" "$phase"
    printf " ${CYN}╰"; printf '─%.0s' $(seq 1 $ibw); printf "╯${R}\n"

    # Task
    printf "\n ${GRY}┌ ${WHT}TASK${GRY} "; printf '─%.0s' $(seq 1 $((ibw - 6))); printf "┐${R}\n"
    _td=$(_trunc_dw "$task" $((ibw - 2)))
    task_t=$(echo "$_td" | head -1)
    task_tw=$(echo "$_td" | tail -1)
    tpad=$((ibw - task_tw - 1)); [ "$tpad" -lt 0 ] && tpad=0
    printf " ${GRY}│${R} ${B}${WHT}%s${R}%*s${GRY}│${R}\n" "$task_t" "$tpad" ""
    printf " ${GRY}└"; printf '─%.0s' $(seq 1 $ibw); printf "┘${R}\n"

    # Agents (dynamic card layout)
    printf "\n ${D}AGENTS${R}\n"
    cw=$(( (bw - 2) / AGENT_COUNT )); [ "$cw" -lt 7 ] && cw=7; ci=$((cw - 2))

    # Row: top borders
    printf " "
    for idx in "${!AGENT_IDS[@]}"; do
      as="${STATUS_VALS[$idx]}"
      ac=$(color_ansi "${AGENT_COLORS[$idx]}")
      case "$as" in done) ac="$GRN" ;; idle|waiting) ac="$GRY" ;; esac
      printf "${ac}┏"; printf '━%.0s' $(seq 1 $ci); printf "┓${R}"
    done; printf "\n"

    # Row: agent name + icon
    printf " "
    for idx in "${!AGENT_IDS[@]}"; do
      an="${AGENT_LABELS[$idx]}"
      as="${STATUS_VALS[$idx]}"
      ac=$(color_ansi "${AGENT_COLORS[$idx]}")
      case "$as" in done) ac="$GRN" ;; idle|waiting) ac="$GRY" ;; esac
      case "$as" in working) sym="$sc" ;; done) sym="●" ;; *) sym="○" ;; esac
      an_trunc=$(echo "$an" | cut -c1-$((ci - 3)))
      vis="${sym} ${an_trunc}"; vl=${#vis}; pd=$((ci - vl)); [ "$pd" -lt 0 ] && pd=0
      printf "${ac}┃${R}${ac}${B}%s${R}%*s${ac}┃${R}" "$vis" "$pd" ""
    done; printf "\n"

    # Row: status text
    printf " "
    for idx in "${!AGENT_IDS[@]}"; do
      as="${STATUS_VALS[$idx]}"
      ac=$(color_ansi "${AGENT_COLORS[$idx]}")
      case "$as" in done) ac="$GRN" ;; idle|waiting) ac="$GRY" ;; esac
      vis=" ${as}"; vl=${#vis}; pd=$((ci - vl)); [ "$pd" -lt 0 ] && pd=0
      printf "${ac}┃${R}${D}%s${R}%*s${ac}┃${R}" "$vis" "$pd" ""
    done; printf "\n"

    # Row: bottom borders
    printf " "
    for idx in "${!AGENT_IDS[@]}"; do
      as="${STATUS_VALS[$idx]}"
      ac=$(color_ansi "${AGENT_COLORS[$idx]}")
      case "$as" in done) ac="$GRN" ;; idle|waiting) ac="$GRY" ;; esac
      printf "${ac}┗"; printf '━%.0s' $(seq 1 $ci); printf "┛${R}"
    done; printf "\n"

    # Progress
    printf "\n ${D}PROGRESS${R} %s ${WHT}%d${R}${GRY}/%d${R}\n" "$pbar" "$results" "$AGENT_COUNT"
    for idx in "${!AGENT_IDS[@]}"; do
      id="${AGENT_IDS[$idx]}"
      if [ -f "$TEAM/${id}-result.md" ] && [ "$(cat "$TEAM/${id}-status.txt" 2>/dev/null)" = "done" ]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          t=$(stat -f "%Sm" -t "%H:%M" "$TEAM/${id}-result.md" 2>/dev/null || echo "??:??")
        else
          t=$(date -r "$TEAM/${id}-result.md" '+%H:%M' 2>/dev/null || echo "??:??")
        fi
        printf "   ${GRN}✓${R} ${GRY}%-12s %s${R}\n" "${AGENT_LABELS[$idx]}" "$t"
      fi
    done

    # Tests
    printf "\n ${D}TESTS${R}"
    has_t=0
    for idx in "${!AGENT_IDS[@]}"; do
      id="${AGENT_IDS[$idx]}"
      if [ -f "$TEAM/${id}-test-stats.txt" ] && [ -s "$TEAM/${id}-test-stats.txt" ]; then
        has_t=1; sv=$(head -1 "$TEAM/${id}-test-stats.txt" 2>/dev/null)
        tclr="$GRN"; pn=$(echo "$sv" | grep -oE '^[0-9]+' | head -1)
        [ -n "$pn" ] && [ "$pn" -lt 100 ] && tclr="$YEL"
        [ -n "$pn" ] && [ "$pn" -lt 80 ] && tclr="$RED"
        printf "\n   ${GRY}%-12s${R}${tclr}%s${R}" "${AGENT_LABELS[$idx]}" "$sv"
      fi
    done
    [ "$has_t" -eq 0 ] && printf " ${GRY}--${R}"
    printf "\n"

    # Feedback (conditional)
    if [ "$FEEDBACK_ON" = "true" ]; then
      printf "\n ${D}FEEDBACK${R} "
      if [ -f "$TEAM/feedback-stats.txt" ]; then
        fbs=$(cat "$TEAM/feedback-stats.txt" 2>/dev/null)
        fc=$(echo "$fbs" | grep -oE 'critical:[0-9]+' | cut -d: -f2)
        fa=$(echo "$fbs" | grep -oE 'actionable:[0-9]+' | cut -d: -f2)
        fn=$(echo "$fbs" | grep -oE 'noise:[0-9]+' | cut -d: -f2)
        fc=${fc:-0}; fa=${fa:-0}; fn=${fn:-0}
        if [ "$fc" -gt 0 ] 2>/dev/null; then
          if [ $((frame % 2)) -eq 0 ]; then printf "${RED}${B}${REV} !! %s ${R}" "$fc"
          else printf "${RED}${B}    %s ${R}" "$fc"; fi
        else printf "${GRY}%s${R}" "$fc"; fi
        printf " ${YEL}%s${R} ${GRY}%s${R}\n" "$fa" "$fn"
        fl=$(echo "$fbs" | grep -oE 'last:.*' | sed 's/^last://')
        [ -n "$fl" ] && printf "   ${GRY}%s${R}\n" "$fl"
      else
        printf "${GRY}--${R}\n"
      fi
    fi
  } > "$buf"

  # Render — \033[K clears leftover content on each row
  printf '\033[H'
  while IFS= read -r _line || [ -n "$_line" ]; do
    printf '%s\033[K\n' "$_line"
  done < <(head -n $((h - 1)) "$buf")
  printf '\033[J'

  sleep 1
done
MONITOR
chmod +x "$WORKSPACE/status-monitor.sh"

# ══════════════════════════════════════════════════════════════
# 4. PM Prompt — dynamically generated from config
#    ★ 180줄 하드코딩 → config 기반 동적 생성
# ══════════════════════════════════════════════════════════════

generate_pm_prompt() {
  local team_list=""
  for i in $(seq 1 "$AGENT_COUNT"); do
    local id_var="AGENT_${i}_ID";       local id="${!id_var}"
    local persona_var="AGENT_${i}_PERSONA"; local persona="${!persona_var:-}"
    local tech_var="AGENT_${i}_TECH";   local tech="${!tech_var:-}"
    team_list="${team_list}- @${id} (${persona}) — ${tech}"$'\n'
  done

  local projects_list=""
  for i in $(seq 1 "$REPO_COUNT"); do
    local path_var="REPO_${i}_PATH";   local path="${!path_var}"
    local label_var="REPO_${i}_LABEL"; local label="${!label_var:-Repo $i}"
    local stack_var="REPO_${i}_STACK"; local stack="${!stack_var:-}"
    projects_list="${projects_list}- ${label}: ${path} (${stack})"$'\n'
  done

  # Build dispatch example (non-QA agents)
  local dispatch_agents=""
  for i in $(seq 1 "$AGENT_COUNT"); do
    local id_var="AGENT_${i}_ID"; local id="${!id_var}"
    local name_var="AGENT_${i}_NAME"; local name="${!name_var:-$id}"
    # Skip QA-like agents for dispatch example (QA dispatched in Step 5)
    if [[ ! "$id" =~ qa|test|review ]]; then
      dispatch_agents="${dispatch_agents}cat << 'TASK' > ${WORKSPACE}/${id}-task.md
[detailed task for ${name}]
TASK
"
    fi
  done

  # Build commit examples
  local commit_cmds=""
  for i in $(seq 1 "$REPO_COUNT"); do
    local path_var="REPO_${i}_PATH"; local path="${!path_var}"
    local label_var="REPO_${i}_LABEL"; local label="${!label_var:-Repo $i}"
    commit_cmds="${commit_cmds}# ${label} (if changed) — list specific files, NEVER use git add -A
cd ${path} && git add [file1] [file2] && git commit -m \"설명\"
"
  done

  # Build QA test commands
  local qa_test_cmds=""
  for i in $(seq 1 "$REPO_COUNT"); do
    local path_var="REPO_${i}_PATH"; local path="${!path_var}"
    local label_var="REPO_${i}_LABEL"; local label="${!label_var:-Repo $i}"
    local stack_var="REPO_${i}_STACK"; local stack="${!stack_var:-}"
    qa_test_cmds="${qa_test_cmds}- ${label}: cd ${path} && [test command for ${stack}]
"
  done

  # Find QA-like agent IDs
  local qa_agents=""
  local dev_agents=""
  for i in $(seq 1 "$AGENT_COUNT"); do
    local id_var="AGENT_${i}_ID"; local id="${!id_var}"
    if [[ "$id" =~ qa|test|review ]]; then
      qa_agents="${qa_agents}${id} "
    else
      dev_agents="${dev_agents}${id} "
    fi
  done

  # Dev status poll command
  local dev_status_cmd="cat"
  for id in $dev_agents; do
    dev_status_cmd="${dev_status_cmd} ${WORKSPACE}/${id}-status.txt"
  done
  dev_status_cmd="${dev_status_cmd} 2>/dev/null"

  # Build QA section (only if QA agents exist)
  local qa_section=""
  if [ -n "${qa_agents// /}" ]; then
    local qa_first="${qa_agents%% *}"
    read -r -d '' qa_section << QASEC || true

### Step 5: QA Review (ALWAYS after dev completes)
When dev agents show "done":
1. Read dev result files to confirm what changed
2. Update phase: \`echo "qa-review" > ${WORKSPACE}/current-phase.txt\`
3. Write QA task with SPECIFIC review instructions:
\`\`\`bash
cat << 'TASK' > ${WORKSPACE}/${qa_first}-task.md
## QA Review

### What changed
- [list files modified by dev agents, from their result files]

### What to verify
- [specific behaviors to test based on the task]
- [edge cases relevant to this change]

### How to test
${qa_test_cmds}
Project paths:
${projects_list}
TASK
\`\`\`
4. Poll QA status every 30 seconds:
\`\`\`bash
cat ${WORKSPACE}/${qa_first}-status.txt 2>/dev/null
\`\`\`
IMPORTANT: Do NOT run QA yourself using Task tool. Just write the task file and poll status. The QA tmux pane handles everything.

### Step 6: Act on QA Result
When QA shows "done", read the result file. Look for "PASS" or "FAIL" in the verdict.

**If FAIL (max 2 retries, then ask user):**
1. Read the specific issues QA found
2. Write NEW dev task files that include QA's exact feedback
3. Go back to Step 3 (re-dispatch)
4. If this is the 2nd failure for the same task, STOP and ask the user for guidance

**If PASS — auto commit + deploy (no approval needed):**
1. \`echo "deploying" > ${WORKSPACE}/current-phase.txt\`
2. Show a brief summary of changes (what changed, QA verdict)
3. Commit ONLY the specific files from dev agents' "Changes Made" reports:
\`\`\`bash
${commit_cmds}\`\`\`
4. Deploy immediately:
\`\`\`bash
${PM_DEPLOY_COMMAND}
\`\`\`
5. \`echo "done" > ${WORKSPACE}/current-phase.txt\`
6. Report final status

IMPORTANT:
- QA PASS = auto commit + deploy. Do NOT ask for confirmation.
- NEVER use \`git add -A\` or \`git add .\` — always list specific files from dev agents' change reports
QASEC
  else
    # No QA agents — dev results go directly to commit + deploy
    read -r -d '' qa_section << QASEC || true

### Step 5: Review & Deploy (no QA agent configured)
When dev agents show "done":
1. Read dev result files to confirm what changed
2. \`echo "deploying" > ${WORKSPACE}/current-phase.txt\`
3. Commit ONLY the specific files from dev agents' "Changes Made" reports:
\`\`\`bash
${commit_cmds}\`\`\`
4. Deploy immediately:
\`\`\`bash
${PM_DEPLOY_COMMAND}
\`\`\`
5. \`echo "done" > ${WORKSPACE}/current-phase.txt\`
6. Report final status

IMPORTANT: NEVER use \`git add -A\` or \`git add .\` — always list specific files from dev agents' change reports
QASEC
  fi

  cat > "$WORKSPACE/pm-prompt.txt" << PMEOF
You are the Tech Lead of ${PROJECT_NAME}. You coordinate a team of ${AGENT_COUNT} AI agents.

## Your Team
${team_list}
## Process (follow this EXACTLY)

### Step 1: Quick Context (30 seconds max)
When user describes a task, read 2-3 KEY source files to understand current state.
- Use Read tool only (max 50 lines each with offset/limit)
- Focus on: the file(s) most likely to change, related tests if they exist
- Do NOT explore broadly — you're confirming structure, not analyzing

### Step 2: Write DETAILED Task Files (30 seconds max)
Write task files via Bash. Each task MUST include:
- **What to change** — specific description of the fix/feature
- **Which files to modify** — exact file paths from what you just read
- **How to change them** — describe the code changes needed
- **Expected behavior** — what should work differently after
- **Project path** — so the agent knows where to work

Example of a GOOD task:
\`\`\`
## Task: Fix voice recording auto-send

### Problem
Recording stops on silence detection but doesn't auto-send.

### Files to modify
- path/to/file.ext (line ~45: relevant function)
- path/to/other.ext (the action to reuse)

### Changes needed
Describe the specific code change.

### Expected result
When X happens, Y should occur.

Project: /path/to/project
\`\`\`

Example of a BAD task (never do this):
\`\`\`
버그를 수정해줘.
\`\`\`

### Step 3: Dispatch
Write files to ${WORKSPACE}/ using Bash:
\`\`\`bash
echo "task summary" > ${WORKSPACE}/current-task.txt
echo "implementing" > ${WORKSPACE}/current-phase.txt
${dispatch_agents}\`\`\`

Rules for Step 3 (dev dispatch):
- Write task files ONLY for agents that need to work on this task
- Do NOT write task files for QA agents here — QA runs in Step 5 AFTER dev completes
- CRITICAL: Dispatch ONLY by writing task files via Bash. NEVER use the Task tool or spawn agents directly. The tmux panes auto-detect task files and handle execution.

### Step 4: Monitor Dev
Poll status every 30 seconds:
\`\`\`bash
${dev_status_cmd}
\`\`\`

${qa_section}

## Allowed Tools
- **Read**: 2-3 source files during planning (max 50 lines each). Result files after agents complete.
- **Bash**: write task files, check status, git, deploy

## Forbidden Tools — NEVER USE
- Edit, Write, Glob, Grep, Explore, NotebookEdit — these are for the agents, not you
- Task tool / background agents — NEVER use the Task tool or spawn background agents. ALL dispatch goes through writing task files.

## Projects
${projects_list}
PMEOF

  # Append feedback section if enabled
  if [ "${FEEDBACK_ENABLED:-false}" = "true" ]; then
    cat >> "$WORKSPACE/pm-prompt.txt" << FBEOF

## Feedback Handling

The feedback-watcher.sh runs in background, classifying feedback into 3 tiers.

### Feedback Alert (Critical — automatic)
When ${WORKSPACE}/feedback-alert.md has content:
1. Read feedback-alert.md immediately
2. Read 1-2 related source files to understand the crash/bug
3. Write a dev task file → dispatch (same as Step 2-3 above)
4. After dispatch, clear the alert: \`> ${WORKSPACE}/feedback-alert.md\`

### Feedback Queue (Actionable — periodic check)
During your 30-second status polls, also check feedback-queue.json:
\`\`\`bash
cat ${WORKSPACE}/feedback-queue.json 2>/dev/null | python3 -c "import json,sys; q=json.load(sys.stdin); cats={}; [cats.__setitem__(i['bug_category'], cats.get(i['bug_category'],0)+1) for i in q]; [print(f'{k}: {v}') for k,v in cats.items() if v>=1]" 2>/dev/null
\`\`\`
- If any category has 1+ items, report to user with a summary and create a dev task
- User approves → write dev task and dispatch
- User declines → clear the queue: \`echo '[]' > ${WORKSPACE}/feedback-queue.json\`

### Noise
feedback-log.txt is informational only. Do not act on it. Status Board shows the count.
FBEOF
  fi

  # Append key principle
  cat >> "$WORKSPACE/pm-prompt.txt" << 'PRINCIPLE'

## Key Principle
You are a tech lead, not a dispatcher and not a developer.
- Dispatcher just copies the request → agents get confused, produce bad results
- Developer does everything themselves → agents are useless
- Tech Lead reads just enough to write clear instructions → agents deliver quality work
PRINCIPLE
}

generate_pm_prompt

# ── PM launcher script ──
cat > "$WORKSPACE/pm-launch.sh" << PMLAUNCH
#!/bin/bash
SYS="\$(cat ${WORKSPACE}/pm-prompt.txt)"
exec claude --dangerously-skip-permissions --append-system-prompt "\$SYS"
PMLAUNCH
chmod +x "$WORKSPACE/pm-launch.sh"

# ══════════════════════════════════════════════════════════════
# 5. Feedback Watcher (conditional)
#    ★ FEEDBACK_ENABLED=true일 때만 생성
# ══════════════════════════════════════════════════════════════

generate_feedback_watcher() {
  local ws_url="${FEEDBACK_WS_URL:-wss://localhost/cable}"
  local api_url="${FEEDBACK_API_URL:-https://localhost}"
  local admin_token="${FEEDBACK_ADMIN_TOKEN:-}"
  local channel="${FEEDBACK_CHANNEL:-FeedbackChannel}"
  local poll_interval="${FEEDBACK_POLL_INTERVAL:-60}"

  cat > "$WORKSPACE/feedback-watcher.sh" << FEEDBACKWATCHER
#!/bin/bash
# feedback-watcher.sh — WebSocket client for feedback pipeline
# Connects to ActionCable, classifies feedback into 3 tiers

TEAM="${WORKSPACE}"
WS_URL="\${REPSTACK_WS_URL:-${ws_url}}"
API_BASE="\${REPSTACK_API_URL:-${api_url}}"
ADMIN_TOKEN="\${FEEDBACK_ADMIN_TOKEN:-${admin_token}}"
LOG="\$TEAM/feedback-watcher-log.txt"
VENV="\$TEAM/.venv"

# Kill existing feedback-watcher processes
for pid in \$(pgrep -f "feedback-watcher.sh" 2>/dev/null); do
  [ "\$pid" != "\$\$" ] && kill "\$pid" 2>/dev/null
done

mkdir -p "\$TEAM"
touch "\$TEAM/feedback-log.txt"
[ ! -f "\$TEAM/feedback-queue.json" ] || [ ! -s "\$TEAM/feedback-queue.json" ] && echo '[]' > "\$TEAM/feedback-queue.json"
: > "\$TEAM/feedback-alert.md"
echo "critical:0 actionable:0 noise:0" > "\$TEAM/feedback-stats.txt"

log() {
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG"
}

if [ ! -f "\$VENV/bin/python3" ]; then
  log "Creating venv and installing websockets..."
  python3 -m venv "\$VENV"
  "\$VENV/bin/pip" install -q websockets
fi

log "feedback-watcher starting — connecting to \$WS_URL"

while true; do
  "\$VENV/bin/python3" << 'PYEOF'
import asyncio
import json
import os
import sys
import signal
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

TEAM = os.environ.get("TEAM", "${WORKSPACE}")
WS_URL = os.environ.get("REPSTACK_WS_URL", "${ws_url}")
API_BASE = os.environ.get("REPSTACK_API_URL", "${api_url}")
ADMIN_TOKEN = os.environ.get("FEEDBACK_ADMIN_TOKEN", "${admin_token}")
CHANNEL = "${channel}"
POLL_INTERVAL = ${poll_interval}

STATS = {"critical": 0, "actionable": 0, "noise": 0}
SEEN_IDS = set()

try:
    existing = Path(f"{TEAM}/feedback-stats.txt").read_text().strip()
    for part in existing.split():
        if ":" in part:
            k, v = part.split(":", 1)
            if k in STATS and v.isdigit():
                STATS[k] = int(v)
except Exception:
    pass

try:
    seen_data = json.loads(Path(f"{TEAM}/feedback-seen-ids.json").read_text())
    SEEN_IDS = set(seen_data)
except Exception:
    pass

def save_seen_ids():
    Path(f"{TEAM}/feedback-seen-ids.json").write_text(json.dumps(sorted(SEEN_IDS)))

def write_stats(last=""):
    line = f"critical:{STATS['critical']} actionable:{STATS['actionable']} noise:{STATS['noise']}"
    if last:
        line += f" last:{last}"
    Path(f"{TEAM}/feedback-stats.txt").write_text(line + "\n")

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(f"{TEAM}/feedback-watcher-log.txt", "a") as f:
        f.write(f"[{ts}] {msg}\n")

def classify_feedback(data):
    severity = data.get("severity", "low")
    category = data.get("bug_category", "other")
    if severity == "critical" or (severity == "high" and category == "crash"):
        return "critical"
    if severity == "medium" or (severity == "high" and category != "crash"):
        return "actionable"
    return "noise"

def handle_critical(data):
    summary = data.get("summary", "Unknown issue")
    repo = data.get("affected_repo", "unknown")
    text = data.get("feedback_text", "")
    version = data.get("app_version", "?")
    ts = datetime.now().strftime("%H:%M")
    alert = (
        f"# Critical Feedback Alert\n\n"
        f"**Severity**: {data.get('severity', '?')} | "
        f"**Category**: {data.get('bug_category', '?')} | "
        f"**Repo**: {repo}\n\n"
        f"## Summary\n{summary}\n\n"
        f"## User Feedback\n{text}\n\n"
        f"**App Version**: {version} | **Time**: {ts}\n"
        f"**Feedback ID**: {data.get('id', '?')}\n"
    )
    Path(f"{TEAM}/feedback-alert.md").write_text(alert)
    STATS["critical"] += 1
    write_stats(f'"{summary[:40]}" {ts}')
    log(f"CRITICAL: {summary} (repo={repo})")
    try:
        import subprocess
        subprocess.run(["tmux", "display-message", "-d", "5000", f"CRITICAL FEEDBACK: {summary[:60]}"], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def handle_actionable(data):
    summary = data.get("summary", "Unknown")
    category = data.get("bug_category", "other")
    fid = data.get("id")
    queue_path = Path(f"{TEAM}/feedback-queue.json")
    try:
        queue = json.loads(queue_path.read_text())
    except (json.JSONDecodeError, FileNotFoundError):
        queue = []
    if fid and any(q.get("id") == fid for q in queue):
        log(f"ACTIONABLE (dedup skip): id={fid} already in queue")
        return
    queue.append({
        "id": fid,
        "severity": data.get("severity"),
        "bug_category": category,
        "affected_repo": data.get("affected_repo"),
        "summary": summary,
        "feedback_text": data.get("feedback_text", ""),
        "app_version": data.get("app_version"),
        "received_at": datetime.now().isoformat()
    })
    queue_path.write_text(json.dumps(queue, ensure_ascii=False, indent=2))
    STATS["actionable"] += 1
    ts = datetime.now().strftime("%H:%M")
    write_stats(f'"{summary[:40]}" {ts}')
    log(f"ACTIONABLE: {summary} (category={category})")
    same_cat = [q for q in queue if q.get("bug_category") == category]
    if len(same_cat) >= 3:
        try:
            import subprocess
            subprocess.run(["tmux", "display-message", "-d", "5000", f"{len(same_cat)}x {category} feedback queued"], stderr=subprocess.DEVNULL)
        except Exception:
            pass

def handle_noise(data):
    summary = data.get("summary", "Unknown")
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(f"{TEAM}/feedback-log.txt", "a") as f:
        f.write(f"[{ts}] [{data.get('severity','?')}] [{data.get('bug_category','?')}] {summary}\n")
    STATS["noise"] += 1
    write_stats(f'"{summary[:40]}" {datetime.now().strftime("%H:%M")}')
    log(f"NOISE: {summary}")

def process_feedback(data):
    fid = data.get("id")
    if fid and fid in SEEN_IDS:
        return
    if fid:
        SEEN_IDS.add(fid)
        save_seen_ids()
    tier = classify_feedback(data)
    if tier == "critical":
        handle_critical(data)
    elif tier == "actionable":
        handle_actionable(data)
    else:
        handle_noise(data)

async def api_poller():
    url = f"{API_BASE}/admin/testflight_feedbacks?admin_token={ADMIN_TOKEN}&limit=20"
    log(f"API poller started — polling every {POLL_INTERVAL}s")
    first_run = len(SEEN_IDS) == 0
    while True:
        try:
            await asyncio.sleep(POLL_INTERVAL)
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                body = json.loads(resp.read().decode())
            feedbacks = body.get("feedbacks", [])
            if first_run:
                for f in feedbacks:
                    fid = f.get("id")
                    if fid:
                        SEEN_IDS.add(fid)
                save_seen_ids()
                log(f"API poller seeded {len(SEEN_IDS)} existing feedback IDs")
                first_run = False
                continue
            new_count = 0
            for f in feedbacks:
                fid = f.get("id")
                if fid and fid not in SEEN_IDS:
                    summary = None
                    if f.get("ai_analysis_json"):
                        summary = f["ai_analysis_json"].get("summary")
                    data = {
                        "id": fid,
                        "severity": f.get("severity", "low"),
                        "bug_category": f.get("bug_category", "other"),
                        "affected_repo": f.get("affected_repo"),
                        "summary": summary or f.get("feedback_text", "")[:80],
                        "feedback_text": f.get("feedback_text", ""),
                        "app_version": f.get("app_version"),
                    }
                    process_feedback(data)
                    new_count += 1
            if new_count > 0:
                log(f"API poller found {new_count} new feedback(s)")
        except asyncio.CancelledError:
            break
        except Exception as e:
            log(f"API poller error: {e}")

async def ws_listener():
    try:
        import websockets
    except ImportError:
        log("ERROR: websockets not installed — running API-only mode")
        await asyncio.Event().wait()
        return
    retry_delay = 2
    max_retry = 30
    while True:
        try:
            log(f"Connecting to {WS_URL}...")
            async with websockets.connect(
                WS_URL,
                subprotocols=["actioncable-v1-json"],
                ping_interval=None,
                ping_timeout=None,
                close_timeout=10,
            ) as ws:
                retry_delay = 2
                welcome = await asyncio.wait_for(ws.recv(), timeout=10)
                welcome_data = json.loads(welcome)
                if welcome_data.get("type") != "welcome":
                    log(f"Unexpected welcome: {welcome}")
                    continue
                log("Connected — received welcome")
                subscribe_cmd = json.dumps({
                    "command": "subscribe",
                    "identifier": json.dumps({"channel": CHANNEL})
                })
                await ws.send(subscribe_cmd)
                subscribed = False
                for _ in range(10):
                    raw = await asyncio.wait_for(ws.recv(), timeout=10)
                    msg = json.loads(raw)
                    if msg.get("type") == "confirm_subscription":
                        log(f"Subscribed to {CHANNEL}")
                        subscribed = True
                        break
                    if msg.get("type") == "ping":
                        continue
                    if msg.get("type") == "reject_subscription":
                        log(f"Subscription rejected")
                        break
                    log(f"Subscription response: {raw}")
                if not subscribed:
                    log("Failed to subscribe, retrying...")
                    await asyncio.sleep(retry_delay)
                    continue
                async for raw in ws:
                    msg = json.loads(raw)
                    msg_type = msg.get("type")
                    if msg_type == "ping":
                        continue
                    if msg_type == "disconnect":
                        log(f"Server disconnect: {msg.get('reason', 'unknown')}")
                        break
                    if "message" in msg:
                        data = msg["message"]
                        process_feedback(data)
        except asyncio.CancelledError:
            log("WebSocket shutting down")
            break
        except Exception as e:
            log(f"Connection error: {e} — retrying in {retry_delay}s")
            await asyncio.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, max_retry)

async def main():
    log("Starting dual-mode: WebSocket + API polling")
    await asyncio.gather(ws_listener(), api_poller())

def shutdown(signum, frame):
    log("Received signal, shutting down")
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)
asyncio.run(main())
PYEOF
  exit_code=\$?
  log "Python exited with code \$exit_code — restarting in 5s"
  sleep 5
done
FEEDBACKWATCHER
  chmod +x "$WORKSPACE/feedback-watcher.sh"
}

if [ "${FEEDBACK_ENABLED:-false}" = "true" ]; then
  generate_feedback_watcher
fi

# ══════════════════════════════════════════════════════════════
# 6. tmux Layout — dynamic N-column
#    ★ 하드코딩 4컬럼 → AGENT_COUNT+1 컬럼 동적 분할
# ══════════════════════════════════════════════════════════════
#
# Layout:
#   ┌──────────┬──────────┬──────────┬─── ─ ─ ──┐
#   │  Status  │ Agent 1  │ Agent 2  │  Agent N  │
#   │  Board   │          │          │           │
#   ├──────────┤          │          │           │
#   │   PM     │          │          │           │
#   └──────────┴──────────┴──────────┴─── ─ ─ ──┘

# Kill old session
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Resolve first agent's repo path for initial pane
first_repo_var="AGENT_1_REPO"
first_repo_idx="${!first_repo_var:-1}"
first_repo_path_var="REPO_${first_repo_idx}_PATH"
first_repo_path="${!first_repo_path_var:-$DEFAULT_REPO_PATH}"

# Start session — this becomes the leftmost pane
tmux new-session -d -s "$SESSION_NAME" -c "$DEFAULT_REPO_PATH"

# Split: left 25% | right 75%
tmux split-window -h -d -t "$SESSION_NAME" -c "$first_repo_path" -l 75%

# Get right pane ID — this becomes Agent 1
RIGHT=$(tmux display-message -t "$SESSION_NAME:0.1" -p '#{pane_id}' 2>/dev/null \
  || tmux list-panes -t "$SESSION_NAME" -F '#{pane_id}' | tail -1)

# Split right into N agent columns
declare -a AGENT_PANES
AGENT_PANES[0]="$RIGHT"

for i in $(seq 2 "$AGENT_COUNT"); do
  # Percentage for new pane: remaining agents / (remaining agents + 1)
  remaining=$((AGENT_COUNT - i + 1))
  total_remaining=$((AGENT_COUNT - i + 2))
  pct=$(( remaining * 100 / total_remaining ))

  # Resolve this agent's repo path
  agent_repo_var="AGENT_${i}_REPO"
  agent_repo_idx="${!agent_repo_var:-1}"
  agent_repo_path_var="REPO_${agent_repo_idx}_PATH"
  agent_repo_path="${!agent_repo_path_var:-$DEFAULT_REPO_PATH}"

  prev_idx=$((i - 2))
  new_pane=$(tmux split-window -h -d -t "${AGENT_PANES[$prev_idx]}" \
    -c "$agent_repo_path" -P -F '#{pane_id}' -l "${pct}%")
  AGENT_PANES[$((i - 1))]="$new_pane"
done

# Left column: top=status (35%), bottom=PM (65%)
LEFT=$(tmux display-message -t "$SESSION_NAME:0.0" -p '#{pane_id}' 2>/dev/null \
  || tmux list-panes -t "$SESSION_NAME" -F '#{pane_id}' | head -1)
ST="$LEFT"
PM=$(tmux split-window -v -d -t "$ST" -c "$DEFAULT_REPO_PATH" -P -F '#{pane_id}' -l 65%)

# Pane titles
tmux select-pane -t "$ST" -T "Status Board"
tmux select-pane -t "$PM" -T "Tech Lead (PM)"

for i in $(seq 1 "$AGENT_COUNT"); do
  id_var="AGENT_${i}_ID"; id="${!id_var}"
  name_var="AGENT_${i}_NAME"; name="${!name_var:-$id}"
  persona_var="AGENT_${i}_PERSONA"; persona="${!persona_var:-}"
  pane_idx=$((i - 1))
  tmux select-pane -t "${AGENT_PANES[$pane_idx]}" -T "${name} (${persona})"
done

tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" history-limit 50000
tmux set-option -t "$SESSION_NAME" mouse on

# ══════════════════════════════════════════════════════════════
# 7. Launch Components
# ══════════════════════════════════════════════════════════════

# Status Monitor
tmux send-keys -t "$ST" "$WORKSPACE/status-monitor.sh $WORKSPACE" Enter

# Agent Viewers
for i in $(seq 1 "$AGENT_COUNT"); do
  id_var="AGENT_${i}_ID"; id="${!id_var}"
  pane_idx=$((i - 1))
  tmux send-keys -t "${AGENT_PANES[$pane_idx]}" "$WORKSPACE/agent-viewer.sh $id $WORKSPACE" Enter
done

# Feedback Watcher (background, conditional)
if [ "${FEEDBACK_ENABLED:-false}" = "true" ] && [ -f "$WORKSPACE/feedback-watcher.sh" ]; then
  "$WORKSPACE/feedback-watcher.sh" &
  WATCHER_PID=$!
  echo "$WATCHER_PID" > "$WORKSPACE/feedback-watcher.pid"
fi

# PM (Claude interactive mode)
tmux select-pane -t "$PM"
tmux send-keys -t "$PM" "$WORKSPACE/pm-launch.sh" Enter

# ══════════════════════════════════════════════════════════════
# Cleanup + Attach
# ══════════════════════════════════════════════════════════════

cleanup() {
  if [ -f "$WORKSPACE/feedback-watcher.pid" ]; then
    kill "$(cat "$WORKSPACE/feedback-watcher.pid")" 2>/dev/null
    rm -f "$WORKSPACE/feedback-watcher.pid"
  fi
}
trap cleanup EXIT

tmux attach-session -t "$SESSION_NAME"
