---
name: testing-strategy
description: Test execution strategy for Phase 4 of the engineering workflow — what to run, in what layers, and how to handle a project whose test tooling isn't auto-detected. Load this when `/develop` reaches Phase 4, or when asked how to test a change already scoped by the engineering-workflow skill. Golden Rules live in the `engineering-workflow` skill.
---

# Testing Strategy

## What "done testing" means for this workflow

A change is not ready for Phase 5 (Code Review) until it has, at minimum:

- **Unit tests** — the new/changed logic itself, in isolation
- **Integration tests** — the change's interaction with the parts of the system the
  design doc's Impact section identified
- **Regression check** — the existing test suite still passes; this change didn't break
  something unrelated

Not every change needs all three in equal depth (a pure internal refactor may lean almost
entirely on regression; a new endpoint needs real integration coverage) — use the design
doc's Testing Plan section to judge proportional coverage, not a fixed checklist.

## Running tests

Get the project's test command from the single detection source:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh" "$(git rev-parse --show-toplevel)"
```

This prints `PROJECT_TYPE`, `TEST_CMD`, `BUILD_CMD`, `LINT_CMD` (any may be empty). Run
`TEST_CMD` as reported — don't hardcode `npm test`/`pytest`/etc. yourself, since the
detector already accounts for Makefile targets, a project-local override
(`.claude/project-commands.json`), and per-language package manager differences
(npm/pnpm/yarn, maven/gradle, etc.).

## Test failure

**Never commit with failing tests.** If `TEST_CMD` fails, that's the end of Phase 4 for
this iteration — go back and fix the implementation (or the test, if the test itself was
wrong), then re-run. The commit hook enforces this as a backstop, but don't rely on it as
the primary gate — treat a red test suite as blocking on your own initiative.

## When detection can't find a test command

If `PROJECT_TYPE` comes back `unknown` or `TEST_CMD` is empty, that is not permission to
skip testing — it means auto-detection isn't enough for this project. In order:

1. Check for an obvious test entry point a human would use (a `test/` or `tests/`
   directory, a CI config file like `.github/workflows/*.yml` that shows the real test
   command) and ask the user to confirm the right command.
2. If genuinely nothing can be inferred, ask the user directly what command runs this
   project's tests, and suggest they add a `.claude/project-commands.json` (see
   `git-workflow` skill / `scripts/detect-project.sh`) so future runs auto-detect it.
3. Never silently proceed to commit without some form of test verification just because
   detection failed.
