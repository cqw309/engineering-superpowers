---
name: git-workflow
description: Branch, commit, PR, and merge conventions for this plugin's engineering workflow — Phases 1, 6, 7, and 8. Load this when the `/develop`, `/prepare-pr` commands reach a git-related phase, or when asked directly about branching/commit/PR/merge conventions for a change already scoped by the engineering-workflow skill. Golden Rules live in the `engineering-workflow` skill; this file only adds git-specific detail.
---

# Git Workflow

Applies the `engineering-workflow` skill's Golden Rules to git operations specifically.
Works with any git hosting (GitHub, GitLab, Bitbucket, self-hosted) — nothing here is
tied to a specific platform's CLI.

## Phase 1: Git Preparation

1. `git status` — the working tree must be clean before starting. If it isn't, stop and
   ask the user what to do with the existing changes (stash, commit, discard) rather than
   assuming.
2. Determine the default branch without hardcoding "main": prefer
   `git symbolic-ref refs/remotes/origin/HEAD` (fast, local, no network); if that's
   unset, fall back to checking for a local `main` then `master` branch. If the team
   also treats another branch as protected (e.g. a `develop` integration branch), that
   should be listed in `.claude/project-commands.json`'s `protectedBranches` — see
   Project-type detection in the README — so the hook in step 3 below catches it too.
3. Confirm the current branch is **not** the default branch (or another configured
   protected branch). If it is, create a feature branch: `git switch -c
   feature/<short-description>` (kebab-case, e.g. `feature/user-authentication`).
4. Never commit directly on the default branch — see Golden Rule 3.

## Phase 6: Commit

Only after Phase 5 Code Review has reached an explicit **APPROVED** verdict:

1. `git add` the specific files that were actually part of this change — avoid
   `git add -A`/`git add .` when it would sweep in unrelated files.
2. Commit message format — Conventional Commits: `type(scope): description`
   - Examples: `feat(auth): add jwt login`, `fix(api): fix user query pagination`
   - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`
3. The plugin's `hooks/pre-commit-check.sh` runs automatically on any `git commit` Bash
   call and will block the commit (exit code 2) if: the branch is the default branch or
   another branch listed in `protectedBranches`, detected tests fail, detected lint
   fails, or a likely secret is found in the staged diff. Read its stderr output if a
   commit is blocked — it names the specific failure.
4. If the hook reports it **could not detect a test command** for this project, that is
   not a green light — it means you are the only check left. Confirm tests were actually
   run and passed before committing anyway.

## Phase 7: Pull Request

Generate the PR body from `templates/pull-request-template.md`, filling in:
**What Changed**, **Why** (link the design doc), **Implementation**, **Testing**,
**Risk**. Push the feature branch and open the PR through whatever mechanism the user's
environment provides (e.g. `gh pr create` if the `gh` CLI is available) — confirm with
the user before pushing or opening the PR, since both are actions visible to others.

## Phase 8: Merge Workflow

Split into an **automatic** part and a **confirm-required** part — never blur the two.

**Automatic** (safe, reversible, purely local-state-sync):
1. Confirm the PR/feature branch has actually been merged (don't assume).
2. `git switch <default-branch>`
3. `git pull origin <default-branch>`
4. `git status` — must report a clean working tree; if not, stop and investigate before
   going further (don't discard anything without asking).

**Requires explicit user confirmation, every time** (destructive, hard to reverse):
5. Deleting the local feature branch: `git branch -d feature/<name>`
6. Deleting the remote feature branch: `git push origin --delete feature/<name>`

For steps 5-6: state the exact commands you're about to run and wait for the user to
confirm before running them. Do not treat "we already agreed to this workflow at the
start" as standing approval for a branch deletion later — confirm again at the point of
execution, because branch deletion is exactly the kind of action this project's outer
guidelines call out as needing a fresh confirmation each time.

## Project type detection

Branch/commit/PR/merge steps above don't need project type. Phase 4 (testing) and the
commit hook do — see `scripts/detect-project.sh`, the single source of truth for
test/build/lint command detection (Makefile → `.claude/project-commands.json` override →
language markers → graceful "unknown" degradation). Don't re-derive detection logic here.
