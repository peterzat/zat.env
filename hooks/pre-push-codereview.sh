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
#
# The tokenizer ignores quoting, so a push named in a commit message or heredoc
# can read as a real one. That was only a needless review until the rule in
# push_is_alone_and_first, which refuses such a command outright. The refusal
# tells the agent to move the text into a file.

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

# True when token <index> of the caller's array t starts a command, so it is not
# just an argument to something else.
_in_command_position() {
  local p=$(( $1 - 1 ))
  if (( p < 0 )); then return 0; fi
  case "${t[p]}" in
    "&&"|"||"|";"|"|"|"&"|"("|"{"|"!") return 0 ;;
  esac
  return 1
}

# Print, one per line, "<git-token-index> <push-token-index>" for each genuine
# command-position git-push invocation; empty output means no push. This is the
# single source of the push-detection walk: every check below consumes it, so
# the command-position rule and the git-level option handling live in exactly
# one place and cannot drift apart.
#
# A "git" token counts as a command only if it is first or follows a shell
# operator (so "echo git push" is not misread as a push). _normalize_ops has
# already promoted those operators to standalone tokens even when the user
# wrote them tight-packed ("cmd1;git push"), across newlines, or in a subshell
# "(git push)".
_push_invocations() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local n=${#t[@]} i=0
  while (( i < n )); do
    if [[ "${t[i]}" != "git" ]]; then i=$((i + 1)); continue; fi
    if ! _in_command_position "$i"; then i=$((i + 1)); continue; fi
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
          printf '%s %s\n' "$i" "$j"; break ;;
        *)
          # Other subcommand (add, commit, status, ...): not a push.
          break ;;
      esac
    done
    i=$((i + 1))
  done
}

# The "push" token index of each invocation, for callers that only need that.
_push_subcommand_indices() {
  local _git_idx push_idx
  while read -r _git_idx push_idx; do
    printf '%s\n' "${push_idx}"
  done < <(_push_invocations "$1")
}

is_git_push() {
  if [[ -n "$(_push_subcommand_indices "$1")" ]]; then return 0; fi
  return 1
}

# The hook runs once, before the command, so it can only vouch for the repo as
# it stands at that moment. Anything an earlier statement does is invisible to
# it: a commit of untracked files, a merge, an edit plus `git commit -a`, a cd
# into another repo, or a `git init`. So a push must be the command's first
# statement, and its only push. Statements after it cannot change what it sends.
push_is_alone_and_first() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local count=0 first="" git_idx _push_idx
  while read -r git_idx _push_idx; do
    count=$((count + 1))
    if [[ -z "${first}" ]]; then first="${git_idx}"; fi
  done < <(_push_invocations "$1")
  if (( count != 1 )); then return 1; fi
  local k=0
  while (( k < first )); do
    case "${t[k]}" in
      "&&"|"||"|";"|"|"|"&"|"("|"{"|"!") ;;
      *) return 1 ;;
    esac
    k=$((k + 1))
  done
  return 0
}

# `gh repo create --push` runs git itself, so there is no git token to detect.
# It can also point at another directory with --source. Refusing it is simpler
# than judging it, and creating the repo first costs one extra command.
is_gh_repo_create_push() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local n=${#t[@]} i=0 k
  while (( i + 2 < n )); do
    if [[ "${t[i]}" == "gh" && "${t[i+1]}" == "repo" && "${t[i+2]}" == "create" ]] && _in_command_position "$i"; then
      k=$((i + 3))
      while (( k < n )); do
        case "${t[k]}" in
          "&&"|"||"|";"|"|"|"&"|"("|"{"|"!"|")"|"}") break ;;
          --push|--push=*) return 0 ;;
        esac
        k=$((k + 1))
      done
    fi
    i=$((i + 1))
  done
  return 1
}

