#!/usr/bin/env bash
set -euo pipefail

# Tests for bin/review-external.sh guard logic and output contract.
# No API calls are made; tests cover behavior when unconfigured or given
# empty input.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${REPO_DIR}/bin/review-external.sh"

FAILS=0
TOTAL=0
pass() { TOTAL=$((TOTAL + 1)); printf '  ok   %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }

# Use a temp directory for config so tests never touch the real config.
# The script respects CLAUDE_REVIEWER_ENV for testability.
TEST_DIR=$(mktemp -d)
REVIEWER_ENV="${TEST_DIR}/.env"
export CLAUDE_REVIEWER_ENV="${REVIEWER_ENV}"
cleanup() { rm -rf "${TEST_DIR}"; }
trap cleanup EXIT

# Unset any API keys that might be in the shell environment.
unset OPENAI_API_KEY GEMINI_API_KEY 2>/dev/null || true

# ============================================================
echo "==> Empty stdin: exits 0, no output"
# ============================================================

STDOUT=$(echo -n "" | bash "${SCRIPT}" 2>/dev/null)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "empty stdin: exit code 0"
else
  fail "empty stdin: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "empty stdin: no stdout"
else
  fail "empty stdin: unexpected stdout: ${STDOUT}"
fi

# ============================================================
echo ""
echo "==> No config file: exits 0, no output"
# ============================================================

# Config file does not exist in the temp directory (nothing to remove).
rm -f "${REVIEWER_ENV}"
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>/dev/null)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "no config: exit code 0"
else
  fail "no config: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "no config: no stdout"
else
  fail "no config: unexpected stdout: ${STDOUT}"
fi

# ============================================================
echo ""
echo "==> Empty config: exits 0, no output"
# ============================================================

true > "${REVIEWER_ENV}"
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>/dev/null)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "empty config: exit code 0"
else
  fail "empty config: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "empty config: no stdout"
else
  fail "empty config: unexpected stdout: ${STDOUT}"
fi

# ============================================================
echo ""
echo "==> Config with empty keys: exits 0, no output"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
OPENAI_API_KEY=
GEMINI_API_KEY=
EOF

STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>/dev/null)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "empty keys: exit code 0"
else
  fail "empty keys: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "empty keys: no stdout"
else
  fail "empty keys: unexpected stdout: ${STDOUT}"
fi

# ============================================================
echo ""
echo "==> Invalid API key: exits 0, error on stderr only"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
OPENAI_API_KEY=sk-invalid-test-key
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "--- a/test.sh\n+++ b/test.sh\n@@ -1 +1 @@\n-old\n+new" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "invalid key: exit code 0 (fail-open)"
else
  fail "invalid key: exit code ${EXIT_CODE} (should be 0)"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "invalid key: no findings on stdout"
else
  fail "invalid key: unexpected stdout: ${STDOUT}"
fi
if [[ "${STDERR}" == *"[openai]"* ]]; then
  pass "invalid key: error logged to stderr with provider tag"
else
  fail "invalid key: no provider-tagged error on stderr: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> Script is shellcheck clean"
# ============================================================

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "${SCRIPT}" >/dev/null 2>&1; then
    pass "shellcheck: review-external.sh"
  else
    fail "shellcheck: review-external.sh"
    shellcheck -S warning "${SCRIPT}" 2>&1 | sed 's/^/         /' | head -20
  fi
else
  echo "  skip (shellcheck not installed)"
fi

# ============================================================
echo ""
echo "==> Invalid GEMINI_EFFORT: exits 0, error on stderr"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
GEMINI_API_KEY=fake-google-key
GEMINI_EFFORT=high
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "--- a/test.sh\n+++ b/test.sh\n@@ -1 +1 @@\n-old\n+new" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "invalid effort: exit code 0 (fail-open)"
else
  fail "invalid effort: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "invalid effort: no findings on stdout"
else
  fail "invalid effort: unexpected stdout: ${STDOUT}"
