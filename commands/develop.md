---
description: Run the full engineering workflow (Phase 1 through 8) for a feature that has already been through Phase 0 requirement analysis.
argument-hint: <feature description>
---

# /develop

Orchestrates Phase 1-8 of the `engineering-workflow` skill. This command is the **only**
place phase sequencing is defined — the auto-triggered `engineering-workflow` skill hands
off here after Phase 0 rather than continuing the sequence itself.

Read the `engineering-workflow`, `git-workflow`, `testing-strategy`, and `code-review`
skills before proceeding; this command composes them, it doesn't replace them.

## Step 0: Resume detection (always run this first)

Don't assume you're starting at Phase 1. Check:

1. Is the current branch already `feature/*`? → Phase 1 is done.
2. Does `docs/design/<feature>.md` exist for this feature? → Phase 2 is done. Read it
   back before continuing so Phase 3 stays consistent with what was approved — don't
   re-ask for approval of a design that was already confirmed in an earlier session.
3. Is there a code review report (in this conversation or referenced by the user) with an
   APPROVED verdict? → Phase 5 is done.

Start from the first phase below that isn't already satisfied. If the feature name is
ambiguous, ask before guessing which `docs/design/*.md` file applies.

## Phase 1 — Git Preparation
Apply `git-workflow` skill, Phase 1. Do not proceed if the working tree isn't clean —
resolve that with the user first.

## Phase 2 — Technical Design
Write `docs/design/<feature>.md` using `templates/design-document.md`. Then **stop and
wait**. Do not call Edit/Write for implementation until the user has replied with
something that reads as approval. If they ask for changes, revise the doc and wait again.

## Phase 3 — Implementation
Only after Phase 2 approval. Follow the design doc; minimal-diff principle — no
unrelated refactors, no speculative abstraction. After each meaningful chunk, run
`git diff` and check it against the design doc's File Changes section before continuing.

## Phase 4 — Testing
Apply `testing-strategy` skill. Do not proceed to Phase 5 with failing tests.

## Phase 5 — Code Review
Prefer independence over convenience: invoke `@agent-engineering-superpowers:code-reviewer`
with the design doc path and what to diff (feature branch vs. default branch). It has no
memory of this conversation and can't edit files — its job is a verdict, not a fix.

If subagent dispatch isn't available in this environment, fall back to applying the
`code-review` skill yourself, producing the same report from
`templates/code-review-report.md`. Same checklist either way — only the reviewer's
independence changes, and the fallback exists so this workflow never gets stuck when
that capability isn't present.

NEEDS CHANGE (from either path) sends you back to Phase 3 for that specific finding, then
re-review — not straight to commit.

## Phase 6 — Commit
Only after an APPROVED verdict. Apply `git-workflow` skill, Phase 6. The commit hook
will independently enforce branch/test/lint/secret checks — a hook block means something
is wrong even if you believed Phase 4/5 already covered it; don't try to work around it.

## Phase 7 — Pull Request
Apply `git-workflow` skill, Phase 7. Confirm with the user before pushing the branch or
opening the PR.

## Phase 8 — Merge Workflow
Apply `git-workflow` skill, Phase 8. Run the automatic sync steps, then present the exact
branch-deletion commands and get explicit confirmation before running them — every time,
regardless of what was agreed earlier in this conversation.
