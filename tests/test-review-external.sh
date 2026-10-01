#!/usr/bin/env bash
set -euo pipefail

# Tests for bin/review-external.sh guard logic and output contract.
# Most tests make no API calls: they cover behavior when unconfigured, given
# empty input, or run against a fake curl. The invalid-key tests do call the
# real APIs with invalid keys and expect a fail-open error.

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
REVIEW_TIMEOUT=10
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
echo "==> Local provider: script set but file does not exist"
# ============================================================

cat > "${REVIEWER_ENV}" <<EOF
LOCAL_REVIEW_SCRIPT=${TEST_DIR}/nonexistent-review-script.py
LOCAL_REVIEW_VENV=${TEST_DIR}/nonexistent-venv
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "local missing script: exit code 0"
else
  fail "local missing script: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "local missing script: no stdout"
else
  fail "local missing script: unexpected stdout: ${STDOUT}"
fi
if [[ -z "${STDERR}" ]]; then
  pass "local missing script: no stderr"
else
  fail "local missing script: unexpected stderr: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> Local provider: both vars empty"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
LOCAL_REVIEW_SCRIPT=
LOCAL_REVIEW_VENV=
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "local empty vars: exit code 0"
else
  fail "local empty vars: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "local empty vars: no stdout"
else
  fail "local empty vars: unexpected stdout: ${STDOUT}"
fi
if [[ -z "${STDERR}" ]]; then
  pass "local empty vars: no stderr"
else
  fail "local empty vars: unexpected stderr: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> Local provider: only script set (missing venv)"
# ============================================================

cat > "${REVIEWER_ENV}" <<EOF
LOCAL_REVIEW_SCRIPT=${TEST_DIR}/nonexistent-review-script.py
EOF

STDERR_FILE=$(mktemp)
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "local missing venv var: exit code 0"
else
  fail "local missing venv var: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "local missing venv var: no stdout"
else
  fail "local missing venv var: unexpected stdout: ${STDOUT}"
fi
if [[ -z "${STDERR}" ]]; then
  pass "local missing venv var: no stderr"
else
  fail "local missing venv var: unexpected stderr: ${STDERR}"
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
GEMINI_EFFORT=banana
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
if [[ "${STDERR}" == *"not a valid thinking level"* ]]; then
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
REVIEW_TIMEOUT=10
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
REVIEW_TIMEOUT=10
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
echo "==> --check: empty config exits 1 with pointer to env file"
# ============================================================

true > "${REVIEWER_ENV}"
STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(bash "${SCRIPT}" --check 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 1 ]]; then
  pass "--check empty: exit code 1"
else
  fail "--check empty: exit code ${EXIT_CODE} (should be 1)"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "--check empty: no stdout"
else
  fail "--check empty: unexpected stdout: ${STDOUT}"
fi
if [[ "${STDERR}" == *"No external reviewers configured"* ]]; then
  pass "--check empty: stderr names the failure"
else
  fail "--check empty: missing failure message: ${STDERR}"
fi
if [[ "${STDERR}" == *"${REVIEWER_ENV}"* ]]; then
  pass "--check empty: stderr names the env file path"
else
  fail "--check empty: missing env path: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --check: one provider configured exits 0 with one stderr line"
# ============================================================

