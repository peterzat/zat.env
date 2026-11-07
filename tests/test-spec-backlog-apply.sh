#!/usr/bin/env bash
set -uo pipefail

# Tests for bin/spec-backlog-apply.sh.
#
# Covers:
#   - delete: and adopt: regression (unchanged by purge-origin addition)
#   - purge-origin: match, ACTIVE preservation, zero-match success,
#     backtick and bullet-marker variations, empty-prefix safety,
#     combination with delete/adopt in one manifest
#   - missing BACKLOG.md fall-through
#   - append: new entry, collisions, file creation, unterminated block
#   - clear: header kept (fenced examples included), headerless file,
#     refused beside any other op; append: with no heading refused
#   - fenced ### lines are not entries for delete/adopt/purge/append
#   - an unclosed fence in an entry body does not hide later entries
#   - symlinked (live or dangling) or non-regular BACKLOG.md is refused
#   - CRLF file: purge-origin keeps the ACTIVE entry; delete, adopt, and
#     the append collision check find their headings

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${REPO_DIR}/bin/spec-backlog-apply.sh"

FAILS=0
TOTAL=0
pass() { TOTAL=$((TOTAL + 1)); printf '  ok   %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }

# Without the check, a failed mktemp left pushd in the caller's directory,
# and every case ran against that directory's BACKLOG.md.
TEST_DIR=$(mktemp -d) || exit 1
cleanup() { rm -rf "${TEST_DIR}"; }
trap cleanup EXIT

# Build a standard multi-entry BACKLOG.md fixture at $1.
fixture_standard() {
  cat > "$1" <<'EOF'
# Backlog

Durable register of considered proposals.

### keep-spec
- **One-line description** generic spec item.
- **Why deferred:** not now.
- **Revisit criteria:** when ready.
- **Origin:** spec 2026-04-01

### tester-one
- **One-line description** first tester rollout.
- **Why deferred:** rollout.
- **Revisit criteria:** tier lands.
- **Origin:** `tester design 2026-04-24`

### tester-active (ACTIVE in spec 2026-04-20)
- **One-line description** tester item adopted into a spec.
- **Why deferred:** originally deferred.
- **Revisit criteria:** drift probe added.
- **Origin:** `tester design 2026-04-20`

### tester-two
- **One-line description** second tester rollout.
- **Why deferred:** rollout.
- **Revisit criteria:** tier lands.
- **Origin:** tester design 2026-04-24

### star-bullet
* **One-line description** uses asterisk bullets.
* **Why deferred:** rollout.
* **Revisit criteria:** tier lands.
* **Origin:** `tester design 2026-04-24`

### tester-minus-dash
- **One-line description** false-positive canary.
- **Why deferred:** has hyphenated origin.
- **Revisit criteria:** never match.
- **Origin:** tester-design-other 2026-04-24
EOF
}

# ============================================================
echo "==> delete: regression"
# ============================================================

BACKLOG="${TEST_DIR}/BACKLOG.md"
fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: keep-spec
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "delete: exit 0"; else fail "delete: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^DELETED: keep-spec$"; then pass "delete: DELETED line emitted"; else fail "delete: missing DELETED line"; fi
if ! grep -q "^### keep-spec$" "${BACKLOG}"; then pass "delete: entry removed from file"; else fail "delete: entry still present"; fi
if grep -q "^### tester-active (ACTIVE" "${BACKLOG}"; then pass "delete: other entries preserved"; else fail "delete: unrelated entry missing"; fi

# ============================================================
echo ""
echo "==> delete: miss emits MISS and exits non-zero"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: does-not-exist
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -ne 0 ]]; then pass "delete miss: non-zero exit"; else fail "delete miss: expected non-zero exit"; fi
if echo "${OUT}" | grep -q "^MISS: delete: does-not-exist"; then pass "delete miss: MISS line on stderr"; else fail "delete miss: missing MISS line"; fi

# ============================================================
echo ""
echo "==> adopt: regression"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
adopt: keep-spec | 2026-04-24
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "adopt: exit 0"; else fail "adopt: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^ANNOTATED: keep-spec (ACTIVE in spec 2026-04-24)$"; then pass "adopt: ANNOTATED line emitted"; else fail "adopt: missing ANNOTATED line"; fi
if grep -q "^### keep-spec (ACTIVE in spec 2026-04-24)$" "${BACKLOG}"; then pass "adopt: heading annotated in file"; else fail "adopt: annotation not present"; fi

