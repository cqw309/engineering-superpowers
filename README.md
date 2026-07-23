# Engineering Superpowers

**English** | [简体中文](README.zh-CN.md)

A Claude Code plugin that turns coding requests into a real engineering process —
requirement analysis, design, implementation, testing, review, commit, PR, merge —
instead of jumping straight to code. Works across Node.js, Python, Go, Java, Rust, and
degrades gracefully on stacks it doesn't recognize.

This is not a code-generation prompt. It's a workflow engine: a set of skills that shape
how Claude approaches a task, slash commands that sequence the phases, and a git hook
that enforces the parts that actually matter (protected branch, tests, lint, secrets) at
commit time regardless of what the conversation did or didn't do.

## What it enforces, and how

| Rule | Mechanism | Enforcement |
|---|---|---|
| Understand before coding | `engineering-workflow` skill, Phase 0 | Soft (prompt-level) |
| Design doc approved before implementation | `/develop`, Phase 2 | Soft (prompt-level) |
| Never commit on `main`/`master` | `hooks/pre-commit-check.sh` | **Hard** (blocks the commit) |
| Tests pass before commit | `hooks/pre-commit-check.sh` | **Hard** where a test command is detected; soft otherwise (with a warning) |
| No obvious secrets in the diff | `hooks/pre-commit-check.sh` | **Hard** (blocks the commit) |
| Code review reaches APPROVED before commit | `agents/code-reviewer.md` (independent context) + `code-review` skill fallback | Medium — the reviewer runs in its own context with `Write`/`Edit` disallowed at the tool-permission level, so it structurally can't patch instead of reporting; reaching APPROVED itself is still soft |
| Branch deletion requires explicit confirmation | `git-workflow` skill, Phase 8 | Soft (prompt-level, but backed by Claude Code's own tool-permission prompts) |

Being upfront about this: skills and commands are instructions injected into Claude's
context, not a hard state machine — Claude can in principle deviate from them. The hook
is the only layer with a real, deterministic guarantee. That's why the things that matter
most if skipped (committing to main, committing broken code, committing a secret) live in
the hook, not just in a skill's prose.

## Install

```
/plugin marketplace add cqw309/engineering-superpowers
/plugin install engineering-superpowers@engineering-superpowers
```

Check it installed: `/plugin list`. Update later with `/plugin marketplace update
engineering-superpowers`. Uninstall with `claude plugin uninstall
engineering-superpowers@engineering-superpowers`.

## Use

**Just ask for something**, in any project — the `engineering-workflow` skill triggers
automatically on non-trivial coding requests ("add a feature", "fix this bug", "refactor
X") and starts with a Requirement Analysis Report before anything else happens. Trivial
edits (typo fixes, renames, formatting) aren't gated — the skill is scoped to skip those.

Or drive it explicitly with the slash commands:

- **`/develop <feature description>`** — the full Phase 1-8 flow: branch, design doc
  (waits for your approval before writing code), implementation, tests, code review,
  commit, PR, merge. Resumable — if you come back in a new session, it checks for an
  existing design doc / feature branch / review verdict and picks up from there instead
  of starting over.
- **`/review [feature or path]`** — just the code review step, against whatever diff
  exists right now. Useful for code that wasn't written through `/develop`.
- **`/prepare-pr [feature description]`** — commit + open a PR, assuming implementation
  and review are already done.

## Example

```
> add rate limiting to the /api/login endpoint
```

Claude responds with a Requirement Analysis Report (goal, scope, impact, risk,
open questions), asks anything genuinely ambiguous (e.g. "per-IP or per-account?"), then
tells you to run:

```
> /develop rate limiting on /api/login
```

which creates `feature/rate-limit-login`, writes `docs/design/rate-limit-login.md` and
waits for you to approve it, implements against that plan, runs the project's tests
(auto-detected — no config needed for common stacks), produces a code review report, and
only commits once that review says APPROVED. Deleting the feature branch after merge is
still confirmed with you explicitly — that step is never automatic.

## Independent code review

Phase 5 doesn't just ask the same conversation to grade its own work. `/develop` and
`/review` dispatch to `agents/code-reviewer.md` — a subagent with no memory of the
implementation discussion, given only the diff and the design doc, and structurally
unable to edit files (`Write`/`Edit` are in its `disallowedTools`). It can only report
findings and a verdict, not quietly patch around them. If subagent dispatch isn't
available in a given environment, both commands fall back to reviewing inline with the
same `code-review` skill checklist.

## Project-type detection

`scripts/detect-project.sh` figures out test/build/lint commands in this priority order:

1. A `Makefile` with `test`/`build`/`lint` targets, if present
2. `.claude/project-commands.json` in the target repo — an explicit override, e.g.:
   ```json
   { "test": "make ci-test", "build": "make ci-build", "lint": "make ci-lint" }
   ```
3. Language markers: `package.json` (npm/pnpm/yarn), `pyproject.toml`/`requirements.txt`
   (pytest), `go.mod`, `pom.xml`/`build.gradle`, `Cargo.toml`
4. If none of the above match: the workflow doesn't block you — it warns that it
   couldn't detect a test command and asks you to verify manually, rather than making the
   plugin unusable on a project it doesn't recognize.

## Structure

```
engineering-superpowers/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # lets this repo be added directly as a marketplace
├── skills/
│   ├── engineering-workflow/SKILL.md   # master SOP + Golden Rules
│   ├── git-workflow/SKILL.md           # Phase 1, 6, 7, 8
│   ├── testing-strategy/SKILL.md       # Phase 4
│   └── code-review/SKILL.md            # Phase 5 checklist (shared by agent + fallback)
├── agents/
│   └── code-reviewer.md                # independent Phase 5 reviewer, can't edit files
├── commands/
│   ├── develop.md
│   ├── review.md
│   └── prepare-pr.md
├── templates/
│   ├── design-document.md
│   ├── code-review-report.md
│   └── pull-request-template.md
├── scripts/
│   └── detect-project.sh
└── hooks/
    ├── hooks.json
    └── pre-commit-check.sh
```

## License

MIT — see `LICENSE`.