cat > "${REVIEWER_ENV}" <<'EOF'
OPENAI_API_KEY=sk-test-key
EOF

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(bash "${SCRIPT}" --check 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "--check one provider: exit code 0"
else
  fail "--check one provider: exit code ${EXIT_CODE}"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "--check one provider: no stdout"
else
  fail "--check one provider: unexpected stdout: ${STDOUT}"
fi
if [[ "${STDERR}" == *"openai: gpt-6.1-sol (high)"* ]]; then
  pass "--check one provider: openai line with model + effort"
else
  fail "--check one provider: missing openai line: ${STDERR}"
fi
LINE_COUNT=$(printf '%s\n' "${STDERR}" | grep -c -E '^(openai|google|local):' || true)
if [[ "${LINE_COUNT}" -eq 1 ]]; then
  pass "--check one provider: exactly one provider line"
else
  fail "--check one provider: expected 1 provider line, got ${LINE_COUNT}: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --check: all three providers configured exits 0 with three stderr lines"
# ============================================================

LOCAL_SCRIPT=$(mktemp)
LOCAL_VENV=$(mktemp -d)
cat > "${REVIEWER_ENV}" <<EOF
OPENAI_API_KEY=sk-test-key
GEMINI_API_KEY=fake-google-key
LOCAL_REVIEW_SCRIPT=${LOCAL_SCRIPT}
LOCAL_REVIEW_VENV=${LOCAL_VENV}
LOCAL_MODEL=Test-Local-Model
EOF

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(bash "${SCRIPT}" --check 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}" "${LOCAL_SCRIPT}"
rmdir "${LOCAL_VENV}" 2>/dev/null || true

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "--check three providers: exit code 0"
else
  fail "--check three providers: exit code ${EXIT_CODE}"
fi
if [[ "${STDERR}" == *"openai:"* ]]; then
  pass "--check three providers: openai line"
else
  fail "--check three providers: missing openai line: ${STDERR}"
fi
if [[ "${STDERR}" == *"google: gemini-3.1-pro-preview (thinking level high)"* ]]; then
  pass "--check three providers: google line with model"
else
  fail "--check three providers: missing google line: ${STDERR}"
fi
if [[ "${STDERR}" == *"local: Test-Local-Model"* ]]; then
  pass "--check three providers: local line with model"
else
  fail "--check three providers: missing local line: ${STDERR}"
fi
LINE_COUNT=$(printf '%s\n' "${STDERR}" | grep -c -E '^(openai|google|local):' || true)
if [[ "${LINE_COUNT}" -eq 3 ]]; then
  pass "--check three providers: exactly three provider lines"
else
  fail "--check three providers: expected 3 provider lines, got ${LINE_COUNT}: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --check regression: default no-flag empty stdin no-config still silent exit 0"
# ============================================================

# This guards the fail-open contract that the full /codereview Step 5.5
# depends on. The new --check flag must not change the default path.
true > "${REVIEWER_ENV}"
STDERR_FILE=$(mktemp)
STDOUT=$(echo "diff content" | bash "${SCRIPT}" 2>"${STDERR_FILE}")
EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  pass "default no-flag no-config: exit code 0 (fail-open preserved)"
else
  fail "default no-flag no-config: exit code ${EXIT_CODE} (regression)"
fi
if [[ -z "${STDOUT}" ]]; then
  pass "default no-flag no-config: no stdout"
else
  fail "default no-flag no-config: unexpected stdout: ${STDOUT}"
fi
if [[ -z "${STDERR}" ]]; then
  pass "default no-flag no-config: silent stderr (no --check leak)"
else
  fail "default no-flag no-config: unexpected stderr: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --check rejects extra positional args with exit 2"
# ============================================================

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(bash "${SCRIPT}" --check extra 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 2 ]]; then
  pass "--check extra arg: exit code 2"
else
  fail "--check extra arg: exit code ${EXIT_CODE} (should be 2)"
fi
if [[ "${STDERR}" == *"takes no further arguments"* ]]; then
  pass "--check extra arg: descriptive error"
else
  fail "--check extra arg: missing descriptive error: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --range without value: exit 2"
# ============================================================

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(echo "diff" | bash "${SCRIPT}" --range 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 2 ]]; then
  pass "--range no value: exit code 2"
else
  fail "--range no value: exit code ${EXIT_CODE}"
fi
if [[ "${STDERR}" == *"requires a git range argument"* ]]; then
  pass "--range no value: descriptive error"
else
  fail "--range no value: missing error: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --range= empty value: exit 2"
# ============================================================

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(echo "diff" | bash "${SCRIPT}" --range= 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 2 ]]; then
  pass "--range= empty: exit code 2"
else
  fail "--range= empty: exit code ${EXIT_CODE}"
fi