# ============================================================
echo ""
echo "==> purge-origin: basic match purges non-ACTIVE entries"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "purge-origin: exit 0"; else fail "purge-origin: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^PURGED: tester-one (origin prefix: tester design)$"; then pass "purge-origin: PURGED tester-one"; else fail "purge-origin: missing PURGED tester-one"; fi
if echo "${OUT}" | grep -q "^PURGED: tester-two (origin prefix: tester design)$"; then pass "purge-origin: PURGED tester-two"; else fail "purge-origin: missing PURGED tester-two"; fi
if echo "${OUT}" | grep -q "^PURGED: star-bullet (origin prefix: tester design)$"; then pass "purge-origin: PURGED star-bullet (asterisk bullets)"; else fail "purge-origin: missing PURGED star-bullet"; fi
if ! grep -q "^### tester-one$" "${BACKLOG}"; then pass "purge-origin: tester-one removed from file"; else fail "purge-origin: tester-one still present"; fi
if ! grep -q "^### tester-two$" "${BACKLOG}"; then pass "purge-origin: tester-two removed from file"; else fail "purge-origin: tester-two still present"; fi
if ! grep -q "^### star-bullet$" "${BACKLOG}"; then pass "purge-origin: star-bullet removed from file"; else fail "purge-origin: star-bullet still present"; fi

# ============================================================
echo ""
echo "==> purge-origin: ACTIVE entries preserved even when prefix matches"
# ============================================================

if grep -q "^### tester-active (ACTIVE in spec 2026-04-20)$" "${BACKLOG}"; then pass "purge-origin: ACTIVE entry preserved"; else fail "purge-origin: ACTIVE entry incorrectly removed"; fi
if ! echo "${OUT}" | grep -q "tester-active"; then pass "purge-origin: ACTIVE entry not listed as PURGED"; else fail "purge-origin: ACTIVE entry incorrectly listed"; fi

# ============================================================
echo ""
echo "==> purge-origin: unrelated entries (non-matching prefix) preserved"
# ============================================================

if grep -q "^### keep-spec$" "${BACKLOG}"; then pass "purge-origin: spec-origin entry preserved"; else fail "purge-origin: spec-origin entry removed"; fi
if grep -q "^### tester-minus-dash$" "${BACKLOG}"; then pass "purge-origin: hyphenated-origin entry preserved (prefix boundary)"; else fail "purge-origin: hyphenated-origin incorrectly matched"; fi

# ============================================================
echo ""
echo "==> purge-origin: CRLF file keeps the ACTIVE entry"
# ============================================================

# Git for Windows checks out CRLF by default; a trailing CR used to stop the
# ACTIVE annotation from matching, so purge-origin removed adopted work.
fixture_standard "${BACKLOG}"
awk '{ printf "%s\r\n", $0 }' "${BACKLOG}" > "${BACKLOG}.crlf" && mv "${BACKLOG}.crlf" "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "purge-origin CRLF: exit 0"; else fail "purge-origin CRLF: expected exit 0, got ${EC}"; fi
if grep -q $'^### tester-active (ACTIVE in spec 2026-04-20)\r$' "${BACKLOG}"; then pass "purge-origin CRLF: ACTIVE entry preserved with its CRLF"; else fail "purge-origin CRLF: ACTIVE entry removed"; fi
if ! echo "${OUT}" | grep -q "tester-active"; then pass "purge-origin CRLF: ACTIVE entry not listed as PURGED"; else fail "purge-origin CRLF: ACTIVE entry listed as PURGED"; fi
if ! grep -q $'^### tester-one\r$' "${BACKLOG}"; then pass "purge-origin CRLF: non-ACTIVE entry still purged"; else fail "purge-origin CRLF: tester-one still present"; fi

# ============================================================
echo ""
echo "==> delete, adopt, append: CRLF headings still match"
# ============================================================

