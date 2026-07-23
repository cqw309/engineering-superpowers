---
description: Run Phase 5 (Code Review) standalone against the current diff, without going through the rest of the engineering workflow.
argument-hint: [feature description or design doc path]
---

# /review

Standalone entry point for the `code-review` skill — use this when code already exists
(possibly written outside this workflow) and just needs a structured review, without
forcing Phase 0-4 first.

1. Read the `code-review` skill.
2. Determine the diff to review: if a design doc path or feature name was given in
   `$ARGUMENTS`, read `docs/design/<feature>.md` if it exists for context; otherwise
   review against `git diff` (uncommitted changes) or the diff of the current branch
   against its base, whichever the user clarifies they mean if it's ambiguous.
3. Produce the report using `templates/code-review-report.md`, covering Correctness,
   Security, Performance, Maintainability.
4. End with an explicit **APPROVED** or **NEEDS CHANGE** verdict — don't leave it
   implicit in the findings.

This command does not commit or push anything itself — that's `/prepare-pr` or the
commit step inside `/develop`.