# ============================================================
echo ""
echo "==> --range with explicit empty-string value: exit 2"
# ============================================================
#
# Regression guard: the space-separated form previously accepted an
# explicit empty string ($# == 2 passes the arity check; RANGE="" then
# fell through to the @{upstream}..HEAD fallback silently). Validation
# must be symmetric with the --range= form.

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(echo "diff" | bash "${SCRIPT}" --range "" 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 2 ]]; then
  pass "--range '': exit code 2"
else
  fail "--range '': exit code ${EXIT_CODE} (regression - silent UPSTREAM fallback)"
fi
if [[ "${STDERR}" == *"non-empty git range argument"* ]]; then
  pass "--range '': descriptive error names the empty cause"
else
  fail "--range '': missing empty-cause error: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --range with extra positional arg: exit 2"
# ============================================================

STDERR_FILE=$(mktemp)
EXIT_CODE=0
STDOUT=$(echo "diff" | bash "${SCRIPT}" --range v1.3..HEAD extra 2>"${STDERR_FILE}") || EXIT_CODE=$?
STDERR=$(cat "${STDERR_FILE}")
rm -f "${STDERR_FILE}"

if [[ "${EXIT_CODE}" -eq 2 ]]; then
  pass "--range extra arg: exit code 2"
else
  fail "--range extra arg: exit code ${EXIT_CODE}"
fi
if [[ "${STDERR}" == *"takes one argument"* ]]; then
  pass "--range extra arg: descriptive error"
else
  fail "--range extra arg: missing error: ${STDERR}"
fi

# ============================================================
echo ""
echo "==> --range plumbs to COMMITS block (end-to-end via fake local provider)"
# ============================================================

# Stand up a fake local provider that emits a [NOTE] containing the commit
# hashes from the COMMITS section of the user message. This proves --range
# changes the COMMIT_SUMMARY input, end to end, without a real API call.
FAKE_VENV=$(mktemp -d)
mkdir -p "${FAKE_VENV}/bin"
cat > "${FAKE_VENV}/bin/python3" <<'PYEOF'
#!/usr/bin/env bash
exec bash "$@"
PYEOF
chmod +x "${FAKE_VENV}/bin/python3"

FAKE_SCRIPT=$(mktemp)
cat > "${FAKE_SCRIPT}" <<'SHEOF'
#!/usr/bin/env bash
set -euo pipefail
INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --system) shift 2 ;;
    --input)  INPUT="$2"; shift 2 ;;
    *)        shift ;;
  esac
done
HASHES=$(awk '/^=== COMMITS ===$/{f=1;next} f && /^$/{exit} f && NF{print $1}' "${INPUT}" | tr '\n' ',' | sed 's/,$//')
echo "[NOTE] commits.txt:1 -- range_commits=${HASHES}"
SHEOF
chmod +x "${FAKE_SCRIPT}"

cat > "${REVIEWER_ENV}" <<EOF
LOCAL_REVIEW_SCRIPT=${FAKE_SCRIPT}
LOCAL_REVIEW_VENV=${FAKE_VENV}
EOF

