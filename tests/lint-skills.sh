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

# Step 6.5 must write CODEREVIEW.md before invoking codefix
has "${SKILLS}/codereview/SKILL.md" "Step 6.5.*Preliminary CODEREVIEW" \
  "codereview: Step 6.5 writes preliminary CODEREVIEW.md before codefix"
has "${SKILLS}/codereview/SKILL.md" "findings must be on disk before.*invoked" \
  "codereview: documents why preliminary write is needed"

# Step 7 delegates to codefix with a cycle limit
has "${SKILLS}/codereview/SKILL.md" "Step 7.*Fix.*Loop" \
  "codereview: Step 7 is the fix/re-review loop"
has "${SKILLS}/codereview/SKILL.md" "Cycle limit: 3" \
  "codereview: 3-cycle cap on fix loop"

# Codefix reads the same severity tags that codereview writes
has "${SKILLS}/codefix/SKILL.md" "BLOCK.*WARN" \
  "codefix: parses BLOCK and WARN severities"
has "${SKILLS}/codereview/SKILL.md" '^\[SEVERITY\]' \
  "codereview: finding format template matches codefix expectation"
has "${SKILLS}/codefix/SKILL.md" "file.*line" \
  "codefix: parses file and line from findings"

# Codefix must not modify review state files
has "${SKILLS}/codefix/SKILL.md" "Modify CODEREVIEW.md" \
  "codefix: explicitly told not to modify CODEREVIEW.md"

# Codereview must not re-run external reviewers during fix cycles
has "${SKILLS}/codereview/SKILL.md" "Do NOT re-run" \
  "codereview: no external reviewers during fix/re-review cycles"

# --- External reviewer integration ---
# Codereview Step 5.5 must call review-external.sh correctly.

echo ""
echo "==> External reviewer integration"

has "${SKILLS}/codereview/SKILL.md" "Step 5.5.*External" \
  "codereview: Step 5.5 is external reviewer step"
has "${SKILLS}/codereview/SKILL.md" "review-external.sh" \
  "codereview: references review-external.sh by name"
has "${SKILLS}/codereview/SKILL.md" "Skipped for light review" \
  "codereview: external reviewers skipped for light review"
has "${SKILLS}/codereview/SKILL.md" "External reviewers.*once.*initial review" \
  "codereview: external reviewers run once only"
has "${SKILLS}/codereview/SKILL.md" "provider.*tag" \
  "codereview: preserves provider tags in findings"

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