fixture_standard "${BACKLOG}"
awk '{ printf "%s\r\n", $0 }' "${BACKLOG}" > "${BACKLOG}.crlf" && mv "${BACKLOG}.crlf" "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: tester-one
adopt: tester-two | 2026-05-01
append: keep-spec
- **One-line description:** would duplicate.
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "CRLF ops: exit 0"; else fail "CRLF ops: expected exit 0, got ${EC}: ${OUT}"; fi
if ! grep -q $'^### tester-one\r$' "${BACKLOG}"; then pass "CRLF delete: entry removed"; else fail "CRLF delete: entry still present"; fi
if grep -q '^### tester-two (ACTIVE in spec 2026-05-01)' "${BACKLOG}"; then pass "CRLF adopt: heading annotated"; else fail "CRLF adopt: heading not annotated"; fi
if echo "${OUT}" | grep -q "^SKIPPED: keep-spec"; then pass "CRLF append: existing heading SKIPPED"; else fail "CRLF append: duplicate not detected"; fi
if [[ "$(grep -c '^### keep-spec' "${BACKLOG}")" -eq 1 ]]; then pass "CRLF append: no duplicate heading"; else fail "CRLF append: duplicate heading written"; fi

# ============================================================
echo ""
echo "==> purge-origin: zero matches returns success with no PURGED lines"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: nothing-matches
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "purge-origin zero-match: exit 0"; else fail "purge-origin zero-match: expected exit 0, got ${EC}"; fi
if ! echo "${OUT}" | grep -q "^PURGED:"; then pass "purge-origin zero-match: no PURGED lines"; else fail "purge-origin zero-match: unexpected PURGED lines"; fi
if ! echo "${OUT}" | grep -q "^MISS:"; then pass "purge-origin zero-match: no MISS lines (unlike delete/adopt)"; else fail "purge-origin zero-match: unexpected MISS line"; fi

# ============================================================
echo ""
echo "==> purge-origin: empty prefix is ignored (safety)"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin:
MANIFEST
)
EC=$?
popd >/dev/null || exit
# Empty prefix means no ops in total, script exits 0 before touching file.
if [[ "${EC}" -eq 0 ]]; then pass "purge-origin empty: exit 0"; else fail "purge-origin empty: expected exit 0, got ${EC}"; fi
if ! echo "${OUT}" | grep -q "^PURGED:"; then pass "purge-origin empty: no PURGED lines"; else fail "purge-origin empty: unexpected PURGED line (would match everything)"; fi
# Verify no entries were purged (all still present).
if grep -q "^### tester-one$" "${BACKLOG}"; then pass "purge-origin empty: did not touch file"; else fail "purge-origin empty: file was modified"; fi

# ============================================================
echo ""
echo "==> purge-origin: combined with delete and adopt in one manifest"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: keep-spec
adopt: tester-one | 2026-04-24
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "combined: exit 0"; else fail "combined: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^DELETED: keep-spec$"; then pass "combined: delete ran"; else fail "combined: delete missing"; fi
if echo "${OUT}" | grep -q "^ANNOTATED: tester-one (ACTIVE in spec 2026-04-24)$"; then pass "combined: adopt ran"; else fail "combined: adopt missing"; fi
# tester-one was adopted (ACTIVE), so it should NOT be purged.
if grep -q "^### tester-one (ACTIVE in spec 2026-04-24)$" "${BACKLOG}"; then pass "combined: adopt protects from purge"; else fail "combined: adopted entry was purged"; fi
# tester-two has no adopt, should be purged.
if echo "${OUT}" | grep -q "^PURGED: tester-two"; then pass "combined: purge ran on non-adopted entry"; else fail "combined: purge did not run"; fi
if ! grep -q "^### tester-two$" "${BACKLOG}"; then pass "combined: tester-two removed"; else fail "combined: tester-two still present"; fi

# ============================================================
echo ""
echo "==> purge-origin: missing BACKLOG.md falls through with message"
# ============================================================

rm -f "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "missing file: exit 0"; else fail "missing file: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "BACKLOG.md not found"; then pass "missing file: fall-through message"; else fail "missing file: missing fall-through message"; fi

# ============================================================
echo ""
echo "==> purge-origin: multiple prefixes in one manifest"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
purge-origin: spec
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "multi-prefix: exit 0"; else fail "multi-prefix: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^PURGED: tester-one"; then pass "multi-prefix: purged tester-design match"; else fail "multi-prefix: missing tester purge"; fi
if echo "${OUT}" | grep -q "^PURGED: keep-spec"; then pass "multi-prefix: purged spec match"; else fail "multi-prefix: missing spec purge"; fi
if grep -q "^### tester-active (ACTIVE in spec 2026-04-20)$" "${BACKLOG}"; then pass "multi-prefix: ACTIVE entry still preserved"; else fail "multi-prefix: ACTIVE incorrectly removed"; fi