# Use HEAD~3..HEAD and HEAD~1..HEAD as two distinguishable ranges.
EXPECTED_3=$(git -C "${REPO_DIR}" log --oneline HEAD~3..HEAD | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
EXPECTED_1=$(git -C "${REPO_DIR}" log --oneline HEAD~1..HEAD | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

if [[ -z "${EXPECTED_3}" ]] || [[ -z "${EXPECTED_1}" ]]; then
  fail "--range end-to-end: cannot resolve HEAD~N ranges in repo (skipping)"
else
  STDOUT=$(echo "diff content" | (cd "${REPO_DIR}" && bash "${SCRIPT}" --range "HEAD~3..HEAD") 2>/dev/null || true)
  if [[ "${STDOUT}" == *"range_commits=${EXPECTED_3}"* ]]; then
    pass "--range HEAD~3..HEAD: COMMITS block matches the supplied range"
  else
    fail "--range HEAD~3..HEAD: expected commits=${EXPECTED_3}, got: ${STDOUT}"
  fi

  STDOUT=$(echo "diff content" | (cd "${REPO_DIR}" && bash "${SCRIPT}" --range "HEAD~1..HEAD") 2>/dev/null || true)
  if [[ "${STDOUT}" == *"range_commits=${EXPECTED_1}"* ]]; then
    pass "--range HEAD~1..HEAD: COMMITS block changes when range changes"
  else
    fail "--range HEAD~1..HEAD: expected commits=${EXPECTED_1}, got: ${STDOUT}"
  fi

  # =--range= form should also work.
  STDOUT=$(echo "diff content" | (cd "${REPO_DIR}" && bash "${SCRIPT}" --range="HEAD~1..HEAD") 2>/dev/null || true)
  if [[ "${STDOUT}" == *"range_commits=${EXPECTED_1}"* ]]; then
    pass "--range=HEAD~1..HEAD: equals form parses identically"
  else
    fail "--range=HEAD~1..HEAD: expected commits=${EXPECTED_1}, got: ${STDOUT}"
  fi
fi

rm -rf "${FAKE_VENV}"
rm -f "${FAKE_SCRIPT}"

# ============================================================
echo ""
echo "==> Provider requests and output handling (fake curl, no network)"
# ============================================================

# A fake curl on PATH records the request body and URL and returns a canned
# response, so request shape, cost math, redaction, and the findings demux are
# checked without calling a real API.
FAKE_BIN=$(mktemp -d)
FAKE_CAPTURE=$(mktemp -d)
cat > "${FAKE_BIN}/curl" <<'CURLEOF'
#!/usr/bin/env bash
url=""
printf '%s\n' "$@" > "${FAKE_CAPTURE}/args"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) cp "${2#@}" "${FAKE_CAPTURE}/body.json"; shift 2 ;;
    -H) if [[ "$2" == @* ]]; then cat "${2#@}"; else printf '%s\n' "$2"; fi >> "${FAKE_CAPTURE}/headers"; shift 2 ;;
    -w|--max-time) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "${url}" > "${FAKE_CAPTURE}/url"
cat "${FAKE_RESPONSE}"
printf '\n%s' "${FAKE_CODE:-200}"
CURLEOF
chmod +x "${FAKE_BIN}/curl"
export FAKE_CAPTURE

# run_fake <response-file> <http-code>: run the script against the fake curl.
# Sets FAKE_STDOUT and FAKE_STDERR; leaves the captured request in place.
run_fake() {
  local errf
  errf=$(mktemp)
  rm -f "${FAKE_CAPTURE}/body.json" "${FAKE_CAPTURE}/url" "${FAKE_CAPTURE}/args" "${FAKE_CAPTURE}/headers"
  FAKE_STDOUT=$(echo "diff content" | PATH="${FAKE_BIN}:${PATH}" FAKE_RESPONSE="$1" FAKE_CODE="$2" bash "${SCRIPT}" 2>"${errf}" || true)
  FAKE_STDERR=$(cat "${errf}")
  rm -f "${errf}"
}

GEMINI_OK="${TEST_DIR}/gemini-ok.json"
printf '%s\n' '{"candidates":[{"content":{"parts":[{"text":"[WARN] a.py:1 -- example finding"}]}}],"usageMetadata":{"promptTokenCount":1000000,"candidatesTokenCount":1000000,"thoughtsTokenCount":0}}' > "${GEMINI_OK}"

# Gemini default: model gemini-3.1-pro-preview, thinkingLevel "high".
printf 'GEMINI_API_KEY=fake-google-key\n' > "${REVIEWER_ENV}"
run_fake "${GEMINI_OK}" 200
if [[ "$(cat "${FAKE_CAPTURE}/url" 2>/dev/null)" == *"/models/gemini-3.1-pro-preview:generateContent" ]] \
   && [[ "$(jq -r '.generationConfig.thinkingConfig.thinkingLevel // empty' "${FAKE_CAPTURE}/body.json" 2>/dev/null)" == "high" ]]; then
  pass "gemini default: gemini-3.1-pro-preview with thinkingLevel high"