fi
if [[ "${STDERR}" == *"not a valid number"* ]]; then
  pass "invalid effort: descriptive error on stderr"
else
  fail "invalid effort: expected validation error on stderr: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> Both providers invalid: exits 0, both get stderr errors"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
OPENAI_API_KEY=sk-invalid-test-key
GEMINI_API_KEY=fake-google-key
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "--- a/test.sh\n+++ b/test.sh\n@@ -1 +1 @@\n-old\n+new" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "both invalid: exit code 0 (fail-open)"
else
  fail "both invalid: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "both invalid: no findings on stdout"
else
  fail "both invalid: unexpected stdout: ${STDOUT}"
fi
if [[ "${STDERR}" == *"[openai]"* ]]; then
  pass "both invalid: openai error on stderr"
else
  fail "both invalid: missing openai error on stderr"
fi
if [[ "${STDERR}" == *"[google]"* ]]; then
  pass "both invalid: google error on stderr"
else
  fail "both invalid: missing google error on stderr"
fi

# ============================================================
echo ""
echo "==> Script reads from stdin (not arguments)"
# ============================================================

# Verify the script does not require positional arguments.
# With no config, it should exit 0 regardless of args.
true > "${REVIEWER_ENV}"
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>/dev/null)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "no args required: exit code 0"
else
  fail "no args required: exit code ${EXIT_CODE}"
fi

# ============================================================
echo ""
echo "==> Runs outside a git repo: exits 0, no crash"
# ============================================================

# The script derives UPSTREAM and commit summary via git commands.
# Outside a repo these should fail gracefully (|| true guards).
# Run in a subshell to isolate the cd from the main test process.
NON_GIT_DIR=$(mktemp -d)
cat > "${REVIEWER_ENV}" <<'EOF'
OPENAI_API_KEY=sk-invalid-test-key
EOF

RESULT_FILE=$(mktemp)
(
  cd "${NON_GIT_DIR}"
  printf '%s\n' "--- a/test.sh" "+++ b/test.sh" "@@ -1 +1 @@" "-old" "+new" \
    | bash "${SCRIPT}" >/dev/null 2>/dev/null
  echo "$?" > "${RESULT_FILE}"
) || true
EXIT_CODE=$(cat "${RESULT_FILE}")
rm -f "${RESULT_FILE}"
rm -rf "${NON_GIT_DIR}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "non-git dir: exit code 0 (fail-open)"
else
  fail "non-git dir: exit code ${EXIT_CODE} (should be 0)"
fi

# ============================================================
echo ""
echo "==> Prompt contains security dimension"
# ============================================================

if grep -q 'injection vectors' "${SCRIPT}"; then
  pass "prompt: includes security dimension"
else
  fail "prompt: missing security dimension"
fi

# ============================================================
echo ""
echo "==> Prompt contains format example"
# ============================================================

if grep -q '^\[BLOCK\].*--.*' "${SCRIPT}" && grep -q '^\[WARN\].*--.*' "${SCRIPT}"; then
  pass "prompt: includes BLOCK and WARN example findings"
else
  fail "prompt: missing example findings"
fi

# ============================================================
echo ""
echo "==> System and user messages are separate"
# ============================================================

# The script should build SYSTEM_FILE and USER_FILE, not a single PROMPT_FILE.
if grep -q 'SYSTEM_FILE=' "${SCRIPT}" && grep -q 'USER_FILE=' "${SCRIPT}"; then
  pass "message split: SYSTEM_FILE and USER_FILE defined"
else
  fail "message split: expected SYSTEM_FILE and USER_FILE variables"
fi

# OpenAI should use developer role for system instructions.
if grep -q '"developer"' "${SCRIPT}"; then
  pass "openai: uses developer role for system message"
else
  fail "openai: missing developer role"
fi

# Google should use systemInstruction field.
if grep -q 'systemInstruction' "${SCRIPT}"; then
  pass "google: uses systemInstruction field"
else
  fail "google: missing systemInstruction field"
fi

# ============================================================
echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
