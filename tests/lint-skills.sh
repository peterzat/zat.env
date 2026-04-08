#!/usr/bin/env bash
set -euo pipefail

# Structural lint for zat.env skills and hooks.
# Catches META field mismatches, gate condition drift, and frontmatter issues.
# Run after modifying any skill or hook.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS="${REPO_DIR}/claude/skills"
HOOK="${REPO_DIR}/hooks/pre-push-codereview.sh"
README="${REPO_DIR}/README.md"
FAILS=0
TOTAL=0

pass() { TOTAL=$((TOTAL + 1)); printf '  ok   %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }

has() {
  # has <file> <pattern> <label> — pass if pattern found
  if grep -qE "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

hasnt() {
  # hasnt <file> <pattern> <label> — pass if pattern NOT found
  if grep -qE "$2" "$1" 2>/dev/null; then fail "$3"; else pass "$3"; fi
}

# --- META field cross-references ---
# Fields read by one skill must exist in the writing skill's template.

echo "==> META field cross-references"

# Codereview reads from SECURITY_META: commit, scope, scanned_files, block, warn, note
for field in commit scope block warn note; do
  has "${SKILLS}/security/SKILL.md" "\"${field}\"" \
    "SECURITY_META has '${field}' (read by codereview)"
done
has "${SKILLS}/security/SKILL.md" "scanned_files" \
  "SECURITY_META documents scanned_files (read by codereview)"

# PR reads from REVIEW_META: block, reviewed_up_to
for field in block reviewed_up_to; do
  has "${SKILLS}/codereview/SKILL.md" "\"${field}\"" \
    "REVIEW_META has '${field}' (read by pr)"
done

# --- Gate condition alignment ---
# Hook, skill, and README must agree on what blocks a push.

echo ""
echo "==> Gate condition alignment"

has "${HOOK}" "all BLOCK items resolved" \
  "hook: gate message says BLOCK items"
hasnt "${HOOK}" "BLOCK and WARN.*(resolved|fixed)" \
  "hook: gate message does not include WARN"
has "${SKILLS}/codereview/SKILL.md" "all BLOCKs are resolved" \
  "codereview: marker condition says BLOCKs only"
has "${README}" "BLOCK.*Yes.*Auto-fixed" \
  "README: severity table BLOCK gates push"
has "${README}" "WARN.*No.*Auto-fixed" \
  "README: severity table WARN does not gate push"

# --- PR merge gate ---
# Must use REVIEW_META (not marker file), must check GitHub state.

echo ""
echo "==> PR merge gate"

has "${SKILLS}/pr/SKILL.md" "REVIEW_BLOCKS|reviewed_up_to" \
  "pr merge: reads REVIEW_META fields"
hasnt "${SKILLS}/pr/SKILL.md" "claude-codereview-" \
  "pr merge: does not use marker file"
has "${SKILLS}/pr/SKILL.md" "mergeable" \
  "pr merge: checks GitHub mergeability"
has "${SKILLS}/pr/SKILL.md" "statusCheckRollup" \
  "pr merge: checks CI status"
has "${SKILLS}/pr/SKILL.md" "REVIEW_REQUIRED" \
  "pr merge: blocks on REVIEW_REQUIRED"
has "${SKILLS}/pr/SKILL.md" "CHANGES_REQUESTED" \
  "pr merge: blocks on CHANGES_REQUESTED"

# --- Security chain coverage ---
# Codereview must verify coverage before skipping /security.
# The chain has three paths: skip (cached + coverage), file-scoped invoke,
# and upstream-scoped invoke. Both skills must agree on META fields and
# invocation contract.

echo ""
echo "==> Security chain coverage"

# Delegation exists
has "${SKILLS}/codereview/SKILL.md" "Skill\(security\)" \
  "codereview: has Skill(security) in allowed-tools"

# Codereview reads SECURITY_META to decide skip-vs-invoke
has "${SKILLS}/codereview/SKILL.md" "SECURITY_META" \
  "codereview: reads SECURITY_META"
has "${SKILLS}/codereview/SKILL.md" "NEEDED" \
  "codereview: computes NEEDED files vs upstream"
has "${SKILLS}/codereview/SKILL.md" "scanned_files" \
  "codereview: checks scanned_files for coverage"
has "${SKILLS}/codereview/SKILL.md" "SCAN_FILES" \
  "codereview: computes SCAN_FILES for scoped invocation"

# Three distinct invocation paths
has "${SKILLS}/codereview/SKILL.md" "no code changes since last scan" \
  "codereview: skip path carries forward existing findings"
has "${SKILLS}/codereview/SKILL.md" "/security.*SCAN_FILES" \
  "codereview: file-scoped invocation path"
has "${SKILLS}/codereview/SKILL.md" "no prior scan" \
  "codereview: upstream-scoped fallback path"

# Skip for light review
has "${SKILLS}/codereview/SKILL.md" "Skipped for light review" \
  "codereview: security chain skipped for light review"

# Security accepts file paths as arguments
has "${SKILLS}/security/SKILL.md" "scope.*paths" \
  "security: supports paths scope"
has "${SKILLS}/security/SKILL.md" "changes-only" \
  "security: supports changes-only scope"

# Security severity format matches codereview
# Security must define all three severity levels
for sev in BLOCK WARN NOTE; do
  has "${SKILLS}/security/SKILL.md" "\*\*${sev}\*\*" \
    "security: defines ${sev} severity"
done

# --- Codereview flow gating ---
# Entry paths, tier classification, and early exits.

echo ""
echo "==> Codereview flow gating"

# Early exit: nothing to review
has "${SKILLS}/codereview/SKILL.md" "nothing to review.*stop" \
  "codereview: early exit when nothing to review"

# Light review skip list names all skipped steps
for step in 3 5 5.5 6.5 7; do
  has "${SKILLS}/codereview/SKILL.md" "skip Steps.*${step}" \
    "codereview: light review skips Step ${step}"
done

# Refresh review detection
has "${SKILLS}/codereview/SKILL.md" "refresh detection" \
  "codereview: documents refresh review detection"
has "${SKILLS}/codereview/SKILL.md" "refresh review.*compute.*file sets" \
  "codereview: refresh review computes focus and already-reviewed sets"

# Config format extensions (.json, .yaml etc.) get full review
has "${SKILLS}/codereview/SKILL.md" 'json.*yaml.*toml' \
  "codereview: config formats get full review (not light)"

# --- Builder/verifier separation ---
# Codereview must not have tools that modify source code.
# Codefix must have tools to modify code but must not invoke skills.

echo ""
echo "==> Builder/verifier separation"

has "${SKILLS}/codefix/SKILL.md" "^context: fork" \
  "codefix: runs in forked context"
has "${SKILLS}/codefix/SKILL.md" "Edit" \
  "codefix: has Edit tool (can modify code)"
hasnt "${SKILLS}/codefix/SKILL.md" "Skill(" \
  "codefix: no Skill invocations (fixer does not self-review)"
hasnt "${SKILLS}/codefix/SKILL.md" "CODEREVIEW.md.*update\|update.*CODEREVIEW.md\|Write.*CODEREVIEW" \
  "codefix: does not update CODEREVIEW.md"
has "${SKILLS}/codereview/SKILL.md" "Skill\(codefix\)" \
  "codereview: delegates to codefix"
hasnt "${SKILLS}/codereview/SKILL.md" "^allowed-tools:.*Edit" \
  "codereview: no Edit tool (reviewer cannot modify source)"
hasnt "${SKILLS}/codereview/SKILL.md" "^allowed-tools:.*Write" \
  "codereview: no Write tool (reviewer cannot modify source)"
has "${SKILLS}/codereview/SKILL.md" "Never fix code yourself" \
  "codereview: explicit no-fix principle"

# --- Codereview/codefix handoff contracts ---
# The two skills must agree on formats, steps, and cycle limits.

echo ""
echo "==> Codereview/codefix handoff contracts"

# --- Step 6.5: preliminary write gating ---
has "${SKILLS}/codereview/SKILL.md" "Step 6.5.*Preliminary CODEREVIEW" \
  "codereview: Step 6.5 writes preliminary CODEREVIEW.md before codefix"
has "${SKILLS}/codereview/SKILL.md" "findings must be on disk before.*invoked" \
  "codereview: documents why preliminary write is needed"
has "${SKILLS}/codereview/SKILL.md" "no BLOCK.WARN findings exist.*skip" \
  "codereview: Step 6.5 skipped when no BLOCK/WARN findings"

# --- Step 7: fix loop structure ---
has "${SKILLS}/codereview/SKILL.md" "Step 7.*Fix.*Loop" \
  "codereview: Step 7 is the fix/re-review loop"
has "${SKILLS}/codereview/SKILL.md" "Cycle limit: 3" \
  "codereview: 3-cycle cap on fix loop"
has "${SKILLS}/codereview/SKILL.md" "without updating CODEREVIEW.md first" \
  "codereview: must update CODEREVIEW.md before re-invoking codefix"

# Terminal states: fix success vs. failure
has "${SKILLS}/codereview/SKILL.md" "requires manual intervention" \
  "codereview: escalates to human after cycle limit"
has "${SKILLS}/codereview/SKILL.md" "tests regressed.*fix cycle fails" \
  "codereview: test regression fails the fix cycle"
has "${SKILLS}/codereview/SKILL.md" "attempt further fixes" \
  "codereview: stops after cycle limit (no infinite loop)"

# Re-review after codefix
has "${SKILLS}/codereview/SKILL.md" "After codefix completes.*re-review" \
  "codereview: re-reviews after each codefix pass"
has "${SKILLS}/codereview/SKILL.md" "re-run it after each codefix" \
  "codereview: re-runs tests after each codefix pass"

# Codereview must not re-run external reviewers during fix cycles
has "${SKILLS}/codereview/SKILL.md" "Do NOT re-run" \
  "codereview: no external reviewers during fix/re-review cycles"

# --- Finding format contract ---
has "${SKILLS}/codefix/SKILL.md" "BLOCK.*WARN" \
  "codefix: parses BLOCK and WARN severities"
has "${SKILLS}/codereview/SKILL.md" '^\[SEVERITY\]' \
  "codereview: finding format template matches codefix expectation"
has "${SKILLS}/codefix/SKILL.md" "file.*line" \
  "codefix: parses file and line from findings"

# --- Codefix constraints ---
has "${SKILLS}/codefix/SKILL.md" "Modify CODEREVIEW.md" \
  "codefix: explicitly told not to modify CODEREVIEW.md"
has "${SKILLS}/codefix/SKILL.md" "Ignore NOTE" \
  "codefix: does not auto-fix NOTE findings"
has "${SKILLS}/codefix/SKILL.md" "more than 20 lines" \
  "codefix: 20-line-per-fix cap"
has "${SKILLS}/codefix/SKILL.md" "syntax.check" \
  "codefix: syntax-checks after each fix"

# --- Marker file gating (Step 8) ---

echo ""
echo "==> Marker file gating"

has "${SKILLS}/codereview/SKILL.md" "all BLOCKs are resolved AND tests did not regress" \
  "codereview: marker requires BLOCKs resolved AND tests stable"
has "${SKILLS}/codereview/SKILL.md" "Do NOT write the marker.*BLOCK.*remain" \
  "codereview: no marker when BLOCKs remain"
has "${SKILLS}/codereview/SKILL.md" "Do NOT write the marker.*tests regressed" \
  "codereview: no marker when tests regressed"

# Marker hash exclusions must be identical between skill and hook.
# Extract the exclusion patterns and compare them directly.
SKILL_EXCL=$(grep -oP ":![A-Z_.]+" "${SKILLS}/codereview/SKILL.md" | sort -u | tr '\n' ' ')
HOOK_EXCL=$(grep -oP ":![A-Z_.]+" "${HOOK}" | sort -u | tr '\n' ' ')
if [[ "${SKILL_EXCL}" == "${HOOK_EXCL}" ]] && [[ -n "${SKILL_EXCL}" ]]; then
  pass "marker: skill and hook exclude identical review files (${SKILL_EXCL% })"
else
  fail "marker: exclusion mismatch -- skill=[${SKILL_EXCL% }] hook=[${HOOK_EXCL% }]"
fi

# Hook blocks when marker missing or mismatched
has "${HOOK}" "exit 2" \
  "hook: exits non-zero to block push"
has "${HOOK}" 'STORED_HASH.*DIFF_HASH' \
  "hook: compares stored marker hash against current diff"

# Hook: tag-only pushes bypass gate
has "${HOOK}" "TAG_PATTERN" \
  "hook: tag-only pushes skip codereview gate"

# Hook: skip marker consumed on use (rm before exit 0)
has "${HOOK}" 'rm.*SKIP_MARKER' \
  "hook: skip marker consumed on use"

# Hook: codereview marker persists after push (NOT consumed).
# The only rm in the hook should be for SKIP_MARKER, not MARKER.
has "${HOOK}" "Marker is kept" \
  "hook: codereview marker persists after push (documented)"

# --- Output verdicts ---

echo ""
echo "==> Output verdicts"

has "${SKILLS}/codereview/SKILL.md" "Changes are ready to push" \
  "codereview: success verdict documented"
has "${SKILLS}/codereview/SKILL.md" "BLOCKED.*require manual intervention" \
  "codereview: failure verdict documented"

# CODEREVIEW.md template completeness
has "${SKILLS}/codereview/SKILL.md" "No issues found" \
  "codereview: template covers clean-review state"
has "${SKILLS}/codereview/SKILL.md" "Fixes Applied" \
  "codereview: template has Fixes Applied section"
has "${SKILLS}/codereview/SKILL.md" "REVIEW_META" \
  "codereview: template has REVIEW_META footer"
for field in date commit reviewed_up_to base tier block warn note; do
  has "${SKILLS}/codereview/SKILL.md" "\"${field}\"" \
    "codereview: REVIEW_META has '${field}' field"
done

# --- Carry-forward severity ---
# Codereview Step 1 must handle prior findings correctly.

echo ""
echo "==> Carry-forward severity"

has "${SKILLS}/codereview/SKILL.md" "Listed in Accepted Risks.*downgrade to NOTE" \
  "codereview: Accepted Risks findings downgrade to NOTE"
has "${SKILLS}/codereview/SKILL.md" "Not listed in Accepted Risks.*re-report at original severity" \
  "codereview: non-accepted findings re-report at original severity"
has "${SKILLS}/codereview/SKILL.md" "Do not auto-fix.*explicit human decision" \
  "codereview: Accepted Risks findings are not auto-fixed"
has "${SKILLS}/codereview/SKILL.md" "Unreviewed findings must not silently lose severity" \
  "codereview: unreviewed findings must not silently lose severity"
has "${SKILLS}/codereview/SKILL.md" "Carry forward the Accepted Risks section" \
  "codereview: Accepted Risks carried forward across reviews"

# --- Cross-skill context graph ---
# Structural enforcement of the DAG: who reads what, terminal nodes.

echo ""
echo "==> Cross-skill context graph"

# Codereview reads SPEC.md for spec alignment
has "${SKILLS}/codereview/SKILL.md" "SPEC.md.*acceptance criteria" \
  "codereview: reads SPEC.md for spec alignment"
has "${SKILLS}/codereview/SKILL.md" "Spec alignment" \
  "codereview: spec alignment is a review dimension"
has "${SKILLS}/codereview/SKILL.md" "no SPEC.md.*skip silently" \
  "codereview: no SPEC.md does not nag"

# Architect is a terminal node (no persistent output file)
has "${SKILLS}/architect/SKILL.md" "does not produce a persistent" \
  "architect: terminal node (no persistent output file)"

# NOTE severity is never auto-fixed (codereview declares it, codefix enforces it)
has "${SKILLS}/codereview/SKILL.md" "Do not auto-fix these" \
  "codereview: NOTE findings not auto-fixed"

# --- Pressure test existence ---
# Review skills must have a pressure-test step to catch false positives.

echo ""
echo "==> Pressure test existence"

has "${SKILLS}/codereview/SKILL.md" "Step 4.5.*Pressure Test" \
  "codereview: has pressure test step"
has "${SKILLS}/security/SKILL.md" "Step 3.5.*Pressure Test" \
  "security: has pressure test step"

# --- Codefix additional constraints ---

echo ""
echo "==> Codefix constraints"

has "${SKILLS}/codefix/SKILL.md" "One fix at a time" \
  "codefix: one-fix-at-a-time constraint"
has "${SKILLS}/codefix/SKILL.md" "No self-evaluation" \
  "codefix: no self-evaluation principle"
has "${SKILLS}/codefix/SKILL.md" "Do not.*re-run the review" \
  "codefix: does not re-run review"

# --- External reviewer integration ---
# Codereview Step 5.5 must call review-external.sh correctly.

echo ""
echo "==> External reviewer integration"

# Skill step exists and references the script
has "${SKILLS}/codereview/SKILL.md" "Step 5.5.*External" \
  "codereview: Step 5.5 is external reviewer step"
has "${SKILLS}/codereview/SKILL.md" "review-external.sh" \
  "codereview: references review-external.sh by name"

# Gating: when it runs vs. when it's skipped
has "${SKILLS}/codereview/SKILL.md" "Skipped for light review" \
  "codereview: external reviewers skipped for light review"
has "${SKILLS}/codereview/SKILL.md" "External reviewers.*once.*initial review" \
  "codereview: external reviewers run once only"
has "${SKILLS}/codereview/SKILL.md" "not on PATH.*skip silently" \
  "codereview: silent skip when script missing or no output"

# Diff excludes review files (same exclusions as marker hash)
has "${SKILLS}/codereview/SKILL.md" ":!CODEREVIEW.*review-external" \
  "codereview: diff piped to external excludes review files"

# Stderr capture and cost log routing
has "${SKILLS}/codereview/SKILL.md" "2>" \
  "codereview: captures external stderr separately"
has "${SKILLS}/codereview/SKILL.md" "cost log" \
  "codereview: routes cost log to CODEREVIEW.md"

# Cost log uses mktemp, not a fixed global path (prevents concurrent collision)
has "${SKILLS}/codereview/SKILL.md" "mktemp.*/tmp/.*cost" \
  "codereview: cost log uses mktemp (no fixed /tmp path)"

# CODEREVIEW.md template covers all exit states
has "${SKILLS}/codereview/SKILL.md" "External reviewers:" \
  "codereview: CODEREVIEW.md template has External reviewers section"
has "${SKILLS}/codereview/SKILL.md" "None configured" \
  "codereview: template covers no-providers-configured state"
has "${SKILLS}/codereview/SKILL.md" 'Skipped.*light review' \
  "codereview: template covers light-review skip state"

# Provider tag preservation through to findings and fixes
has "${SKILLS}/codereview/SKILL.md" "provider.*tag" \
  "codereview: preserves provider tags in findings"
has "${SKILLS}/codereview/SKILL.md" "provider attribution" \
  "codereview: fixes section attributes external findings to provider"

# Script-level contracts (structural, not runtime)
SCRIPT="${REPO_DIR}/bin/review-external.sh"
has "${SCRIPT}" "REVIEW_TIMEOUT" \
  "script: configurable per-provider timeout"
has "${SCRIPT}" 'max-time.*TIMEOUT' \
  "script: timeout applied to curl calls"
has "${SCRIPT}" "GEMINI_EFFORT.*not a valid" \
  "script: validates GEMINI_EFFORT is numeric"
has "${SCRIPT}" 'BLOCK.WARN.NOTE' \
  "script: output format uses BLOCK/WARN/NOTE severity tags"
has "${SCRIPT}" 'sed.*openai' \
  "script: tags openai findings with provider name"
has "${SCRIPT}" 'sed.*google' \
  "script: tags google findings with provider name"
has "${SCRIPT}" "exit 0" \
  "script: always exits 0 (fail-open)"
hasnt "${SCRIPT}" "exit 1" \
  "script: never exits non-zero on provider failure"

# --- Codereview bypass ---
# Skill description must not contain bypass instructions.

echo ""
echo "==> Codereview bypass removed"

hasnt "${SKILLS}/codereview/SKILL.md" "touch.*/tmp/.*codereview" \
  "codereview: no bypass touch command in description"

# --- Accepted Risks ---
# Both codereview and security must have Accepted Risks in their templates.

echo ""
echo "==> Accepted Risks consistency"

has "${SKILLS}/codereview/SKILL.md" "Accepted Risks" \
  "codereview: template has Accepted Risks section"
has "${SKILLS}/security/SKILL.md" "Accepted Risks" \
  "security: template has Accepted Risks section"
has "${SKILLS}/codereview/SKILL.md" "Listed in Accepted Risks" \
  "codereview: carry-forward checks Accepted Risks"

# --- Skill frontmatter ---
# Required fields for each skill.

echo ""
echo "==> Skill frontmatter"

for skill_dir in "${SKILLS}"/*/; do
  name="$(basename "${skill_dir}")"
  file="${skill_dir}SKILL.md"
  [[ -f "${file}" ]] || continue
  has "${file}" "^name:" "${name}: has name"
  has "${file}" "^description:" "${name}: has description"
  has "${file}" "^context:" "${name}: has context"
done

# --- Shellcheck ---

echo ""
echo "==> Shellcheck"

if command -v shellcheck >/dev/null 2>&1; then
  for script in "${REPO_DIR}/hooks"/*.sh "${REPO_DIR}/bin"/*; do
    [[ -f "${script}" ]] || continue
    name="$(basename "${script}")"
    if shellcheck -S warning "${script}" >/dev/null 2>&1; then
      pass "shellcheck: ${name}"
    else
      fail "shellcheck: ${name}"
      shellcheck -S warning "${script}" 2>&1 | sed 's/^/         /' | head -20
    fi
  done
else
  echo "  skip (shellcheck not installed)"
fi

# --- Summary ---

echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