else
  fail "gemini default: url=$(cat "${FAKE_CAPTURE}/url" 2>/dev/null) config=$(jq -c .generationConfig "${FAKE_CAPTURE}/body.json" 2>/dev/null)"
fi
if [[ "${FAKE_STDERR}" == *"-- 1000000 in / 1000000 out / 0 thinking -- ~\$22"* ]]; then
  pass "gemini cost: prompts over 200k tokens use the \$4 in / \$18 out tier"
else
  fail "gemini cost (long prompt): unexpected cost line: ${FAKE_STDERR}"
fi
# The key reaches curl through a file descriptor, never its argument list,
# which any local account can read in /proc/<pid>/cmdline.
if ! grep -qF 'fake-google-key' "${FAKE_CAPTURE}/args" 2>/dev/null \
   && grep -qxF 'x-goog-api-key: fake-google-key' "${FAKE_CAPTURE}/headers" 2>/dev/null; then
  pass "gemini key: sent from a file descriptor, not in curl's arguments"
else
  fail "gemini key: args=$(tr '\n' ' ' < "${FAKE_CAPTURE}/args" 2>/dev/null) headers=$(tr '\n' ' ' < "${FAKE_CAPTURE}/headers" 2>/dev/null)"
fi
GEMINI_SHORT="${TEST_DIR}/gemini-short.json"
printf '%s\n' '{"candidates":[{"content":{"parts":[{"text":"No issues found."}]}}],"usageMetadata":{"promptTokenCount":100000,"candidatesTokenCount":1000000,"thoughtsTokenCount":0}}' > "${GEMINI_SHORT}"
run_fake "${GEMINI_SHORT}" 200
if [[ "${FAKE_STDERR}" == *"-- 100000 in / 1000000 out / 0 thinking -- ~\$12.2"* ]]; then
  pass "gemini cost: prompts up to 200k tokens use the \$2 in / \$12 out tier"
else
  fail "gemini cost (short prompt): unexpected cost line: ${FAKE_STDERR}"
fi

# A numeric GEMINI_EFFORT is sent as thinkingBudget.
printf 'GEMINI_API_KEY=fake-google-key\nGEMINI_EFFORT=12000\n' > "${REVIEWER_ENV}"
run_fake "${GEMINI_OK}" 200
if [[ "$(jq -r '.generationConfig.thinkingConfig.thinkingBudget // empty' "${FAKE_CAPTURE}/body.json" 2>/dev/null)" == "12000" ]]; then
  pass "gemini numeric effort: sent as thinkingBudget"
else
  fail "gemini numeric effort: config=$(jq -c .generationConfig "${FAKE_CAPTURE}/body.json" 2>/dev/null)"
fi

# A pinned 2.5 model with no effort keeps the old default budget.
printf 'GEMINI_API_KEY=fake-google-key\nGEMINI_MODEL=gemini-2.5-pro\n' > "${REVIEWER_ENV}"
run_fake "${GEMINI_OK}" 200
if [[ "$(jq -r '.generationConfig.thinkingConfig.thinkingBudget // empty' "${FAKE_CAPTURE}/body.json" 2>/dev/null)" == "32768" ]]; then
  pass "gemini 2.5 pinned: default thinkingBudget 32768"
else
  fail "gemini 2.5 pinned: config=$(jq -c .generationConfig "${FAKE_CAPTURE}/body.json" 2>/dev/null)"
fi

# OpenAI: output_tokens already includes reasoning tokens, so cost must not
# add them again. gpt-6.1-sol at $2 / $10: 100k in + 1M out = $10.2, not $15.2.
printf 'OPENAI_API_KEY=sk-test-key\n' > "${REVIEWER_ENV}"
OPENAI_OK="${TEST_DIR}/openai-ok.json"
printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"[BLOCK] b.py:2 -- example finding"}]}],"usage":{"input_tokens":100000,"output_tokens":1000000,"output_tokens_details":{"reasoning_tokens":500000}}}' > "${OPENAI_OK}"
run_fake "${OPENAI_OK}" 200
if [[ "${FAKE_STDERR}" == *"gpt-6.1-sol (high)"*"~\$10.2"* ]] && [[ "${FAKE_STDERR}" != *"~\$15.2"* ]]; then
  pass "openai cost: reasoning tokens not counted twice"
