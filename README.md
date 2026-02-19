# AI Team

A bash template that spins up AI agent teams using tmux + Claude CLI.
One script to create and manage agent teams per project.

## Quick Start

```bash
cd ai-team
bash ai-team.sh        # select a project or create new
```

## UX Flow

### First Run

```
  Language: 1) English  2) 한국어
  Select [1]: ⏎

🚀 AI Team Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1) AI auto setup — describe your project
  2) Manual setup — configure each item

  Select [1]: ⏎
```

**Mode 1: AI Auto Setup** — Describe your project in one line, AI suggests config values.
Press Enter to accept each suggestion, or type to override.

```
  Describe your project:
  > Next.js web app + Fastify API, repos at ~/Code/web and ~/Code/api

  ⠋ Generating AI suggestions 3s

  ✓ AI suggestions ready — Enter to accept, type to change
  ──────────────────────────────────────

  Project name [MyApp]: ⏎
  Session name [myapp-team]: ⏎

  ── Repositories ──
  How many repos? [2]: ⏎
  Repo 1 path [/Users/you/Code/web]: ⏎
  Repo 1 label [Web App]: ⏎
  Repo 1 stack [Next.js, React, TypeScript]: ⏎
  ...

  ── Agents ──
  How many agents? [3]: ⏎
  Agent 1 ID [frontend-dev]: ⏎
  Agent 1 persona [Dan Abramov]: ⏎
  ...
```

**Mode 2: Manual Setup** — Fill in each field yourself.

### Existing Projects

```
  Existing projects:
    1) myapp-team
    2) another-project
    3) + New project

  Select [1]: ⏎
  Starting AI Team...
```

Pick a number to launch, or select the last option to create a new project.

### Direct Launch

```bash
bash ai-team.sh myapp-team           # by project name
bash ai-team.sh projects/my-team/team.config.sh   # by config path
```

## File Structure

```
ai-team/
  ai-team.sh                  # main launcher (reusable template)
  team.config.sh.example      # config reference with full examples
  .ai-team-lang               # saved language preference (en/ko)
  .env.example                # secrets template
  .gitignore                  # excludes projects/, .env
  projects/
    myapp-team/
      team.config.sh           # per-project config
    another-project/
      team.config.sh
```

`ai-team.sh` stays as a reusable template. Each project config lives in `projects/<name>/`.

## Features

- **AI Auto Setup**: Describe your project, `claude` CLI suggests the config
- **Manual Setup**: Step-by-step interactive wizard
- **Multi-language**: English / Korean (selected on first run, saved to `.ai-team-lang`)
- **Multi-project**: Manage multiple projects under `projects/`
- **Auto directory creation**: Missing repo paths trigger `mkdir -p` + `git init` + optional GitHub repo creation
- **Feedback pipeline**: Real-time feedback collection via WebSocket/API (optional)

## Config Reference

### Project

| Variable | Required | Description |
|----------|----------|-------------|
| `PROJECT_NAME` | Yes | Project name (shown on Status Board) |
| `SESSION_NAME` | Yes | tmux session name |

### Repositories

| Variable | Required | Description |
|----------|----------|-------------|
| `REPO_COUNT` | Yes | Number of repositories (1~N) |
| `REPO_N_PATH` | Yes | Absolute path to repository |
| `REPO_N_LABEL` | Yes | Display name (e.g. "Backend") |
| `REPO_N_STACK` | Yes | Tech stack summary |

