# Code Review Report: <feature-name>

Branch: `feature/<name>` → `<default-branch>`
Design doc: `docs/design/<feature-name>.md`

## Correctness
- [ ] Implements the design doc's Technical Solution as written (deviations called out below)
- [ ] Edge cases and boundary conditions handled
- Findings:

## Security
- [ ] No SQL/command/XSS injection surfaces introduced
- [ ] AuthN/AuthZ checks present where required
- [ ] No sensitive data logged or exposed in responses
- Findings:

## Performance
- [ ] No N+1 queries introduced
- [ ] No obvious memory leaks (unbounded caches, unclosed handles/listeners)
- [ ] No unnecessary recomputation in hot paths
- Findings:

## Maintainability
- [ ] Naming is clear and consistent with surrounding code
- [ ] Complexity is proportional to the problem (no premature abstraction, no unnecessary cleverness)
- [ ] Structure follows existing project conventions
- Findings:

## Deviations from Design Doc
List anything implemented differently than planned, and why.

## Verdict

**APPROVED** / **NEEDS CHANGE**

If NEEDS CHANGE: list the specific blocking items above that must be fixed before re-review.
