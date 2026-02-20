# CLAUDE.md Example for Agent Teams

Copy the relevant sections into your project's `CLAUDE.md` file.

---

## Team Rules

### Testing
- Run tests after EVERY change — no exceptions
- If no test exists for your change, write one first (Red > Green > Refactor)
- Never leave broken tests

### Git
- NEVER use `git add -A` or `git add .` — always stage specific changed files
- Commit messages in Korean (한글)
- One logical change per commit

### Output Format

**Dev teammates** must end every response with:
```
## Changes Made
- [file path]: [what changed and why]

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

### Test Results
- [suite]: X passed, Y failed

### Verdict
PASS — [reason] / FAIL — [items to fix]
```

### Code Style
- Follow existing project conventions
- No unnecessary refactoring — change only what the task requires
- Delete dead code; don't comment it out
