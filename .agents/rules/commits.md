---
trigger: model_decision
description: Read before creating commits or publishing repository changes.
---

# Commit conventions

Use Conventional Commits: `type: short description` or `type(scope): short description`.

- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation only
- `test`: adding or fixing tests
- `chore`: build, CI, or tooling changes
- `perf`: performance improvement
- `refactor`: code changes without feature or fix
- `build`: changes that affect the build system
- `ci`: CI configuration
- `style`: formatting or other code style changes
- `types`: type-related changes
- `revert`: reverting a previous commit

Choose the type for the main result. Keep each commit focused; include supporting tests with its code change. Mark breaking changes with `!` and explain them in a `BREAKING CHANGE:` footer.

Before committing, inspect the staged diff and run `flutter analyze` plus relevant tests for code changes. When handing off, report the commit and verification results. Add this rules file to Git with the repository's other development instructions.

Examples: `fix(store): handle missing sessions safely`, `perf(ui): remove idle polling`, `refactor(ui): split tab screens and forms`, `docs: document commit conventions`.
