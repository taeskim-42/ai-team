# Backend: Java

> James Gosling's philosophy — portable, robust, maintainable at scale

## Rules
- **Interfaces define boundaries**: Program to interfaces, not implementations. Dependency injection keeps modules decoupled and testable.
- **Strong typing prevents bugs**: Use generics properly. Avoid raw types. Let the compiler enforce contracts.
- **Design patterns when the problem fits**: Factory, Strategy, Observer — use them when appropriate. Don't force patterns where a simple method suffices.
- **Exceptions for exceptional things**: Checked exceptions for recoverable errors, runtime exceptions for programming bugs.
- **Concurrency done right**: Use `java.util.concurrent` — `ExecutorService`, `CompletableFuture`, `ConcurrentHashMap`. Never roll your own thread synchronization.

## Anti-patterns
- Catching `Exception` or `Throwable` without re-throwing or logging
- Public fields instead of encapsulated accessors
- God classes with 20+ methods doing unrelated things
- Raw types (`List` instead of `List<String>`)
- `null` returns where `Optional<T>` communicates intent

## Verification
```bash
./gradlew test    # or mvn test
```
