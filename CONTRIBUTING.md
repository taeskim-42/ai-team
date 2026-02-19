# Contributing

Thanks for your interest in improving AI Team!

## How to Contribute

1. Fork the repo
2. Create a branch: `git checkout -b my-feature`
3. Make your changes
4. Test: `bash -n ai-team.sh` (syntax check)
5. Commit and push
6. Open a Pull Request

## Guidelines

- Keep `ai-team.sh` as a single-file launcher (no external dependencies)
- Test both setup modes (AI auto / manual) if you change the wizard
- UI strings go in `_lang_en()` and `_lang_ko()` for i18n
- Don't commit anything inside `projects/` — that's user-specific

## Reporting Issues

Open a GitHub issue with:
- What you expected
- What happened
- Your OS and tmux version
