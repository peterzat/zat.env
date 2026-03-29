#!/usr/bin/env bash
set -euo pipefail

# Pre-push hook for Claude Code: blocks git push unless /codereview has passed
# for the current diff. Installed as a PreToolUse hook on Bash(git push*) via
# ~/.claude/settings.json by zat.env-install.sh.
#
# Claude Code PreToolUse hooks fire for ALL invocations of the matched tool
# (here: every Bash call). The hook receives a JSON payload on stdin with
# tool_name, tool_input, and hook_event_name. We must parse tool_input.command
# to determine whether this is actually a git push — if not, exit 0 immediately.
#
# The codereview skill writes a marker file containing the diff hash when it
# passes cleanly. This hook verifies the marker exists and matches the current
# diff before allowing the push.
#
# Marker file: /tmp/.claude-codereview-<project-hash>
# Marker content: <diff-hash> (16 hex chars)

# Read and parse the hook input JSON from stdin
HOOK_INPUT=$(cat)

# Extract the bash command being invoked.
# NOTE: Do NOT use BASH_COMMAND — it is a bash reserved variable (the currently
# executing command) and cannot be reliably set here.
INVOKED_CMD=$(printf '%s' "${HOOK_INPUT}" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

# Only gate on git push commands — pass through everything else immediately
if [[ "${INVOKED_CMD}" != git\ push* ]]; then
  exit 0
fi

# Determine per-project marker file path
PROJ_HASH=$(git rev-parse --show-toplevel 2>/dev/null | md5sum | cut -c1-8) || {
  # Not in a git repo — allow the push (don't block non-project pushes)
  exit 0
}
MARKER="/tmp/.claude-codereview-${PROJ_HASH}"
SKIP_MARKER="/tmp/.claude-codereview-skip-${PROJ_HASH}"

# "push now" bypass: skip codereview for this one push
if [[ -f "${SKIP_MARKER}" ]]; then
  rm -f "${SKIP_MARKER}"
  exit 0
fi

# Compute a hash of the total diff between upstream and the current working tree,
# excluding review output files. This uses a single diff that spans both unpushed
# commits and uncommitted changes, so the hash is stable whether the user commits
# before or after running codereview.
#
# git diff <upstream> = (upstream..HEAD commits) + (uncommitted working tree changes)
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || UPSTREAM="origin/$(git rev-parse --abbrev-ref HEAD)"
if git rev-parse "${UPSTREAM}" >/dev/null 2>&1; then
  DIFF_HASH=$(git diff "${UPSTREAM}" -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' 2>/dev/null | sha256sum | cut -c1-16)
else
  # No upstream ref exists (first push of a new branch). Fall back to diffing
  # the entire working tree against an empty tree so the hash still works.
  EMPTY_TREE=$(git hash-object -t tree /dev/null)
  DIFF_HASH=$(git diff "${EMPTY_TREE}" -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' 2>/dev/null | sha256sum | cut -c1-16)
fi

# Check marker
if [[ -f "${MARKER}" ]]; then
  STORED_HASH=$(cat "${MARKER}")
  if [[ "${STORED_HASH}" == "${DIFF_HASH}" ]]; then
    # Codereview passed for this exact diff — allow push, consume marker
    rm -f "${MARKER}"
    exit 0
  fi
fi

# No valid marker — block and instruct
cat >&2 <<EOF
Pre-push gate: /codereview has not been run on the current changes.

Run /codereview first. After the review passes (all BLOCK and WARN items
resolved and tests stable), retry the push.

To skip codereview for this push (e.g. docs-only changes), the user can
say "push now". If they do, create the bypass marker and push:
  touch ${SKIP_MARKER} && git push
EOF

exit 2
