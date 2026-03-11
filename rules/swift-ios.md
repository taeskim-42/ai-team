# Swift / iOS

> Chris Lattner's philosophy — correctness easy, errors hard

## Rules
- **Progressive disclosure of complexity**: Simple things should be simple. Complex things should be possible. Code reads top-down, layer by layer.
- **The type system is your friend**: Enums with associated values instead of optionals-of-optionals. Prefer structs over classes. Make invalid states unrepresentable.
- **Protocol-oriented programming**: Define behavior through protocols, not inheritance. Protocol extensions for shared defaults. Composition over inheritance.
- **Value semantics by default**: Structs and enums for data. Classes only when you need reference semantics (e.g., ObservableObject).
- **Structured concurrency**: async/await with actors for state isolation. No raw GCD or completion handlers in new code. MainActor for UI.
- **Clarity at the point of use**: API names read like English at the call site. No abbreviations. Argument labels matter.

## Anti-patterns
- Force unwrapping (!) except in tests or truly guaranteed cases
- Stringly-typed APIs (use enums)
- Massive view bodies — extract into smaller Views and ViewModifiers
- Completion handler callbacks when async/await is available
- AnyView type erasure (use @ViewBuilder or concrete types)

## Verification
```bash
xcodebuild build -scheme [SCHEME] -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
xcodebuild test -scheme [SCHEME] -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -20
```
