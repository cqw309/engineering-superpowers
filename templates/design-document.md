# Feature Design: <feature-name>

> Status: DRAFT — awaiting user approval before implementation begins (Phase 3 is blocked until this is confirmed).

## Background
Why this work exists. Link to the originating request/issue if any.

## Requirement
What must be true when this is done. Restate the goal in the requester's own terms — this section should be checkable against the Phase 0 Requirement Analysis Report.

## Architecture
How this fits into the existing system. Call out which existing modules/services/components are touched.

## Technical Solution
The actual approach: key abstractions, data flow, sequence of changes. State the approach you chose and, briefly, the alternative you didn't (and why), if one was considered.

## File Changes
| File | Change type (new/modify/delete) | Purpose |
|---|---|---|
| | | |

## API Design
Request/response shapes, new endpoints, changed contracts. Omit if not applicable.

## Database Changes
Schema changes, migrations, backfill needs. Omit if not applicable.

## Security Consideration
AuthN/AuthZ impact, data exposure, injection surfaces touched by this change.

## Performance Consideration
Expected load, N+1 risk, indexes needed, caching implications.

## Risk
What could go wrong, blast radius, rollback plan.

## Testing Plan
Unit / integration / regression coverage this change requires (see testing-strategy skill for how these are executed).
