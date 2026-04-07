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

echo ""
echo "==> Security chain coverage"

has "${SKILLS}/codereview/SKILL.md" "NEEDED" \
  "codereview: computes NEEDED files vs upstream"
has "${SKILLS}/codereview/SKILL.md" "scanned_files" \
  "codereview: checks scanned_files for coverage"
has "${SKILLS}/security/SKILL.md" "scope.*paths" \
  "security: supports paths scope"

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