# ============================================================
echo ""
echo "==> append: basic new entry"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: fresh-rollout
- **One-line description** brand new entry.
- **Why deferred:** out of scope for current contract seed.
- **Revisit criteria:** when CI lands.
- **Origin:** `tester design 2026-04-24`
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "append: exit 0"; else fail "append: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^APPENDED: fresh-rollout$"; then pass "append: APPENDED line emitted"; else fail "append: missing APPENDED line"; fi
if grep -q "^### fresh-rollout$" "${BACKLOG}"; then pass "append: entry heading in file"; else fail "append: heading not in file"; fi
if grep -q "brand new entry" "${BACKLOG}"; then pass "append: body in file"; else fail "append: body missing"; fi
if grep -q "^### keep-spec$" "${BACKLOG}"; then pass "append: preexisting entries untouched"; else fail "append: existing entry lost"; fi

# ============================================================
echo ""
echo "==> append: collision with non-ACTIVE heading is SKIPPED"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: keep-spec
- **One-line description** duplicate heading attempt.
- **Why deferred:** should be skipped.
- **Revisit criteria:** never.
- **Origin:** `tester design 2026-04-24`
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "append collision: exit 0"; else fail "append collision: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^SKIPPED: keep-spec"; then pass "append collision: SKIPPED line"; else fail "append collision: missing SKIPPED line"; fi
if ! echo "${OUT}" | grep -q "^APPENDED: keep-spec"; then pass "append collision: no APPENDED line"; else fail "append collision: should not have appended"; fi
# Count occurrences of "### keep-spec" -- must stay at 1.
keep_count=$(grep -c "^### keep-spec$" "${BACKLOG}" || true)
if [[ "${keep_count}" -eq 1 ]]; then pass "append collision: no duplicate heading created"; else fail "append collision: expected 1 keep-spec heading, got ${keep_count}"; fi

# ============================================================
echo ""
echo "==> append: collision with ACTIVE-annotated heading is SKIPPED"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: tester-active
- **One-line description** attempting to shadow an ACTIVE entry.
- **Why deferred:** should be skipped.
- **Revisit criteria:** never.
- **Origin:** `tester design 2026-04-24`
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "append ACTIVE collision: exit 0"; else fail "append ACTIVE collision: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^SKIPPED: tester-active"; then pass "append ACTIVE collision: SKIPPED line"; else fail "append ACTIVE collision: missing SKIPPED line"; fi
# Original ACTIVE heading must still be intact.
if grep -q "^### tester-active (ACTIVE in spec 2026-04-20)$" "${BACKLOG}"; then pass "append ACTIVE collision: ACTIVE heading preserved"; else fail "append ACTIVE collision: ACTIVE heading altered"; fi

# ============================================================
echo ""
echo "==> append: creates BACKLOG.md with header if file missing"
# ============================================================

rm -f "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: first-ever-entry
- **One-line description** first entry in a new file.
- **Why deferred:** bootstrap.
- **Revisit criteria:** immediately.
- **Origin:** `tester design 2026-04-24`
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "append create: exit 0"; else fail "append create: expected exit 0, got ${EC}"; fi
if [[ -f "${BACKLOG}" ]]; then pass "append create: BACKLOG.md created"; else fail "append create: file not created"; fi
if grep -q "^# Backlog$" "${BACKLOG}"; then pass "append create: header written"; else fail "append create: missing # Backlog header"; fi
if grep -q "^### first-ever-entry$" "${BACKLOG}"; then pass "append create: entry written"; else fail "append create: entry missing"; fi
if echo "${OUT}" | grep -q "^APPENDED: first-ever-entry$"; then pass "append create: APPENDED line"; else fail "append create: missing APPENDED line"; fi

# ============================================================
echo ""
echo "==> append: unterminated block errors out"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: dangling
- **One-line description** no end-append follows.
- **Why deferred:** forgot delimiter.
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -ne 0 ]]; then pass "append unterminated: non-zero exit"; else fail "append unterminated: expected non-zero exit"; fi
if echo "${OUT}" | grep -q "missing end-append"; then pass "append unterminated: error message"; else fail "append unterminated: missing error message"; fi
# File must not have a partial write.
if ! grep -q "^### dangling$" "${BACKLOG}"; then pass "append unterminated: no partial write"; else fail "append unterminated: partial entry written"; fi

