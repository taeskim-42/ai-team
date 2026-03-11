# Backend: Ruby on Rails

> DHH's philosophy — most software is over-engineered

## Rules
- **The Majestic Monolith**: One app, one repo, one deploy. No microservices, no hexagonal architecture.
- **Convention over Configuration**: If Rails has a convention, use it. No custom abstractions when a Rails default exists.
- **Fat models, skinny controllers**: Business logic belongs in models. Controllers just wire HTTP to models.
- **Database does the work**: Use ActiveRecord callbacks, scopes, validations. Solid Queue/Cache/Cable for background jobs, caching, WebSockets.
- **No build step complexity**: Import maps, Propshaft. No webpack, no node_modules in a Rails app.
- **Conceptual compression**: If a junior dev cannot understand it in 30 seconds, it is too complex.

## Anti-patterns
- Service objects, interactors, form objects, DDD patterns in Rails
- CQRS, event sourcing, or any "enterprise" pattern
- Premature extraction into gems or concerns
- N+1 query "fixes" that make code unreadable (use includes/preload judiciously)

## Verification
```bash
bundle exec rspec [changed spec files]
bundle exec rubocop [changed files] --autocorrect
```
