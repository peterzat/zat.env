#!/usr/bin/env bash
set -euo pipefail

# Pre-push hook for Claude Code: blocks git push unless /codereview has passed
# for the current diff. Installed as a PreToolUse hook on Bash via
# ~/.claude/settings.json by zat.env-install.sh, with an "if" filter on
# Bash(git push*).
#
# Claude Code PreToolUse hooks fire for every matching Bash invocation. The
# hook receives a JSON payload on stdin with tool_name, tool_input, and
# hook_event_name. We must parse tool_input.command to determine whether this
# is actually a git push — if not, exit 0 immediately so unrelated commands
# pass through untouched.
#
# The codereview skill writes a marker file containing the diff hash when it
# passes cleanly. This hook verifies the marker exists and matches the current
# diff before allowing the push.
#
# Marker file: /tmp/.claude-codereview-<project-hash>
# Marker content: <diff-hash> (16 hex chars)

# --- git push detection ---
#
# Detect whether a Bash command invokes "git push". An earlier version of
# this hook used a simple string-prefix check on the invoked command, which
# silently failed on common forms like `git -C <dir> push` — letting pushes
# bypass the gate entirely. This tokenizer walks the command string, finds
# each "git" token, skips git-level options that may precede the subcommand,
# and checks whether the first non-option token is "push".
#
# Git-level options that take a separate-space argument: -C, -c, --git-dir,
# --work-tree, --namespace, --exec-path, --super-prefix, --config-env.
# Any other --long or -short token is treated as a boolean flag or inline
# --key=value and consumed as a single token.
#
# Compound commands ("git add . && git push") work because the walker keeps
# looking for further "git" tokens after an earlier match fails.
#
# Known limitation: the tokenizer uses whitespace splitting and cannot parse
# quoted paths containing whitespace (e.g. `git -C "/a b" push`). Such forms
# may be missed (false negative — push bypasses the gate) or misdetected.
# Quoted paths with whitespace are rare in interactive git usage; the guard
# is intentionally simple rather than embedding a shell parser.

is_git_push() {
  local cmd="$1"
  local -a toks
  # shellcheck disable=SC2206
  read -ra toks <<< "${cmd}"
  local i=0 n=${#toks[@]}
  while (( i < n )); do
    if [[ "${toks[i]}" != "git" ]]; then
      i=$((i + 1))
      continue
    fi
    # Verify "git" is being invoked as a command, not used as a literal
    # argument to something else. It must either be the first token OR
    # preceded by a shell operator token. Prevents "echo git push" and
    # similar from being misdetected as a push. Requires shell operators
    # to have whitespace around them; tight-packed "cmd1;git push" with
    # no spaces is a known missed case (the tokenizer sees "cmd1;git"
    # as a single token).
    if (( i > 0 )); then
      case "${toks[i-1]}" in
        "&&"|"||"|";"|"|"|"&"|"("|"{"|"!")
          ;;
        *)
          i=$((i + 1))
          continue
          ;;
      esac
    fi
    local j=$((i + 1))
    while (( j < n )); do
      case "${toks[j]}" in
        # Git-level options that take a separate-space argument
        -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env)
          j=$((j + 2))
          ;;
        # Other options: boolean flag or --key=value, consume single token
        --*|-*)
          j=$((j + 1))
          ;;
        push)
          return 0
          ;;
        *)
          # Some other subcommand (add, commit, status, ...) — not a push.
          break
          ;;
      esac
    done
    i=$((i + 1))
  done
  return 1
}

# Detect tag-only pushes. A tag push either sets --tags as a flag OR passes
# a ref that looks like a version tag (v0.0.0, v1, etc.). Tag pushes contain
# no code content to review, so we skip the gate. Reuses whitespace tokens.
is_tag_only_push() {
  local cmd="$1"
  local -a toks
  # shellcheck disable=SC2206
  read -ra toks <<< "${cmd}"
  local tok
  for tok in "${toks[@]}"; do
    if [[ "${tok}" == "--tags" ]]; then
      return 0
    fi
    if [[ "${tok}" =~ ^v[0-9] ]] || [[ "${tok}" =~ ^refs/tags/ ]]; then
      return 0
    fi
  done
  return 1
}

# --- main ---

HOOK_INPUT=$(cat)
INVOKED_CMD=$(printf '%s' "${HOOK_INPUT}" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

# Pass through anything that is not a git push invocation.
if ! is_git_push "${INVOKED_CMD}"; then
  exit 0
fi

# Tag-only pushes carry no code changes — skip the gate.
if is_tag_only_push "${INVOKED_CMD}"; then
  exit 0
fi

# Determine per-project marker file path.
PROJ_HASH=$(git rev-parse --show-toplevel 2>/dev/null | md5sum | cut -c1-8) || {
  # Not in a git repo — allow the push (don't block non-project pushes).
  exit 0
}
MARKER="/tmp/.claude-codereview-${PROJ_HASH}"
SKIP_MARKER="/tmp/.claude-codereview-skip-${PROJ_HASH}"

# "push now" bypass: skip codereview for this one push.
if [[ -f "${SKIP_MARKER}" ]]; then
  rm -f "${SKIP_MARKER}"
  exit 0
fi

# Compute a hash of the total diff between upstream and the current working
# tree, excluding review output files. This uses a single diff that spans
# both unpushed commits and uncommitted changes, so the hash is stable
# whether the user commits before or after running codereview.
#
# git diff <upstream> = (upstream..HEAD commits) + (uncommitted working tree changes)
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || UPSTREAM="origin/$(git rev-parse --abbrev-ref HEAD)"
if git rev-parse "${UPSTREAM}" >/dev/null 2>&1; then
  BASE="${UPSTREAM}"
else
  # No upstream ref (first push of a new branch) — diff against empty tree.
  BASE=$(git hash-object -t tree /dev/null)
fi

# Empty non-excluded diff allow-path. If the only changes relative to upstream
# are in the excluded review files (or there are no changes at all), there is
# nothing that would need /codereview. Allow the push and log the reason to
# stderr so the agent sees why the gate passed.
if git diff --quiet "${BASE}" -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' 2>/dev/null; then
  echo "Pre-push gate: no reviewable changes vs ${BASE} (only review files or nothing). Allowed." >&2
  exit 0
fi

DIFF_HASH=$(git diff "${BASE}" -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' 2>/dev/null | sha256sum | cut -c1-16)

# Check marker.
if [[ -f "${MARKER}" ]]; then
  STORED_HASH=$(cat "${MARKER}")
  if [[ "${STORED_HASH}" == "${DIFF_HASH}" ]]; then
    # Codereview passed for this exact diff — allow push. Marker is kept
    # so a failed push (network error, remote rejection) does not force
    # a full re-review. The marker is content-addressed by diff hash, so
    # a stale marker for an old diff is harmless.
    exit 0
  fi
fi

# No valid marker — block and instruct.
cat >&2 <<EOF
Pre-push gate: /codereview has not been run on the current changes.

Run /codereview now. After the review passes (all BLOCK items resolved
and tests stable), retry the push. Do not offer to skip the review.

If the user explicitly says "push now", create the
bypass marker then push (two separate commands, not combined, so the
hook sees the marker before the push re-runs):
  codereview-skip
  git push
EOF

exit 2