# ============================================================
echo ""
echo "==> append: combined purge+append round-trips as expected"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
append: tester-one
- **One-line description** revised rollout entry.
- **Why deferred:** replaced older version.
- **Revisit criteria:** next turn.
- **Origin:** `tester design 2026-04-24`
end-append
append: tester-active
- **One-line description** duplicate of ACTIVE entry.
- **Why deferred:** should be skipped.
- **Revisit criteria:** never.
- **Origin:** `tester design 2026-04-24`
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "combined purge+append: exit 0"; else fail "combined purge+append: expected exit 0, got ${EC}"; fi
# Old tester-one was purged (non-ACTIVE), new tester-one appended.
if echo "${OUT}" | grep -q "^PURGED: tester-one"; then pass "combined purge+append: old tester-one purged"; else fail "combined purge+append: old tester-one not purged"; fi
if echo "${OUT}" | grep -q "^APPENDED: tester-one$"; then pass "combined purge+append: new tester-one appended"; else fail "combined purge+append: new tester-one not appended"; fi
if grep -q "revised rollout entry" "${BACKLOG}"; then pass "combined purge+append: new body in file"; else fail "combined purge+append: new body missing"; fi
# ACTIVE entry preserved through purge, append skipped.
if grep -q "^### tester-active (ACTIVE in spec 2026-04-20)$" "${BACKLOG}"; then pass "combined purge+append: ACTIVE preserved"; else fail "combined purge+append: ACTIVE removed"; fi
if echo "${OUT}" | grep -q "^SKIPPED: tester-active"; then pass "combined purge+append: duplicate append SKIPPED"; else fail "combined purge+append: duplicate append not skipped"; fi

# ============================================================
echo ""
echo "==> clear: removes entries, keeps a project's own header"
# ============================================================

cat > "${BACKLOG}" <<'EOF'
# Backlog

This project's own notes: review findings go to docs/other.md.

```
### an-example-inside-a-fence
- not an entry
```

## Theme A

### first
- **Origin:** spec 2026-04-01

## Theme B

### second (ACTIVE in spec 2026-04-20)
- **Origin:** `tester design 2026-04-20`
EOF
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
clear
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "clear: exit 0"; else fail "clear: expected exit 0, got ${EC}"; fi
if echo "${OUT}" | grep -q "^CLEARED: 2 entries$"; then pass "clear: CLEARED counts entries, not the fenced example"; else fail "clear: wrong or missing CLEARED line: ${OUT}"; fi
if echo "${OUT}" | grep -q "^BACKLOG.md: 0 entries$"; then pass "clear: trailing count is 0"; else fail "clear: trailing count not 0"; fi
if grep -q "^This project's own notes" "${BACKLOG}"; then pass "clear: custom header kept"; else fail "clear: custom header lost"; fi
if grep -q "^### an-example-inside-a-fence$" "${BACKLOG}"; then pass "clear: fenced ### in the header kept"; else fail "clear: fenced ### treated as an entry"; fi
if ! grep -qE "^### (first|second)" "${BACKLOG}"; then pass "clear: entries removed, ACTIVE included"; else fail "clear: an entry survived"; fi
if ! grep -q "^## Theme" "${BACKLOG}"; then pass "clear: emptied theme subheads removed"; else fail "clear: theme subhead left behind"; fi
if [[ "$(tail -n 1 "${BACKLOG}")" == '```' ]]; then pass "clear: no trailing blank lines"; else fail "clear: file does not end at the header's last line"; fi

# ============================================================
echo ""
echo "==> clear: a file with no header gets the standard one"
# ============================================================

printf '### lonely\n- **Origin:** ad-hoc\n' > "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
clear
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "clear headerless: exit 0"; else fail "clear headerless: expected exit 0, got ${EC}"; fi
if grep -q "^# Backlog$" "${BACKLOG}"; then pass "clear headerless: standard header written"; else fail "clear headerless: no header"; fi
if ! grep -q "^### lonely$" "${BACKLOG}"; then pass "clear headerless: entry removed"; else fail "clear headerless: entry survived"; fi

