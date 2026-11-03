#!/usr/bin/env bash
set -euo pipefail

# Pre-push hook for Claude Code: blocks git push unless /codereview has passed
# for the current diff. Installed as a PreToolUse hook on Bash via
# ~/.claude/settings.json by zat.env-install.sh, with no "if" filter, so it runs
# on every shell command and decides for itself.
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
# shell parser): the tokenizer splits inside quotes, and the walks rejoin a split
# word with _word_end, so a quoted -C path with a space (`git -C "/a b" push`) is
# refused rather than followed. A push wrapped in an interpreter (`bash -c "git
# push"`, `eval "git push"`) is missed, as is a wrapper that takes a non-numeric
# argument (`sudo -u bob git push`). See push-gate-wrapped-push-detection in
# BACKLOG.md.
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
# detection; the hook never re-executes the command. A line continuation joins
# its lines first, as the shell does: only an odd run of trailing backslashes
# escapes the newline, and not at the end of a comment, where the shell ends the
# comment at the newline anyway. Redirections are padded so that
# "git push>/dev/null" still has a bare "push". The loop reads through process
# substitution, not a here-string: a here-string hung on Git Bash for commands of
# 65,536 bytes and up until the hook timed out, and a timed-out hook allows.
# Set _HD to a heredoc delimiter word after quote removal: single-quoted text
# stays as it is, and outside single quotes a backslash keeps the next character.
_hd_unquote() {
  # Every character tested is ASCII; the C locale makes indexing far cheaper.
  local LC_ALL=C
  local w="$1" c i n=${#1} sq=0
  _HD=""
  for (( i = 0; i < n; i++ )); do
    c="${w:i:1}"
    if (( sq == 1 )); then if [[ "${c}" == "'" ]]; then sq=0; else _HD+="${c}"; fi
    elif [[ "${c}" == "'" ]]; then sq=1
    elif [[ "${c}" == "\\" ]]; then i=$((i + 1)); _HD+="${w:i:1}"
    elif [[ "${c}" != '"' ]]; then _HD+="${c}"; fi
  done
}

_normalize_ops() {
  local norm="$1"
  local nl=$'\n'
  if [[ "${norm}" == *$'\\\n'* ]]; then
    local joined="" line slashes comment_re='(^|[[:space:];&|()])#' q="'" h cmp rest
    local hd_re="(^|[^<])<<(-?)[[:space:]]*((${q}[^${q}]*${q}|\"[^\"]*\"|\\\\.|[^[:space:];&|()<>${q}\"\\\\])+)(.*)$"
    local -a hds=() hdt=()
    local nm
    while IFS= read -r line || [[ -n "${line}" ]]; do
      # The terminator of a quoted heredoc is literal: a trailing backslash there
      # joins nothing (cat <<'X\' ends at the line X\). Every other line joins as
      # usual, so a misread marker affects only a line equal to its delimiter.
      # Its trailing backslashes are dropped, since the line is literal text and
      # a kept one would read as escaping the separator the newline becomes.
      for h in "${!hds[@]}"; do
        cmp="${line}"
        if [[ "${hdt[h]}" == "-" ]]; then cmp="${line#"${line%%[!$'\t']*}"}"; fi
        if [[ "${cmp}" == "${hds[h]}" ]]; then
          unset 'hds[h]' 'hdt[h]'
          joined+="${line%"${line##*[!\\]}"}${nl}"
          continue 2
        fi
      done
      # A delimiter over 256 characters is not tracked, at most 16 open heredocs
      # are, and at most 16 markers per line are read: these bound the time a
      # long or crafted command can take. The regex captures the rest of the line
      # (group 5), since stripping the match off the front is quadratic.
      rest="${line}"; nm=0
      while (( nm < 16 && ${#hds[@]} < 16 )) && [[ "${rest}" == *'<<'* && "${rest}" =~ ${hd_re} ]]; do
        nm=$((nm + 1))
        if (( ${#BASH_REMATCH[3]} <= 256 )) && [[ "${BASH_REMATCH[3]}" == *[\"\'\\]* ]]; then
          _hd_unquote "${BASH_REMATCH[3]}"; hds+=("${_HD}"); hdt+=("${BASH_REMATCH[2]}")
        fi
        rest="${BASH_REMATCH[5]}"
      done
      slashes="${line##*[!\\]}"
      if (( ${#slashes} % 2 == 1 )) && [[ ! "${line}" =~ ${comment_re} ]]; then
        joined+="${line%\\}"
      else
        joined+="${line}${nl}"
      fi
    done < <(printf '%s\n' "${norm}")
    norm="${joined}"
  fi
  norm="${norm//;/ ; }"
  norm="${norm//|/ | }"
  norm="${norm//&/ & }"
  norm="${norm//(/ ( }"
  norm="${norm//)/ ) }"
  # An escaped angle bracket is part of its word, not a redirection, so it must
  # not be padded apart from it. The placeholder keeps the backslash.
  local esc_lt='\<' esc_gt='\>' ph='\_'
  norm="${norm//"${esc_lt}"/"${ph}"}"
  norm="${norm//"${esc_gt}"/"${ph}"}"
  norm="${norm//</ < }"
  norm="${norm//>/ > }"
  norm="${norm//$nl/ ; }"
  printf '%s' "${norm}"
}

# True when a word holds an unmatched quote, so what follows is inside the quote
# however the operators and # read.
_has_open_quote() {
  # The C locale makes the substitutions far cheaper on a long word.
  local LC_ALL=C
  local d="${1//[^\"]/}" s="${1//[^\']/}"
  (( ${#d} % 2 == 1 || ${#s} % 2 == 1 ))
}

# _quote_scan for a long word that holds no backslash, no $', and only one kind
# of quote: the parity of that kind gives the state after it, in linear time.
_quote_parity() {
  local LC_ALL=C
  local d="${1//[^\"]/}" s="${1//[^\']/}"
  _QESC=0
  case "${_QS}" in
    '"') if (( ${#d} % 2 == 1 )); then _QS=""; fi ;;
    "'"|'$') if (( ${#s} % 2 == 1 )); then _QS=""; fi ;;
    *) if (( ${#d} % 2 == 1 )); then _QS='"'; elif (( ${#s} % 2 == 1 )); then _QS="'"; fi ;;
  esac
}

# True when a word holds an escape at its end, an escaped quote, or both kinds of
# quote, so the parity count above can misread whether a quote is open.
_quote_is_unclear() {
  case "$1" in *\\|*\\\"*|*\\\'*|*\"*\'*|*\'*\"*) return 0 ;; esac
  return 1
}

# Read a word as the shell does, starting from the quote state in the caller's
# _QS: empty outside quotes, or the quote that is open (" ' or $ for $'...').
# Leaves the state after the word in _QS, and sets _QESC to 1 when the word ends
# in a backslash that escapes the space after it. The parity count above misreads
# mixed quotes such as "O'Brien -x", which hid the push after them.
_quote_scan() {
  _QESC=0
  if [[ "$1" != *[\"\'\\]* ]]; then return 0; fi
  # Every character tested is ASCII; the C locale makes indexing far cheaper.
  local LC_ALL=C
  local w="$1" c i n=${#1} dol=0
  for (( i = 0; i < n; i++ )); do
    c="${w:i:1}"
    if [[ "${_QS}" == "'" ]]; then
      if [[ "${c}" == "'" ]]; then _QS=""; fi
    elif [[ "${c}" == "\\" ]]; then
      if (( i + 1 == n )); then _QESC=1; else i=$((i + 1)); fi
    elif [[ "${_QS}" == '$' ]]; then
      if [[ "${c}" == "'" ]]; then _QS=""; fi
    elif [[ "${c}" == '"' ]]; then
      if [[ -z "${_QS}" ]]; then _QS='"'; else _QS=""; fi
    elif [[ "${c}" == "'" && -z "${_QS}" ]]; then
      # Only an odd run of unescaped $ opens $'...': $$ is a pair, and a \$ was
      # consumed by the backslash branch.
      if (( dol % 2 == 1 )); then _QS='$'; else _QS="'"; fi
    fi
    if [[ "${c}" == '$' && -z "${_QS}" ]]; then dol=$((dol + 1)); else dol=0; fi
  done
  return 0
}

# Set _WORD_END to the index just past the shell word that starts at token $1 of
# the caller's array t. _normalize_ops splits a quoted or escaped value with a
# space or an operator in it into several tokens, and the walks below step over
# the whole word.
_word_end() {
  local j=$1 n=${#t[@]} _QS="" _QESC=0
  _quote_scan "${t[j]:-}"
  j=$((j + 1))
  while (( j < n )) && [[ -n "${_QS}" || "${_QESC}" == 1 ]]; do
    _quote_scan "${t[j]}"
    j=$((j + 1))
  done
  # A quote still open at the end is a misreading (the shell would reject the
  # command), so step over only the first token rather than hide the rest.
  if [[ -n "${_QS}" ]]; then j=$(($1 + 1)); fi
  _WORD_END=${j}
}

# True when a token leaves a quote open or ends in an escape, so the tokenizer
# split a shell word there. The checks that refuse such a word use both
# readings, since each one misses spellings the other catches.
_word_is_open() {
  if _has_open_quote "$1"; then return 0; fi
  local _QS="" _QESC=0
  _quote_scan "$1"
  [[ -n "${_QS}" || "${_QESC}" == 1 ]]
}

# Set _CMDPOS[k] for each token k of the caller's array t that is in command
# position when quotes, escapes, and redirections are read as the shell reads
# them. _in_command_position uses it only to add detections: it does not model
# heredoc bodies or a substitution inside double quotes, and the walk it backs
# up treats every operator as real, which is the safe reading there.
_exact_command_positions() {
  _CMDPOS=()
  local n=${#t[@]} k=0 ok=1 redir=0 cont=0 _QS="" _QESC=0
  while (( k < n )); do
    # The scan is quadratic in word length; a long word (minified JSON in a
    # heredoc) would hold the hook past its timeout. _quote_parity reads the
    # common long words; for the rest, stopping only drops detections this
    # fallback adds.
    local long=0
    if (( ${#t[k]} > 1024 )); then
      case "${t[k]}" in *\\*|*\"*\'*|*\'*\"*|*\$\'*) break ;; esac
      long=1
    fi
    if [[ -z "${_QS}" ]] && (( cont == 0 )); then
      case "${t[k]}" in
        "&&"|"||"|";"|"|"|"&"|"("|")"|"{"|"!") ok=1; redir=0; k=$((k + 1)); continue ;;
        ">"|"<") redir=1; k=$((k + 1)); continue ;;
      esac
      if (( redir == 1 )); then
        redir=0
      elif (( ok == 1 )); then
        _CMDPOS[k]=1
        if ! _is_command_prefix "${t[k]}"; then ok=0; fi
      fi
    fi
    if (( long == 1 )); then _quote_parity "${t[k]}"; else _quote_scan "${t[k]}"; fi
    cont=${_QESC}
    k=$((k + 1))
  done
  _CMDPOS_DONE=1
}

# True for a word that can come before a command in its statement without being
# the command: a shell keyword, a wrapper that runs what follows, one of their
# options or numeric arguments, or a VAR=value assignment.
_is_command_prefix() {
  case "$1" in
    if|then|elif|else|do|while|until) return 0 ;;
    env|command|builtin|exec|nohup|time|sudo|xargs|nice|ionice|setsid|stdbuf|timeout) return 0 ;;
    -*) return 0 ;;
  esac
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || [[ "$1" =~ ^[0-9]+[smhd]?$ ]]
}

# True when token <index> of the caller's array t starts a command, so it is not
# just an argument to something else. Walks back over command prefixes to the
# statement boundary; any other word means the token is an argument, so
# "echo git push" and "echo -n 5 git push" are not pushes.
_in_command_position() {
  local p=$(( $1 - 1 ))
  while (( p >= 0 )); do
    case "${t[p]}" in
      "&&"|"||"|";"|"|"|"&"|"("|")"|"{"|"!") return 0 ;;
    esac
    if _has_open_quote "${t[p]}" && ! _quote_is_unclear "${t[p]}"; then
      p=$((p - 1))
      while (( p >= 0 )) && ! _has_open_quote "${t[p]}"; do p=$((p - 1)); done
      if (( p < 0 )); then _exact_command_position "$1"; return; fi
    fi
    if ! _is_command_prefix "${t[p]}"; then _exact_command_position "$1"; return; fi
    p=$((p - 1))
  done
  return 0
}

# The second reading for _in_command_position, computed once per token array.
# The caller declares _CMDPOS and _CMDPOS_DONE local so the cache is its own.
_exact_command_position() {
  if (( ${_CMDPOS_DONE:-0} == 0 )); then _exact_command_positions; fi
  [[ -n "${_CMDPOS[$1]:-}" ]]
}

# Print, one per line, "<git-token-index> <push-token-index>" for each genuine
# command-position git-push invocation; empty output means no push. This is the
# single source of the push-detection walk: every check below consumes it, so
# the command-position rule and the git-level option handling live in exactly
# one place and cannot drift apart.
#
# A "git" token, or a path ending in /git, counts as a command only if it is in
# command position (see _in_command_position). _normalize_ops has already
# promoted the shell operators to standalone tokens even when the user wrote
# them tight-packed ("cmd1;git push"), across newlines, or in a subshell
# "(git push)".
_push_invocations() {
  local -a t _CMDPOS=()
  local _CMDPOS_DONE=0
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local n=${#t[@]} i=0
  while (( i < n )); do
    if [[ "${t[i]}" != "git" && "${t[i]}" != */git ]]; then i=$((i + 1)); continue; fi
    if ! _in_command_position "$i"; then i=$((i + 1)); continue; fi
    # Skip git-level options to reach the subcommand. The listed options take
    # a separate-space argument (consume two tokens); any other -short/--long
    # is a boolean flag or inline --key=value (one token). Each -C value's
    # index goes on the output line after the push index, so enter_push_target
    # follows only the -C options git will see.
    local j=$((i + 1))
    local -a cvals=()
    while (( j < n )); do
      local v=""
      case "${t[j]}" in
        -C)
          cvals+=("$((j + 1))"); v="${t[j+1]:-}"; j=$((j + 2)) ;;
        -c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env)
          v="${t[j+1]:-}"; j=$((j + 2)) ;;
        --*|-*)
          v="${t[j]}"; j=$((j + 1)) ;;
        push)
          printf '%s %s%s\n' "$i" "$j" "${cvals[*]:+ ${cvals[*]}}"; break ;;
        ">"|"<")
          # A redirection (git -C .>log push): step over it and its target.
          while [[ "${t[j+1]:-}" == ">" || "${t[j+1]:-}" == "<" || "${t[j+1]:-}" == "&" ]]; do j=$((j + 1)); done
          if (( j + 1 >= n )); then break; fi
          _word_end $((j + 1)); j=${_WORD_END}; continue ;;
        "&")
          # &> is a redirection; a lone & ends the command.
          if [[ "${t[j+1]:-}" == ">" ]]; then j=$((j + 1)); continue; fi
          break ;;
        [0-9]|[0-9][0-9])
          # The file descriptor of a redirection (git 2>/dev/null push).
          if [[ "${t[j+1]:-}" == ">" || "${t[j+1]:-}" == "<" ]]; then j=$((j + 1)); continue; fi
          break ;;
        *)
          # Other subcommand (add, commit, status, ...): not a push.
          break ;;
      esac
      # _normalize_ops split a substitution in the value, so step past the rest
      # of it. enter_push_target then refuses a -C value by its $ or backtick.
      local ticks="${v//[^\`]/}"
      if [[ "${v}" == *'$' && "${t[j]:-}" == "(" ]]; then
        local depth=0
        while (( j < n )); do
          case "${t[j]}" in
            "(") depth=$((depth + 1)) ;;
            ")") depth=$((depth - 1)) ;;
          esac
          j=$((j + 1))
          if (( depth == 0 )); then break; fi
        done
        case "${t[j]:-}" in \"*|\'*|/*) j=$((j + 1)) ;; esac
      elif (( ${#ticks} % 2 == 1 )); then
        while (( j < n )) && [[ "${t[j]}" != *'`'* ]]; do j=$((j + 1)); done
        j=$((j + 1))
      elif [[ -n "${v}" ]]; then
        # A quoted or escaped value the tokenizer split: step past the word.
        _word_end $((j - 1)); j=${_WORD_END}
      fi
    done
    i=$((i + 1))
  done
}

# The "push" token index of each invocation, for callers that only need that.
_push_subcommand_indices() {
  local _git_idx push_idx _cvals
  while read -r _git_idx push_idx _cvals; do
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
  local count=0 first="" git_idx _push_idx _cvals
  while read -r git_idx _push_idx _cvals; do
    count=$((count + 1))
    if [[ -z "${first}" ]]; then first="${git_idx}"; fi
  done < <(_push_invocations "$1")
  if (( count != 1 )); then return 1; fi
  local k=0 at_start=1
  while (( k < first )); do
    case "${t[k]}" in
      "&&"|"||"|";"|"|"|"&"|"("|"{"|"!") at_start=1 ;;
      '#'*)
        # A comment runs to the newline, which is a ";" here. A ";" inside the
        # comment ends the skip early, which only over-refuses. Past the start of
        # a statement the # may be inside a quoted value, so refuse.
        if (( at_start == 0 )); then return 1; fi
        while (( k < first )) && [[ "${t[k]}" != ";" ]]; do k=$((k + 1)); done
        ;;
      *)
        # An unclear quote or escape (A=x\;#y) can hide that a # or an operator
        # after it is part of the word, so refuse it too.
        if ! _is_command_prefix "${t[k]}" || _has_open_quote "${t[k]}" || _quote_is_unclear "${t[k]}"; then return 1; fi
        at_start=0
        ;;
    esac
    k=$((k + 1))
  done
  return 0
}

# `gh repo create --push` runs git itself, so there is no git token to detect.
# It can also point at another directory with --source. Refusing it is simpler
# than judging it, and creating the repo first costs one extra command.
is_gh_repo_create_push() {
  local -a t _CMDPOS=()
  local _CMDPOS_DONE=0
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
        # Step over a whole word, so an operator inside a quoted value
        # (--description "a; b") does not end the walk.
        _word_end "${k}"; k=${_WORD_END}
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
# that does not exist. The same redirection in a prefix (GIT_DIR=x git push, env
# --chdir=x git push) is refused too, since the hook steps over prefixes. The -C
# values come from _push_invocations, so a -C inside a quoted or substituted -c
# value (git -c "x=a -C /tmp" push) is not followed; git never sees it either.
enter_push_target() {
  local -a t inv=()
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  read -ra inv < <(_push_invocations "$1") || true
  local git_idx=${inv[0]:-0} push_idx=${inv[1]:-0} d ci
  local k=0
  while (( k < git_idx )); do
    case "${t[k]}" in
      GIT_DIR=*|GIT_WORK_TREE=*|GIT_COMMON_DIR=*|--chdir|--chdir=*|-C*|-D*) return 1 ;;
    esac
    k=$((k + 1))
  done
  k=$((git_idx + 1))
  while (( k < push_idx )); do
    case "${t[k]}" in
      --git-dir|--git-dir=*|--work-tree|--work-tree=*) return 1 ;;
    esac
    k=$((k + 1))
  done
  for ci in "${inv[@]:2}"; do
    # A value split into several tokens holds a space or an operator, and the
    # tokens alone do not say what path the shell builds from it.
    _word_end "${ci}"
    if (( _WORD_END != ci + 1 )); then return 1; fi
    d="${t[ci]:-}"
    d="${d#[\"\']}"
    d="${d%[\"\']}"
    # The tokens are unexpanded text, so a literal tilde is what is matched.
    # shellcheck disable=SC2088
    case "${d}" in
      *'$'*|*'`'*) return 1 ;;
      "~") d="${HOME}" ;;
      "~/"*) d="${HOME}/${d#"~/"}" ;;
    esac
    CDPATH='' cd -P -- "${d}" 2>/dev/null || return 1
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
# Prints the first ref carrying commits the review cannot have covered, or the
# first argument the shell would expand, which could name anything. A delete
# sends no commits. A literal name that does not resolve is skipped, because git
# fails on it too. /pr's `git push -u origin "$(git rev-parse --abbrev-ref HEAD)"`
# names the checked-out branch, so that exact spelling reads as HEAD.
push_sends_commits_outside_head() {
  local -a t
  # shellcheck disable=SC2206
  read -ra t < <(_normalize_ops "$1") || true
  local n=${#t[@]} _git_idx push_idx _cvals r
  read -r _git_idx push_idx _cvals < <(_push_invocations "$1") || true
  local k=$((push_idx + 1)) seen_remote=0 amp_redir=0
  local -a refs=() globs=()
  while (( k < n )); do
    if [[ "${t[*]:k:8}" == '"$ ( git rev-parse --abbrev-ref HEAD ) "' ]]; then
      seen_remote=1
      k=$((k + 8))
      continue
    fi
    if [[ "${t[k]}" == '#'* ]]; then break; fi
    # The tokenizer split a quoted value, so an operator, # or -d inside it
    # would end or misread the walk. A refspec or remote name holds no
    # whitespace, so this refuses only option values with spaces (-o "ci skip")
    # and a remote path with a space. A # word can only be inside a quote that
    # an earlier word opened, and that word is refused here first.
    if _word_is_open "${t[k]}"; then printf '%s\n' "${t[k]}"; return 0; fi
    # &> is a redirection, not the end of the arguments: the > arm takes it. The
    # tokens cannot tell it from & followed by >, which ends the push, so a later
    # -d may belong to the next statement.
    if [[ "${t[k]}" == "&" && "${t[k+1]:-}" == ">" ]]; then amp_redir=1; k=$((k + 1)); continue; fi
    case "${t[k]}" in
      "&&"|"||"|";"|"|"|"&"|"("|"{"|"!"|")"|"}") break ;;
      ">"|"<")
        # A redirection target is not an argument to the push, but a split one
        # (> "log #1" feature) would hide what follows it.
        while [[ "${t[k+1]:-}" == ">" || "${t[k+1]:-}" == "<" ]]; do k=$((k + 1)); done
        k=$((k + 1))
        if _word_is_open "${t[k]:-}"; then printf '%s\n' "${t[k]}"; return 0; fi
        ;;
      *'$'*|*'`'*|*\\*|*\{*,*\}*|*\{*..*\}*|*'?'*|*'['*) printf '%s\n' "${t[k]}"; return 0 ;;
      -o|--push-option|-[!-]*o)
        # git takes the next word as the value, so -o -d (or -fo -d) is not a
        # delete.
        if [[ "${t[k+1]:-}" == "-d" || "${t[k+1]:-}" == "--delete" ]]; then k=$((k + 1)); fi
        ;;
      --delete|-d)
        if (( amp_redir == 1 )); then break; fi
        return 1 ;;
      --all|--branches) globs+=(--branches) ;;
      --mirror) globs+=(--all) ;;
      --tags) globs+=(--tags) ;;
      --*|-*) ;;
      *)
        r="${t[k]#[\"\']}"
        r="${r%[\"\']}"
        if [[ "${r}" == *[\"\']* ]]; then printf '%s\n' "${t[k]}"; return 0; fi
        if (( seen_remote == 0 )); then seen_remote=1
        elif [[ "${r}" == ":" || "${r}" == "+:" ]]; then globs+=(--branches)
        else refs+=("${t[k]}"); fi
        ;;
    esac
    k=$((k + 1))
  done
  local g src sha
  if (( ${#globs[@]} > 0 )); then
    for g in "${globs[@]}"; do
      if _has_commits_outside_head "${g}"; then printf '%s\n' "${g}"; return 0; fi
      if [[ "${g}" != "--branches" ]] && _has_non_commit_tag; then printf '%s\n' "${g}"; return 0; fi
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
      if sha=$(git rev-parse --verify --quiet "${src}^{commit}" 2>/dev/null); then
        if _has_commits_outside_head "${sha}"; then printf '%s\n' "${src}"; return 0; fi
      elif git rev-parse --verify --quiet "${src}" >/dev/null 2>&1; then
        # It resolves, but to a tree or blob: content no review of HEAD read.
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
  # A wildcard or a word the shell expands names tags the check below cannot see.
  case "${r}" in
    *'*'*|*'$'*|*'`'*|*\\*|*'{'*|*'?'*|*'['*) return 1 ;;
  esac
  name="${r#refs/tags/}"
  if [[ "${r}" != refs/tags/* ]] && git show-ref --verify --quiet "refs/heads/${name}" 2>/dev/null; then
    return 1
  fi
  if git show-ref --verify --quiet "refs/tags/${name}" 2>/dev/null; then
    # A tag on a tree or blob sends content, and has no commit to compare.
    sha=$(git rev-parse --verify --quiet "refs/tags/${name}^{commit}" 2>/dev/null) || return 1
    [[ -z "$(git rev-list --max-count=1 "${sha}" --not --remotes 2>/dev/null)" ]] || return 1
  fi
  return 0
}

# True when a tag peels to a tree or blob. rev-list skips those, so nothing else
# here sees the content such a tag sends.
_has_non_commit_tag() {
  git for-each-ref --format='%(objecttype) %(*objecttype)' refs/tags 2>/dev/null \
    | grep -vE '^(commit |tag commit)$' >/dev/null
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
      # A quoted value the tokenizer split can hide an operator or a refspec.
      if _word_is_open "${toks[k]}"; then return 1; fi
      # &> is a redirection: the > then counts as a positional, which makes the
      # push not tag-only, the safe direction.
      if [[ "${toks[k]}" == "&" && "${toks[k+1]:-}" == ">" ]]; then k=$((k + 1)); continue; fi
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
      # `git push --tags origin`): tag-only only if --tags was given; otherwise
      # this sends code and must be reviewed.
      tag_only_here=${has_tags}
    fi
    # --tags sends every tag, whatever else is named, so each tag's commits must
    # already be on a remote-tracking ref.
    if (( has_tags == 1 )) && { [[ -n "$(git rev-list --max-count=1 --tags --not --remotes 2>/dev/null)" ]] || _has_non_commit_tag; }; then
      tag_only_here=0
    fi
    if (( tag_only_here == 0 )); then return 1; fi
  done
  return 0
}

# --- main ---

HOOK_INPUT=$(cat)

# If jq cannot run (missing from the hook's PATH, or a payload it cannot
# parse), the command used to read as empty, which is "not a push", and the
# push went through. So refuse instead. This hook runs on every shell command,
# so a payload that never mentions a push passes: a broken jq should not stop
# the shell commands needed to fix it.
if ! INVOKED_CMD=$(printf '%s' "${HOOK_INPUT}" | jq -r '.tool_input.command // ""' 2>/dev/null); then
  if [[ "${HOOK_INPUT}" != *push* ]]; then exit 0; fi
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

If the command only mentions a push, in a commit message, heredoc, or quoted
pattern, move that text to a file and pass the file (git commit -F <file>,
grep -f <file>).
EOF
  exit 2
fi

SESSION_TOP=$(git rev-parse --show-toplevel 2>/dev/null || true)
if ! enter_push_target "${INVOKED_CMD}"; then
  cat >&2 <<EOF
Pre-push gate: cannot tell which repo this push targets, so refusing it.

Push from inside the repo, or use git -C with a literal path to one that exists.
The gate does not follow --git-dir, --work-tree, GIT_DIR and its relatives,
env --chdir, or a path the shell expands.
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
#
# A repo with no working tree (a bare repo, or inside .git) is not that case:
# git pushes from there, and there is nothing for a review to read.
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0
  cat >&2 <<EOF
Pre-push gate: this push targets a repo with no working tree, so there is
nothing to review and refusing it.

Push from the repo's working tree instead.
EOF
  exit 2
fi

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

If that is a word the shell expands, the gate cannot tell what it names, so
spell the ref out. A quoted value with a space or shell operator in it, such as
-o "ci skip", is refused too, since the gate cannot tell where it ends.
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
