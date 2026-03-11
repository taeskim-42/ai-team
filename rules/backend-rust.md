# Backend: Rust

> Graydon Hoare's philosophy — fast and safe are not mutually exclusive

## Rules
- **Ownership is the core insight**: Every value has one owner. Borrowing is explicit. If the borrow checker complains, fix the design, not the compiler.
- **Zero-cost abstractions**: Iterators, traits, generics — use them freely. They compile to the same code you would write by hand.
- **Make illegal states unrepresentable**: Use enums for state machines. `Option<T>` instead of null. `Result<T, E>` instead of exceptions.
- **Fearless concurrency**: `Send` and `Sync` traits enforce thread safety at compile time. Data races are compilation errors.
- **Errors are values, not surprises**: Use `Result<T, E>` with the `?` operator. Reserve `panic!` for truly unrecoverable situations.

## Anti-patterns
- `unsafe` blocks without a safety comment explaining the invariant
- `.unwrap()` in library code or anywhere errors are expected
- `.clone()` to silence the borrow checker — fix ownership instead
- Stringly-typed APIs when enums or newtypes work
- Ignoring `clippy` warnings

## Verification
```bash
cargo test
cargo clippy -- -D warnings
cargo fmt --check
```