# ============================================================
echo ""
echo "==> clear: refused beside any other op; nothing changes"
# ============================================================

# Only /spec backlog clear sends clear, so a clear beside other ops is a
# stray line. A body line reading exactly end-append ends the block early,
# and the clear after it then reads as an op: the refusal covers that too.
for case_name in with-delete early-end-append; do
  fixture_standard "${BACKLOG}"
  cp "${BACKLOG}" "${TEST_DIR}/before.md"
  pushd "${TEST_DIR}" >/dev/null || exit
  if [[ "${case_name}" == "with-delete" ]]; then
    OUT=$(printf 'delete: keep-spec\nclear\n' | bash "${SCRIPT}" 2>&1)
  else
    OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: early-end
- **One-line description:** body that quotes a manifest.
end-append
clear
end-append
MANIFEST
)
  fi
  EC=$?
  popd >/dev/null || exit
  if [[ "${EC}" -eq 1 ]]; then pass "clear ${case_name}: exit 1"; else fail "clear ${case_name}: expected exit 1, got ${EC}"; fi
  if cmp -s "${BACKLOG}" "${TEST_DIR}/before.md"; then pass "clear ${case_name}: BACKLOG.md unchanged"; else fail "clear ${case_name}: BACKLOG.md changed"; fi
  if echo "${OUT}" | grep -q "clear must be the only op"; then pass "clear ${case_name}: error names the rule"; else fail "clear ${case_name}: missing error: ${OUT}"; fi
done

# ============================================================
echo ""
echo "==> append: a body line 'end-append' ending the block early is refused"
# ============================================================

# The body lines after the early end-append would otherwise run as ops:
# here the delete would remove keep-spec and the real end-append would be
# ignored.
fixture_standard "${BACKLOG}"
cp "${BACKLOG}" "${TEST_DIR}/before.md"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: early-end
- **One-line description:** body that quotes a manifest.
end-append
delete: keep-spec
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 1 ]]; then pass "stray end-append: exit 1"; else fail "stray end-append: expected exit 1, got ${EC}"; fi
if cmp -s "${BACKLOG}" "${TEST_DIR}/before.md"; then pass "stray end-append: BACKLOG.md unchanged"; else fail "stray end-append: BACKLOG.md changed"; fi
if echo "${OUT}" | grep -q "end-append outside an append block"; then pass "stray end-append: error names the rule"; else fail "stray end-append: missing error: ${OUT}"; fi

# ============================================================
echo ""
echo "==> append: a body line 'clear' is body, not an op"
# ============================================================

fixture_standard "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: quotes-clear
- **One-line description:** mentions the op.
clear
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "append body clear: exit 0"; else fail "append body clear: expected exit 0, got ${EC}"; fi
if grep -q "^### quotes-clear$" "${BACKLOG}"; then pass "append body clear: entry appended"; else fail "append body clear: entry missing"; fi
if grep -q "^### keep-spec$" "${BACKLOG}"; then pass "append body clear: other entries kept"; else fail "append body clear: entries cleared"; fi
if [[ "$(grep -c '^clear$' "${BACKLOG}")" -eq 1 ]]; then pass "append body clear: body line stored verbatim"; else fail "append body clear: body line lost or duplicated"; fi

# ============================================================
echo ""
echo "==> append: an empty heading is refused before any op runs"
# ============================================================

# An append: with no heading used to skip the block, so its body lines were
# read as ops and the delete below ran.
fixture_standard "${BACKLOG}"
cp "${BACKLOG}" "${TEST_DIR}/before.md"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append:
delete: keep-spec
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 1 ]]; then pass "append empty heading: exit 1"; else fail "append empty heading: expected exit 1, got ${EC}"; fi
if cmp -s "${BACKLOG}" "${TEST_DIR}/before.md"; then pass "append empty heading: BACKLOG.md unchanged"; else fail "append empty heading: BACKLOG.md changed"; fi

# ============================================================
echo ""
echo "==> fenced ### in the header is not an entry for delete/adopt/purge/append"
# ============================================================

fenced_fixture() {
  cat > "$1" <<'EOF'
# Backlog

Entry format:

```
### <short name>
- **Origin:** `tester design YYYY-MM-DD`
```

### keep
- **Origin:** spec 2026-04-01

### <short name>
- **Origin:** `tester design 2026-04-24`
EOF
}

