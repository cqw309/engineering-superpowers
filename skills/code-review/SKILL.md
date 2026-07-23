---
name: code-review
description: Code review checklist and verdict process for Phase 5 of the engineering workflow. Load this when `/develop` or `/review` reaches the review step, i.e. after implementation and tests pass but before commit. Produces an APPROVED / NEEDS CHANGE verdict using templates/code-review-report.md. Golden Rules live in the engineering-workflow skill.
---

# Code Review

Review happens after tests pass (Phase 4) and before commit (Phase 6). Run `git diff`
against the design doc before writing anything — the review is a check against what was
*planned*, not just a general code quality pass.

## Review dimensions

**Correctness**
- Does the implementation match the design doc's Technical Solution? Any deviation must
  be called out explicitly, not silently accepted.
- Boundary conditions: empty input, null/undefined, max size, concurrent access where
  relevant.

**Security**
- Injection surfaces: SQL, command, XSS — anywhere user input reaches a query, a shell,
  or rendered HTML without sanitization/parameterization.
- AuthN/AuthZ: does this change introduce or touch an endpoint/action that needs an auth
  check it doesn't have?
- Sensitive data: secrets, PII, tokens logged, returned in responses, or committed to the
  repo.

**Performance**
- N+1 queries introduced by the change.
- Memory leaks: unbounded caches, listeners/handles never released.
- Unnecessary computation in a hot path (e.g., recomputing something on every render/call
  that could be cached or hoisted).

**Maintainability**
- Naming matches the vocabulary already used in this codebase.
- Complexity is proportional to the problem — flag both under-engineering (missing
  handling for a case the design doc calls out) and over-engineering (abstraction,
  configurability, or error handling for scenarios that can't happen here).
- Structure follows the surrounding code's existing conventions rather than introducing a
  new pattern without reason.

## Verdict

Fill out `templates/code-review-report.md` and end with exactly one of:

- **APPROVED** — proceed to Phase 6 (Commit).
- **NEEDS CHANGE** — list the specific blocking findings. Phase 6 is blocked until the
  implementation is revised and re-reviewed; this is a re-review, not a negotiation over
  whether the finding counts.

A change with only maintainability nitpicks and no correctness/security/performance
findings can still be marked NEEDS CHANGE if the issues are real — severity determines
how much back-and-forth is worth having, not whether the gate applies.