else
  fail "openai cost: unexpected cost line: ${FAKE_STDERR}"
fi
if [[ "${FAKE_STDOUT}" == "[BLOCK] (openai) b.py:2 -- example finding" ]]; then
  pass "openai finding: tagged with its provider on stdout"
else
  fail "openai finding: unexpected stdout: ${FAKE_STDOUT}"
fi
if ! grep -qF 'sk-test-key' "${FAKE_CAPTURE}/args" 2>/dev/null \
   && grep -qxF 'Authorization: Bearer sk-test-key' "${FAKE_CAPTURE}/headers" 2>/dev/null; then
  pass "openai key: sent from a file descriptor, not in curl's arguments"
else
  fail "openai key: args=$(tr '\n' ' ' < "${FAKE_CAPTURE}/args" 2>/dev/null) headers=$(tr '\n' ' ' < "${FAKE_CAPTURE}/headers" 2>/dev/null)"
fi

# Prompts over 272k input tokens use the long-context tier: 1M in + 1M out at
# $4 / $15 = $19, not the short-tier $12.
OPENAI_LONG="${TEST_DIR}/openai-long.json"
printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"No issues found."}]}],"usage":{"input_tokens":1000000,"output_tokens":1000000,"output_tokens_details":{"reasoning_tokens":0}}}' > "${OPENAI_LONG}"
run_fake "${OPENAI_LONG}" 200
if [[ "${FAKE_STDERR}" == *"-- 1000000 in / 1000000 out / 0 reasoning -- ~\$19"* ]]; then
  pass "openai cost: prompts over 272k tokens use the \$4 in / \$15 out tier"
else
  fail "openai cost (long prompt): unexpected cost line: ${FAKE_STDERR}"
fi

# Costs below $1 keep their leading zero: 414 in + 264 out = $0.0034, as in a
# live run, not "$.0034".
OPENAI_SMALL="${TEST_DIR}/openai-small.json"
printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"No issues found."}]}],"usage":{"input_tokens":414,"output_tokens":264,"output_tokens_details":{"reasoning_tokens":196}}}' > "${OPENAI_SMALL}"
run_fake "${OPENAI_SMALL}" 200
if [[ "${FAKE_STDERR}" == *"-- ~\$0.0034"* ]]; then
  pass "openai cost: values below \$1 print with a leading zero"
else
  fail "openai cost (small): unexpected cost line: ${FAKE_STDERR}"
fi

# Non-numeric token counts never reach bc.
OPENAI_HOSTILE="${TEST_DIR}/openai-hostile.json"
printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"No issues found."}]}],"usage":{"input_tokens":"1; while (1) { }","output_tokens":5,"output_tokens_details":{"reasoning_tokens":0}}}' > "${OPENAI_HOSTILE}"
start=$(date +%s)
run_fake "${OPENAI_HOSTILE}" 200
if [[ $(( $(date +%s) - start )) -lt 20 ]] && [[ "${FAKE_STDERR}" == *"-- 0 in / 5 out"* ]]; then
  pass "openai usage: non-numeric token count treated as 0, never evaluated"
else
  fail "openai usage: hostile token count not neutralized: ${FAKE_STDERR}"
fi

# A key echoed in an API error is redacted before it reaches the cost log.
OPENAI_401="${TEST_DIR}/openai-401.json"
printf '%s\n' '{"error":{"message":"Incorrect API key provided: sk-test-****real. You can find your API key at https://platform.openai.com/account/api-keys."}}' > "${OPENAI_401}"
run_fake "${OPENAI_401}" 401
if [[ "${FAKE_STDERR}" == *"sk-[REDACTED]"* ]] && [[ "${FAKE_STDERR}" != *"****real"* ]]; then
  pass "openai error: key-shaped text redacted"