fenced_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "fenced purge: exit 0"; else fail "fenced purge: expected exit 0, got ${EC}"; fi
if [[ "$(echo "${OUT}" | grep -c '^PURGED: ')" -eq 1 ]]; then pass "fenced purge: only the real entry purged"; else fail "fenced purge: wrong PURGED count: ${OUT}"; fi
if [[ "$(grep -c '^```$' "${BACKLOG}")" -eq 2 ]]; then pass "fenced purge: both fence lines kept"; else fail "fenced purge: a fence line was removed"; fi
if [[ "$(grep -c '^### <short name>$' "${BACKLOG}")" -eq 1 ]]; then pass "fenced purge: fenced example kept, real entry purged"; else fail "fenced purge: fenced example removed or real entry kept"; fi
if grep -q "^### keep$" "${BACKLOG}"; then pass "fenced purge: unrelated entry kept"; else fail "fenced purge: unrelated entry lost"; fi
if echo "${OUT}" | grep -q "^BACKLOG.md: 1 entries$"; then pass "fenced purge: trailing count is 1"; else fail "fenced purge: trailing count not 1: ${OUT}"; fi

fenced_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: <short name>
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "fenced delete: exit 0"; else fail "fenced delete: expected exit 0, got ${EC}"; fi
if [[ "$(grep -c '^```$' "${BACKLOG}")" -eq 2 ]] && [[ "$(grep -c '^### <short name>$' "${BACKLOG}")" -eq 1 ]] && grep -q "^### keep$" "${BACKLOG}"; then pass "fenced delete: real entry deleted, fenced example kept"; else fail "fenced delete: fenced example matched instead of the entry"; fi

fenced_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
adopt: <short name> | 2026-05-01
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "fenced adopt: exit 0"; else fail "fenced adopt: expected exit 0, got ${EC}"; fi
if [[ "$(sed -n 6p "${BACKLOG}")" == '### <short name>' ]] && grep -q '^### <short name> (ACTIVE in spec 2026-05-01)$' "${BACKLOG}"; then pass "fenced adopt: real entry annotated, fenced example untouched"; else fail "fenced adopt: fenced example annotated"; fi

printf '# Backlog\n\n```\n### only-in-fence\n```\n' > "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: only-in-fence
- **Origin:** ad-hoc
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if echo "${OUT}" | grep -q "^APPENDED: only-in-fence$"; then pass "fenced append: fenced heading is not a collision"; else fail "fenced append: fenced heading read as a collision: ${OUT}"; fi

# ============================================================
echo ""
echo "==> an unclosed fence in an entry body does not hide later entries"
# ============================================================

