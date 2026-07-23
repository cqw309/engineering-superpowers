#!/usr/bin/env bash
# PreToolUse hook, matcher="Bash" — fires on EVERY Bash call, so the first job
# is to cheaply bail out (exit 0) unless the command is actually `git commit`.
#
# Exit codes (Claude Code PreToolUse contract):
#   0 = allow
#   2 = block (stderr is shown to Claude/user as the reason)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

INPUT="$(cat)"

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    echo "$INPUT" | jq -r '.tool_input.command // empty'
  else
    echo "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null
  fi
}

CMD="$(extract_command)"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# --- from here on, this Bash call IS a git commit: run the real gate ---

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

get_default_branch() {
  local ref
  ref="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
  if [ -n "$ref" ]; then
    echo "$ref"
    return
  fi
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/heads/$candidate"; then
      echo "$candidate"
      return
    fi
  done
  echo "main"
}

CURRENT_BRANCH="$(git branch --show-current)"
DEFAULT_BRANCH="$(get_default_branch)"

if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "BLOCKED: commit refused on protected branch '$DEFAULT_BRANCH'. Create a feature/* branch first (see git-workflow skill, Phase 1)." >&2
  exit 2
fi

# --- test / lint gate, via the single shared detector ---

eval "$("$PLUGIN_ROOT/scripts/detect-project.sh" "$(git rev-parse --show-toplevel)")"

if [ "${PROJECT_TYPE:-unknown}" = "unknown" ] || [ -z "${TEST_CMD:-}" ]; then
  echo "WARNING: could not auto-detect a test command for this project — skipping automated test gate. Verify tests manually before this commit." >&2
else
  if ! (cd "$(git rev-parse --show-toplevel)" && eval "$TEST_CMD"); then
    echo "BLOCKED: tests failed ('$TEST_CMD'). Fix failing tests before committing (Phase 4, testing-strategy skill)." >&2
    exit 2
  fi
fi

if [ -n "${LINT_CMD:-}" ]; then
  if ! (cd "$(git rev-parse --show-toplevel)" && eval "$LINT_CMD"); then
    echo "BLOCKED: lint failed ('$LINT_CMD'). Fix lint errors before committing." >&2
    exit 2
  fi
fi

# --- secret scan on the staged diff ---

STAGED_DIFF="$(git diff --cached -- . ':(exclude)*.lock' ':(exclude)package-lock.json' 2>/dev/null)"

if echo "$STAGED_DIFF" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: possible AWS access key found in staged changes." >&2
  exit 2
fi

if echo "$STAGED_DIFF" | grep -qE -- '-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----'; then
  echo "BLOCKED: possible private key found in staged changes." >&2
  exit 2
fi

if echo "$STAGED_DIFF" | grep -qiE '(api|secret|access)[_-]?(key|token)\s*[:=]\s*["'"'"'][A-Za-z0-9/+=_-]{20,}["'"'"']'; then
  echo "BLOCKED: possible hardcoded secret found in staged changes. If this is a false positive, review the diff and adjust or remove the flagged string." >&2
  exit 2
fi

exit 0
