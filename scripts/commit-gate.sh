#!/usr/bin/env bash
# Shared commit gate: protected-branch check, secret scan, test/lint gate.
# Called by both hooks/pre-commit-check.sh (Claude Code PreToolUse hook)
# and hooks/git-pre-commit-hook.sh (native git hook), so the two
# enforcement paths can't silently drift apart.
#
# Usage: commit-gate.sh <plugin_root> <repo_root>
# Exit codes: 0 = allow, 1 = block (reason on stderr)

set -uo pipefail

PLUGIN_ROOT="$1"
REPO_ROOT="$2"

cd "$REPO_ROOT" || exit 1

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

# Run project detection once, up front — it's also where an optional
# `protectedBranches` list lives (.claude/project-commands.json), for teams
# whose protected branch isn't just the git-detected default (e.g. a
# "develop" integration branch alongside "main").
eval "$("$PLUGIN_ROOT/scripts/detect-project.sh" "$REPO_ROOT")"

CURRENT_BRANCH="$(git branch --show-current)"
DEFAULT_BRANCH="$(get_default_branch)"

is_extra_protected_branch() {
  local branch="$1" extra
  for extra in ${PROTECTED_BRANCHES:-}; do
    [ "$branch" = "$extra" ] && return 0
  done
  return 1
}

if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] || is_extra_protected_branch "$CURRENT_BRANCH"; then
  echo "BLOCKED: commit refused on protected branch '$CURRENT_BRANCH'. Create a feature/* branch first (see git-workflow skill, Phase 1)." >&2
  exit 1
fi

# --- secret scan on the staged diff (cheap — run before the potentially
# slow test/lint gate below so a leaked secret fails fast) ---

STAGED_DIFF="$(git diff --cached -- . ':(exclude)*.lock' ':(exclude)package-lock.json' 2>/dev/null)"

if echo "$STAGED_DIFF" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: possible AWS access key found in staged changes." >&2
  exit 1
fi

if echo "$STAGED_DIFF" | grep -qE -- '-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----'; then
  echo "BLOCKED: possible private key found in staged changes." >&2
  exit 1
fi

if echo "$STAGED_DIFF" | grep -qE '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b'; then
  echo "BLOCKED: possible GitHub token found in staged changes." >&2
  exit 1
fi

if echo "$STAGED_DIFF" | grep -qE '\bxox[baprs]-[A-Za-z0-9-]{10,}\b'; then
  echo "BLOCKED: possible Slack token found in staged changes." >&2
  exit 1
fi

if echo "$STAGED_DIFF" | grep -qiE '(api|secret|access)[_-]?(key|token)\s*[:=]\s*["'"'"'][A-Za-z0-9/+=_-]{20,}["'"'"']'; then
  echo "BLOCKED: possible hardcoded secret found in staged changes. If this is a false positive, review the diff and adjust or remove the flagged string." >&2
  exit 1
fi

# JWTs (e.g. Supabase service_role keys) aren't caught by the patterns
# above — decode the payload segment and check for a service_role claim.
JWT_CANDIDATES="$(echo "$STAGED_DIFF" | grep -oE 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' || true)"
if [ -n "$JWT_CANDIDATES" ]; then
  while IFS= read -r jwt; do
    [ -z "$jwt" ] && continue
    payload="$(echo "$jwt" | cut -d. -f2)"
    payload="${payload//-/+}"
    payload="${payload//_//}"
    case $(( ${#payload} % 4 )) in
      2) payload="${payload}==" ;;
      3) payload="${payload}=" ;;
    esac
    decoded="$(printf '%s' "$payload" | base64 -d 2>/dev/null || printf '%s' "$payload" | base64 -D 2>/dev/null)"
    if echo "$decoded" | grep -qE '"role"[[:space:]]*:[[:space:]]*"service_role"'; then
      echo "BLOCKED: possible Supabase service_role key (JWT) found in staged changes." >&2
      exit 1
    fi
  done <<< "$JWT_CANDIDATES"
fi

# --- test / lint gate, using the detection already run above ---

if [ "${PROJECT_TYPE:-unknown}" = "unknown" ] || [ -z "${TEST_CMD:-}" ]; then
  echo "WARNING: could not auto-detect a test command for this project — skipping automated test gate. Verify tests manually before this commit." >&2
else
  if ! (cd "$REPO_ROOT" && eval "$TEST_CMD"); then
    echo "BLOCKED: tests failed ('$TEST_CMD'). Fix failing tests before committing (Phase 4, testing-strategy skill)." >&2
    exit 1
  fi
fi

if [ -n "${LINT_CMD:-}" ]; then
  if ! (cd "$REPO_ROOT" && eval "$LINT_CMD"); then
    echo "BLOCKED: lint failed ('$LINT_CMD'). Fix lint errors before committing." >&2
    exit 1
  fi
fi

exit 0
