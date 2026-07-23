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

# Detects a real `git commit` invocation — even with global options in
# between (`git -c user.email=x commit`, `git --no-pager commit`,
# `git -C dir commit`) or shell metacharacters jammed against it with no
# spaces (`foo&&git commit`) — while NOT firing on strings that merely
# contain the words "git" and "commit" as arguments to something else
# (`grep -r "git commit" .`, `echo "remember to git commit"`). A plain
# substring match on "git commit" gets both of these wrong.
is_git_commit() {
  local raw="$1"
  local spaced
  # A newline separates shell statements exactly like `;` — without this,
  # a `git commit` that isn't the very first line of a multi-line Bash
  # tool command (e.g. `git add x` then `git commit -m y` on the next
  # line) would fail to register as an invocation start below.
  spaced="${raw//$'\n'/ ; }"
  spaced="$(printf '%s' "$spaced" | sed -E 's/(&&|\|\||[;&|(){}])/ \1 /g')"
  local -a words
  set -f
  words=($spaced)
  set +f
  local n=${#words[@]} i=0 w base prev a
  while [ "$i" -lt "$n" ]; do
    w="${words[$i]}"
    base="${w##*/}"
    if [ "$base" = "git" ]; then
      prev=""
      [ "$i" -gt 0 ] && prev="${words[$((i - 1))]}"
      case "$prev" in
        # "git" only counts as an invocation if it sits where a command
        # can start: the very first word, right after a shell separator,
        # or right after a common wrapper command.
        ""|";"|"&"|"&&"|"|"|"||"|"("|")"|"{"|"}"|"!"|sudo|time|nice|nohup|env|exec|ionice)
          i=$((i + 1))
          while [ "$i" -lt "$n" ]; do
            a="${words[$i]}"
            case "$a" in
              -c|-C) i=$((i + 2)) ;;
              -*) i=$((i + 1)) ;;
              *) break ;;
            esac
          done
          if [ "$i" -lt "$n" ] && [ "${words[$i]}" = "commit" ]; then
            return 0
          fi
          ;;
      esac
    fi
    i=$((i + 1))
  done
  return 1
}

if ! is_git_commit "$CMD"; then
  exit 0
fi

# --- from here on, this Bash call IS a git commit: run the real gate ---

# Bash tool calls can be preceded by earlier `cd`s in the same persistent
# shell. Claude Code reports the shell's actual cwd for this call in the
# hook payload — use it explicitly instead of trusting our own process's
# cwd, so the branch/test/secret checks below never run against the wrong
# repo.
HOOK_CWD="$(echo "$INPUT" | { command -v jq >/dev/null 2>&1 && jq -r '.cwd // empty' || python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    print("")
' 2>/dev/null; })"
if [ -n "$HOOK_CWD" ] && [ -d "$HOOK_CWD" ]; then
  cd "$HOOK_CWD" || exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Branch protection, secret scan, and test/lint gate are shared with the
# native git pre-commit hook (hooks/git-pre-commit-hook.sh) via this one
# script, so the two enforcement paths can't drift apart.
if ! "$PLUGIN_ROOT/scripts/commit-gate.sh" "$PLUGIN_ROOT" "$(git rev-parse --show-toplevel)"; then
  exit 2
fi

exit 0
