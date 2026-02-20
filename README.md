# AI Team

Personas, hooks, and multi-LLM orchestration for [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams).

Agent Teams handles spawning and coordination natively. This repo adds **personas**, **quality-gate hooks**, and a **pluggable external agent system** that lets you call any LLM (Gemini, GPT, Codex, local models) as part of the workflow.

## Quick Start

### 1. Enable Agent Teams

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Install Hooks (optional)

Copy the hooks to your project and register them in `.claude/settings.json`:

```json
{
  "hooks": {
    "TaskCompleted": [
      { "command": "/path/to/hooks/task-completed.sh" }
    ],
    "TeammateIdle": [
      { "command": "/path/to/hooks/teammate-idle.sh" }
    ]
  }
}
```

### 3. Add External Agents (optional)

Copy an example from `external-agents/examples/` to `external-agents/`:

```bash
cp -r external-agents/examples/gemini-reviewer external-agents/gemini-reviewer
```

Edit `agent.sh` to set your LLM command. The `task-completed` hook will automatically dispatch to all configured external agents.

### 4. Start a Team

Launch Claude Code and use `/teammates` to configure your team. Use the personas from `personas/` as system prompts, and refer to `templates/team-prompt-example.md` for a Team Lead prompt.

## Architecture

```
┌──────────────────────────────┬─────────────────────────┐
│   Claude Agent Teams         │   External Agents       │
│   (native coordination)     │   (any LLM via CLI)     │
│                              │                         │
│   Lead ─► Dev (Claude)       │   gemini-reviewer/      │
│        ─► Dev (Claude)       │   codex-coder/          │
│        ─► QA  (Claude)  ◄────┤   gpt-security/         │
│                              │   your-custom-agent/    │
└──────────┬───────────────────┴────────────┬────────────┘
           │        hooks/                  │
           ├── task-completed.sh ───────────┘
           ├── teammate-idle.sh    (triggers external agents
           └── run-external-agents.sh  after tests pass)
```

## Personas

Pre-built agent personas with philosophy, verification steps, and output format requirements.

| File | Role | Tech Stack |
|------|------|------------|
| [`personas/dhh.md`](personas/dhh.md) | Backend Dev | Rails, GraphQL, PostgreSQL |
| [`personas/chris-lattner.md`](personas/chris-lattner.md) | iOS/Frontend Dev | Swift, SwiftUI, Apollo |
| [`personas/kent-beck.md`](personas/kent-beck.md) | QA | TDD, Code Review, Coverage |

### Writing Your Own Persona

A good persona prompt includes:
1. **Philosophy** — What principles guide this agent's coding decisions?
2. **Anti-patterns** — What should this agent never do?
3. **Verification** — What commands must run before declaring "done"?
4. **Output format** — Structured reporting (Changes Made, Tests, QA Report)

## External Agents

Plug any LLM into the workflow. Each external agent is a directory with two files:

```
external-agents/
├── _template/          # Copy this to create your own
│   ├── agent.sh        # LLM command + trigger + input mode
│   └── persona.md      # System prompt
└── examples/
    ├── gemini-reviewer/ # Long-context code review
    ├── codex-coder/     # Alternative implementation suggestions
    └── gpt-security/    # OWASP security audit
```

### `agent.sh` Configuration

```bash
COMMAND="gemini -m gemini-2.5-pro"   # Any CLI that reads stdin
TRIGGER="task-completed"              # When to run
INPUT="changed-files"                 # What to feed it
```

| `TRIGGER` | When |
|-----------|------|
| `task-completed` | After a dev teammate finishes (and tests pass) |
| `pre-commit` | Before committing changes |
| `on-demand` | Only when explicitly called |

| `INPUT` | What gets piped to the LLM |
|---------|---------------------------|
| `changed-files` | Full content of changed files |
| `full-diff` | `git diff` output |
| `staged` | Staged files content |

### Adding Your Own

```bash
cp -r external-agents/_template external-agents/my-agent
# Edit agent.sh: set COMMAND, TRIGGER, INPUT
# Edit persona.md: write your system prompt
```

The dispatcher (`hooks/run-external-agents.sh`) auto-discovers all agents in `external-agents/` and runs those matching the current trigger. Results are saved to `.claude/external-reviews/<agent-name>.md` for the QA teammate to consume.

## Hooks

### `task-completed.sh`

Runs when a dev teammate completes a task:
1. **Tests** — Auto-detects framework and runs tests (rspec, npm test, xcodebuild)
2. **External agents** — Dispatches to all `task-completed` external agents (non-blocking)

QA teammates are excluded. Exits with code 2 on test failure.

### `teammate-idle.sh`

Validates output format before a teammate goes idle:
- **Dev teammates**: Must include `## Changes Made` and `## Tests`
- **QA teammates**: Must include `## QA Report` and a `PASS`/`FAIL` verdict

### `run-external-agents.sh`

Generic dispatcher — scans `external-agents/*/agent.sh`, matches trigger, pipes persona + input to the LLM CLI, saves output. Called by other hooks or manually:

```bash
./hooks/run-external-agents.sh task-completed /path/to/project
./hooks/run-external-agents.sh pre-commit /path/to/project
```

## Templates

| File | Description |
|------|-------------|
| [`templates/claude-md-example.md`](templates/claude-md-example.md) | Project `CLAUDE.md` rules for teams (testing, git, output format) |
| [`templates/team-prompt-example.md`](templates/team-prompt-example.md) | Team Lead initial prompt with full workflow |

## Workflow

```
User describes task
       │
       ▼
  Team Lead reads 2-3 key files
       │
       ▼
  Team Lead writes detailed task specs
       │
       ▼
  Dev teammates implement  ◄──────────────┐
       │                                   │
       ▼                                   │
  hook: tests run automatically            │
       │                                   │
       ▼                                   │
  hook: external agents review in parallel │
  (Gemini, GPT, Codex, ...)               │
       │                                   │
       ▼                                   │
  QA teammate reviews                      │
  (own review + external reviews)          │
       │                                   │
   ┌───┴───┐                               │
   ▼       ▼                               │
 PASS    FAIL ─────────────────────────────┘
   │      (max 2 retries)
   ▼
 Commit specific files
       │
       ▼
    Deploy
```

## v1 (Legacy)

The original version was a 2000-line bash script (`ai-team.sh`) that orchestrated Claude Code agents via tmux panes with file-based IPC. With the release of [Agent Teams](https://code.claude.com/docs/en/agent-teams), the bash infrastructure is no longer needed. The personas, QA workflow, and hooks from v1 are preserved in this repo.

## License

MIT
