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
  # has <file> <pattern> <label> — pass if pattern found.
  # `--` terminates grep option parsing so patterns starting with `-`
  # (e.g. "-C", "--git-dir") are treated as patterns, not options.
  if [[ ! -f "$1" ]]; then fail "$3 [FILE MISSING: $1]"; return; fi
  if grep -qE -- "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

hasnt() {
  # hasnt <file> <pattern> <label> — pass if pattern NOT found
  if [[ ! -f "$1" ]]; then fail "$3 [FILE MISSING: $1]"; return; fi
  if grep -qE -- "$2" "$1" 2>/dev/null; then fail "$3"; else pass "$3"; fi
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

# Marker hash algorithm must match between skill and hook.
# Both must use sha256sum truncated to 16 chars with the same diff command.
SKILL_HASH_CMD=$(grep 'sha256sum.*cut' "${SKILLS}/codereview/SKILL.md" | head -1 | sed 's/.*|//' | xargs)
HOOK_HASH_CMD=$(grep 'sha256sum.*cut' "${HOOK}" | head -1 | sed 's/.*|//' | xargs)
if [[ "${SKILL_HASH_CMD}" == "${HOOK_HASH_CMD}" ]] && [[ -n "${SKILL_HASH_CMD}" ]]; then
  pass "marker: skill and hook use identical hash truncation (${SKILL_HASH_CMD})"
else
  fail "marker: hash computation mismatch -- skill=[${SKILL_HASH_CMD}] hook=[${HOOK_HASH_CMD}]"
fi

# Hook blocks when marker missing or mismatched
has "${HOOK}" "exit 2" \
  "hook: exits non-zero to block push"
has "${HOOK}" 'STORED_HASH.*DIFF_HASH' \
  "hook: compares stored marker hash against current diff"

# Hook: tag-only pushes bypass gate
has "${HOOK}" "is_tag_only_push" \
  "hook: tag-only pushes skip codereview gate (is_tag_only_push function)"

# Hook: git-push detection uses a tokenizer, not a prefix match.
# The earlier prefix-match implementation silently bypassed the gate on
# `git -C <dir> push` and similar forms — a real bug that reached main.
has "${HOOK}" "is_git_push" \
  "hook: git-push detection uses is_git_push tokenizer"
hasnt "${HOOK}" '!= git\\ push\*' \
  "hook: no legacy 'git push*' prefix match (regression guard)"

# Hook: tokenizer must handle git-level options that take separate arguments.
# If any of these are missing from the case block, commands like `git -C dir push`
# would fall through and be missed.
for opt in "-C" "-c" "--git-dir" "--work-tree" "--namespace" "--exec-path" "--super-prefix" "--config-env"; do
  has "${HOOK}" "${opt}" \
    "hook: is_git_push handles ${opt} option"
done

# Hook: empty non-excluded diff is explicitly allowed with a stderr log.
# Without this, a review-files-only commit on an already-reviewed base would
# be blocked because the stored marker hash wouldn't match the empty-diff hash.
has "${HOOK}" "git diff --quiet.*:!CODEREVIEW" \
  "hook: empty non-excluded diff allow path uses git diff --quiet"
has "${HOOK}" "no reviewable changes" \
  "hook: empty-diff allow path logs a stderr explanation"

# Hook: no leftover diagnostic trace from investigation.
hasnt "${HOOK}" "hook.*trace" \
  "hook: no diagnostic trace log (cleanup after investigation)"
hasnt "${HOOK}" "TEMPORARY.*REMOVE" \
  "hook: no leftover TEMPORARY comment"

# Hook: skip marker consumed on use (rm before exit 0)
has "${HOOK}" 'rm.*SKIP_MARKER' \
  "hook: skip marker consumed on use"

# Hook: codereview marker persists after push (NOT consumed).
# The only rm in the hook should be for SKIP_MARKER, not MARKER.
has "${HOOK}" "Marker is kept" \
  "hook: codereview marker persists after push (documented)"

# Marker file path format must match between skill and hook.
# Both must use /tmp/.claude-codereview-${PROJ_HASH} (not skip variant).
has "${SKILLS}/codereview/SKILL.md" '/tmp/.claude-codereview-' \
  "codereview: marker path uses expected /tmp/.claude-codereview- prefix"
has "${HOOK}" '/tmp/.claude-codereview-\$' \
  "hook: marker path uses expected /tmp/.claude-codereview- prefix"

# Skip marker path must match between codereview-skip script and hook.
SKIP_SCRIPT="${REPO_DIR}/bin/codereview-skip"
SKIP_PATH_SCRIPT=$(grep -oP '/tmp/\.claude-codereview-skip-[^"]+' "${SKIP_SCRIPT}" | head -1)
SKIP_PATH_HOOK=$(grep -oP '/tmp/\.claude-codereview-skip-[^"]+' "${HOOK}" | head -1)
if [[ "${SKIP_PATH_SCRIPT}" == "${SKIP_PATH_HOOK}" ]] && [[ -n "${SKIP_PATH_SCRIPT}" ]]; then
  pass "skip marker: script and hook use identical path template"
else
  fail "skip marker: path mismatch -- script=[${SKIP_PATH_SCRIPT}] hook=[${SKIP_PATH_HOOK}]"
fi

# codereview-skip PROJ_HASH must use the same derivation as the hook.
SKIP_PROJ_HASH=$(grep "PROJ_HASH=" "${SKIP_SCRIPT}" | grep -oP 'md5sum \| cut -c\d+-\d+')
HOOK_PROJ_HASH_M=$(grep "PROJ_HASH=" "${HOOK}" | head -1 | grep -oP 'md5sum \| cut -c\d+-\d+')
if [[ "${SKIP_PROJ_HASH}" == "${HOOK_PROJ_HASH_M}" ]] && [[ -n "${SKIP_PROJ_HASH}" ]]; then
  pass "skip marker: codereview-skip and hook use identical PROJ_HASH derivation"
else
  fail "skip marker: PROJ_HASH mismatch -- script=[${SKIP_PROJ_HASH}] hook=[${HOOK_PROJ_HASH_M}]"
fi

# --- REVIEW_META field contract ---
# Fields written by codereview Step 9 must match fields read by
# codereview refresh detection (Step 2) and /pr merge gate.

echo ""
echo "==> REVIEW_META field contracts"

# Codereview refresh detection reads: reviewed_up_to, block, base
# These must exist in the Step 9 template.
for field in reviewed_up_to block base; do
  has "${SKILLS}/codereview/SKILL.md" "\"${field}\"" \
    "REVIEW_META: codereview writes '${field}' (read by refresh detection)"
done

# PR merge gate reads: block, reviewed_up_to via grep patterns.
# Verify the grep patterns in /pr match the field names in codereview's template.
PR_BLOCK_FIELD=$(grep -oP '"block"' "${SKILLS}/pr/SKILL.md" | head -1)
CR_BLOCK_FIELD=$(grep -oP '"block"' "${SKILLS}/codereview/SKILL.md" | head -1)
if [[ "${PR_BLOCK_FIELD}" == "${CR_BLOCK_FIELD}" ]] && [[ -n "${PR_BLOCK_FIELD}" ]]; then
  pass "REVIEW_META: pr and codereview use identical 'block' field name"
else
  fail "REVIEW_META: 'block' field name mismatch between pr and codereview"
fi

PR_REVIEWED_FIELD=$(grep -oP '"reviewed_up_to"' "${SKILLS}/pr/SKILL.md" | head -1)
CR_REVIEWED_FIELD=$(grep -oP '"reviewed_up_to"' "${SKILLS}/codereview/SKILL.md" | head -1)
if [[ "${PR_REVIEWED_FIELD}" == "${CR_REVIEWED_FIELD}" ]] && [[ -n "${PR_REVIEWED_FIELD}" ]]; then
  pass "REVIEW_META: pr and codereview use identical 'reviewed_up_to' field name"
else
  fail "REVIEW_META: 'reviewed_up_to' field name mismatch between pr and codereview"
fi

# PR merge uses REVIEW_META, NOT the marker file. README must agree.
hasnt "${README}" '/pr merge.*marker\b' \
  "README: /pr merge does not reference marker file"
has "${README}" '/pr merge.*REVIEW_META' \
  "README: /pr merge references REVIEW_META"

# --- Agent boundary risks ---
# Guards against LLM non-determinism at the prompt/infrastructure boundary.
# These catch regressions where prompt changes could let the agent bypass
# hard-coded safety gates or violate role separation.

echo ""
echo "==> Agent boundary risks"

# Risk: codereview has Bash(*) and could modify source via sed/cat/echo.
# The "Never fix" principle is the only guard. It must be in the Prompt
# Design Principles section (read first, before steps) not buried in a step.
has "${SKILLS}/codereview/SKILL.md" "Prompt Design Principles" \
  "codereview: has Prompt Design Principles section"
# The never-fix rule must appear BEFORE the first step (i.e., in the principles,
# not just somewhere in the file). Extract line numbers and compare.
NEVER_FIX_LINE=$(grep -n "Never fix code yourself" "${SKILLS}/codereview/SKILL.md" | head -1 | cut -d: -f1)
FIRST_STEP_LINE=$(grep -n "^## Step 1" "${SKILLS}/codereview/SKILL.md" | head -1 | cut -d: -f1)
if [[ -n "${NEVER_FIX_LINE}" ]] && [[ -n "${FIRST_STEP_LINE}" ]] && [[ "${NEVER_FIX_LINE}" -lt "${FIRST_STEP_LINE}" ]]; then
  pass "codereview: never-fix rule appears before Step 1 (line ${NEVER_FIX_LINE} < ${FIRST_STEP_LINE})"
else
  fail "codereview: never-fix rule must appear before Step 1 to be read early"
fi

# Risk: codefix has Bash(*) and could modify CODEREVIEW.md via shell redirect.
# The "do not modify" list must name all review state files explicitly.
for f in CODEREVIEW.md SECURITY.md TESTING.md SPEC.md; do
  has "${SKILLS}/codefix/SKILL.md" "${f}" \
    "codefix: explicitly names ${f} in do-not-modify list"
done

# Risk: hook stderr tells the agent how to bypass the gate. The message
# must say "Do not offer to skip" to prevent autonomous bypass.
has "${HOOK}" "Do not offer to skip" \
  "hook: stderr instructs agent not to offer skip"
has "${HOOK}" "user explicitly says" \
  "hook: bypass requires explicit user instruction"

# Risk: codereview writes marker via a bash snippet the LLM interprets.
# If the PROJ_HASH computation drifts between skill and hook, hashes diverge
# silently (review passes but push is blocked). Both must use the same formula.
# Compare the hash derivation core (md5sum + cut), ignoring error handling.
SKILL_PROJ_HASH=$(grep "PROJ_HASH=" "${SKILLS}/codereview/SKILL.md" | head -1 | grep -oP 'md5sum \| cut -c\d+-\d+')
HOOK_PROJ_HASH=$(grep "PROJ_HASH=" "${HOOK}" | head -1 | grep -oP 'md5sum \| cut -c\d+-\d+')
if [[ "${SKILL_PROJ_HASH}" == "${HOOK_PROJ_HASH}" ]] && [[ -n "${SKILL_PROJ_HASH}" ]]; then
  pass "marker: skill and hook use identical PROJ_HASH derivation (${SKILL_PROJ_HASH})"
else
  fail "marker: PROJ_HASH derivation mismatch -- skill=[${SKILL_PROJ_HASH}] hook=[${HOOK_PROJ_HASH}]"
fi

# --- Plan-mode handoff contract ---
# The /spec plan mode and the post-ExitPlanMode hook are a two-piece contract.
# If they drift (renamed mode, moved hook, changed message) the handoff breaks
# silently: the hook still reminds about a keyword the skill no longer recognizes,
# or the skill waits for a handoff the hook no longer triggers.

echo ""
echo "==> Plan-mode handoff contract"

PLAN_HOOK="${REPO_DIR}/hooks/post-tool-exit-plan-mode.sh"
INSTALL="${REPO_DIR}/zat.env-install.sh"

# Spec skill declares plan mode in frontmatter argument-hint
has "${SKILLS}/spec/SKILL.md" "argument-hint:.*plan" \
  "spec: argument-hint advertises plan mode"

# Spec skill has a Step 3e for plan adoption
has "${SKILLS}/spec/SKILL.md" "Step 3e.*Plan Adoption" \
  "spec: Step 3e is Plan Adoption Mode"

# Step 2 router must include 'plan' as a keyword branch
has "${SKILLS}/spec/SKILL.md" '`plan` or `plan <slug>`' \
  "spec: Step 2 router has plan keyword branch"

# The router must explicitly note that 'plan' wins over "no SPEC.md"
has "${SKILLS}/spec/SKILL.md" "Wins over every other branch" \
  "spec: plan keyword wins over no-SPEC.md fallback"

# Spec skill must NOT still have the old advisory plan read in Step 1.
# The old text was "Check ~/.claude/plans/ for the most recently modified"
hasnt "${SKILLS}/spec/SKILL.md" "Check .*plans.*most recently modified" \
  "spec: removed legacy advisory plan read from Step 1"

# Spec skill must still explicitly name the plans directory in Step 3e
# (that is where the plan files are located)
has "${SKILLS}/spec/SKILL.md" 'ls -t.*plans.*\.md.*head' \
  "spec: Step 3e locates most-recent plan via ls -t"

# Spec skill's under-specification escape hatch points at /spec plan
has "${SKILLS}/spec/SKILL.md" "/spec plan.*convert the saved plan" \
  "spec: under-specification escape hatch points at /spec plan"

# The hook file exists and is executable
if [[ -x "${PLAN_HOOK}" ]]; then
  pass "hook: post-tool-exit-plan-mode.sh exists and is executable"
else
  fail "hook: post-tool-exit-plan-mode.sh missing or not executable"
fi

# The hook's reminder text mentions /spec plan by name so the main-context
# Claude knows which keyword to use
has "${PLAN_HOOK}" '/spec plan' \
  "hook: reminder mentions /spec plan keyword"

# The hook double-checks tool_name as a safety net against matcher drift
has "${PLAN_HOOK}" '"ExitPlanMode"' \
  "hook: guards on tool_name == ExitPlanMode"

# The install script registers the hook with the correct matcher
has "${INSTALL}" '"matcher": "ExitPlanMode"' \
  "install: registers hook with ExitPlanMode matcher"

# The install script references the hook by filename so the stale-hook pruner
# and the register block both find the same script
has "${INSTALL}" "post-tool-exit-plan-mode.sh" \
  "install: references post-tool-exit-plan-mode.sh by name"

# The install script uses PostToolUse (not PreToolUse) for the plan hook
has "${INSTALL}" '\.hooks\.PostToolUse.*post-tool-exit-plan-mode' \
  "install: plan hook is registered under PostToolUse"

# --- BACKLOG.md contracts ---
# Producer-consumer pairs within the spec skill, the approval phrase that the
# main-thread agent interprets, and the entry template field labels. These are
# prompt-level contracts with no runtime gate; rename in one site and the
# counterpart silently misses entries.

echo ""
echo "==> BACKLOG.md contracts"

# "Revisit candidates" subsection: written in Step 3d, consumed in Step 3b.
# Must appear at least twice (producer + consumer).
REVISIT_COUNT=$(grep -c "Revisit candidates" "${SKILLS}/spec/SKILL.md" || true)
if [[ "${REVISIT_COUNT}" -ge 2 ]]; then
  pass "spec: BACKLOG.md 'Revisit candidates' has producer and consumer"
else
  fail "spec: BACKLOG.md 'Revisit candidates' appears <2 times (producer/consumer pair broken)"
fi

# "Backlog Sweep" subsection: written in Step 3c.5, consumed in Step 3b,
# summarized in Step 5. Must appear at least three times.
SWEEP_COUNT=$(grep -c "Backlog Sweep" "${SKILLS}/spec/SKILL.md" || true)
if [[ "${SWEEP_COUNT}" -ge 3 ]]; then
  pass "spec: BACKLOG.md 'Backlog Sweep' referenced by producer, consumer, and summary"
else
  fail "spec: BACKLOG.md 'Backlog Sweep' appears <3 times (producer/consumer/summary)"
fi

# Approval phrase: literal that the main-thread agent interprets from user reply.
# Produced in the Step 3c.5 sweep format and echoed in Step 5 Confirm.
APPROVE_COUNT=$(grep -c "approve backlog deletions" "${SKILLS}/spec/SKILL.md" || true)
if [[ "${APPROVE_COUNT}" -ge 2 ]]; then
  pass "spec: BACKLOG.md approval phrase appears in both producer and summary"
else
  fail "spec: BACKLOG.md approval phrase appears <2 times (sweep + summary contract broken)"
fi

# Entry template field labels. The template is inlined in Step 3c for the
# main-thread handoff and also listed in the tail Format section. Both copies
# must carry the same four fields.
for field in "One-line description" "Why deferred" "Revisit criteria" "Origin"; do
  FIELD_COUNT=$(grep -c "\*\*${field}" "${SKILLS}/spec/SKILL.md" || true)
  if [[ "${FIELD_COUNT}" -ge 2 ]]; then
    pass "spec: BACKLOG.md entry field '${field}' appears in inline template and tail Format"
  else
    fail "spec: BACKLOG.md entry field '${field}' appears <2 times (template duplication drifted)"
  fi
done

# Step 3.6 shared subroutine must exist and be referenced by Steps 3a, 3b, 3e.
has "${SKILLS}/spec/SKILL.md" "Step 3.6.*BACKLOG.md Overlap Scan" \
  "spec: Step 3.6 BACKLOG.md overlap scan subroutine exists"
REF_COUNT=$(grep -c "Step 3.6" "${SKILLS}/spec/SKILL.md" || true)
if [[ "${REF_COUNT}" -ge 4 ]]; then
  pass "spec: Step 3.6 referenced by its three callers plus the section heading"
else
  fail "spec: Step 3.6 referenced <4 times (expected heading + 3 callers in 3a/3b/3e)"
fi

# Backlog append mode (Step 3f): new keyword in argument-hint, routing branch
# in Step 2, Step 3f section exists, Step 5 Confirm has the append variant,
# and Step 5 advertises the add syntax as part of BACKLOG surfacing.
has "${SKILLS}/spec/SKILL.md" "argument-hint:.*backlog" \
  "spec: argument-hint advertises backlog mode"
has "${SKILLS}/spec/SKILL.md" '`backlog <description>`' \
  "spec: Step 2 router has backlog keyword branch"
has "${SKILLS}/spec/SKILL.md" "Step 3f.*Backlog Append Mode" \
  "spec: Step 3f Backlog Append Mode section exists"
has "${SKILLS}/spec/SKILL.md" '"Added `<short name>` to BACKLOG.md' \
  "spec: Step 5 Confirm has backlog-append variant"
has "${SKILLS}/spec/SKILL.md" '/spec backlog <description>' \
  "spec: Step 5 surfacing advertises /spec backlog add syntax"

# Step 3f pressure test must enforce specificity, revisit criterion, and
# why-deferred reason. These are the three gates that keep BACKLOG entries
# from turning into vague prose.
has "${SKILLS}/spec/SKILL.md" "Is the description specific" \
  "spec: Step 3f pressure test checks description specificity"
has "${SKILLS}/spec/SKILL.md" "Can a revisit criterion be derived" \
  "spec: Step 3f pressure test checks revisit criterion"
has "${SKILLS}/spec/SKILL.md" "Is the why-deferred reason concrete" \
  "spec: Step 3f pressure test checks why-deferred reason"

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
has "${SCRIPT}" 'LOCAL_REVIEW_SCRIPT.*LOCAL_REVIEW_VENV.*-f' \
  "script: local provider gates on vars and file existence"
has "${SCRIPT}" "GEMINI_EFFORT.*not a valid" \
  "script: validates GEMINI_EFFORT is numeric"
has "${SCRIPT}" 'BLOCK.WARN.NOTE' \
  "script: output format uses BLOCK/WARN/NOTE severity tags"
has "${SCRIPT}" 'sed.*openai' \
  "script: tags openai findings with provider name"
has "${SCRIPT}" 'sed.*google' \
  "script: tags google findings with provider name"
has "${SCRIPT}" 'sed.*qwen' \
  "script: tags local findings with provider name"
has "${SCRIPT}" "exit 0" \
  "script: always exits 0 (fail-open)"
hasnt "${SCRIPT}" "exit 1[^0-9]|exit 1$" \
  "script: never exits non-zero on provider failure"

# --- Concurrency safety ---
# Temp files must use mktemp (not fixed paths). Background processes must
# be waited on before cleanup. Config must be overridable for test isolation.

echo ""
echo "==> Concurrency safety"

# review-external.sh: all temp files use mktemp
for varname in SYSTEM_FILE USER_FILE OPENAI_OUT GOOGLE_OUT LOCAL_OUT; do
  has "${SCRIPT}" "${varname}=.\(mktemp" \
    "script: ${varname} uses mktemp"
done

# review-external.sh: EXIT trap waits for background jobs before cleanup
has "${SCRIPT}" "trap.*wait.*rm" \
  "script: EXIT trap waits for background jobs before cleanup"

# review-external.sh: background job PIDs captured and waited on
has "${SCRIPT}" 'OPENAI_PID=\$!' \
  "script: captures openai background PID"
has "${SCRIPT}" 'GOOGLE_PID=\$!' \
  "script: captures google background PID"
has "${SCRIPT}" "wait.*OPENAI_PID" \
  "script: waits for openai background job"
has "${SCRIPT}" "wait.*GOOGLE_PID" \
  "script: waits for google background job"
has "${SCRIPT}" 'LOCAL_PID=\$!' \
  "script: captures local background PID"
has "${SCRIPT}" "wait.*LOCAL_PID" \
  "script: waits for local background job"

# review-external.sh: config path overridable for test isolation
has "${SCRIPT}" "CLAUDE_REVIEWER_ENV" \
  "script: config path overridable via CLAUDE_REVIEWER_ENV"

# Codereview skill: no fixed /tmp paths (all use mktemp or project-scoped hash)
hasnt "${SKILLS}/codereview/SKILL.md" '/tmp/\.claude-external-cost\.log' \
  "codereview: no fixed /tmp cost log path (must use mktemp)"

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
  for script in "${REPO_DIR}/hooks"/*.sh "${REPO_DIR}/bin"/* \
                "${REPO_DIR}/hw-bootstrap.sh" "${REPO_DIR}/zat.env-install.sh" \
                "${REPO_DIR}/tests"/*.sh; do
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
