#!/usr/bin/env bash
set -euo pipefail

# Run all test suites and report a combined summary.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
SUITES=0
FAILED_SUITES=""

run_suite() {
  local script="$1"
  local name
  name="$(basename "${script}")"
  echo "━━━ ${name} ━━━"
  echo ""
  SUITES=$((SUITES + 1))

  local output
  output=$(bash "${script}" 2>&1) || true
  echo "${output}"
  echo ""

  # Extract counts from the summary line.
  local summary
  summary=$(echo "${output}" | tail -1)
  local pass=0 fail=0 total=0
  if [[ "${summary}" =~ All\ ([0-9]+)\ checks\ passed ]]; then
    total="${BASH_REMATCH[1]}"
    pass="${total}"
  elif [[ "${summary}" =~ ([0-9]+)\ of\ ([0-9]+)\ checks\ failed ]]; then
    fail="${BASH_REMATCH[1]}"
    total="${BASH_REMATCH[2]}"
    pass=$((total - fail))
    FAILED_SUITES="${FAILED_SUITES} ${name}"
  fi
  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
}

run_suite "${TESTS_DIR}/lint-skills.sh"
run_suite "${TESTS_DIR}/test-review-external.sh"
run_suite "${TESTS_DIR}/test-pre-push-hook.sh"
run_suite "${TESTS_DIR}/test-spec-backlog-apply.sh"
run_suite "${TESTS_DIR}/test-codereview-marker.sh"

echo "━━━ Combined ━━━"
echo ""
GRAND=$((TOTAL_PASS + TOTAL_FAIL))
if [[ "${TOTAL_FAIL}" -eq 0 ]]; then
  echo "All ${GRAND} checks passed across ${SUITES} suites."
else
  echo "${TOTAL_FAIL} of ${GRAND} checks failed across ${SUITES} suites."
  echo "Failed suites:${FAILED_SUITES}"
  exit 1
fi