# Move this process to the repo the push targets, so that everything below
# judges that repo: `git -C other push` from a clean checkout used to read as
# nothing to review. git applies each -C in order, so this does too. Returns
# non-zero when the target cannot be established: --git-dir and --work-tree,
# which a cd cannot model, a path that needs the shell to expand it, or a path
# that does not exist.
enter_push_target() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local git_idx push_idx d
  read -r git_idx push_idx < <(_push_invocations "$1") || true
  local k=$((git_idx + 1))
  while (( k < push_idx )); do
    case "${t[k]}" in
      -C)
        d="${t[k+1]}"
        d="${d#[\"\']}"
        d="${d%[\"\']}"
        # The tokens are unexpanded text, so a literal tilde is what is matched.
        # shellcheck disable=SC2088
        case "${d}" in
          *'$'*|*'`'*) return 1 ;;
          "~") d="${HOME}" ;;
          "~/"*) d="${HOME}/${d#"~/"}" ;;
        esac
        cd -- "${d}" 2>/dev/null || return 1
        k=$((k + 2))
        ;;
      --git-dir|--git-dir=*|--work-tree|--work-tree=*) return 1 ;;
      -c|--namespace|--exec-path|--super-prefix|--config-env) k=$((k + 2)) ;;
      *) k=$((k + 1)) ;;
    esac
  done
  return 0
}

# True when the given revisions reach a commit that is neither in HEAD nor on
# any remote-tracking ref. The review covers HEAD, and what a remote has already
# went through the gate. Fails closed if rev-list itself fails.
_has_commits_outside_head() {
  local -a exclude=(--remotes)
  if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then exclude+=(HEAD); fi
  local out
  out=$(git rev-list --max-count=1 "$@" --not "${exclude[@]}" 2>/dev/null) || return 0
  [[ -n "${out}" ]]
}