### Agents

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENT_COUNT` | Yes | Number of agents (1~N) |
| `AGENT_N_ID` | Yes | Unique ID (used in filenames) |
| `AGENT_N_NAME` | No | Display name (defaults to ID) |
| `AGENT_N_PERSONA` | No | Persona name (e.g. "DHH") |
| `AGENT_N_SUBTITLE` | No | Subtitle (e.g. "Creator of Rails") |
| `AGENT_N_TECH` | No | Tech tags |
| `AGENT_N_COLOR` | No | Color: RED/GRN/YEL/BLU/MAG/CYN/WHT/GRY |
| `AGENT_N_REPO` | Yes | Repo index (1-based) |
| `AGENT_N_PROMPT` | No | System prompt (inline) |
| `AGENT_N_PROMPT_FILE` | No | System prompt (external file) |

**Prompt variables** (auto-substituted):
- `$PROJECT_PATH` → agent's repo path
- `$PROJECT_STACK` → agent's repo stack
- `$REPO_N_PATH`, `$REPO_N_STACK`, `$REPO_N_LABEL` → reference specific repos

### PM

| Variable | Required | Description |
|----------|----------|-------------|
| `PM_DEPLOY_COMMAND` | No | Deploy command to run after QA passes |

### Feedback Pipeline

| Variable | Required | Description |
|----------|----------|-------------|
| `FEEDBACK_ENABLED` | No | Set to `true` to enable feedback watcher |
| `FEEDBACK_WS_URL` | No | ActionCable WebSocket URL |
| `FEEDBACK_API_URL` | No | API polling URL |
| `FEEDBACK_CHANNEL` | No | ActionCable channel name |
| `FEEDBACK_POLL_INTERVAL` | No | Polling interval in seconds (default 60) |

Secrets go in `.env`:
```bash
FEEDBACK_ADMIN_TOKEN=your_token
```

## tmux Layout

```
┌──────────┬──────────┬──────────┬─── ─ ─ ──┐
│  Status  │ Agent 1  │ Agent 2  │ Agent N  │
│  Board   │          │          │          │
├──────────┤          │          │          │
│   PM     │          │          │          │
└──────────┴──────────┴──────────┴─── ─ ─ ──┘
```

Auto-splits by agent count. Left panel (Status + PM) 25% | Right panels split equally 75%.

## Examples

### 1. Next.js + Fastify

```bash
PROJECT_NAME="MyApp"
SESSION_NAME="myapp-team"
REPO_COUNT=2
REPO_1_PATH="$HOME/Code/myapp-web"
REPO_1_LABEL="Web App"
REPO_1_STACK="Next.js, React, TypeScript, Tailwind"
REPO_2_PATH="$HOME/Code/myapp-api"
REPO_2_LABEL="API Server"
REPO_2_STACK="Node.js, Fastify, PostgreSQL, Prisma"
AGENT_COUNT=3   # Frontend Dev, Backend Dev, QA
```

### 2. Go + React

```bash
PROJECT_NAME="MyAPI"
REPO_COUNT=2
REPO_1_PATH="$HOME/Code/api"
REPO_1_LABEL="API"
REPO_1_STACK="Go 1.22, gRPC, PostgreSQL"
REPO_2_PATH="$HOME/Code/web"
REPO_2_LABEL="Web"
REPO_2_STACK="TypeScript, React 19, Vite"

AGENT_COUNT=2
AGENT_1_ID="api-dev"
AGENT_1_PERSONA="Rob Pike"
AGENT_1_SUBTITLE="Creator of Go"
AGENT_1_TECH="Go · gRPC · PostgreSQL"
AGENT_1_COLOR="CYN"
AGENT_1_REPO=1

AGENT_2_ID="web-dev"
AGENT_2_PERSONA="Dan Abramov"
AGENT_2_SUBTITLE="Creator of Redux"
AGENT_2_TECH="React · TypeScript · Vite"
AGENT_2_COLOR="YEL"
AGENT_2_REPO=2
```

### 3. Python + Flutter

```bash
PROJECT_NAME="HealthApp"
REPO_COUNT=2
REPO_1_PATH="$HOME/Code/health-api"
REPO_1_STACK="Python 3.12, FastAPI, SQLAlchemy"
REPO_2_PATH="$HOME/Code/health-mobile"
REPO_2_STACK="Dart, Flutter 3, Riverpod"

AGENT_COUNT=4
AGENT_1_ID="api-dev"
AGENT_1_PERSONA="Guido van Rossum"
AGENT_1_COLOR="BLU"
AGENT_1_REPO=1

AGENT_2_ID="mobile-dev"
AGENT_2_PERSONA="Eric Seidel"
AGENT_2_COLOR="CYN"
AGENT_2_REPO=2

AGENT_3_ID="ml-dev"
AGENT_3_PERSONA="Andrej Karpathy"
AGENT_3_COLOR="GRN"
AGENT_3_REPO=1

AGENT_4_ID="qa"
AGENT_4_PERSONA="Kent Beck"
AGENT_4_COLOR="MAG"
AGENT_4_REPO=1
```

## Requirements

- `tmux` (1.8+)
- `claude` CLI (Claude Code)
- `python3` (for feedback watcher, optional)
- `git`
- `gh` (GitHub CLI, optional — for auto repo creation)
