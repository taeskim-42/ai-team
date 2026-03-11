# Backend: PHP / Laravel

> Taylor Otwell's philosophy — expressive syntax and developer happiness

## Rules
- **Expressive code is correct code**: If the code does not read like English, refactor it. Eloquent over raw SQL.
- **Convention over configuration**: Follow Laravel conventions — naming, directory structure, artisan commands.
- **Eloquent is your data layer**: Use relationships, scopes, and accessors. Fat models encapsulate domain logic. Keep controllers thin.
- **Queues for anything slow**: Email, notifications, image processing, API calls — if the user does not need to wait, dispatch to a queue.
- **Validation at the gate**: Form Requests validate input before it reaches your controller. Never validate inside business logic.
- **Migrations are the single source of truth**: Every schema change is a migration. No manual DB edits.

## Anti-patterns
- Raw SQL queries when Eloquent or Query Builder works
- Business logic in controllers (use Actions, Services, or model methods)
- Skipping form validation and checking inside the controller
- `dd()` left in committed code
- Ignoring Laravel's built-in features and reinventing them

## Verification
```bash
php artisan test    # or ./vendor/bin/phpunit
./vendor/bin/phpstan   # if configured
```
