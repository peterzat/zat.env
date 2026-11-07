#!/usr/bin/env bash
set -uo pipefail

# Tests for hooks/pre-push-codereview.sh.
#
# Covers:
#   - is_git_push detection across many command forms (the bug that motivated
#     this suite: `git -C <dir> push` and other prefix variants silently
#     bypassed the gate)
#   - is_tag_only_push detection
#   - What the gate refuses because it cannot vouch for it: a statement before
#     the push, a second push, gh repo create --push, an unknown target repo,
#     and a ref with commits outside HEAD
#   - Empty non-excluded diff allow-path
#   - Marker file hash match / mismatch
#   - Skip marker consumption
#   - Non-push commands pass through
#   - Fail closed when codereview-marker or jq is unavailable
#   - CRLF jq output (native Windows jq) and PowerShell tool payloads

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/pre-push-codereview.sh"

# Ensure the hook can find codereview-marker on PATH the same way it does
# in production. The repo's bin/ is prepended so the test is self-contained
# even on a fresh checkout where the user has not run zat.env-install.sh yet.
export PATH="${REPO_DIR}/bin:${PATH}"

FAILS=0
TOTAL=0
pass() { TOTAL=$((TOTAL + 1)); printf '  ok   %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }

# Invoke the hook with a command string wrapped in a minimal JSON payload.
# Prints nothing on stdout/stderr; returns the exit code.
invoke_hook() {
  local cmd="$1"
  local payload
  payload=$(jq -n --arg c "${cmd}" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
  printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1
  return $?
}

# assert_exit <cmd-string> <expected-exit> <label>
# Runs the hook against the given command string and asserts the exit code.
# IMPORTANT: for detection-only tests we set the working directory to a
# scratch non-git directory so the hook exits 0 via the "not in a git repo"
# branch whenever detection says "this is a push". That lets us test detection
# without needing controlled marker state. For push cases that should be
# detected, the expected exit is 0 (detected-as-push, not-in-git-repo, allow).
# For non-push cases, the expected exit is also 0 but via the early-exit path.
# To distinguish the two we also check stderr in a separate assertion helper.
assert_exit() {
  local cmd="$1" expected="$2" label="$3"
  local actual
  (cd "${SCRATCH_NOGIT}" && invoke_hook "${cmd}")
  actual=$?
  if [[ "${actual}" -eq "${expected}" ]]; then
    pass "${label}"
  else
    fail "${label} (expected exit ${expected}, got ${actual})"
  fi
}

# Detection-check helpers: these run the hook against a temp git repo with
# controlled marker state so we can observe whether detection classified the
# command as a push.

# Set up a throwaway git repo with one committed file, so we have a meaningful
# diff to test against and a well-defined upstream.
setup_test_repo() {
  TEST_REPO=$(mktemp -d)
  git -C "${TEST_REPO}" init -q -b main
  git -C "${TEST_REPO}" config user.email test@test.invalid
  git -C "${TEST_REPO}" config user.name "test"
  echo "first" > "${TEST_REPO}/file.txt"
  git -C "${TEST_REPO}" add file.txt
  git -C "${TEST_REPO}" commit -q -m "initial"
  # Fake an upstream by creating refs/remotes/origin/main pointing at HEAD.
  # The hook does `git rev-parse origin/main` and expects this ref layout.
  git -C "${TEST_REPO}" update-ref refs/remotes/origin/main HEAD
  # Resolve marker paths via the same script the hook uses, so the test is
  # invariant to the path scheme. codereview-marker requires a git context,
  # so call it from inside the test repo.
  TEST_MARKER=$(cd "${TEST_REPO}" && codereview-marker path)
  TEST_SKIP_MARKER=$(cd "${TEST_REPO}" && codereview-marker skip-path)
  rm -f "${TEST_MARKER}" "${TEST_SKIP_MARKER}"
}

teardown_test_repo() {
  rm -rf "${TEST_REPO}"
  rm -f "${TEST_MARKER}" "${TEST_SKIP_MARKER}"
}

# Run the hook inside the test repo with a given command string.
invoke_in_test_repo() {
  local cmd="$1"
  local payload
  # The command goes to jq on stdin: a long one passed with --arg exceeds
  # Windows' 32,767-character command-line limit.
  payload=$(printf '%s' "${cmd}" | jq -Rs '{tool_name:"Bash", tool_input:{command:.}, hook_event_name:"PreToolUse"}')
  (cd "${TEST_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" 2>&1)
}

# ----------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------

# A scratch directory that is NOT a git repo, used for detection-only tests.
SCRATCH_NOGIT=$(mktemp -d)
trap 'rm -rf "${SCRATCH_NOGIT}" "${JQ_SHIM_DIR:-}"; rm -rf "${TEST_REPO:-}"; rm -f "${TEST_MARKER:-}" "${TEST_SKIP_MARKER:-}"' EXIT

# ============================================================
echo "==> Detection: positive cases (should be classified as git push)"
# ============================================================
#
# In a non-git directory, the hook exits 0 for a detected push via the
# "not in a git repo" branch. For a non-push command it also exits 0, via
# the early-exit path. So detection-only positive/negative both yield exit 0
# in the non-git directory. We rely on the negative-case block below to
# exercise the same commands in a real repo and verify dispatch.

for cmd in \
  "git push" \
  "git push origin main" \
  "git -C /tmp push" \
  "git -c user.name=foo push" \
  "git -c user.name=foo -c user.email=bar push" \
  "git --namespace=foo push" \
  "git --exec-path=/usr/lib/git-core push" \
  "git --super-prefix=sub push" \
  "git -C ${SCRATCH_NOGIT} push" \
  "git push --force-with-lease"; do
  assert_exit "${cmd}" 0 "detects as push (no-git-repo allow): ${cmd}"
done

# These allowed through the not-a-repo exit until the push-first rule, which
# has to run before that exit: `git init && ... && git push` starts outside a
# repo. Exit 2 also shows detection directly, where exit 0 could not.
for cmd in \
  "git add . && git push" \
  "git commit -m done && git push" \
  "( cd /tmp && git push )" \
  "git init && git add . && git commit -m x && git push"; do
  assert_exit "${cmd}" 2 "refused outside a repo when a statement comes first: ${cmd}"
done

# The gate cannot follow these to a repo, so it refuses them wherever it runs.
for cmd in \
  "git --git-dir=/tmp/x push" \
  "git --work-tree=/tmp/x push" \
  "git --git-dir /tmp/x push" \
  'git -C "$HOME/src/x" push' \
  'git -C `pwd` push' \
  "git -C ${SCRATCH_NOGIT}/does-not-exist push"; do
  assert_exit "${cmd}" 2 "refused when the target repo is unknown: ${cmd}"
done

# ============================================================
echo ""
echo "==> Detection: negative cases (should NOT be classified as git push)"
# ============================================================

for cmd in \
  "git status" \
  "git diff" \
  "git log --oneline" \
  "git commit -m push" \
  "git commit -m \"fix push bug\"" \
  "git branch --list" \
  "echo git push" \
  "echo 'git push is a command'" \
  "cat /tmp/notes-about-git-push.txt" \
  "grep -r 'git push' docs/" \
  "ls -la" \
  ""; do
  assert_exit "${cmd}" 0 "passes through: ${cmd}"
done

# ============================================================
echo ""
echo "==> Dispatch: real repo, no diff → empty-diff allow path"
# ============================================================

setup_test_repo
# Working tree matches upstream — non-excluded diff is empty.
out=$(invoke_in_test_repo "git push")
ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "no-diff: exit code 0"
else
  fail "no-diff: expected exit 0, got ${ec}"
fi
if [[ "${out}" == *"no reviewable changes"* ]]; then
  pass "no-diff: stderr explains why gate passed"
else
  fail "no-diff: expected 'no reviewable changes' on stderr, got: ${out}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: real repo, diff exists, no marker → block"
# ============================================================

setup_test_repo
# Introduce an uncommitted change so the non-excluded diff is non-empty.
echo "modified" > "${TEST_REPO}/file.txt"
out=$(invoke_in_test_repo "git push")
ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "diff-no-marker: exit code 2 (block)"
else
  fail "diff-no-marker: expected exit 2, got ${ec}"
fi
if [[ "${out}" == *"Run /codereview now"* ]]; then
  pass "diff-no-marker: stderr explains the block"
else
  fail "diff-no-marker: expected block message on stderr"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: real repo, diff exists, marker matches → allow"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
# The reviewed change is committed, as it is when it is pushed.
git -C "${TEST_REPO}" commit -q -am "change"
# Compute the same hash the hook would compute and write it as the marker.
EXPECTED=$(cd "${TEST_REPO}" && git diff origin/main -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' | sha256sum | cut -c1-16)
echo "${EXPECTED}" > "${TEST_MARKER}"
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "diff-marker-match: exit code 0 (allow)"
else
  fail "diff-marker-match: expected exit 0, got ${ec}"
fi
if [[ -f "${TEST_MARKER}" ]]; then
  pass "diff-marker-match: marker preserved after allow"
else
  fail "diff-marker-match: marker was consumed (should persist)"
fi
# Review output files left uncommitted (CODEREVIEW.md after Step 9) are not
# hashed and do not block.
echo "review" > "${TEST_REPO}/CODEREVIEW.md"
git -C "${TEST_REPO}" add CODEREVIEW.md
echo "more review" >> "${TEST_REPO}/CODEREVIEW.md"
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "diff-marker-match: uncommitted review output files do not block"
else
  fail "diff-marker-match: uncommitted CODEREVIEW.md blocked the push (exit ${ec})"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: marker matches but reviewed changes are uncommitted → block"
# ============================================================
# The marker hashes base vs the working tree; a push sends only commits. An
# uncommitted /codefix fix made the marker match while the unfixed commits
# were pushed.

setup_test_repo
echo "unfixed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unfixed change"
echo "fixed" > "${TEST_REPO}/file.txt"
EXPECTED=$(cd "${TEST_REPO}" && git diff origin/main -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' | sha256sum | cut -c1-16)
echo "${EXPECTED}" > "${TEST_MARKER}"
ec=0
out=$(invoke_in_test_repo "git push" 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "uncommitted-fix: exit code 2 (block)"
else
  fail "uncommitted-fix: expected exit 2, got ${ec}"
fi
if [[ "${out}" == *"not"*"committed"* ]] && [[ "${out}" == *"file.txt"* ]]; then
  pass "uncommitted-fix: stderr names the uncommitted file"
else
  fail "uncommitted-fix: expected the uncommitted-changes message naming file.txt"
fi
# Staged but not committed is still not pushed.
git -C "${TEST_REPO}" add file.txt
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "uncommitted-fix: staged-only change still blocks"
else
  fail "uncommitted-fix: staged-only change expected exit 2, got ${ec}"
fi
# Committing it keeps the same hash, so the marker now allows the push.
git -C "${TEST_REPO}" commit -q -m "fix"
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "uncommitted-fix: after commit the same marker allows the push"
else
  fail "uncommitted-fix: after commit expected exit 0, got ${ec}"
fi
teardown_test_repo

# More than a pipe buffer of uncommitted names must still block (exit 2);
# a writer cut off by SIGPIPE would exit 141, which Claude Code treats as a
# non-blocking error.
setup_test_repo
mkdir -p "${TEST_REPO}/many"
for i in $(seq 1 2500); do
  echo "a" > "${TEST_REPO}/many/file-with-a-long-name-to-fill-the-pipe-buffer-${i}.txt"
done
git -C "${TEST_REPO}" add many
git -C "${TEST_REPO}" commit -q -m "many files"
for i in $(seq 1 2500); do
  echo "b" > "${TEST_REPO}/many/file-with-a-long-name-to-fill-the-pipe-buffer-${i}.txt"
done
EXPECTED=$(cd "${TEST_REPO}" && git diff origin/main -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md' | sha256sum | cut -c1-16)
echo "${EXPECTED}" > "${TEST_MARKER}"
ec=0
out=$(invoke_in_test_repo "git push" 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]] && [[ "${out}" == *"Commit them"* ]]; then
  pass "uncommitted-fix: over 64 KB of uncommitted names still blocks"
else
  fail "uncommitted-fix: large uncommitted list expected exit 2 with message, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: commits reverted only in the working tree → block"
# ============================================================
# The working tree matches the base ("nothing to review"), but the commits
# being pushed do not.

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed change"
git -C "${TEST_REPO}" checkout -q origin/main -- file.txt
ec=0
out=$(invoke_in_test_repo "git push" 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]] && [[ "${out}" == *"file.txt"* ]]; then
  pass "revert-in-worktree: exit code 2 (block), names file.txt"
else
  fail "revert-in-worktree: expected exit 2 naming file.txt, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: real repo, diff exists, marker stale → block"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
echo "0000000000000000" > "${TEST_MARKER}"
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "diff-marker-stale: exit code 2 (block)"
else
  fail "diff-marker-stale: expected exit 2, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: skip marker present → allow and consume"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
touch "${TEST_SKIP_MARKER}"
ec=0
invoke_in_test_repo "git push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "skip-marker: exit code 0 (allow)"
else
  fail "skip-marker: expected exit 0, got ${ec}"
fi
if [[ ! -f "${TEST_SKIP_MARKER}" ]]; then
  pass "skip-marker: consumed on use"
else
  fail "skip-marker: should have been deleted"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: tag-only push via --tags → allow"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
ec=0
invoke_in_test_repo "git push --tags" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "tag-push --tags: exit code 0"
else
  fail "tag-push --tags: expected 0, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Dispatch: tag-only push via version ref → allow"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
ec=0
invoke_in_test_repo "git push origin v1.2" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "tag-push origin v1.2: exit code 0"
else
  fail "tag-push origin v1.2: expected 0, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: the -C <dir> bug that motivated this suite"
# ============================================================

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
# The old hook returned exit 0 here (bypass). The new hook must return 2.
ec=0
invoke_in_test_repo "git -C ${TEST_REPO} push" >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "git -C <dir> push: detected and blocked (was the bug)"
else
  fail "git -C <dir> push: expected exit 2, got ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: tight-packed operators and newlines must not bypass the gate"
# ============================================================
#
# Before is_git_push normalized shell operators, a compound command whose
# separator was not surrounded by whitespace glued "git"/"push" to a
# neighbour, so the whitespace tokenizer never saw a bare token and detection
# returned false — a real code push silently bypassed the gate. This covers
# tight-packed control operators (;, &&, ||, |, &) and newline separators
# (common in multi-line agent-issued Bash). Each is a genuine push and must
# be detected and blocked (exit 2) when a diff exists and no marker is present.
bypass_cmds=(
  'echo hi;git push'
  'true&&git push'
  'false||git push'
  'git add .;git push'
  'git push;echo done'
  'git push&'
  'cat x|git push'
  $'git add -A\ngit push'
  $'git commit -m wip\ngit push origin main'
  $'git add -A\ngit commit -m wip\ngit push'
)
for cmd in "${bypass_cmds[@]}"; do
  setup_test_repo
  echo "modified" > "${TEST_REPO}/file.txt"
  ec=0
  invoke_in_test_repo "${cmd}" >/dev/null 2>&1 || ec=$?
  if [[ "${ec}" -eq 2 ]]; then
    pass "compound push detected+blocked: $(printf '%q' "${cmd}")"
  else
    fail "compound push NOT gated (bypass): $(printf '%q' "${cmd}") (got exit ${ec})"
  fi
  teardown_test_repo
done

# ============================================================
echo ""
echo "==> Over-detection guard: non-push compounds still pass through"
# ============================================================
#
# Operator normalization is biased toward over-detection, but it must not
# turn a command that merely contains other git subcommands (or mentions
# push) into a spurious block. Run in a real repo with a diff so a
# false-positive detection would surface as an unexpected exit 2.
nonpush_cmds=(
  'git status&&git diff'
  'echo done;ls -la'
  "echo 'git push';true"
  $'git status\ngit diff'
  $'echo building\nmake all'
)
for cmd in "${nonpush_cmds[@]}"; do
  setup_test_repo
  echo "modified" > "${TEST_REPO}/file.txt"
  ec=0
  invoke_in_test_repo "${cmd}" >/dev/null 2>&1 || ec=$?
  if [[ "${ec}" -eq 0 ]]; then
    pass "non-push compound passes through: $(printf '%q' "${cmd}")"
  else
    fail "non-push compound spuriously gated: $(printf '%q' "${cmd}") (got exit ${ec})"
  fi
  teardown_test_repo
done

# ============================================================
echo ""
echo "==> Regression: tag-only detection is scoped to the push's own refspecs"
# ============================================================
#
# is_tag_only_push previously scanned EVERY token in the command, so a stray
# version-like token anywhere (a commit message, an echo, an unrelated file)
# made a real code push look tag-only and SKIPPED the gate entirely. Each of
# these is a genuine code push and MUST be gated (exit 2) despite the stray
# token or the --tags flag.
tagfp_cmds=(
  'git push origin main && echo "deployed v1.0"'
  'git commit -m v2-prep && git push origin main'
  'git push origin main; cat v1.txt'
  'git push --tags origin main'
  'git push origin main v1.0'
  'git push origin v1.0 && git push origin main'
  'git push origin HEAD'
)
for cmd in "${tagfp_cmds[@]}"; do
  setup_test_repo
  echo "modified" > "${TEST_REPO}/file.txt"
  ec=0
  invoke_in_test_repo "${cmd}" >/dev/null 2>&1 || ec=$?
  if [[ "${ec}" -eq 2 ]]; then
    pass "code push with stray tag-like token gated: $(printf '%q' "${cmd}")"
  else
    fail "code push wrongly skipped as tag-only: $(printf '%q' "${cmd}") (got exit ${ec})"
  fi
  teardown_test_repo
done

# ============================================================
echo ""
echo "==> Genuine tag-only pushes still skip the gate (no over-gating)"
# ============================================================
#
# The conservative rewrite must not over-gate the common tag-push forms.
# These carry no reviewable code, so they short-circuit to exit 0 even with
# an uncommitted diff and no marker present.
tagok_cmds=(
  'git push --tags'
  'git push --tags origin'
  'git push origin v2.0.0'
  'git push origin refs/tags/v2.0.0'
  'git push origin v1.0 v2.0'
)
for cmd in "${tagok_cmds[@]}"; do
  setup_test_repo
  echo "modified" > "${TEST_REPO}/file.txt"
  ec=0
  invoke_in_test_repo "${cmd}" >/dev/null 2>&1 || ec=$?
  if [[ "${ec}" -eq 0 ]]; then
    pass "genuine tag-only push skips gate: $(printf '%q' "${cmd}")"
  else
    fail "genuine tag-only push wrongly gated: $(printf '%q' "${cmd}") (got exit ${ec})"
  fi
  teardown_test_repo
done

# ============================================================
echo ""
echo "==> Regression: glued subshell (git push) is detected and gated"
# ============================================================
setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
ec=0
invoke_in_test_repo '(git push)' >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "(git push) subshell detected and blocked"
else
  fail "(git push) subshell NOT gated (bypass): got exit ${ec}"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a push cannot be vouched for after an earlier statement"
# ============================================================
#
# The hook sees the repo only as it stands when the command starts. zat-hermes's
# first push went out this way: nothing was tracked yet, so the diff read as
# "nothing to review", and the commit existed by the time the push ran. Every
# case here used to exit 0. They run on a tree with nothing to review (or a
# valid marker), where only the push-first rule can catch them.
same_command_cmds=(
  'git add -A && git commit -qm x && git push'
  $'git add -A\ngit commit -qm x\ngit push -u origin main'
  'git merge -q feature && git push'
  'git cherry-pick feature && git push'
  'git am patch && git push'
  'git rebase feature && git push'
  'sed -i s/a/b/ file.txt && git commit -qam x && git push'
  'cd ../other && git push'
  'git push origin main && git push origin v1.0'
  # The tag-only exit must not carry an earlier statement past the rule.
  'git commit -qam x && git tag v1.0 && git push origin v1.0'
)
for cmd in "${same_command_cmds[@]}"; do
  setup_test_repo
  ec=0
  out=$(invoke_in_test_repo "${cmd}" 2>&1) || ec=$?
  if [[ "${ec}" -eq 2 ]] && [[ "${out}" == *"run this push as its own command"* ]]; then
    pass "statement before push refused: $(printf '%q' "${cmd}")"
  else
    fail "statement before push not refused: $(printf '%q' "${cmd}") (exit ${ec})"
  fi
  teardown_test_repo
done

# The incident itself: an unborn branch with only untracked files.
UNBORN_REPO=$(mktemp -d)
git -C "${UNBORN_REPO}" init -q -b main
echo "x" > "${UNBORN_REPO}/README.md"
ec=0
payload=$(jq -n --arg c $'git add README.md && git commit -qm first\ngit push -u origin main' '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
(cd "${UNBORN_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "first commit and push in one command refused on an unborn branch"
else
  fail "first commit and push in one command: expected exit 2, got ${ec}"
fi
rm -rf "${UNBORN_REPO}"

# A valid marker does not help: the hash still matches and nothing is
# uncommitted when the command starts, but the file is new by the time it pushes.
setup_test_repo
echo "reviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "reviewed"
(cd "${TEST_REPO}" && codereview-marker write)
echo "new" > "${TEST_REPO}/untracked.txt"
ec=0
invoke_in_test_repo 'git add -A && git commit -qm x && git push' >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "valid marker does not cover a file committed in the same command"
else
  fail "valid marker with same-command commit: expected exit 2, got ${ec}"
fi
teardown_test_repo

# A refused command leaves the one-shot bypass in place for the separate retry.
setup_test_repo
touch "${TEST_SKIP_MARKER}"
ec=0
invoke_in_test_repo 'git add -A && git commit -qm x && git push' >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]] && [[ -f "${TEST_SKIP_MARKER}" ]]; then
  pass "refusal does not consume the skip marker"
else
  fail "refusal and skip marker: expected exit 2 with the marker kept, got ${ec}"
fi
teardown_test_repo

# A push that comes first is judged as before, whatever follows it.
for cmd in \
  'git push' \
  'git push -u origin main' \
  'git push 2>&1 | tail -3' \
  'git push; echo done' \
  'git push && git status' \
  '(git push)' \
  '{ git push; }' \
  $'\ngit push'; do
  setup_test_repo
  ec=0
  invoke_in_test_repo "${cmd}" >/dev/null 2>&1 || ec=$?
  if [[ "${ec}" -eq 0 ]]; then
    pass "push that comes first is allowed on a clean tree: $(printf '%q' "${cmd}")"
  else
    fail "push that comes first wrongly refused: $(printf '%q' "${cmd}") (exit ${ec})"
  fi
  teardown_test_repo
done

# Asserts the hook's exit code for a command run in the test repo, and when a
# message is given, that stderr contains it.
expect_in_repo() {
  local cmd="$1" expected="$2" label="$3" message="${4:-}" ec=0 out
  out=$(invoke_in_test_repo "${cmd}" 2>&1) || ec=$?
  if [[ "${ec}" -eq "${expected}" ]] && [[ "${out}" == *"${message}"* ]]; then
    pass "${label}"
  else
    fail "${label} (expected exit ${expected}, got ${ec}: ${out})"
  fi
}

# ============================================================
echo ""
echo "==> Regression: a prefix before git does not hide the push"
# ============================================================
# Only a shell operator counted as the start of a command, so a push behind any
# other word read as an argument to it, and the hook passed the command through.

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
for cmd in \
  'GIT_TERMINAL_PROMPT=0 git push' \
  'A=1 B=2 git push origin main' \
  'if git push; then echo ok; fi' \
  'until git push; do sleep 1; done' \
  'time git push' \
  'env git push' \
  'env -i FOO=1 git push' \
  'command git push' \
  'builtin git push' \
  'exec git push' \
  'nohup git push' \
  'sudo git push' \
  'xargs git push' \
  'nice -n 10 git push' \
  'ionice -c2 git push' \
  'setsid git push' \
  'stdbuf -o0 git push' \
  'timeout 60 git push' \
  'timeout 5m git push' \
  '/usr/bin/git push' \
  'env /usr/bin/git -C . push' \
  '! git push' \
  $'if git push\nthen echo ok\nfi'; do
  expect_in_repo "${cmd}" 2 "prefixed push goes to review: $(printf '%q' "${cmd}")" "has not passed /codereview"
done
# With a statement in front, they are refused like any other push.
for cmd in \
  'for r in a; do git push; done' \
  'if true; then git push; fi' \
  'cd .. && env git push' \
  'echo hi; GIT_TRACE=1 git push'; do
  expect_in_repo "${cmd}" 2 "prefixed push after a statement refused: $(printf '%q' "${cmd}")" "run this push as its own command"
done
# Other words still mean the token is an argument, not a command.
for cmd in \
  'echo 5 git push' \
  'echo -n git push' \
  'echo env git push' \
  'echo then git push' \
  'grep -r git push' \
  'ls /usr/bin/git push' \
  'FOO=git push' \
  'env FOO=1 ls' \
  'time make' \
  'if true; then echo git push; fi' \
  'sudo -u bob ls' \
  'timeout 60 make'; do
  expect_in_repo "${cmd}" 0 "not a push, passes through: $(printf '%q' "${cmd}")"
done
# A quoted or escaped value that the tokenizer splits does not hide the push.
for cmd in \
  'A="x>y" git push' \
  'git -c "a.b=c>d" push' \
  'A=x\>y git push' \
  'A="x;y" git push' \
  'TOKEN="$(echo x)" git push' \
  'GIT_SSH_COMMAND="ssh -i key" git push'; do
  expect_in_repo "${cmd}" 2 "push behind a split value detected: ${cmd}"
done
for cmd in \
  'echo "a git push b"' \
  'echo "x" "a git push"'; do
  expect_in_repo "${cmd}" 0 "quoted push text passes through: ${cmd}"
done
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: git -C judges the repo it targets, not the current one"
# ============================================================
# `git -C other push` from a clean checkout read as nothing to review.

OTHER_REPO=$(mktemp -d)
git -C "${OTHER_REPO}" init -q -b main
git -C "${OTHER_REPO}" config user.email test@test.invalid
git -C "${OTHER_REPO}" config user.name "test"
echo "first" > "${OTHER_REPO}/file.txt"
git -C "${OTHER_REPO}" add file.txt
git -C "${OTHER_REPO}" commit -q -m "initial"
git -C "${OTHER_REPO}" update-ref refs/remotes/origin/main HEAD
echo "unreviewed" > "${OTHER_REPO}/file.txt"
git -C "${OTHER_REPO}" commit -q -am "unreviewed"
OTHER_MARKER=$(cd "${OTHER_REPO}" && codereview-marker path)
rm -f "${OTHER_MARKER}"

setup_test_repo
expect_in_repo "git -C ${OTHER_REPO} push" 2 "git -C: unreviewed other repo is blocked" "This push targets"
expect_in_repo "git -C \"${OTHER_REPO}\" push" 2 "git -C: quoted path is followed" "This push targets"
# Git applies a relative -C against the directory before it.
expect_in_repo "git -C $(dirname "${OTHER_REPO}") -C $(basename "${OTHER_REPO}") push" 2 "git -C: stacked paths are followed in order" "This push targets"
(cd "${OTHER_REPO}" && codereview-marker write)
expect_in_repo "git -C ${OTHER_REPO} push" 0 "git -C: the other repo's own marker allows it"
rm -f "${OTHER_MARKER}"
git -C "${OTHER_REPO}" update-ref refs/remotes/origin/main HEAD
expect_in_repo "git -C ${OTHER_REPO} push" 0 "git -C: other repo with nothing to review is allowed"
# Same repo: no note about another repo.
echo "modified" > "${TEST_REPO}/file.txt"
ec=0
out=$(invoke_in_test_repo "git -C ${TEST_REPO} push" 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]] && [[ "${out}" != *"This push targets"* ]]; then
  pass "git -C: pointing at the current repo reads as the current repo"
else
  fail "git -C: current repo expected exit 2 with no note (exit ${ec})"
fi
teardown_test_repo
rm -rf "${OTHER_REPO}"
rm -f "${OTHER_MARKER}"

# ============================================================
echo ""
echo "==> Regression: a named ref with commits outside HEAD is refused"
# ============================================================
# The hash describes HEAD and the working tree, so `git push origin feature`
# from a clean main read as nothing to review.

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
for cmd in \
  'git push origin feature' \
  'git push origin "feature"' \
  'git push origin +feature' \
  'git push origin feature:main' \
  'git push origin refs/heads/feature' \
  'git push origin main feature' \
  'git push origin refs/heads/*:refs/heads/*' \
  'git push --all' \
  'git push --branches origin' \
  'git push --mirror'; do
  expect_in_repo "${cmd}" 2 "other ref refused: ${cmd}" "the review cannot cover"
done
for cmd in \
  'git push origin main' \
  'git push origin HEAD' \
  'git push origin HEAD:refs/heads/copy' \
  'git push origin no-such-branch' \
  'git push origin --delete feature' \
  'git push origin :feature' \
  'git push -u origin "$(git rev-parse --abbrev-ref HEAD)"' \
  'git push origin main > /tmp/push.log 2>&1'; do
  expect_in_repo "${cmd}" 0 "sends nothing outside HEAD, allowed: ${cmd}"
done
# "Push now" stays a bypass for this check as well.
touch "${TEST_SKIP_MARKER}"
expect_in_repo 'git push origin feature' 0 "other ref: the skip marker still applies"
# Once a remote has the commits, there is nothing left to review.
git -C "${TEST_REPO}" update-ref refs/remotes/origin/feature feature
expect_in_repo 'git push origin feature' 0 "other ref: already on a remote-tracking ref, allowed"
expect_in_repo 'git push --all' 0 "other ref: --all with everything on a remote, allowed"
teardown_test_repo

# Fully merged into HEAD: the review of HEAD covers it.
setup_test_repo
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
git -C "${TEST_REPO}" merge -q --ff-only feature
expect_in_repo 'git push origin feature' 2 "other ref in HEAD: goes to review instead" "has not passed /codereview"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: version-like branches and tags on unpushed commits are reviewed"
# ============================================================
# Any name starting v<digit> read as a tag, and a tag push counted as carrying
# no code, though it sends the commits the tag points at.

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b v2-fix
echo "fix" > "${TEST_REPO}/fix.txt"
git -C "${TEST_REPO}" add fix.txt
git -C "${TEST_REPO}" commit -q -m "fix"
expect_in_repo 'git push origin v2-fix' 2 "version-like branch, checked out: goes to review" "has not passed /codereview"
git -C "${TEST_REPO}" checkout -q main
expect_in_repo 'git push origin v2-fix' 2 "version-like branch, elsewhere: refused" "the review cannot cover"
expect_in_repo 'git push origin v2-fix:main' 2 "version-like source with another destination: refused" "the review cannot cover"
teardown_test_repo

setup_test_repo
git -C "${TEST_REPO}" tag v1.0
expect_in_repo 'git push origin v1.0' 0 "tag on a pushed commit: still skips the gate"
expect_in_repo 'git push origin refs/tags/v1.0' 0 "tag by full ref on a pushed commit: still skips the gate"
expect_in_repo 'git push --tags' 0 "--tags with every tag on a pushed commit: still skips the gate"
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
git -C "${TEST_REPO}" tag v1.1
expect_in_repo 'git push origin v1.1' 2 "tag on an unpushed HEAD: goes to review" "has not passed /codereview"
expect_in_repo 'git push origin refs/tags/v1.1' 2 "tag by full ref on an unpushed HEAD: goes to review" "has not passed /codereview"
expect_in_repo 'git push --tags' 2 "--tags with a tag on an unpushed HEAD: goes to review" "has not passed /codereview"
(cd "${TEST_REPO}" && codereview-marker write)
expect_in_repo 'git push origin v1.1' 0 "tag on an unpushed HEAD with a valid marker: allowed"
teardown_test_repo

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b elsewhere
echo "elsewhere" > "${TEST_REPO}/elsewhere.txt"
git -C "${TEST_REPO}" add elsewhere.txt
git -C "${TEST_REPO}" commit -q -m "elsewhere"
git -C "${TEST_REPO}" tag v3.0
git -C "${TEST_REPO}" checkout -q main
expect_in_repo 'git push origin v3.0' 2 "tag on another branch's unpushed commit: refused" "the review cannot cover"
expect_in_repo 'git push --tags' 2 "--tags with a tag on another branch's unpushed commit: refused" "the review cannot cover"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a repo with no working tree is refused, not read as no repo"
# ============================================================
# Following -C landed where --show-toplevel fails, which read as "not a repo",
# though git pushes from there.

setup_test_repo
BARE_REPO=$(mktemp -d)
git -C "${BARE_REPO}" init -q --bare
expect_in_repo 'git -C .git push' 2 "git -C .git refused" "no working tree"
expect_in_repo 'git -C .git/hooks push' 2 "git -C .git/hooks refused" "no working tree"
expect_in_repo "git -C ${BARE_REPO} push" 2 "bare repo through -C refused" "no working tree"
expect_in_repo "git -C ${SCRATCH_NOGIT} push" 0 "git -C to a directory that is no repo: still passes through"
git -C "${TEST_REPO}" config core.bare true
expect_in_repo 'git -C .git push' 2 "core.bare=true refused" "no working tree"
teardown_test_repo
rm -rf "${BARE_REPO}"

# ============================================================
echo ""
echo "==> Regression: a prefix cannot redirect git to another repo"
# ============================================================
# enter_push_target read only the tokens after git, so these were judged against
# the current repo, which reads as nothing to review from a clean checkout.

setup_test_repo
for cmd in \
  'GIT_DIR=/tmp/other/.git git push' \
  'env GIT_DIR=/tmp/other/.git git push' \
  'GIT_WORK_TREE=/tmp/other git push' \
  'GIT_COMMON_DIR=/tmp/other/.git git push' \
  'env --chdir=/tmp/other git push' \
  'sudo -D5 git push'; do
  expect_in_repo "${cmd}" 2 "redirecting prefix refused: ${cmd}" "cannot tell which repo"
done
expect_in_repo 'GIT_TRACE=1 git push' 0 "other assignment prefix on a clean tree: allowed"

# git resolves -C through the symlink; a logical cd would judge a different repo.
LINK_PARENT=$(mktemp -d)
LINK_REAL=$(mktemp -d)
mkdir "${LINK_REAL}/inner"
ln -s "${LINK_REAL}/inner" "${LINK_PARENT}/link"
git -C "${LINK_REAL}" init -q -b main
git -C "${LINK_REAL}" config user.email test@test.invalid
git -C "${LINK_REAL}" config user.name "test"
echo "x" > "${LINK_REAL}/f.txt"
git -C "${LINK_REAL}" add f.txt
git -C "${LINK_REAL}" commit -q -m "unreviewed"
LINK_MARKER=$(cd "${LINK_REAL}" && codereview-marker path)
rm -f "${LINK_MARKER}"
expect_in_repo "git -C ${LINK_PARENT}/link/.. push" 2 "git -C link/..: judges the physical parent" "has not passed /codereview"
# CDPATH must not send a relative -C somewhere else: that directory is no repo,
# so the push would pass through instead of being judged here.
mkdir -p "${LINK_PARENT}/cdpath/sub"
mkdir "${TEST_REPO}/sub"
echo "modified" > "${TEST_REPO}/file.txt"
ec=0
CDPATH="${LINK_PARENT}/cdpath" invoke_in_test_repo 'git -C sub push' >/dev/null 2>&1 || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "git -C: CDPATH does not redirect a relative path"
else
  fail "git -C: CDPATH redirected a relative path (exit ${ec})"
fi
rm -rf "${LINK_PARENT}" "${LINK_REAL}"
rm -f "${LINK_MARKER}"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: the tag-only exit does not pass a push that sends commits"
# ============================================================

setup_test_repo
git -C "${TEST_REPO}" tag v1.0
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
git -C "${TEST_REPO}" tag v2.0
expect_in_repo 'git push origin v1.0 --tags' 2 "--tags beside a pushed tag: judged on every tag" "has not passed /codereview"
expect_in_repo 'git push --tags origin v1.0' 2 "--tags first, beside a pushed tag: judged on every tag" "has not passed /codereview"
expect_in_repo 'git push origin refs/tags/*' 2 "tag wildcard refused" "the review cannot cover"
expect_in_repo 'git push origin v1*' 2 "version wildcard refused" "the review cannot cover"
teardown_test_repo

setup_test_repo
TREE_SHA=$(git -C "${TEST_REPO}" rev-parse 'HEAD^{tree}')
git -C "${TEST_REPO}" tag v5.0 "${TREE_SHA}"
expect_in_repo 'git push origin v5.0' 2 "tag on a tree refused" "the review cannot cover"
expect_in_repo 'git push origin refs/tags/v5.0' 2 "tag on a tree by full ref refused" "the review cannot cover"
expect_in_repo 'git push --tags' 2 "--tags with a tag on a tree refused" "the review cannot cover"
teardown_test_repo

setup_test_repo
BLOB_SHA=$(git -C "${TEST_REPO}" rev-parse HEAD:file.txt)
git -C "${TEST_REPO}" tag -a -m x v6.0 "${BLOB_SHA}"
expect_in_repo 'git push --tags' 2 "--tags with an annotated tag on a blob refused" "the review cannot cover"
expect_in_repo 'git push origin v6.0' 2 "annotated tag on a blob refused" "the review cannot cover"
teardown_test_repo

# Annotated tags on commits still pass.
setup_test_repo
git -C "${TEST_REPO}" tag -a -m x v7.0
expect_in_repo 'git push --tags' 0 "--tags with an annotated tag on a pushed commit: skips the gate"
expect_in_repo 'git push origin v7.0' 0 "annotated tag on a pushed commit: skips the gate"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a word the shell expands cannot name an unseen ref"
# ============================================================
# An unresolved name was skipped "because git fails on it too", which is false
# for a word the shell expands first.

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
for cmd in \
  'git push origin $B' \
  'git push origin "$B"' \
  'git push origin $(echo feature)' \
  'git push origin "$(echo feature)"' \
  'git push origin `echo feature`' \
  'git push origin fea\ture' \
  'git push origin fea"tu"re' \
  'git push origin :' \
  'git push origin +:'; do
  expect_in_repo "${cmd}" 2 "expansion or matching refspec refused: ${cmd}" "the review cannot cover"
done
expect_in_repo 'B=feature; git push origin $B' 2 "assignment before the push, expanded in it: refused" "the review cannot cover"
for cmd in \
  'git push -u origin "$(git rev-parse --abbrev-ref HEAD)"' \
  'git push origin main > "$LOG"' \
  'git push origin main>"$LOG" 2>&1' \
  'git push origin "main"' \
  "git push origin 'main'" \
  "git push origin main # don't" \
  'git push origin :feature'; do
  expect_in_repo "${cmd}" 0 "literal refs stay allowed: ${cmd}"
done
# /pr's spelling reads as HEAD, so it does not cover a ref named after it.
expect_in_repo 'git push -u origin "$(git rev-parse --abbrev-ref HEAD)" feature' 2 "/pr's spelling beside another ref refused" "the review cannot cover"
teardown_test_repo

# A matching refspec with every branch on a remote sends nothing outside HEAD.
setup_test_repo
expect_in_repo 'git push origin :' 0 "matching refspec with nothing outside HEAD: allowed"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: continuations, ) and redirections do not hide a push"
# ============================================================

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
for cmd in \
  $'git \\\n push' \
  $'git -C . \\\n push' \
  'git push>/dev/null' \
  'git push</dev/null' \
  'git push 2>/dev/null'; do
  expect_in_repo "${cmd}" 2 "hidden push goes to review: $(printf '%q' "${cmd}")" "has not passed /codereview"
done
for cmd in \
  'TOKEN=$(gh auth token) git push' \
  'FOO=$(git commit --allow-empty -qm x) git push' \
  'case x in x) git push ;; esac'; do
  expect_in_repo "${cmd}" 2 "push after ) refused: ${cmd}" "run this push as its own command"
done
# A continuation ends with a comment, so the next line is its own command.
expect_in_repo $'# note \\\ngit push' 2 "backslash at the end of a comment does not join the push to it" "has not passed /codereview"
teardown_test_repo

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
expect_in_repo $'git push origin \\\n feature' 2 "continuation does not hide the ref" "the review cannot cover"
expect_in_repo $'echo a \\\n git push' 0 "continuation that makes git an argument: not a push"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a -C value that is a substitution is detected and refused"
# ============================================================

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
for cmd in \
  'git -C $(pwd) push' \
  'git -C "$(git rev-parse --show-toplevel)" push' \
  'git -C `git rev-parse --show-toplevel` push' \
  'git -C "`git rev-parse --show-toplevel`" push' \
  'git -C $(pwd)/sub push' \
  'git -C "$(dirname "$(pwd)")" push' \
  'git -C $(pwd) -C sub push'; do
  expect_in_repo "${cmd}" 2 "substitution in -C refused: ${cmd}" "cannot tell which repo"
done
# A substitution in another option's value does not hide the push either.
expect_in_repo 'git -c user.name=$(whoami) push' 2 "substitution in -c: goes to review" "has not passed /codereview"
# Not a push, whatever the value is.
expect_in_repo 'git -C $(pwd) status' 0 "substitution in -C on another subcommand passes through"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a comment line does not count as an earlier statement"
# ============================================================

setup_test_repo
expect_in_repo $'# plain comment\ngit push' 0 "comment before a push: allowed on a clean tree"
expect_in_repo $'#!/bin/bash\n# second\n\ngit push' 0 "several comment lines before a push: allowed on a clean tree"
expect_in_repo $'# Push branch to remote (set upstream if needed)\ngit push -u origin "$(git rev-parse --abbrev-ref HEAD)"\n\n# Create the PR\ngh pr create --title "<title>" --body "<body>"' 0 "/pr's block as written: allowed on a clean tree"
expect_in_repo $'# c\ngit commit -qm x\ngit push' 2 "statement after a comment still refused" "run this push as its own command"
expect_in_repo $'# a; b\ngit push' 2 "semicolon in a comment over-refuses" "run this push as its own command"
teardown_test_repo
setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
expect_in_repo $'# plain comment\ngit push' 2 "comment before a push: still gated" "has not passed /codereview"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: a # inside a quoted value is not a comment"
# ============================================================
# Reading it as one hid the statement before the push, and the ref after it.

setup_test_repo
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
expect_in_repo 'TITLE="fix #12" make release && git push' 2 "# in a quoted value does not hide the statement before the push" "run this push as its own command"
expect_in_repo 'git push -o "ci.title=fix #12" origin feature' 2 "# in a quoted value does not hide the ref" "the review cannot cover"
expect_in_repo 'git push --push-option="ci.title=fix #12" origin feature' 2 "# in a quoted option value does not hide the ref" "the review cannot cover"
git -C "${TEST_REPO}" tag v1.0
# An operator or -d inside a quoted value ended the argument walk before the ref.
for cmd in \
  'git push -o "merge_request.title=Fix login (SSO)" origin feature' \
  'git push -o "a;b" origin feature' \
  'git push --push-option="Fix A & B" origin feature' \
  'git push -o "x -d y" origin feature' \
  'git push origin v1.0 --push-option="a;b" feature'; do
  expect_in_repo "${cmd}" 2 "split quoted value refused: ${cmd}" "the review cannot cover"
done
expect_in_repo "git push origin main # don't" 0 "real comment after a push: allowed on a clean tree"
expect_in_repo 'git push origin main # feature' 0 "real comment naming a ref: allowed on a clean tree"
expect_in_repo 'git push origin main # do not -d' 0 "real comment with -d after a push: allowed on a clean tree"
expect_in_repo 'git push -o ci.skip origin main' 0 "push option without a space: allowed on a clean tree"
expect_in_repo $'# Push branch to remote (set upstream if needed)\ngit push -u origin "$(git rev-parse --abbrev-ref HEAD)"\n\n# Create the PR\ngh pr create --title "<title>" --body "<body>"' 0 "/pr's block with an unpushed branch elsewhere: allowed on a clean tree"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: only an odd run of backslashes continues a line"
# ============================================================
# An even run ends the statement at the newline, and a comment needs no space
# before its #, so these pushes are real statements of their own.

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
for cmd in \
  $'echo a\\\\\ngit push' \
  $'echo \\\\\ngit push' \
  $'true;# x \\\ngit push'; do
  expect_in_repo "${cmd}" 2 "push on the next line refused: $(printf '%q' "${cmd}")" "run this push as its own command"
done
expect_in_repo $'git \\\n push' 2 "single backslash still joins the push" "has not passed /codereview"
expect_in_repo $'git \\\\\\\n push' 0 "odd run of three still joins, so git's argument is a backslash: not a push"
expect_in_repo $'echo a\\\\\\\ngit push' 0 "odd run of three makes git an argument: not a push"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: brace expansion and globs cannot name an unseen ref"
# ============================================================

setup_test_repo
git -C "${TEST_REPO}" tag v1.0
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" tag v2.0
git -C "${TEST_REPO}" checkout -q main
for cmd in \
  'git push origin {main,feature}' \
  'git push origin fea{t..t}ure' \
  'git push origin refs/tags/{v1.0,v2.0}' \
  'git push origin v{1,2}.0' \
  'git push origin featur?' \
  'git push origin v?.0' \
  'git push origin f[e]ature' \
  'git push origin v[12].0'; do
  expect_in_repo "${cmd}" 2 "shell-expanded ref refused: ${cmd}" "the review cannot cover"
done
expect_in_repo 'git push origin HEAD@{0}:refs/heads/copy' 0 "reflog syntax is not brace expansion: allowed on a clean tree"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: mixed quotes, redirections, and a -C inside a value"
# ============================================================
# Counting each quote kind separately misread "O'Brien -x" as an open quote,
# padding < and > split A=x>y into words that are not prefixes, and the -C walk
# followed a -C that only appeared inside a quoted or substituted -c value.

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
for cmd in \
  'A=x>y git push' \
  'git -c a.b=c>d push' \
  'git -C .>log push' \
  'git 2>/dev/null push' \
  'git &>log push' \
  "git -c \"user.name=O'Brien -x\" push" \
  "git -c \"x.y=it's -c z.w=1\" push" \
  "A=\"x -y'z -w\" git push" \
  "git -c x.y=\$'it\\'s' push" \
  'git -c a.b=c\ d push'; do
  expect_in_repo "${cmd}" 2 "push behind a mixed quote or redirection detected: ${cmd}"
done
SCRATCH_PLAIN=$(mktemp -d)
for cmd in \
  "git -c \"x.y=a -C ${SCRATCH_PLAIN}\" push" \
  "git -c x.y=\$(echo -C ${SCRATCH_PLAIN}) push" \
  "git -c x.y=\`echo -C ${SCRATCH_PLAIN}\` push"; do
  expect_in_repo "${cmd}" 2 "-C inside a -c value is not followed: ${cmd}" "has not passed /codereview"
done
expect_in_repo 'git -C "a b" push' 2 "-C value with a space refused" "cannot tell which repo"
rmdir "${SCRATCH_PLAIN}"
for cmd in \
  "git commit -m \"don't git push yet\"" \
  "echo \"it's\" git push" \
  'echo x>y git push'; do
  expect_in_repo "${cmd}" 0 "not a push, passes through: ${cmd}"
done
teardown_test_repo

setup_test_repo
git -C "${TEST_REPO}" tag v1.0
git -C "${TEST_REPO}" checkout -q -b feature
echo "feature" > "${TEST_REPO}/feature.txt"
git -C "${TEST_REPO}" add feature.txt
git -C "${TEST_REPO}" commit -q -m "feature"
git -C "${TEST_REPO}" checkout -q main
expect_in_repo 'git push origin main > "log #1" feature' 2 "split redirection target does not hide the ref" "the review cannot cover"
expect_in_repo "git push origin v1.0 --push-option='\"'\"a;b\" feature" 2 "mixed-quote option value does not make a branch push tag-only" "the review cannot cover"
expect_in_repo 'git push origin main > log' 0 "plain redirection after a push: allowed on a clean tree"
expect_in_repo 'git push origin &>/dev/null feature:main' 2 "&> does not end the arguments before a ref" "the review cannot cover"
expect_in_repo 'git push -o -d origin feature:main' 2 "-d as the value of -o is not a delete" "the review cannot cover"
expect_in_repo 'git push -fo -d origin feature:main' 2 "-d as the value of a clustered -fo is not a delete" "the review cannot cover"
expect_in_repo 'git push origin feature:main & >/dev/null git branch -d old' 2 "-d after & > belongs to the next statement" "the review cannot cover"
expect_in_repo 'git push origin -d feature' 0 "a plain -d is still a delete"
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: escaped dollars, escaped operators, heredoc backslashes, &>"
# ============================================================
# The scanner opened \$'...' quoting after an escaped \$ or a $$ pair, which
# bash reads as a plain single quote, and stepped over the rest of the command.

setup_test_repo
git -C "${TEST_REPO}" tag v1.0
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
for cmd in \
  "git -c x.y=\\\$'a\\' push" \
  "git -c x.y=\$\$'a\\' push" \
  "git -c 'x.y=a' -c x.z=\\\$'b\\' push" \
  "git --no-pager -c x.y=\\\$'a\\' push origin main" \
  "git --namespace=\\\$'x\\' push" \
  "git -c x.y=\$\$\$'it\\'s' push" \
  'git push origin v1.0 &>/dev/null main'; do
  expect_in_repo "${cmd}" 2 "push detected and gated: ${cmd}" "has not passed /codereview"
done
expect_in_repo "gh repo create x --description \\\$'a\\' --push" 2 "gh --push after an escaped dollar refused" "Create the repo without --push"
for cmd in \
  'A=x\;#y git commit --allow-empty -qm z && git push' \
  'A="x\"; #y" git commit --allow-empty -qm z && git push' \
  $'cat <<\'X\\\'\nX\\\ngit push' \
  $'cat <<X\'\\\'\nX\\\ngit push' \
  $'cat <<\\X\\\\\nX\\\ngit push' \
  $'cat <<\'A\' <<\'X\\\'\nA\nX\\\ngit push' \
  $'cat <<-\'X\\\'\n\tX\\\ngit push' \
  $'echo "<<\'X\'"\ngit \\\npush' \
  $'git commit -qm "use <<\'EOF\' here"\ngit \\\npush' \
  $'read -r x <<<\'y\'\ngit \\\npush origin feature'; do
  expect_in_repo "${cmd}" 2 "statement before the push refused: $(printf '%q' "${cmd}")" "run this push as its own command"
done
expect_in_repo $'# see <<\'EOF\'\ngit -C . \\\npush origin main' 2 "heredoc-like text in a comment does not stop the join" "has not passed /codereview"
# A word over the long-word limit used to stop the fallback reading for the
# rest of the command.
LONGQ='"'$(printf 'a%.0s' {1..2000})'"'
for cmd in \
  "cat > f <<'EOF'"$'\n'"${LONGQ}"$'\nEOF\n>/dev/null git push origin main' \
  "cat > f <<'EOF'"$'\n'"${LONGQ}"$'\nEOF\nA="x it\'s y" git push'; do
  expect_in_repo "${cmd}" 2 "push after a ${#LONGQ}-byte quoted word refused" "run this push as its own command"
done
# A long word used to hold the quadratic scanner past the 30 s hook timeout.
JSON='['
for (( i = 0; i < 2200; i++ )); do JSON+="{\"id\":${i},\"name\":\"it's-item-${i}\"},"; done
JSON+='{}]'
LONG_START=${SECONDS}
expect_in_repo "git push origin main && echo uses git && cat > data.json <<'EOF'"$'\n'"${JSON}"$'\n'"EOF" 2 "push with a ${#JSON}-byte heredoc word is gated" "has not passed /codereview"
if (( SECONDS - LONG_START < 10 )); then
  pass "push with a ${#JSON}-byte heredoc word finishes well inside the timeout"
else
  fail "push with a ${#JSON}-byte heredoc word took $((SECONDS - LONG_START)) s"
fi
# A quoted heredoc terminator that ends in a backslash kept it in the join, and
# the next line read as part of the delimiter's word.
expect_in_repo $'cat <<\'X\\\' >/dev/null\nX\\\nA="x it\'s y" git push origin main' 2 "push after a backslash-ending heredoc terminator refused" "run this push as its own command"
# A long quoted delimiter word and many unclosed quoted heredocs used to hold
# the continuation join past the 30 s hook timeout.
LONGD="'$(printf 'a%.0s' {1..65536})'"
LONG_START=${SECONDS}
expect_in_repo "git push origin main && echo a \\"$'\n'"b"$'\n'"x <<${LONGD}" 2 "push before a ${#LONGD}-byte quoted heredoc delimiter refused" "has not passed /codereview"
if (( SECONDS - LONG_START < 10 )); then
  pass "push before a ${#LONGD}-byte quoted heredoc delimiter finishes well inside the timeout"
else
  fail "push before a ${#LONGD}-byte quoted heredoc delimiter took $((SECONDS - LONG_START)) s"
fi
MANYHD="git push origin main && echo a \\"$'\n'"b"
for (( i = 0; i < 1200; i++ )); do MANYHD+=$'\n'"x <<'never-closed-${i}'"; done
LONG_START=${SECONDS}
expect_in_repo "${MANYHD}" 2 "push before ${#MANYHD} bytes of unclosed quoted heredocs refused" "has not passed /codereview"
if (( SECONDS - LONG_START < 10 )); then
  pass "push before 1,200 unclosed quoted heredocs finishes well inside the timeout"
else
  fail "push before 1,200 unclosed quoted heredocs took $((SECONDS - LONG_START)) s"
fi
teardown_test_repo

# ============================================================
echo ""
echo "==> Regression: gh repo create --push pushes with no git token to detect"
# ============================================================

setup_test_repo
echo "unreviewed" > "${TEST_REPO}/file.txt"
git -C "${TEST_REPO}" commit -q -am "unreviewed"
expect_in_repo 'gh repo create me/x --private --source . --push' 2 "gh repo create --push refused" "Create the repo without --push"
expect_in_repo 'echo hi; gh repo create me/x --source . --push' 2 "gh repo create --push refused after a statement" "Create the repo without --push"
expect_in_repo 'gh repo create me/x --description "a; b" --source . --push' 2 "gh repo create --push refused past a quoted operator" "Create the repo without --push"
expect_in_repo 'gh repo create me/x --description "use --push later" --source .' 0 "--push inside a quoted value passes through"
expect_in_repo 'gh repo create me/x --private --source . --remote origin' 0 "gh repo create without --push passes through"
expect_in_repo 'echo gh repo create me/x --push' 0 "gh in an echo passes through"
expect_in_repo 'gh repo view; echo --push' 0 "another gh command passes through"
teardown_test_repo

# ============================================================
echo ""
echo "==> Fail-closed: codereview-marker missing from PATH blocks the push"
# ============================================================
#
# Earlier versions of the hook treated any non-zero exit from
# `codereview-marker hash` as "allow push", which silently bypassed the
# gate whenever the script was missing from PATH (e.g. shell init order
# or a fresh checkout without zat.env-install.sh having run). The hook
# must now fail closed on unexpected error.

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"
# Strip codereview-marker from PATH for this single invocation. The hook
# must still find git (the in-a-repo check) and jq (reading the payload), so
# keep only their directories and the system bin dirs. On Linux both live in
# /usr/bin; on Windows they are native programs in Git's and WinGet's own
# directories, which /usr/bin:/bin alone would drop.
ec=0
PATH_SANITIZED="$(dirname "$(command -v git)"):$(dirname "$(command -v jq)"):/usr/bin:/bin"
payload=$(jq -n --arg c "git push" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
stderr_out=$(cd "${TEST_REPO}" && export PATH="${PATH_SANITIZED}" && printf '%s' "${payload}" | bash "${HOOK}" 2>&1 >/dev/null) || ec=$?
if [[ "${ec}" -eq 2 ]] && printf '%s' "${stderr_out}" | grep -q "codereview-marker is unavailable"; then
  pass "missing codereview-marker: hook exits 2 (fail closed)"
else
  fail "missing codereview-marker: expected exit 2 with 'codereview-marker is unavailable' stderr, got ec=${ec} stderr=${stderr_out}"
fi
teardown_test_repo

# Pushes from outside any git repo still pass through (not our concern).
ec=0
payload=$(jq -n --arg c "git push" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
(cd "${SCRATCH_NOGIT}" && export PATH="${PATH_SANITIZED}" && printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "outside any repo + missing codereview-marker: still exit 0"
else
  fail "outside any repo: expected exit 0, got ${ec}"
fi

# ============================================================
echo ""
echo "==> Windows: CRLF from jq, the PowerShell tool, and jq failing"
# ============================================================
#
# The native Windows jq writes CRLF, and Git Bash strips only the final CR
# from a command substitution, so a push on any line but the last read as
# "push\r" and passed the gate. A shim that ends each line of the real jq's
# output with CR reproduces that on every platform.

JQ_SHIM_DIR=$(mktemp -d)
REAL_JQ=$(command -v jq)
mkdir -p "${JQ_SHIM_DIR}/crlf" "${JQ_SHIM_DIR}/broken"
cat > "${JQ_SHIM_DIR}/crlf/jq" <<'EOF'
#!/usr/bin/env bash
set -o pipefail
"${REAL_JQ}" "$@" | awk '{ printf "%s\r\n", $0 }'
EOF
cat > "${JQ_SHIM_DIR}/broken/jq" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
chmod +x "${JQ_SHIM_DIR}/crlf/jq" "${JQ_SHIM_DIR}/broken/jq"

setup_test_repo
echo "modified" > "${TEST_REPO}/file.txt"

ec=0
payload=$(jq -n --arg c $'git push\necho done' '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
stderr_out=$(cd "${TEST_REPO}" && printf '%s' "${payload}" | PATH="${JQ_SHIM_DIR}/crlf:${PATH}" REAL_JQ="${REAL_JQ}" bash "${HOOK}" 2>&1 >/dev/null) || ec=$?
if [[ "${ec}" -eq 2 ]] && printf '%s' "${stderr_out}" | grep -q "has not passed /codereview"; then
  pass "CRLF jq output: a push on a non-final line is still gated"
else
  fail "CRLF jq output: expected exit 2 (gated), got ec=${ec} stderr=${stderr_out}"
fi

# The install registers the hook for the PowerShell tool too; the payload
# differs only in tool_name, which the hook does not consult.
ec=0
payload=$(jq -n --arg c "git push" '{tool_name:"PowerShell", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
(cd "${TEST_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "PowerShell tool payload: git push is gated"
else
  fail "PowerShell tool payload: expected exit 2, got ${ec}"
fi

# The Bash entry also matches the Monitor tool, whose input carries the same
# command field; a WebSocket monitor has no command and reads as not a push.
ec=0
payload=$(jq -n --arg c "git push" '{tool_name:"Monitor", tool_input:{command:$c, description:"d", timeout_ms:1000}, hook_event_name:"PreToolUse"}')
(cd "${TEST_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 2 ]]; then
  pass "Monitor tool payload: git push is gated"
else
  fail "Monitor tool payload: expected exit 2, got ${ec}"
fi
ec=0
payload=$(jq -n '{tool_name:"Monitor", tool_input:{ws:{url:"wss://example.invalid/"}, description:"d", timeout_ms:1000}, hook_event_name:"PreToolUse"}')
(cd "${TEST_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "Monitor WebSocket payload: no command, allowed"
else
  fail "Monitor WebSocket payload: expected exit 0, got ${ec}"
fi

# jq failing used to leave the command empty, which read as "not a push".
ec=0
payload=$(jq -n --arg c "git push" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
stderr_out=$(cd "${TEST_REPO}" && printf '%s' "${payload}" | PATH="${JQ_SHIM_DIR}/broken:${PATH}" bash "${HOOK}" 2>&1 >/dev/null) || ec=$?
if [[ "${ec}" -eq 2 ]] && printf '%s' "${stderr_out}" | grep -q "cannot read the command"; then
  pass "jq unavailable: hook exits 2 (fail closed)"
else
  fail "jq unavailable: expected exit 2 with 'cannot read the command' stderr, got ec=${ec} stderr=${stderr_out}"
fi

# The hook runs on every shell command, so a broken jq must not stop the ones
# needed to fix it. Only a payload that mentions a push is refused.
ec=0
payload=$(jq -n --arg c "ls -la" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
(cd "${TEST_REPO}" && printf '%s' "${payload}" | PATH="${JQ_SHIM_DIR}/broken:${PATH}" bash "${HOOK}" >/dev/null 2>&1) || ec=$?
if [[ "${ec}" -eq 0 ]]; then
  pass "jq unavailable: a command that never mentions a push still runs"
else
  fail "jq unavailable: non-push command expected exit 0, got ${ec}"
fi

teardown_test_repo
rm -rf "${JQ_SHIM_DIR}"

# ============================================================
echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