# The hash describes HEAD and the working tree, but a push can name something
# else: `git push origin feature` from a clean main read as nothing to review.
# Prints the first ref carrying commits the review cannot have covered. A delete
# sends no commits. A name that does not resolve is skipped, because git fails
# on it too; that also covers redirection tokens and the quoted substitution in
# `git push -u origin "$(git rev-parse --abbrev-ref HEAD)"`, which /pr uses.
push_sends_commits_outside_head() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local n=${#t[@]} _git_idx push_idx
  read -r _git_idx push_idx < <(_push_invocations "$1") || true
  local k=$((push_idx + 1)) seen_remote=0
  local -a refs=() globs=()
  while (( k < n )); do
    case "${t[k]}" in
      "&&"|"||"|";"|"|"|"&"|"("|"{"|"!"|")"|"}") break ;;
      --delete|-d) return 1 ;;
      --all|--branches) globs+=(--branches) ;;
      --mirror) globs+=(--all) ;;
      --tags) globs+=(--tags) ;;
      --*|-*) ;;
      *)
        if (( seen_remote == 0 )); then seen_remote=1; else refs+=("${t[k]}"); fi
        ;;
    esac
    k=$((k + 1))
  done
  local g r src sha
  if (( ${#globs[@]} > 0 )); then
    for g in "${globs[@]}"; do
      if _has_commits_outside_head "${g}"; then printf '%s\n' "${g}"; return 0; fi
    done
  fi
  if (( ${#refs[@]} > 0 )); then
    for r in "${refs[@]}"; do
      r="${r#[\"\']}"
      r="${r%[\"\']}"
      r="${r#+}"
      src="${r%%:*}"
      if [[ -z "${src}" ]]; then continue; fi
      case "${src}" in
        *'*'*) printf '%s\n' "${src}"; return 0 ;;
      esac
      if sha=$(git rev-parse --verify --quiet "${src}^{commit}" 2>/dev/null) \
        && _has_commits_outside_head "${sha}"; then
        printf '%s\n' "${src}"
        return 0
      fi
    done
  fi
  return 1
}

# A refspec is tag-only when it looks like a tag and nothing says otherwise. The
# name alone is not enough: a branch can be called v2-fix, v2-fix:main sends
# that branch, and a tag push sends the commits the tag points at, so a tag on
# an unpushed commit carries code. A name that resolves to nothing passes, since
# git then has nothing to send.
_refspec_is_tag_only() {
  local r="$1" name sha
  if [[ ! "${r}" =~ ^v[0-9] ]] && [[ ! "${r}" =~ ^refs/tags/ ]]; then return 1; fi
  if [[ "${r}" == *:* ]]; then return 1; fi
  name="${r#refs/tags/}"
  if [[ "${r}" != refs/tags/* ]] && git show-ref --verify --quiet "refs/heads/${name}" 2>/dev/null; then
    return 1
  fi
  if sha=$(git rev-parse --verify --quiet "refs/tags/${name}^{commit}" 2>/dev/null); then
    [[ -z "$(git rev-list --max-count=1 "${sha}" --not --remotes 2>/dev/null)" ]] || return 1
  fi
  return 0
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
  read -ra toks < <(_normalize_ops "${cmd}") || true
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
      # Explicit refspecs present: tag-only iff every refspec is a tag push.
      tag_only_here=1
      local r
      for r in "${positionals[@]:1}"; do
        if ! _refspec_is_tag_only "${r}"; then
          tag_only_here=0; break
        fi
      done
    else
      # No explicit refspec (`git push`, `git push origin`, `git push --tags`,
      # `git push --tags origin`): tag-only only if --tags was given and every
      # tag's commits are already on a remote-tracking ref; otherwise this
      # sends code and must be reviewed.
      tag_only_here=${has_tags}
      if (( has_tags == 1 )) && [[ -n "$(git rev-list --max-count=1 --tags --not --remotes 2>/dev/null)" ]]; then
        tag_only_here=0
      fi
    fi
    if (( tag_only_here == 0 )); then return 1; fi
  done
  return 0
}

# --- main ---

HOOK_INPUT=$(cat)

# If jq cannot run (missing from the hook's PATH, or a payload it cannot
# parse), the command used to read as empty, which is "not a push", and the
# push went through. zat.env-install.sh registers this hook only for commands
# Claude Code has already matched as `git push*`, so refuse instead.
if ! INVOKED_CMD=$(printf '%s' "${HOOK_INPUT}" | jq -r '.tool_input.command // ""' 2>/dev/null); then
  echo "Pre-push gate: cannot read the command from the hook payload (is jq on PATH?)." >&2
  echo "Refusing to push. Investigate, then retry." >&2
  exit 2
fi

# The native Windows jq writes CRLF, and Git Bash strips only the final CR
# from a command substitution. A CR left inside a multi-line command glues to
# its token ("push\r"), the walker never sees a bare "push", and a push that
# is not on the last line skips the gate. jq on Linux and macOS emits none.
INVOKED_CMD="${INVOKED_CMD//$'\r'/}"

if is_gh_repo_create_push "${INVOKED_CMD}"; then
  cat >&2 <<EOF
Pre-push gate: gh repo create --push pushes where the gate cannot check it.

Create the repo without --push, then run git push as its own command.
EOF
  exit 2
fi

# Pass through anything that is not a git push invocation.
if ! is_git_push "${INVOKED_CMD}"; then
  exit 0
fi

# This comes before every exit that allows the push, so that neither a tag push
# nor a directory that is not a repo yet can carry an earlier statement past it.
if ! push_is_alone_and_first "${INVOKED_CMD}"; then
  cat >&2 <<EOF
Pre-push gate: run this push as its own command.

The gate sees the repo as it stands when the command starts, so it cannot vouch
for anything an earlier statement in the same command does, such as a commit.
Run those statements first, then push in a separate call, one push per call.
Any /codereview the push needs is checked then. To push another repo, use
git -C <path> push rather than cd <path> && git push.

If the command only mentions a push, in a commit message or heredoc, move that
text to a file and pass the file (for example, git commit -F <file>).
EOF
  exit 2
fi

SESSION_TOP=$(git rev-parse --show-toplevel 2>/dev/null || true)
if ! enter_push_target "${INVOKED_CMD}"; then
  cat >&2 <<EOF
Pre-push gate: cannot tell which repo this push targets, so refusing it.

Push from inside the repo, or use git -C with a literal path to one that exists.
The gate does not follow --git-dir, --work-tree, or a path the shell expands.
EOF
  exit 2
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

if OUTSIDE_REF=$(push_sends_commits_outside_head "${INVOKED_CMD}"); then
  cat >&2 <<EOF
Pre-push gate: this push sends commits the review cannot cover (${OUTSIDE_REF}).

The gate reviews the checked-out branch, and those commits are in neither HEAD
nor any remote-tracking ref. Check out that ref, then run /codereview and push
from there. To push several branches, push each one from its own checkout.
EOF
  exit 2
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
  # The working tree matches the base, but a push sends commits: committed
  # changes reverted only in the working tree would go out unreviewed.
  # Allow only when the commits match the working tree too.
  if ! UNCOMMITTED=$(codereview-marker uncommitted 2>/dev/null); then
    echo "Pre-push gate: codereview-marker uncommitted failed." >&2
    echo "Refusing to push. Investigate, then retry." >&2
    exit 2
  fi
  if [[ -n "${UNCOMMITTED}" ]]; then
    {
      echo "Pre-push gate: the working tree has nothing to review, but the commits"
      echo "being pushed differ from it in these files:"
      printf '%s\n' "${UNCOMMITTED}" | sed -n '1,20s/^/  /p'
      echo ""
      echo "Commit or discard the working-tree changes so the commits match what"
      echo "you intend to push, then run /codereview and retry."
    } >&2
    exit 2
  fi
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
    # The marker covers the base vs the working tree, but a push sends only
    # commits. Reviewed changes that were never committed (typically
    # /codefix's fixes) would let the unfixed commits through, so refuse
    # until they are committed. Fail closed if the check itself fails.
    if ! UNCOMMITTED=$(codereview-marker uncommitted 2>/dev/null); then
      echo "Pre-push gate: codereview-marker uncommitted failed." >&2
      echo "Refusing to push. Investigate, then retry." >&2
      exit 2
    fi
    if [[ -n "${UNCOMMITTED}" ]]; then
      {
        echo "Pre-push gate: /codereview passed, but these reviewed changes are not"
        echo "committed, so the push would send the commits without them:"
        printf '%s\n' "${UNCOMMITTED}" | sed -n '1,20s/^/  /p'
        echo ""
        echo "Commit them, then retry the push; the review covers them, so the"
        echo "marker stays valid. If they should not ship, stash them and run"
        echo "/codereview again."
      } >&2
      exit 2
    fi
    # Codereview passed for this exact diff, all of it committed — allow
    # push. Marker is kept so a failed push (network error, remote
    # rejection) does not force a full re-review. The marker is
    # content-addressed by diff hash, so a stale marker for an old diff is
    # harmless.
    exit 0
  fi
fi

# No valid marker — block and instruct.
cat >&2 <<EOF
Pre-push gate: this push has not passed /codereview.

Run /codereview now, without asking the user first. When the gate blocks,
running the review is the routine next step, not a choice to put to the user.
On success (all BLOCK items resolved, tests stable) it writes the marker;
then retry the push. It runs as a background fork: wait for its final
result, which ends with the verdict, not an interim notice that its own
background work is still running.

Do not offer to skip the review. The one-time bypass is only for when the
user explicitly says "push now" unprompted; never suggest it.
EOF

TARGET_TOP=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ "${TARGET_TOP}" != "${SESSION_TOP}" ]]; then
  printf '\nThis push targets %s, not the current repo, so /codereview has to run there.\n' "${TARGET_TOP}" >&2
fi

exit 2
