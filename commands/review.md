---
description: Run Phase 5 (Code Review) standalone against the current diff, without going through the rest of the engineering workflow.
argument-hint: [feature description or design doc path]
---

# /review

Standalone entry point for Phase 5 — use this when code already exists (possibly written
outside this workflow) and just needs a structured review, without forcing Phase 0-4
first.

1. Determine what to review: if a design doc path or feature name was given in
   `$ARGUMENTS`, resolve `docs/design/<feature>.md` if it exists for context; otherwise
   review `git diff` (uncommitted changes) or the current branch against its base,
   whichever the user clarifies they mean if it's ambiguous.
2. Invoke `@agent-engineering-superpowers:code-reviewer` with that context — it reviews
   independently and can't edit files, only report findings. If subagent dispatch isn't
   available here, apply the `code-review` skill yourself instead, using the same
   `templates/code-review-report.md` output.
3. End with an explicit **APPROVED** or **NEEDS CHANGE** verdict — don't leave it
   implicit in the findings.

This command does not commit or push anything itself — that's `/prepare-pr` or the
commit step inside `/develop`.
