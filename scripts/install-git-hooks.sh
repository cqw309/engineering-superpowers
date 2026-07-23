#!/usr/bin/env bash
# Installs the native git pre-commit hook into the CURRENT repo, so the
# branch/secret/test/lint gate still runs even if Claude Code's
# PreToolUse hook doesn't fire (child sessions, a stale plugin cache, or
# a commit made outside Claude Code entirely).
#
# Usage: run from inside the target git repo:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/install-git-hooks.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Not inside a git repository." >&2
  exit 1
}

TARGET="$REPO_ROOT/.git/hooks/pre-commit"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ] && ! grep -q "engineering-superpowers" "$TARGET" 2>/dev/null; then
  echo "A pre-commit hook already exists at $TARGET and doesn't look like ours — not overwriting. Merge manually if you want both." >&2
  exit 1
fi

cp "$PLUGIN_ROOT/hooks/git-pre-commit-hook.sh" "$TARGET"
chmod +x "$TARGET"
echo "Installed native pre-commit hook at $TARGET"
