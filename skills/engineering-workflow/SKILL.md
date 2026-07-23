---
name: engineering-workflow
description: Use this skill whenever asked to implement a feature, fix a non-trivial bug, refactor logic, change an API/schema, or make any change that alters code behavior — in ANY project (Node, Python, Go, Java, Rust, or unrecognized stacks). Read this BEFORE writing any code. It enforces requirement analysis and a confirmed design before implementation starts, instead of jumping straight to code. SKIP for trivial edits — typo fixes, renaming a single local variable, formatting-only changes, single-line config/version bumps, adding a code comment — and skip entirely if the user has explicitly said something like "just write the code" / "skip the process" / "no need for a design doc". When in doubt about whether a change is trivial, treat it as non-trivial.
---

# Engineering Workflow — Master SOP

This skill turns coding requests into a real engineering process: understand → design →
implement → test → review → commit → PR → merge. It is the single source of truth for
the plugin's Golden Rules — the other three skills in this plugin (`git-workflow`,
`testing-strategy`, `code-review`) reference these rules rather than redefine them.

## Golden Rules (non-negotiable)

1. **Never code before understanding the requirement.** No implementation before Phase 0 is done.
2. **Never guess business logic.** Ask a clarifying question instead of assuming.
3. **Never modify `main`/`master` directly.** Work happens on `feature/*` branches. The
   plugin's commit hook (`hooks/pre-commit-check.sh`) enforces this at commit time as a
   backstop — but treat it as your own rule, not something to route around.
4. **Always produce a design document and get explicit user approval before Phase 3.**
   If the user hasn't replied with approval (e.g. "looks good", "approved", "go ahead"),
   do not call Edit/Write to start implementation — ask again instead of assuming silence
   means yes.
5. **Always run tests before commit.** The commit hook blocks failing tests where it can
   detect a test command; where it can't (unrecognized project type), you are the only
   line of defense — don't skip this just because the hook won't catch you.
6. **Always reach an explicit APPROVED verdict in code review before commit.** NEEDS
   CHANGE means another implementation pass, not a negotiation.
7. **Never leave the working tree dirty at a phase boundary.** Run `git status` before
   moving to the next phase.
8. **Always synchronize the default branch after a merge** (pull latest), but **never
   auto-delete branches** (local or remote). Deleting a branch is destructive and
   hard to reverse — always show the exact commands and get explicit user confirmation
   first, even mid-flow in `/develop`.
9. **When project-type auto-detection can't determine a command, degrade gracefully.**
   Warn the user and ask them to verify manually — never block a project indefinitely
   just because it doesn't match a known stack. This workflow must stay usable on
   projects it doesn't recognize.
10. **Match the user's input language for everything you write.** Requirement Analysis
    Reports, design doc prose, review findings, PR descriptions, and all conversational
    text should be in whatever language the user is writing in — Chinese in, Chinese out;
    English in, English out; and so on for any other language. This applies per-request,
    not per-project: if the user switches language mid-conversation, follow them. Keep
    these fixed regardless of input language, because tooling and other humans depend on
    them staying literal and greppable: Conventional Commit type prefixes (`feat`, `fix`,
    etc.), `feature/*` branch naming, the verdict tokens `APPROVED` / `NEEDS CHANGE`, and
    template section headers (e.g. `## Background`, `## Risk`) — translate the content
    under those headers, not the headers themselves.

## This skill's job vs. `/develop`

This skill, when auto-triggered by a plain-language coding request, is responsible for
**Phase 0 only**: producing the Requirement Analysis Report and, once the requirement is
clear, telling the user to run `/develop` to proceed. It does not itself execute Phase
1-8 — that orchestration lives in exactly one place, the `/develop` command, so phase
sequencing never has two competing definitions. If the user is already inside a
`/develop` run, that command's instructions take precedence for sequencing; this file is
still the source of truth for the Golden Rules and Phase 0 content it references.

## Phase 0: Requirement Analysis

Before any coding task, produce a **Requirement Analysis Report** covering:

- **Goal** — what the user actually wants, in their own terms
- **Scope** — what's in and explicitly what's out
- **Impact** — which existing files/modules/services this touches (look, don't guess)
- **Risk** — what could break, blast radius
- **Questions** — anything ambiguous, asked as actual questions, not assumptions

Forbidden during this phase: writing code, guessing business logic, treating silence on
an ambiguous point as permission to assume.

Once the report is produced and any open questions are resolved, tell the user their
next step is `/develop` to proceed through design, implementation, testing, review,
commit, PR, and merge.

## Phase Map (reference)

| Phase | Name | Owner |
|---|---|---|
| 0 | Requirement Analysis | this skill |
| 1 | Git Preparation | `git-workflow` skill, via `/develop` |
| 2 | Technical Design | this skill + `templates/design-document.md`, via `/develop` |
| 3 | Implementation | this skill, via `/develop` |
| 4 | Testing | `testing-strategy` skill, via `/develop` |
| 5 | Code Review | `agents/code-reviewer.md` (independent context) + `code-review` skill, via `/develop` or `/review` |
| 6 | Commit | `git-workflow` skill, via `/develop` or `/prepare-pr` |
| 7 | Pull Request | `git-workflow` skill + `templates/pull-request-template.md`, via `/develop` or `/prepare-pr` |
| 8 | Merge Workflow | `git-workflow` skill, via `/develop` |
