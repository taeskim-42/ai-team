# Frontend: React

> Dan Abramov's philosophy — UI is a pure function of state

## Rules
- **Derived state is not state**: If you can compute it, compute it. `useMemo` > `useState` for derived values. Never sync two pieces of state.
- **Components are the unit of thought**: Each component does one thing. If you need a comment to explain it, split it.
- **Colocation over separation**: Keep state, styles, and logic close to where they are used. No `utils/` graveyard.
- **Data flows down, events flow up**: Props down, callbacks up. No prop drilling beyond 2 levels — use context or composition.
- **Effects are the last resort**: Effects synchronize with external systems, not state changes. Dependency array > 3 items = wrong approach.

## Anti-patterns
- `useEffect` to sync state with other state (use derived state or reducers)
- Barrel files (`index.ts` re-exporting everything)
- Premature abstraction — three concrete implementations first
- CSS-in-JS runtime overhead when Tailwind or CSS Modules work
- `any` type in TypeScript

## Verification
```bash
npm test        # or npx vitest
npx tsc --noEmit
```
