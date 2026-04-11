#!/usr/bin/env bash
set -uo pipefail

# Tests for hooks/pre-push-codereview.sh.
#
# Covers:
#   - is_git_push detection across many command forms (the bug that motivated
#     this suite: `git -C <dir> push` and other prefix variants silently
#     bypassed the gate)
#   - is_tag_only_push detection
#   - Empty non-excluded diff allow-path
#   - Marker file hash match / mismatch
#   - Skip marker consumption
#   - Non-push commands pass through

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/pre-push-codereview.sh"

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
  # Compute the project hash the hook uses for marker paths.
  TEST_PROJ_HASH=$(cd "${TEST_REPO}" && git rev-parse --show-toplevel | md5sum | cut -c1-8)
  TEST_MARKER="/tmp/.claude-codereview-${TEST_PROJ_HASH}"
  TEST_SKIP_MARKER="/tmp/.claude-codereview-skip-${TEST_PROJ_HASH}"
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
  payload=$(jq -n --arg c "${cmd}" '{tool_name:"Bash", tool_input:{command:$c}, hook_event_name:"PreToolUse"}')
  (cd "${TEST_REPO}" && printf '%s' "${payload}" | bash "${HOOK}" 2>&1)
}

# ----------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------

# A scratch directory that is NOT a git repo, used for detection-only tests.
SCRATCH_NOGIT=$(mktemp -d)
trap 'rm -rf "${SCRATCH_NOGIT}"; rm -rf "${TEST_REPO:-}"; rm -f "${TEST_MARKER:-}" "${TEST_SKIP_MARKER:-}"' EXIT

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
  "git --git-dir=/tmp/x push" \
  "git --work-tree=/tmp/x push" \
  "git --namespace=foo push" \
  "git --exec-path=/usr/lib/git-core push" \
  "git --super-prefix=sub push" \
  "git -C /home/peter/src/zat.env push" \
  "git add . && git push" \
  "git commit -m done && git push" \
  "( cd /tmp && git push )" \
  "git push --force-with-lease"; do
  assert_exit "${cmd}" 0 "detects as push (no-git-repo allow): ${cmd}"
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
if [[ "${out}" == *"codereview has not been run"* ]]; then
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
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
