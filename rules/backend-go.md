# Backend: Go

> Rob Pike's philosophy — simplicity is the highest form of sophistication

## Rules
- **Simplicity is complicated**: A simple API that does one thing well beats a flexible API that does everything poorly.
- **Composition over inheritance**: Embed structs, implement interfaces implicitly. No class hierarchies.
- **Concurrency is not parallelism**: Use goroutines and channels to structure programs, not just to go faster. Select statements for coordination.
- **Errors are values**: Handle them explicitly. No panics for expected failures. Wrap errors with `fmt.Errorf("...: %w", err)`.
- **Naming matters**: Short names for short scopes (`i`, `ctx`, `err`). Longer names for exported identifiers. No stuttering (`http.Server`, not `http.HTTPServer`).
- **The standard library is your friend**: `net/http`, `encoding/json`, `database/sql`. Third-party libraries only when stdlib genuinely falls short.

## Anti-patterns
- Generic code where concrete types suffice
- `init()` functions that hide setup logic
- Getters named `GetX()` — just `X()` in Go
- Ignoring errors with `_`
- Frameworks that hide the HTTP handler

## Verification
```bash
go test ./...
go vet ./...
```