stray_fence_fixture() {
  cat > "$1" <<'EOF'
# Backlog

### a
- **Origin:** `tester design 2026-01-01`
- **Why deferred:** example below
```

### b
- **Origin:** spec 2026-01-01

### c (ACTIVE in spec 2026-01-02)
- **Origin:** `tester design 2026-01-01`
EOF
}

stray_fence_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
delete: a
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "stray fence delete: exit 0"; else fail "stray fence delete: expected exit 0, got ${EC}"; fi
if ! grep -q "^### a$" "${BACKLOG}" && grep -q "^### b$" "${BACKLOG}" && grep -q "^### c (ACTIVE in spec 2026-01-02)$" "${BACKLOG}"; then pass "stray fence delete: only the named entry removed"; else fail "stray fence delete: later entries lost or target kept"; fi
if echo "${OUT}" | grep -q "^BACKLOG.md: 2 entries$"; then pass "stray fence delete: trailing count is 2"; else fail "stray fence delete: trailing count not 2: ${OUT}"; fi

stray_fence_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
purge-origin: tester design
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]]; then pass "stray fence purge: exit 0"; else fail "stray fence purge: expected exit 0, got ${EC}"; fi
if [[ "$(echo "${OUT}" | grep -c '^PURGED: ')" -eq 1 ]] && echo "${OUT}" | grep -q "^PURGED: a "; then pass "stray fence purge: only the matching entry purged"; else fail "stray fence purge: wrong PURGED lines: ${OUT}"; fi
if grep -q "^### b$" "${BACKLOG}"; then pass "stray fence purge: non-matching entry kept"; else fail "stray fence purge: non-matching entry lost"; fi
if grep -q "^### c (ACTIVE in spec 2026-01-02)$" "${BACKLOG}"; then pass "stray fence purge: ACTIVE entry kept"; else fail "stray fence purge: ACTIVE entry lost"; fi

stray_fence_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
adopt: b | 2026-05-01
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -eq 0 ]] && grep -q "^### b (ACTIVE in spec 2026-05-01)$" "${BACKLOG}"; then pass "stray fence adopt: later entry annotated"; else fail "stray fence adopt: later entry not found: ${OUT}"; fi

stray_fence_fixture "${BACKLOG}"
pushd "${TEST_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: c
- **Origin:** ad-hoc
end-append
MANIFEST
)
EC=$?
popd >/dev/null || exit
if echo "${OUT}" | grep -q "^SKIPPED: c (heading already present)$"; then pass "stray fence append: later heading is a collision"; else fail "stray fence append: later heading not detected: ${OUT}"; fi
if [[ "$(grep -c '^### c' "${BACKLOG}")" -eq 1 ]]; then pass "stray fence append: no duplicate heading written"; else fail "stray fence append: duplicate heading written"; fi

# ============================================================
echo ""
echo "==> symlinked or non-regular BACKLOG.md is refused"
# ============================================================

OUTSIDE="${TEST_DIR}/outside.md"
printf '# Outside\n\n### secret\n- **Origin:** spec 2026-04-01\n' > "${OUTSIDE}"
LINK_DIR="${TEST_DIR}/linkrepo"
mkdir -p "${LINK_DIR}"
ln -s "${OUTSIDE}" "${LINK_DIR}/BACKLOG.md"
if [[ -L "${LINK_DIR}/BACKLOG.md" ]]; then
  pushd "${LINK_DIR}" >/dev/null || exit
  OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
clear
append: x
- **Origin:** ad-hoc
end-append
MANIFEST
)
  EC=$?
  popd >/dev/null || exit
  if [[ "${EC}" -ne 0 ]]; then pass "live symlink: non-zero exit"; else fail "live symlink: expected non-zero exit"; fi
  if echo "${OUT}" | grep -q "^ERROR: BACKLOG.md is a symlink"; then pass "live symlink: ERROR names the refusal"; else fail "live symlink: no refusal message: ${OUT}"; fi
  if [[ -L "${LINK_DIR}/BACKLOG.md" ]]; then pass "live symlink: link left in place"; else fail "live symlink: link replaced"; fi
  if grep -q "^### secret$" "${OUTSIDE}" && ! grep -q "^### x$" "${OUTSIDE}"; then pass "live symlink: target untouched"; else fail "live symlink: target modified"; fi

  rm -f "${LINK_DIR}/BACKLOG.md"
  ln -s "${TEST_DIR}/dangling-target.md" "${LINK_DIR}/BACKLOG.md"
  pushd "${LINK_DIR}" >/dev/null || exit
  OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
append: x
- **Origin:** ad-hoc
end-append
MANIFEST
)
  EC=$?
  popd >/dev/null || exit
  if [[ "${EC}" -ne 0 ]]; then pass "dangling symlink: non-zero exit"; else fail "dangling symlink: expected non-zero exit"; fi
  if [[ ! -e "${TEST_DIR}/dangling-target.md" ]]; then pass "dangling symlink: target not created"; else fail "dangling symlink: target created outside the repo"; fi
  rm -f "${LINK_DIR}/BACKLOG.md"
else
  echo "  skip symlink cases (this account cannot create symlinks)"
  rm -f "${LINK_DIR}/BACKLOG.md"
fi

mkdir "${LINK_DIR}/BACKLOG.md"
pushd "${LINK_DIR}" >/dev/null || exit
OUT=$(bash "${SCRIPT}" <<'MANIFEST' 2>&1
clear
MANIFEST
)
EC=$?
popd >/dev/null || exit
if [[ "${EC}" -ne 0 ]] && echo "${OUT}" | grep -q "not a regular file"; then pass "directory BACKLOG.md: refused"; else fail "directory BACKLOG.md: not refused (exit ${EC}): ${OUT}"; fi

# ============================================================
echo ""
if [[ "${FAILS}" -eq 0 ]]; then
  echo "All ${TOTAL} checks passed."
else
  echo "${FAILS} of ${TOTAL} checks failed."
  exit 1
fi
