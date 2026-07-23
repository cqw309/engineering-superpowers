#!/usr/bin/env bash
# Portable git-native `pre-commit` hook — defense in depth for when the
# Claude Code PreToolUse hook doesn't fire (child sessions, a stale
# plugin cache, or a commit made outside Claude Code entirely). Install
# with scripts/install-git-hooks.sh from inside the target repo.
#
# Runs the same branch/secret/test/lint gate as the PreToolUse hook by
# locating this plugin's installed copy and calling its shared
# scripts/commit-gate.sh. Fails OPEN (exits 0) if the plugin can't be
# found, so a machine without it installed is never blocked by a hook
# it doesn't know about.

set -uo pipefail

find_plugin_root() {
  local candidate
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$CLAUDE_PLUGIN_ROOT/scripts/commit-gate.sh" ]; then
    echo "$CLAUDE_PLUGIN_ROOT"
    return
  fi
  for candidate in "$HOME"/.claude/plugins/cache/engineering-superpowers/engineering-superpowers/*; do
    if [ -x "$candidate/scripts/commit-gate.sh" ]; then
      echo "$candidate"
      return
    fi
  done
}

PLUGIN_ROOT="$(find_plugin_root)"
if [ -z "$PLUGIN_ROOT" ]; then
  echo "NOTE: engineering-superpowers plugin not found — skipping commit gate (install the plugin for branch/test/secret checks)." >&2
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
"$PLUGIN_ROOT/scripts/commit-gate.sh" "$PLUGIN_ROOT" "$REPO_ROOT"
