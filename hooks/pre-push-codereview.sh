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
# Marker file: ${XDG_CACHE_HOME:-${HOME}/.cache}/claude-codereview/marker-<project-hash>
# Marker content: <diff-hash> (16 hex chars)
# Path is single-sourced via `codereview-marker path` and `codereview-marker
# skip-path`; this hook never constructs the marker location itself.

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
# looking for further "git" tokens after an earlier match fails. Before
# splitting, the command string is normalized (see _normalize_ops) so shell
# statement separators, control operators, and grouping parens (newline,
# ; && || | & and "(" ")") become standalone tokens. Without this, a
# tight-packed operator, newline, or subshell glues "git"/"push" to a
# neighbour ("echo hi;git push", "git push&", "(git push)", or a multi-line
# script whose last line is "git push"), the whitespace tokenizer never sees
# a bare "git"/"push" token, and a real code push silently bypasses the gate.
# The bias is deliberately toward over-detection: a false positive only
# triggers a needless review, whereas a missed push is a silent
# security-gate bypass.
#
# Remaining limitation (rare; the guard stays simple rather than embedding a
# shell parser): quoted paths containing whitespace, e.g. `git -C "/a b"
# push`, can be missed or misdetected (the tokenizer splits inside the quotes).

# Promote shell statement separators, control operators, and grouping parens
# (newline, ; && || | & and "(" ")") to standalone, whitespace-delimited
# tokens. Single-sourced so is_git_push and is_tag_only_push tokenize
# identically. Each operator CHARACTER is padded, so "&&" becomes "& &" and
# "||" becomes "| |"; that is harmless because the command-position checks
# accept the single-character operators too. A newline is a statement
# separator, so it is normalized to ";". The result is used only for
# detection; the hook never re-executes the command.
_normalize_ops() {
  local norm="$1"
  local nl=$'\n'
  norm="${norm//;/ ; }"
  norm="${norm//|/ | }"
  norm="${norm//&/ & }"
  norm="${norm//(/ ( }"
  norm="${norm//)/ ) }"
  norm="${norm//$nl/ ; }"
  printf '%s' "${norm}"
}

# Print, one per line, the token index of the "push" subcommand for each
# genuine command-position git-push invocation; empty output means no push.
# This is the single source of the push-detection walk: both is_git_push and
# is_tag_only_push consume it, so the command-position rule and the git-level
# option handling live in exactly one place and cannot drift apart.
#
# A "git" token counts as a command only if it is first or follows a shell
# operator (so "echo git push" is not misread as a push). _normalize_ops has
# already promoted those operators to standalone tokens even when the user
# wrote them tight-packed ("cmd1;git push"), across newlines, or in a subshell
# "(git push)".
_push_subcommand_indices() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t <<< "$(_normalize_ops "$1")"
  local n=${#t[@]} i=0
  while (( i < n )); do
    if [[ "${t[i]}" != "git" ]]; then i=$((i + 1)); continue; fi
    if (( i > 0 )); then
      case "${t[i-1]}" in
        "&&"|"||"|";"|"|"|"&"|"("|"{"|"!") ;;
        *) i=$((i + 1)); continue ;;
      esac
    fi
    # Skip git-level options to reach the subcommand. The listed options take
    # a separate-space argument (consume two tokens); any other -short/--long
    # is a boolean flag or inline --key=value (one token).
    local j=$((i + 1))
    while (( j < n )); do
      case "${t[j]}" in
        -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env)
          j=$((j + 2)) ;;
        --*|-*)
          j=$((j + 1)) ;;
        push)
          printf '%s\n' "$j"; break ;;
        *)
          # Other subcommand (add, commit, status, ...): not a push.
          break ;;
      esac
    done
    i=$((i + 1))
  done
}

is_git_push() {
  if [[ -n "$(_push_subcommand_indices "$1")" ]]; then return 0; fi
  return 1
}

