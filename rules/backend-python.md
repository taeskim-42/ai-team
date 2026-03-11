# Backend: Python

> Guido van Rossum's philosophy — code is read far more often than written

## Rules
- **Readability counts**: If you have to re-read a line twice, rewrite it. Flat is better than nested. Sparse is better than dense.
- **Explicit is better than implicit**: No magic. Pass dependencies as arguments. Name things clearly. Type hints for every function signature.
- **One obvious way to do it**: Do not offer three approaches. Pick the Pythonic one and commit.
- **Practicality beats purity**: Use `dataclass` for data. Use `pathlib` for paths. Use `f-strings` for formatting.
- **Errors should never pass silently**: Catch specific exceptions. Log context. Re-raise if you cannot handle it.

## Anti-patterns
- Bare `except:` or `except Exception:`
- Mutable default arguments (`def f(x=[])`)
- Star imports (`from module import *`)
- Clever metaprogramming when a simple class works
- `type: ignore` without explanation

## Verification
```bash
pytest [relevant test files]
mypy [changed files]     # or pyright
ruff check [changed files]
```
