---
description: Run Phase 6 (Commit) and Phase 7 (Pull Request) standalone, assuming implementation, testing, and review are already done.
argument-hint: [feature description]
---

# /prepare-pr

Standalone entry point for the commit + PR steps of the `git-workflow` skill — use this
when Phase 0-5 already happened (in this session or a prior one) and you just need to get
the change committed and a PR opened.

1. Read the `git-workflow` skill (Phase 6 and Phase 7 sections).
2. Confirm there's an APPROVED code review verdict for this change before committing. If
   there isn't one, stop and run `/review` first — don't commit an unreviewed change just
   because this command was invoked directly.
3. Commit following Conventional Commits format (`type(scope): description`). The
   plugin's commit hook will independently check branch/tests/lint/secrets.
4. Generate the PR body from `templates/pull-request-template.md`.
5. Confirm with the user before pushing the branch or opening the PR — both are visible
   to others and not easily undone.
