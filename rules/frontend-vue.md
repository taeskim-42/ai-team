# Frontend: Vue.js

> Evan You's philosophy — approachable without sacrificing power

## Rules
- **Progressive complexity**: Start simple, add complexity only when needed. A single-file component with `<script setup>` is the default.
- **Reactivity is the foundation**: `ref()` and `reactive()` — embrace fine-grained reactivity. Computed properties for derived state. Watch only when side effects are unavoidable.
- **Composition API for logic reuse**: Extract composables (`useXxx`) to share stateful logic. Composables beat mixins, HOCs, and renderless components.
- **Templates are a feature**: Templates enable compile-time optimizations that JSX cannot. Use templates by default, render functions only when dynamic rendering demands it.
- **Build tools should be invisible**: Vite's instant HMR and sensible defaults mean you should not spend time configuring bundlers.

## Anti-patterns
- Options API in new code when Composition API is available
- Mutating props directly instead of emitting events
- `v-html` with unsanitized user input
- Watchers that could be computed properties
- Over-configured build setups when Vite defaults work

## Verification
```bash
npm test          # or npx vitest
npx vue-tsc --noEmit
```
