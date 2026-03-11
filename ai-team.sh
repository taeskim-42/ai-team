#!/bin/bash
# ai-team.sh — AI Team Launcher (Claude Code Agent Teams)
# Usage: ai-team [project-name | /path/to/repo]
#        ai-team --install    (create global 'ai-team' command)
#        ai-team --uninstall  (remove global command)
#
# Reads team.config.sh, injects persona .md files into a system prompt,
# and launches Claude Code with native Agent Teams enabled.

set -euo pipefail

_src="${BASH_SOURCE[0]}"
while [ -L "$_src" ]; do
  _dir="$(cd "$(dirname "$_src")" && pwd)"
  _src="$(readlink "$_src")"
  [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
mkdir -p "$PROJECTS_DIR"

# ══════════════════════════════════════════════════════════════
# Install / Uninstall global command
# ══════════════════════════════════════════════════════════════

_LINK_NAME="ai-team"

_find_bin_dir() {
  local user_bin="$HOME/.local/bin"
  if [ -d "$user_bin" ] && echo "$PATH" | grep -q "$user_bin"; then
    echo "$user_bin"
  elif [ -d "/usr/local/bin" ]; then
    echo "/usr/local/bin"
  else
    echo "$user_bin"
  fi
}

if [ "${1:-}" = "--install" ]; then
  _bin_dir="$(_find_bin_dir)"
  _link="$_bin_dir/$_LINK_NAME"
  _target="$SCRIPT_DIR/ai-team.sh"
  mkdir -p "$_bin_dir"
  if [ -L "$_link" ] && [ "$(readlink "$_link")" = "$_target" ]; then
    echo "✓ Already installed: $_link → $_target"; exit 0
  fi
  [ -e "$_link" ] && { [ -L "$_link" ] && rm "$_link" || { echo "✗ $_link exists and is not a symlink."; exit 1; }; }
  ln -s "$_target" "$_link"; chmod +x "$_target"
  echo "✓ Installed: $_link → $_target"
  echo "  Usage: ai-team [project-name]"
  echo "$PATH" | grep -q "$_bin_dir" || echo "  ⚠ Add to PATH: export PATH=\"$_bin_dir:\$PATH\""
  exit 0
fi

if [ "${1:-}" = "--uninstall" ]; then
  _bin_dir="$(_find_bin_dir)"
  _link="$_bin_dir/$_LINK_NAME"
  [ -L "$_link" ] && { rm "$_link"; echo "✓ Removed: $_link"; } || echo "· Not installed"
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# Colors & i18n (minimal)
# ══════════════════════════════════════════════════════════════

_R=$'\033[0m'; _B=$'\033[1m'; _D=$'\033[2m'
_CYN=$'\033[36m'; _GRY=$'\033[90m'; _RED=$'\033[31m'
_GRN=$'\033[32m'; _YEL=$'\033[33m'; _WHT=$'\033[97m'

_lang_file="$SCRIPT_DIR/.ai-team-lang"
LANG_CODE="en"
[ -f "$_lang_file" ] && LANG_CODE=$(cat "$_lang_file")

if [ "$LANG_CODE" = "ko" ]; then
  L_EXISTING="기존 프로젝트:"; L_NEW="+ 새 프로젝트"; L_SELECT="선택"
  L_INVALID="올바른 번호를 선택해주세요"; L_STARTING="AI Team 시작 중..."
  L_NO_PERSONA="페르소나 파일 없음"
else
  L_EXISTING="Existing projects:"; L_NEW="+ New project"; L_SELECT="Select"
  L_INVALID="Please select a valid number"; L_STARTING="Starting AI Team..."
  L_NO_PERSONA="Persona file not found"
fi

# ══════════════════════════════════════════════════════════════
# Resolve config from argument
# ══════════════════════════════════════════════════════════════

CONFIG=""
QUICK_SETUP_PATH=""

if [ -n "${1:-}" ]; then
  if [ -f "$1" ]; then
    CONFIG="$1"
  elif [ -f "$PROJECTS_DIR/$1/team.config.sh" ]; then
    CONFIG="$PROJECTS_DIR/$1/team.config.sh"
  elif [ -f "$1/team.config.sh" ]; then
    CONFIG="$1/team.config.sh"
  elif [ -d "$1" ]; then
    # Check if any existing project config points to this path
    _resolved="$(cd "$1" && pwd)"
    _found_cfg=""
    for _cfg in "$PROJECTS_DIR"/*/team.config.sh; do
      [ -f "$_cfg" ] || continue
      _pp=$(grep -m1 '^PROJECT_PATH=\|^REPO_1_PATH=' "$_cfg" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
      if [ "$_pp" = "$_resolved" ]; then
        _found_cfg="$_cfg"; break
      fi
    done
    if [ -n "$_found_cfg" ]; then
      CONFIG="$_found_cfg"
    else
      QUICK_SETUP_PATH="$_resolved"
    fi
  else
    echo "ERROR: Project '$1' not found"; exit 1
  fi
fi

# ══════════════════════════════════════════════════════════════
# Project selector (no args → pick or create)
# ══════════════════════════════════════════════════════════════

if [ -z "$CONFIG" ]; then
  if [ -n "$QUICK_SETUP_PATH" ]; then
    # ── Auto-detect tech stack from repo ──
    _scan_dirs=("$QUICK_SETUP_PATH")
    for _sd in "$QUICK_SETUP_PATH"/*/; do
      [ -d "$_sd" ] || continue
      case "$(basename "$_sd")" in node_modules|.git|.next|dist|build|vendor|__pycache__) continue ;; esac
      _scan_dirs+=("${_sd%/}")
    done
    _has_file() { for _d in "${_scan_dirs[@]}"; do [ -f "$_d/$1" ] && return 0; done; return 1; }

    _det=()
    _has_file "Gemfile"            && _det+=("rails")
    _has_file "Package.swift"      && _det+=("swift")
    { _has_file "next.config.js" || _has_file "next.config.ts" || _has_file "next.config.mjs"; } && _det+=("nextjs")
    { _has_file "nuxt.config.ts" || _has_file "nuxt.config.js"; } && _det+=("nuxt")
    _has_file "tsconfig.json"      && _det+=("typescript")
    _has_file "package.json"       && _det+=("node")
    _has_file "go.mod"             && _det+=("go")
    { _has_file "requirements.txt" || _has_file "pyproject.toml"; } && _det+=("python")
    _has_file "Cargo.toml"         && _det+=("rust")
    { _has_file "build.gradle" || _has_file "pom.xml"; } && _det+=("java")
    _has_file "composer.json"      && _det+=("php")
    _has_file "Dockerfile"         && _det+=("docker")

    # Nothing detected → fall back to interactive setup
    if [ ${#_det[@]} -eq 0 ]; then
      exec bash "$SCRIPT_DIR/setup.sh" "$QUICK_SETUP_PATH"
    fi

    _thas() { printf '%s\n' "${_det[@]}" | grep -qw "$1"; }

    # ── Match rules to detected tech ──
    _frontend_rules=""
    _backend_rules=""

    _thas "swift"      && _frontend_rules="swift-ios"
    _thas "nextjs"     && _frontend_rules="frontend-react,frontend-nextjs"
    _thas "nuxt"       && _frontend_rules="frontend-vue"
    if [ -z "$_frontend_rules" ]; then
      { _thas "typescript" || _thas "node"; } && _frontend_rules="frontend-react"
    fi

    _thas "rails"      && _backend_rules="backend-rails"
    _thas "go"         && _backend_rules="backend-go"
    _thas "python"     && _backend_rules="backend-python"
    _thas "rust"       && _backend_rules="backend-rust"
    _thas "java"       && _backend_rules="backend-java"
    _thas "php"        && _backend_rules="backend-php"

    # Attach infra rules to backend (or frontend if no backend)
    _thas "docker"     && {
      if [ -n "$_backend_rules" ]; then _backend_rules="${_backend_rules},infra"
      elif [ -n "$_frontend_rules" ]; then _frontend_rules="${_frontend_rules},infra"
      else _backend_rules="infra"; fi
    }

    # Helper: rules CSV → tech label for display
    _rules_to_tech() {
      local _result="" _r _t
      IFS=',' read -ra _parts <<< "$1"
      for _r in "${_parts[@]}"; do
        case "$_r" in
          frontend-react)   _t="React" ;;
          frontend-nextjs)  _t="Next.js" ;;
          frontend-vue)     _t="Vue.js · Nuxt" ;;
          swift-ios)        _t="Swift · iOS" ;;
          backend-rails)    _t="Ruby · Rails" ;;
          backend-go)       _t="Go" ;;
          backend-python)   _t="Python" ;;
          backend-rust)     _t="Rust" ;;
          backend-java)     _t="Java · Spring" ;;
          backend-php)      _t="PHP · Laravel" ;;
          infra)            _t="Docker · Infra" ;;
          *)                _t="" ;;
        esac
        [ -n "$_t" ] && _result="${_result:+$_result · }$_t"
      done
      echo "$_result"
    }

    # ── Build agent list (parallel arrays) ──
    _agent_ids=(); _agent_personas=(); _agent_rules=(); _agent_techs=()
    _has_both=false
    [ -n "$_frontend_rules" ] && [ -n "$_backend_rules" ] && _has_both=true

    if [ -n "$_frontend_rules" ]; then
      if $_has_both; then _agent_ids+=("frontend-dev"); else _agent_ids+=("dev"); fi
      _agent_personas+=("dev")
      _agent_rules+=("$_frontend_rules")
      _agent_techs+=("$(_rules_to_tech "$_frontend_rules")")
    fi

    if [ -n "$_backend_rules" ]; then
      if $_has_both; then _agent_ids+=("backend-dev"); else _agent_ids+=("dev"); fi
      _agent_personas+=("dev")
      _agent_rules+=("$_backend_rules")
      _agent_techs+=("$(_rules_to_tech "$_backend_rules")")
    fi

    # QA always last
    _agent_ids+=("qa")
    _agent_personas+=("Kent Beck")
    _agent_rules+=("")
    _agent_techs+=("Testing · Quality Assurance")

    # ── Build stack label ──
    _stk=()
    _thas "nextjs"     && _stk+=("Next.js")
    _thas "nuxt"       && _stk+=("Nuxt")
    _thas "typescript" && _stk+=("TypeScript")
    _thas "node" && ! _thas "nextjs" && ! _thas "nuxt" && _stk+=("Node.js")
    _thas "rails"      && _stk+=("Rails")
    _thas "swift"      && _stk+=("Swift")
    _thas "go"         && _stk+=("Go")
    _thas "python"     && _stk+=("Python")
    _thas "rust"       && _stk+=("Rust")
    _thas "java"       && _stk+=("Java")
    _thas "php"        && _stk+=("PHP/Laravel")
    _thas "docker"     && _stk+=("Docker")
    _STACK=$(printf '%s, ' "${_stk[@]}"); _STACK="${_STACK%, }"

    # ── Generate team.config.sh ──
    _proj_name="$(basename "$QUICK_SETUP_PATH")"
    _slug=$(printf '%s' "$_proj_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--*/-/g;s/^-//;s/-$//')
    _cfg_dir="$PROJECTS_DIR/${_slug}-team"
    mkdir -p "$_cfg_dir"
    _cfg_file="$_cfg_dir/team.config.sh"

    {
      printf '#!/bin/bash\n'
      printf '# AI Team — Auto-detected from %s\n' "$QUICK_SETUP_PATH"
      printf '# Stack: %s\n\n' "$_STACK"
      printf 'PROJECT_NAME="%s"\n' "$_proj_name"
      printf 'SESSION_NAME="%s-team"\n\n' "$_slug"
      printf 'REPO_COUNT=1\n'
      printf 'REPO_1_PATH="%s"\n' "$QUICK_SETUP_PATH"
      printf 'REPO_1_LABEL="%s"\n' "$_proj_name"
      printf 'REPO_1_STACK="%s"\n\n' "$_STACK"
      printf 'AGENT_COUNT=%d\n' "${#_agent_ids[@]}"
      for _ai in "${!_agent_ids[@]}"; do
        _aidx=$((_ai + 1))
        printf '\nAGENT_%d_ID="%s"\n' "$_aidx" "${_agent_ids[$_ai]}"
        printf 'AGENT_%d_PERSONA="%s"\n' "$_aidx" "${_agent_personas[$_ai]}"
        [ -n "${_agent_rules[$_ai]}" ] && printf 'AGENT_%d_RULES="%s"\n' "$_aidx" "${_agent_rules[$_ai]}"
        printf 'AGENT_%d_TECH="%s"\n' "$_aidx" "${_agent_techs[$_ai]}"
        printf 'AGENT_%d_REPO=1\n' "$_aidx"
      done
    } > "$_cfg_file"

    CONFIG="$_cfg_file"

    # ── Show auto-detect summary ──
    printf "\n"
    printf "  ${_CYN}${_B}┌─────────────────────────────────────────┐${_R}\n"
    printf "  ${_CYN}${_B}│${_R}  ${_GRN}✓${_R} ${_B}Auto-detected${_R}%-*s${_CYN}${_B}│${_R}\n" 22 ""
    printf "  ${_CYN}${_B}└─────────────────────────────────────────┘${_R}\n"
    printf "\n"
    printf "  ${_B}Project${_R}  %s ${_GRY}(%s)${_R}\n" "$_proj_name" "$_STACK"
    printf "  ${_B}Team${_R}    "
    for _ai in "${!_agent_ids[@]}"; do
      printf " ${_CYN}@%s${_R}${_GRY}(%s)${_R}" "${_agent_ids[$_ai]}" "${_agent_techs[$_ai]}"
    done
    printf "\n  ${_B}Config${_R}   ${_GRY}%s${_R}\n" "$_cfg_file"
  fi

  # Skip project selector if auto-detect already set CONFIG
  if [ -n "$CONFIG" ]; then :; else

  _project_dirs=(); _project_names=()
  while IFS= read -r _cfg; do
    _pdir=$(dirname "$_cfg")
    _pname=$(grep '^PROJECT_NAME=' "$_cfg" 2>/dev/null | head -1 | cut -d'"' -f2)
    _project_dirs+=("$_pdir")
    _project_names+=("${_pname:-$(basename "$_pdir")}")
  done < <(find "$PROJECTS_DIR" -maxdepth 2 -name 'team.config.sh' -type f 2>/dev/null | sort)

  if [ ${#_project_dirs[@]} -eq 0 ]; then
    exec bash "$SCRIPT_DIR/setup.sh"
  fi

  echo ""
  printf "  ${_CYN}${_B}AI Team${_R}\n"
  printf "  ${_GRY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_R}\n\n"
  printf "  ${_WHT}%s${_R}\n" "$L_EXISTING"
  for _i in "${!_project_dirs[@]}"; do
    _dirname=$(basename "${_project_dirs[$_i]}")
    printf "    ${_WHT}%d)${_R} %s ${_GRY}(%s)${_R}\n" "$((_i + 1))" "${_project_names[$_i]}" "$_dirname"
  done
  _new_idx=$(( ${#_project_dirs[@]} + 1 ))
  printf "    ${_GRN}%d)${_R} ${_GRN}%s${_R}\n" "$_new_idx" "$L_NEW"
  echo ""
  read -e -r -p "  $L_SELECT [1]: " _choice
  _choice="${_choice:-1}"

  if [ "$_choice" -eq "$_new_idx" ] 2>/dev/null; then
    exec bash "$SCRIPT_DIR/setup.sh"
  elif [ "$_choice" -ge 1 ] && [ "$_choice" -le "${#_project_dirs[@]}" ] 2>/dev/null; then
    CONFIG="${_project_dirs[$((_choice - 1))]}/team.config.sh"
  else
    printf "  ${_RED}✗ %s${_R}\n" "$L_INVALID"; exit 1
  fi

  fi # end: skip project selector if CONFIG set
fi

# ══════════════════════════════════════════════════════════════
# Load config
# ══════════════════════════════════════════════════════════════

set +e; source "$CONFIG"; set -e

ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then set -a; source "$ENV_FILE"; set +a; fi

# ══════════════════════════════════════════════════════════════
# Validate config (minimal — no tmux required)
# ══════════════════════════════════════════════════════════════

errors=0
[ -z "${PROJECT_NAME:-}" ] && echo "ERROR: PROJECT_NAME not set" && errors=$((errors+1))
[ -z "${REPO_COUNT:-}" ] || [ "$REPO_COUNT" -lt 1 ] 2>/dev/null && echo "ERROR: REPO_COUNT must be >= 1" && errors=$((errors+1))
[ -z "${AGENT_COUNT:-}" ] || [ "$AGENT_COUNT" -lt 1 ] 2>/dev/null && echo "ERROR: AGENT_COUNT must be >= 1" && errors=$((errors+1))

for i in $(seq 1 "${REPO_COUNT:-0}"); do
  _pv="REPO_${i}_PATH"; _p="${!_pv:-}"
  [ -z "$_p" ] && echo "ERROR: ${_pv} not set" && errors=$((errors+1))
  [ -n "$_p" ] && [ ! -d "$_p" ] && echo "ERROR: ${_pv}='${_p}' not found" && errors=$((errors+1))
done

command -v claude &>/dev/null || { echo "ERROR: 'claude' not found in PATH"; errors=$((errors+1)); }
[ "$errors" -gt 0 ] && exit 1

# ══════════════════════════════════════════════════════════════
# Enable Agent Teams & install hooks (per repo)
# ══════════════════════════════════════════════════════════════

HOOKS_SRC="$SCRIPT_DIR/hooks"
_GLOBAL_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

# Enable Agent Teams in global settings
if [ -f "$_GLOBAL_SETTINGS" ]; then
  _HAS_TEAMS=$(python3 -c "
import json
with open('$_GLOBAL_SETTINGS') as f: d = json.load(f)
print(d.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS',''))
" 2>/dev/null || echo "")
  if [ "$_HAS_TEAMS" != "1" ]; then
    python3 -c "
import json
with open('$_GLOBAL_SETTINGS') as f: d = json.load(f)
d.setdefault('env',{})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
with open('$_GLOBAL_SETTINGS','w') as f: json.dump(d, f, indent=2); f.write('\n')
"
  fi
else
  printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  }\n}\n' > "$_GLOBAL_SETTINGS"
fi

for _ri in $(seq 1 "$REPO_COUNT"); do
  _rp_var="REPO_${_ri}_PATH"; _rp="${!_rp_var:-}"
  [ -z "$_rp" ] && continue

  if [ -d "$HOOKS_SRC" ] && ls "$HOOKS_SRC"/*.sh &>/dev/null; then
    _hooks_dst="$_rp/.claude/hooks"
    _proj_settings="$_rp/.claude/settings.json"
    mkdir -p "$_hooks_dst"
    cp "$HOOKS_SRC"/task-completed.sh "$HOOKS_SRC"/teammate-idle.sh "$HOOKS_SRC"/guard-hooks.sh "$HOOKS_SRC"/update-architecture.sh "$HOOKS_SRC"/scan-architecture.py "$_hooks_dst/" 2>/dev/null || true
    chmod +x "$_hooks_dst"/*.sh

    _PROJ_SETTINGS="$_proj_settings" _HOOKS_DST="$_hooks_dst" python3 << 'PYEOF'
import json, os
s = os.environ["_PROJ_SETTINGS"]
h = os.environ["_HOOKS_DST"]
d = json.load(open(s)) if os.path.exists(s) else {}
d.setdefault("hooks", {})

def has_hook(event, cmd):
    for entry in d["hooks"].get(event, []):
        for hk in entry.get("hooks", []):
            if hk.get("command") == cmd:
                return True
    return True if any(e.get("command") == cmd for e in d["hooks"].get(event, [])) else False

for name, event in {"task-completed.sh":"TaskCompleted","teammate-idle.sh":"TeammateIdle"}.items():
    path = os.path.join(h, name)
    if not os.path.exists(path): continue
    d["hooks"].setdefault(event, [])
    if not has_hook(event, path):
        d["hooks"][event].append({"hooks": [{"type": "command", "command": path}]})

guard = os.path.join(h, "guard-hooks.sh")
if os.path.exists(guard):
    d["hooks"].setdefault("PreToolUse", [])
    if not has_hook("PreToolUse", guard):
        d["hooks"]["PreToolUse"].append({"matcher": "Edit|Write", "hooks": [{"type": "command", "command": guard}]})

os.makedirs(os.path.dirname(s), exist_ok=True)
with open(s,"w") as f: json.dump(d, f, indent=2); f.write("\n")
PYEOF

    chmod 444 "$_hooks_dst"/task-completed.sh "$_hooks_dst"/teammate-idle.sh "$_hooks_dst"/guard-hooks.sh
    printf "  ${_GRN}✓${_R} [repo $_ri] Hooks installed\n"
  fi

  # Generate CLAUDE.md (only if missing)
  _claude_md="$_rp/CLAUDE.md"
  if [ ! -f "$_claude_md" ]; then
    cat > "$_claude_md" << CLAUSEEOF
# $(basename "$_rp")

## Protected Files (DO NOT MODIFY)
- \`.claude/hooks/task-completed.sh\` — Type check + test + file size enforcement
- \`.claude/hooks/teammate-idle.sh\` — Output format enforcement
- \`.claude/hooks/guard-hooks.sh\` — This protection mechanism

## Architecture (Clean Architecture + DDD)
All code MUST follow Clean Architecture with Domain-Driven Design, regardless of project size or language:

**Layer structure (dependency flows inward only):**
- \`domain/\` — Pure business logic. Entities, value objects, repository interfaces. ZERO external dependencies.
- \`application/\` — Use cases. Orchestrates domain objects. Depends only on domain.
- \`infrastructure/\` — Implements domain interfaces. DB, APIs, file system, external services.
- \`presentation/\` — UI or API endpoints. Depends on application layer.

**Rules:**
- Domain NEVER imports from infrastructure or presentation
- Infrastructure implements domain interfaces (dependency inversion)
- Each bounded context has its own domain/application/infrastructure
- Generated files should be excluded from review

## Navigation
- Read \`ARCHITECTURE.md\` FIRST before exploring — it's your codebase map
- Auto-updated by hooks after every task completion
- If missing, run: \`python3 .claude/hooks/scan-architecture.py .\`

## Code Style
- No function exceeds ~30 lines
- No file exceeds ~300 lines — split into focused modules
- No magic numbers or strings — use named constants
- Names are self-documenting
- Errors include context (not silently swallowed)
- Follow existing project conventions
CLAUSEEOF
    printf "  ${_GRN}✓${_R} [repo $_ri] CLAUDE.md created\n"
  fi

  # Generate initial ARCHITECTURE.md
  _arch_update="$_hooks_dst/update-architecture.sh"
  if [ -f "$_arch_update" ] && [ -x "$_arch_update" ]; then
    bash "$_arch_update" "$_rp" 2>/dev/null && \
      printf "  ${_GRN}✓${_R} [repo $_ri] ARCHITECTURE.md generated\n" || true
  fi
done

# ══════════════════════════════════════════════════════════════
# Build system prompt with persona content
# ══════════════════════════════════════════════════════════════

# Helper: resolve persona .md file from name (e.g. "Dan Abramov" → "dan-abramov.md")
_resolve_persona() {
  local persona_name="$1" project_path="$2"
  local slug
  slug="$(printf '%s' "$persona_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
  # Check project-local first, then bundled
  for _pdir in "$project_path/.claude/personas" "$SCRIPT_DIR/personas"; do
    if [ -f "$_pdir/${slug}.md" ]; then
      echo "$_pdir/${slug}.md"
      return 0
    fi
  done
  return 1
}

# Helper: resolve and read rules files, return concatenated content
_resolve_rules() {
  local rules_csv="$1" project_path="$2"
  local _content="" _rule _slug _found
  IFS=',' read -ra _rule_list <<< "$rules_csv"
  for _rule in "${_rule_list[@]}"; do
    _found=""
    # Check project-local first, then bundled
    for _rdir in "$project_path/.claude/rules" "$SCRIPT_DIR/rules"; do
      if [ -f "$_rdir/${_rule}.md" ]; then
        _found="$_rdir/${_rule}.md"
        break
      fi
    done
    if [ -n "$_found" ]; then
      _content="${_content}

$(cat "$_found")"
    else
      printf "  ${_YEL}⚠${_R} Rule file not found: ${_rule}\n" >&2
    fi
  done
  echo "$_content"
}

# Build team roster and persona blocks
TEAM_ROSTER=""
PERSONA_BLOCKS=""
QA_AGENT_ID=""
PRIMARY_REPO_PATH="${REPO_1_PATH:-}"

for i in $(seq 1 "$AGENT_COUNT"); do
  id_var="AGENT_${i}_ID";           id="${!id_var:-agent-$i}"
  persona_var="AGENT_${i}_PERSONA"; persona="${!persona_var:-Agent $i}"
  rules_var="AGENT_${i}_RULES";     rules="${!rules_var:-}"
  subtitle_var="AGENT_${i}_SUBTITLE"; subtitle="${!subtitle_var:-}"
  tech_var="AGENT_${i}_TECH";       tech="${!tech_var:-}"
  repo_var="AGENT_${i}_REPO";       repo_idx="${!repo_var:-1}"

  repo_path_var="REPO_${repo_idx}_PATH";   repo_path="${!repo_path_var:-}"
  repo_stack_var="REPO_${repo_idx}_STACK"; repo_stack="${!repo_stack_var:-}"

  # Detect QA agent
  if [[ "$id" =~ qa|QA|test|review ]]; then
    QA_AGENT_ID="$id"
  fi

  # Build roster line
  TEAM_ROSTER="${TEAM_ROSTER}- @${id} (${persona}) — ${tech}\n"

  # Resolve persona content: dev + rules composition or legacy persona file
  if [ -n "$rules" ]; then
    # New system: compose dev.md + rule files
    persona_md=$(_resolve_persona "$persona" "$repo_path") || {
      printf "  ${_RED}✗${_R} $L_NO_PERSONA: ${persona}\n"; exit 1
    }
    rules_content=$(_resolve_rules "$rules" "$repo_path")
    persona_content="$(cat "$persona_md")
${rules_content}"
  else
    # Legacy: use persona file as-is (backward compatible)
    persona_md=$(_resolve_persona "$persona" "$repo_path") || {
      printf "  ${_RED}✗${_R} $L_NO_PERSONA: ${persona}\n"; exit 1
    }
    persona_content=$(cat "$persona_md")
  fi

  # Build persona block
  PERSONA_BLOCKS="${PERSONA_BLOCKS}
### Teammate: ${id}
Working directory: ${repo_path}
Tech stack: ${repo_stack}

<persona>
${persona_content}

Work in ${repo_path} (${repo_stack}).
</persona>

---
"
done

# Build repo list
REPO_LIST=""
for i in $(seq 1 "$REPO_COUNT"); do
  _label_var="REPO_${i}_LABEL"; _label="${!_label_var:-Repo $i}"
  _path_var="REPO_${i}_PATH";   _path="${!_path_var:-}"
  _stack_var="REPO_${i}_STACK"; _stack="${!_stack_var:-}"
  REPO_LIST="${REPO_LIST}- ${_label}: ${_path} (${_stack})\n"
done

# QA step (conditional)
QA_STEP=""
if [ -n "$QA_AGENT_ID" ]; then
  QA_STEP="
### Step 4: QA Review (ALWAYS after dev completes)
When dev teammates finish:
1. Review their output to confirm what changed
2. Assign a QA task to @${QA_AGENT_ID} with SPECIFIC review instructions:
   - What files were changed (from dev output)
   - What behaviors to verify
   - Edge cases relevant to this change
   - Which test commands to run

### Step 5: Act on QA Result
- **FAIL** (max 2 retries, then ask user): Read QA feedback, assign new dev tasks, re-dispatch
- **PASS**: Show summary, commit specific files only (never git add -A)"
fi

# Assemble the full system prompt
SYSTEM_PROMPT="You are the Tech Lead of ${PROJECT_NAME}.

## Your Team

$(printf '%b' "$TEAM_ROSTER")

## Spawning Teammates

Create an agent team. For each teammate below, include the FULL content inside <persona> tags as their spawn prompt. Do NOT summarize — use the complete persona verbatim.

${PERSONA_BLOCKS}

## Project Repositories

$(printf '%b' "$REPO_LIST")

## Process (follow this EXACTLY)

### Step 1: Quick Context (30 seconds max)
1. Read ARCHITECTURE.md FIRST — this is your codebase map (auto-updated by hooks)
2. Based on the map, read 2-3 KEY source files to understand current state
- Use Read tool only (max 50 lines each with offset/limit)
- Focus on: the file(s) most likely to change, related tests if they exist
- Do NOT explore broadly — the map tells you where everything is

### Step 2: Write DETAILED Tasks
Each task MUST include:
- **What to change** — specific description
- **Which files to modify** — exact file paths
- **How to change them** — describe the code changes needed
- **Expected behavior** — what should work differently after
- **Project path** — so the agent knows where to work

### Step 3: Dispatch to Teammates
Assign tasks to dev teammates. Do NOT assign to QA yet.
${QA_STEP}

## Team Rules

### Git
- NEVER use git add -A or git add . — always stage specific files
- One logical change per commit
- Commit message: explain WHY, not just WHAT

### Architecture (Clean Architecture + DDD)
All code MUST follow Clean Architecture with Domain-Driven Design, regardless of project size or language:

**Layer structure (dependency flows inward only):**
- domain/ — Pure business logic. Entities, value objects, repository interfaces. ZERO external dependencies.
- application/ — Use cases. Orchestrates domain objects. Depends only on domain.
- infrastructure/ — Implements domain interfaces. DB, APIs, file system, external services.
- presentation/ — UI or API endpoints. Depends on application layer.

**Rules:**
- Domain NEVER imports from infrastructure or presentation
- Infrastructure implements domain interfaces (dependency inversion)
- Each bounded context has its own domain/application/infrastructure
- Generated files should be excluded from review

Adapt folder naming to language conventions (e.g. src/domain/, lib/2_domain/, pkg/domain/), but the layering principle is non-negotiable.

### Code Style
- No function exceeds ~30 lines
- No file exceeds ~300 lines — split into focused modules
- No magic numbers or strings — use named constants
- Names are self-documenting
- Errors include context (not silently swallowed)
- Follow existing project conventions

### Protected Files (DO NOT MODIFY)
- .claude/hooks/task-completed.sh — Type check + test + file size enforcement
- .claude/hooks/teammate-idle.sh — Output format enforcement
- .claude/hooks/guard-hooks.sh — This protection mechanism

## Key Principle
You are a tech lead, not a dispatcher and not a developer.
- Dispatcher just copies the request → agents produce bad results
- Developer does everything themselves → agents are useless
- Tech Lead reads just enough to write clear instructions → agents deliver quality work"

# ══════════════════════════════════════════════════════════════
# Launch Claude Code with Agent Teams
# ══════════════════════════════════════════════════════════════

# Build agent table for display
_agent_lines=""
for _ai in $(seq 1 "$AGENT_COUNT"); do
  _aid_var="AGENT_${_ai}_ID"; _aid="${!_aid_var:-}"
  _ap_var="AGENT_${_ai}_PERSONA"; _ap="${!_ap_var:-}"
  _as_var="AGENT_${_ai}_SUBTITLE"; _as="${!_as_var:-}"
  _at_var="AGENT_${_ai}_TECH"; _at="${!_at_var:-}"
  _agent_lines="${_agent_lines}  ${_CYN}@${_aid}${_R}  ${_WHT}${_ap}${_R} ${_GRY}${_as}${_R}  ${_D}${_at}${_R}\n"
done

# Repo lines
_repo_lines=""
for _ri in $(seq 1 "$REPO_COUNT"); do
  _rl_var="REPO_${_ri}_LABEL"; _rl="${!_rl_var:-}"
  _rp_var="REPO_${_ri}_PATH";  _rp="${!_rp_var:-}"
  _rs_var="REPO_${_ri}_STACK"; _rs="${!_rs_var:-}"
  _display_rp="${_rp/#$HOME/\~}"
  _repo_lines="${_repo_lines}  ${_WHT}${_rl}${_R}  ${_GRY}${_display_rp}${_R}  ${_D}${_rs}${_R}\n"
done

printf "\n"
printf "  ${_CYN}${_B}┌─────────────────────────────────────────┐${_R}\n"
printf "  ${_CYN}${_B}│${_R}  ${_B}${_WHT}${PROJECT_NAME}${_R}%-*s${_CYN}${_B}│${_R}\n" "$((39 - ${#PROJECT_NAME}))" ""
printf "  ${_CYN}${_B}└─────────────────────────────────────────┘${_R}\n"
printf "\n"
printf "  ${_B}Repos${_R}\n"
printf '%b' "$_repo_lines"
printf "\n"
printf "  ${_B}Team${_R} ${_GRY}(${AGENT_COUNT} agents)${_R}\n"
printf '%b' "$_agent_lines"
printf "\n"
printf "  ${_GRN}${_B}▶ ${L_STARTING}${_R} ${_GRY}(yolo mode)${_R}\n"
printf "\n"

cd "$PRIMARY_REPO_PATH"
exec claude --dangerously-skip-permissions --append-system-prompt "$SYSTEM_PROMPT"