else
  fail "openai error: key not redacted: ${FAKE_STDERR}"
fi

# Terminal control characters in provider text never reach the terminal: a CR
# plus erase-line would make this BLOCK display as the NOTE that follows it.
# Both texts must stay visible, with tab and UTF-8 text intact.
OPENAI_CTRL="${TEST_DIR}/openai-ctrl.json"
printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"[BLOCK] evil.py:1 -- real finding\r\u001b[2K[NOTE] evil.py:1 -- cosmetic only\u001b]0;title\u0007 \u009b2J\tcafé"}]}],"usage":{"input_tokens":10,"output_tokens":5,"output_tokens_details":{"reasoning_tokens":0}}}' > "${OPENAI_CTRL}"
run_fake "${OPENAI_CTRL}" 200
if [[ "${FAKE_STDOUT}" == "[BLOCK] (openai) evil.py:1 -- real finding[2K[NOTE] evil.py:1 -- cosmetic only]0;title 2J"$'\t'"café" ]]; then
  pass "control characters: stripped from findings, text and tab kept"
else
  fail "control characters in findings: $(printf '%s' "${FAKE_STDOUT}" | od -c | head -5)"
fi
OPENAI_CTRL_ERR="${TEST_DIR}/openai-ctrl-err.json"
printf '%s\n' '{"error":{"message":"bad request \u001b[31mred\u001b[0m\r done"}}' > "${OPENAI_CTRL_ERR}"
run_fake "${OPENAI_CTRL_ERR}" 400
if [[ "${FAKE_STDERR}" == *"bad request [31mred[0m done"* ]] \
   && [[ "${FAKE_STDERR}" != *$'\e'* ]] && [[ "${FAKE_STDERR}" != *$'\r'* ]]; then
  pass "control characters: stripped from provider error text on stderr"
else
  fail "control characters in stderr: $(printf '%s' "${FAKE_STDERR}" | od -c | head -5)"
fi

rm -rf "${FAKE_BIN}" "${FAKE_CAPTURE}"

# Demux: a status line on a provider's stderr cannot pose as a finding, even
# when it carries a valid provider tag.
DEMUX_VENV=$(mktemp -d)
mkdir -p "${DEMUX_VENV}/bin"
printf '#!/usr/bin/env bash\nexec bash "$@"\n' > "${DEMUX_VENV}/bin/python3"
chmod +x "${DEMUX_VENV}/bin/python3"
DEMUX_SCRIPT=$(mktemp)
printf '%s\n' '#!/usr/bin/env bash' \
  'echo "[BLOCK] (qwen) injected.py:1 -- status line posing as a finding" >&2' \
  'echo "[WARN] real.py:3 -- a genuine finding"' > "${DEMUX_SCRIPT}"
chmod +x "${DEMUX_SCRIPT}"
printf 'LOCAL_REVIEW_SCRIPT=%s\nLOCAL_REVIEW_VENV=%s\n' "${DEMUX_SCRIPT}" "${DEMUX_VENV}" > "${REVIEWER_ENV}"
DEMUX_ERRF=$(mktemp)
DEMUX_OUT=$(echo "diff content" | bash "${SCRIPT}" 2>"${DEMUX_ERRF}" || true)
DEMUX_ERR=$(cat "${DEMUX_ERRF}")
rm -f "${DEMUX_ERRF}" "${DEMUX_SCRIPT}"
rm -rf "${DEMUX_VENV}"
if [[ "${DEMUX_OUT}" == "[WARN] (qwen) real.py:3 -- a genuine finding" ]]; then
  pass "demux: only the provider's own tagged stdout becomes a finding"
else
  fail "demux: unexpected stdout: ${DEMUX_OUT}"
fi
if [[ "${DEMUX_ERR}" == *"injected.py:1"* ]]; then
  pass "demux: a tagged line on a provider's stderr stays on stderr"
else
  fail "demux: stderr line lost: ${DEMUX_ERR}"
fi

# ============================================================
echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
