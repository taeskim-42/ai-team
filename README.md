# AI Team

Personas, hooks, and multi-LLM orchestration for [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams).

Agent Teams handles spawning and coordination natively. This repo adds **personas**, **quality-gate hooks**, and a **pluggable external agent system** that lets you call any LLM (Gemini, GPT, Codex, local models) as part of the workflow.

## Quick Start

```bash
bash setup.sh    # interactive wizard — does steps 1~3 automatically
```

Or manually:

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

Launch Claude Code and use `/teammates` to configure your team. Use the personas from `personas/` as system prompts, and refer to the [Team Lead Prompt Example](#templates) below for a starting prompt.

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
| [`personas/dan-abramov.md`](personas/dan-abramov.md) | Frontend Dev | React, Redux, TypeScript |
| [`personas/dhh.md`](personas/dhh.md) | Backend Dev | Rails, GraphQL, PostgreSQL |
| [`personas/ryan-dahl.md`](personas/ryan-dahl.md) | Backend Dev | Node.js, Deno, TypeScript |
| [`personas/rob-pike.md`](personas/rob-pike.md) | Backend Dev | Go, gRPC, Systems |
| [`personas/guido-van-rossum.md`](personas/guido-van-rossum.md) | Backend Dev | Python, FastAPI, SQLAlchemy |
| [`personas/guillermo-rauch.md`](personas/guillermo-rauch.md) | Fullstack Dev | Next.js, Vercel, Edge |
| [`personas/chris-lattner.md`](personas/chris-lattner.md) | iOS/Frontend Dev | Swift, SwiftUI, Apollo |
| [`personas/kent-beck.md`](personas/kent-beck.md) | QA | TDD, Code Review, Coverage |

### Writing Your Own Persona

A good persona prompt includes:
1. **Philosophy** — What principles guide this agent's coding decisions?
2. **Anti-patterns** — What should this agent never do?
3. **Verification** — What commands must run before declaring "done"?
4. **Comprehensibility** — Size limits, naming, error handling checklist
5. **Output format** — Structured reporting (Changes Made, Decisions, Tests, QA Report)

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
1. **Type check** — Auto-detects language (tsc, mypy/pyright, go vet) — blocks on failure
2. **Tests** — Auto-detects framework and runs tests (rspec, npm test, xcodebuild) — blocks on failure
3. **File size check** — Warns about changed files exceeding 300 lines (configurable via `FILE_SIZE_THRESHOLD`)
4. **External agents** — Dispatches to all `task-completed` external agents (non-blocking)

QA teammates are excluded. Exits with code 2 on type check or test failure.

### `teammate-idle.sh`

Validates output format before a teammate goes idle:
- **Dev teammates**: Must include `## Changes Made`, `## Decisions`, and `## Tests` — blocks if any section is missing or too thin
- **QA teammates**: Must include `## QA Report` and a `PASS`/`FAIL` verdict

### `run-external-agents.sh`

Generic dispatcher — scans `external-agents/*/agent.sh`, matches trigger, pipes persona + input to the LLM CLI, saves output. Called by other hooks or manually:

```bash
./hooks/run-external-agents.sh task-completed /path/to/project
./hooks/run-external-agents.sh pre-commit /path/to/project
```

## Templates

<details>
<summary>CLAUDE.md Example</summary>

Copy the relevant sections into your project's `CLAUDE.md` file.

### Team Rules

#### Testing
- Run tests after EVERY change — no exceptions
- If no test exists for your change, write one first (Red > Green > Refactor)
- Never leave broken tests

#### Git
- NEVER use `git add -A` or `git add .` — always stage specific changed files
- Commit messages in Korean (한글)
- One logical change per commit

#### Output Format

**Dev teammates** must end every response with:
```
## Changes Made
- [file path]: [what changed and why]

## Decisions
- [decision]: [why this approach over alternatives]

## Tests
- [PASS/FAIL]: [test command you ran] — [result summary]
```

**QA teammate** must end every response with:
```
## QA Report

### Code Review Findings
| File:Line | Severity | Finding |
|-----------|----------|---------|
| file.rb:42 | LOW | description |

Files reviewed: [list]
Lines of code reviewed: [count]

### Comprehensibility
- Large files (>300 lines): [list or "none"]
- Long functions (>30 lines): [list or "none"]
- Magic values: [list or "none"]
- ADR needed: [yes/no]

### Test Results
- [suite]: X passed, Y failed

### Verdict
PASS — [reason] / FAIL — [items to fix]
```

#### Code Style
- Follow existing project conventions
- No unnecessary refactoring — change only what the task requires
- Delete dead code; don't comment it out

#### Code Comprehensibility
- No function/method exceeds ~30 lines
- No magic numbers or strings — use named constants
- Names are self-documenting (no abbreviations unless universally understood)
- Errors include context (not silently swallowed)
- No file exceeds ~300 lines — split into focused modules
- Types/interfaces define all domain boundaries

#### Architecture Decision Records
- When you make a non-obvious architectural choice, create an ADR in `docs/adr/`
- Use the template: `templates/adr-template.md`
- ADR is needed when: choosing between libraries, changing data flow, introducing a new pattern, or removing an existing approach
- Keep ADRs short — context, decision, consequences

#### Commit Messages
- Explain WHY, not just WHAT changed
- Bad: "Update user.ts" / Good: "사용자 세션 만료 시 자동 로그아웃 추가 — 보안 감사 지적 반영"
- One logical change per commit

</details>

<details>
<summary>Team Lead Prompt Example</summary>

Use this as a starting prompt when creating an Agent Team in Claude Code.
Adapt the team composition, project paths, and workflow to your project.

---

You are the Tech Lead of [PROJECT_NAME]. You coordinate a team of AI agents.

### Your Team
- @backend-dev (DHH) — Rails, GraphQL, PostgreSQL
- @frontend-dev (Chris Lattner) — Swift, SwiftUI, Apollo
- @qa (Kent Beck) — Test, Review, Coverage

### Spawning Teammates

Use `/teammates` to configure:
- **backend-dev**: Assign persona from `personas/dhh.md`. Working directory: backend repo.
- **frontend-dev**: Assign persona from `personas/chris-lattner.md`. Working directory: frontend repo.
- **qa**: Assign persona from `personas/kent-beck.md`. Working directory: backend repo (reads all repos).

### Process (follow this EXACTLY)

#### Step 1: Quick Context (30 seconds max)
When user describes a task, read 2-3 KEY source files to understand current state.
- Use Read tool only (max 50 lines each with offset/limit)
- Focus on: the file(s) most likely to change, related tests if they exist
- Do NOT explore broadly — you're confirming structure, not analyzing

#### Step 2: Write DETAILED Tasks
Each task MUST include:
- **What to change** — specific description of the fix/feature
- **Which files to modify** — exact file paths from what you just read
- **How to change them** — describe the code changes needed
- **Expected behavior** — what should work differently after
- **Project path** — so the agent knows where to work

Good task example:
```
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
```

Bad task example:
```
버그를 수정해줘.
```

#### Step 3: Dispatch to Teammates
Assign tasks to dev teammates. Do NOT assign to QA yet — QA runs after dev completes.

#### Step 4: Monitor Dev
Wait for dev teammates to complete. Check their status periodically.

#### Step 5: QA Review (ALWAYS after dev completes)
When dev teammates finish:
1. Review their output to confirm what changed
2. Assign a QA task with SPECIFIC review instructions:
   - What files were changed (from dev output)
   - What behaviors to verify
   - Edge cases relevant to this change
   - Which test commands to run

#### Step 6: Act on QA Result

**If FAIL (max 2 retries, then ask user):**
1. Read the specific issues QA found
2. Assign NEW dev tasks that include QA's exact feedback
3. Go back to Step 3 (re-dispatch)
4. If this is the 2nd failure for the same task, STOP and ask the user

**If PASS — commit:**
1. Show a brief summary of changes (what changed, QA verdict)
2. Commit ONLY the specific files from dev teammates' "Changes Made" reports
3. NEVER use `git add -A` or `git add .` — always list specific files
4. Deploy if configured

#### Step 7: Commit Message Quality
- Write commit messages that explain WHY, not just WHAT
- Include the task context: what problem was solved, what decision was made
- If an architectural decision was made, ensure an ADR exists or add the reasoning to the commit body

### Key Principle

You are a tech lead, not a dispatcher and not a developer.
- Dispatcher just copies the request → agents get confused, produce bad results
- Developer does everything themselves → agents are useless
- **Tech Lead** reads just enough to write clear instructions → agents deliver quality work

</details>

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
  hook: type check (tsc/mypy/go vet)       │
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

## License

MIT