# Detect tag-only pushes. Tag pushes carry no code content to review, so we
# skip the gate for them. This is CONSERVATIVE by construction: a false
# positive here SKIPS the gate (the opposite polarity from is_git_push, where
# a false positive only costs a needless review), so we return success only
# when EVERY git-push invocation in the command pushes tags and nothing else.
# A push that also names a branch refspec, a bare `git push` to the default
# branch, or any non-tag push in a compound makes the whole command
# reviewable. Crucially, each push is judged ONLY by its own argument list
# (the tokens between its "push" subcommand and the next shell operator), so a
# stray version-like token elsewhere in the command (a commit message such as
# `-m v2-prep`, an `echo "deployed v1.0"`, an unrelated `cat v1.txt`) no
# longer skips review. Shares the push-detection walk with is_git_push via
# _push_subcommand_indices.
is_tag_only_push() {
  local cmd="$1"
  local -a toks
  # shellcheck disable=SC2206
  read -ra toks <<< "$(_normalize_ops "${cmd}")"
  local n=${#toks[@]}
  local -a pushidx
  # shellcheck disable=SC2207
  pushidx=($(_push_subcommand_indices "${cmd}"))
  # Reached only after is_git_push succeeds, but be defensive: if no push is
  # recognized, treat it as not tag-only (gate). toks and the indices come
  # from the same _normalize_ops output, so the indices align with toks.
  if (( ${#pushidx[@]} == 0 )); then return 1; fi
  local pj
  for pj in "${pushidx[@]}"; do
    # Inspect ONLY this push's own arguments: the tokens after its "push"
    # token (index pj) up to the next shell operator (or end). positionals[0]
    # is the remote (name or URL); the rest are refspecs. Options are ignored;
    # an option that takes a separate value at worst leaves a stray positional,
    # which only over-gates (a needless review) and can never cause a bypass.
    local k=$((pj + 1)) has_tags=0
    local -a positionals=()
    while (( k < n )); do
      case "${toks[k]}" in
        "&&"|"||"|";"|"|"|"&"|"("|"{"|"!"|")"|"}") break;;
        --tags) has_tags=1;;
        --*|-*) ;;
        *) positionals+=("${toks[k]}");;
      esac
      k=$((k + 1))
    done
    local tag_only_here=0
    if (( ${#positionals[@]} >= 2 )); then
      # Explicit refspecs present: tag-only iff every refspec looks like a tag.
      tag_only_here=1
      local r
      for r in "${positionals[@]:1}"; do
        if [[ ! "${r}" =~ ^v[0-9] ]] && [[ ! "${r}" =~ ^refs/tags/ ]]; then
          tag_only_here=0; break
        fi
      done
    else
      # No explicit refspec (`git push`, `git push origin`, `git push --tags`,
      # `git push --tags origin`): tag-only only if --tags was given;
      # otherwise this pushes the current branch and must be reviewed.
      tag_only_here=${has_tags}
    fi
    if (( tag_only_here == 0 )); then return 1; fi
  done
  return 0
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

# Resolve marker paths via the shared script. Both this hook and
# codereview-skip call `codereview-marker {path,skip-path}` so the marker
# directory layout and PROJ_HASH derivation are single-sourced.
#
# Pass-through for pushes that aren't in a git repo at all. The hook is
# registered globally; pushes outside any project are not our concern.
git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

# Inside a repo, codereview-marker MUST work, otherwise the gate is
# blind to the diff and any push would be a silent bypass. Fail closed.
if ! MARKER=$(codereview-marker path 2>/dev/null); then
  echo "Pre-push gate: codereview-marker is unavailable (not on PATH or broken)." >&2
  echo "Cannot verify the diff; refusing to push. Investigate, then retry." >&2
  exit 2
fi
if ! SKIP_MARKER=$(codereview-marker skip-path 2>/dev/null); then
  echo "Pre-push gate: codereview-marker skip-path failed." >&2
  echo "Refusing to push. Investigate, then retry." >&2
  exit 2
fi

# "push now" bypass: skip codereview for this one push.
if [[ -f "${SKIP_MARKER}" ]]; then
  rm -f "${SKIP_MARKER}"
  exit 0
fi

# Compute the diff hash via the shared script. The script encapsulates
# UPSTREAM derivation (with the @{upstream} -> origin/<branch> -> empty-tree
# fallback chain), the excluded-files diff, and the sha256 truncation. Both
# this hook and codereview's Step 8 call the same script, so the two sites
# are guaranteed to compute the same hash for the same project state — no
# parallel-bash-snippet drift possible.
#
# Exit codes from `codereview-marker hash`:
#   0 = hash printed on stdout
#   2 = no reviewable changes (only excluded files differ, or no changes;
#       the script writes its own explanation to stderr) -- pass through
#   1 (or anything else) = unexpected failure; the gate cannot vouch for
#       the diff, so refuse the push (fail closed). Earlier versions
#       allowed the push on unexpected error, which silently bypassed
#       the gate whenever codereview-marker was missing from PATH or
#       otherwise broken.
HASH_EC=0
DIFF_HASH=$(codereview-marker hash) || HASH_EC=$?
if [[ "${HASH_EC}" -eq 2 ]]; then
  echo "Pre-push gate: nothing to review. Allowed." >&2
  exit 0
fi
if [[ "${HASH_EC}" -ne 0 ]]; then
  echo "Pre-push gate: codereview-marker hash failed (exit ${HASH_EC})." >&2
  echo "Refusing to push -- the gate cannot verify the diff. Investigate the" >&2
  echo "codereview-marker install (likely PATH or shell-init issue), then retry." >&2
  exit 2
fi

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
