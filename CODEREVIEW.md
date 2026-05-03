## Review -- 2026-05-03 (commit: 8cb06bc + uncommitted, side-effect audit)

**Review scope:** Full review with explicit user focus on side-effects in non-`/codereview external` paths. Working tree is the same 14-file slice the immediately-prior 2026-05-03 entry covered (CLAUDE.md, CODEREVIEW.md, README.md, SECURITY.md, bin/codereview-marker, bin/codereview-skip, bin/review-external.sh, claude/skills/codereview/SKILL.md, hooks/README.md, hooks/pre-push-codereview.sh, tests/lint-skills.sh, tests/test-codereview-marker.sh, tests/test-pre-push-hook.sh, tests/test-review-external.sh) plus SPEC.md. The user's focus narrows to: did the External-Only Mode commits (096866f, 06cc69e, 8cb06bc) leak unwanted side-effects into the full-review path, the marker/hook chain, or `bin/review-external.sh`'s default no-flag mode?

**Summary:** Marker hash `487a08ee842fa3b0` matches the current diff hash AND the stored marker; no code has changed since the prior review. tests/run-all.sh: 581/581 green across 5 suites. Side-effect audit on the External-Only Mode commits found:

1. **Step 0 dispatch** correctly preserves the empty-args -> Full Review Mode branch. The `Stop here. Do NOT proceed to any of Steps 1-9.` line at the end of Step E.5 is the explicit barrier preventing external-mode execution from falling into Steps 1-9.
2. **Lint-asserted invariants hold**: External-Only Mode body contains no `codereview-marker write` and no `/codefix` invocation; the footer disclaimer is present. Verified via the new lint checks (which all pass) and by manual re-read of the SKILL.md region between the section heading and Step 1.
3. **`bin/review-external.sh` default no-flag path is preserved**. `if ! ${CHECK_ONLY}; then DIFF=$(cat); fi` correctly guards stdin consumption to the default path. The config-loading block runs in both paths (intentional; `--check` needs the same `HAS_*` derivation). The `if ! ${HAS_OPENAI} && ! ${HAS_GOOGLE} && ! ${HAS_LOCAL}` silent-exit-0 fallback for the default path is unchanged. Lint asserts both. Behavioral test "default no-flag no-config: silent stderr (no --check leak)" exercises the regression guard end-to-end.
4. **`--range` flag plumbing**: `if [[ -n "${RANGE}" ]]; then ... else ... ${UPSTREAM}..HEAD ... fi` keeps the default path's `@{upstream}..HEAD` fallback exactly as before; the new code only branches on RANGE being non-empty. Lint asserts both branches survive.
5. **Marker / hook / codereview-skip refactor** is from earlier commit 6240448 (predates external-mode work). The migration to `${XDG_CACHE_HOME:-${HOME}/.cache}/claude-codereview/` and the hook fail-closed change are intentional and documented in CLAUDE.md's "Marker hash computation and path" bullet. Per-call `mkdir -p && chmod 700` in `marker_dir()` is idempotent; calling `codereview-marker {path,skip-path}` from a fresh system creates `~/.cache/claude-codereview/` as a side effect of resolving the path. Acceptable: the directory is the marker's home, lazy creation is correct, and the chmod hardens against drift.

No new BLOCK or WARN findings. Two NOTEs carry forward from prior review (test mode bit, hooks/README.md inaccuracy).

**External reviewers:**
Skipped silently (Step 5.5 produced empty output). Step 5.5 was not re-run this turn since: (a) the diff bytes are identical to the immediately-prior review (marker hash matches), (b) Step 5.5's contract says "External reviewers run once at initial review. Do NOT re-run them during fix/re-review cycles" -- this is functionally a re-review of the same diff.

Note on Step 5 (security): SECURITY_META commit is 8cb06bc and matches HEAD. `git diff --name-only -- ':!*.md'` produces the eight code files all of which appear in `scanned_files` from the 2026-05-03 paths-scope scan. Prior security scan covers the current security surface. Skipped; 0 BLOCK / 0 WARN / 0 NOTE carried forward from SECURITY.md.

### Findings

[NOTE] tests/test-review-external.sh -- file is not executable
  Evidence: `ls -la tests/test-review-external.sh` shows mode `-rw-rw-r--` (644). Every other test script (`test-codereview-marker.sh`, `test-pre-push-hook.sh`, `test-spec-backlog-apply.sh`, `lint-skills.sh`, `run-all.sh`) is mode `-rwxrwxr-x` (755). tests/run-all.sh invokes via `bash "${script}"` so the suite works, but `./tests/test-review-external.sh` from a developer's terminal still fails with "Permission denied". Carried from prior review's NOTE.
  Suggested fix: `chmod +x tests/test-review-external.sh` (one-line consistency restore).

[NOTE] hooks/README.md:22 -- "The marker is consumed on push (deleted after use)" is factually wrong
  Evidence: hooks/pre-push-codereview.sh:194-200 explicitly comments `# Marker is kept so a failed push (network error, remote rejection) does not force a full re-review.` and the lint check `has "${HOOK}" "Marker is kept"` enforces it. Only the SKIP_MARKER is consumed (line 158). Pre-existing wording bug; the current diff edits surrounding lines (replaces the inline `/tmp/...` test recipe with `codereview-marker write` and adds the fail-closed paragraph) but does not fix the inaccurate description. Carried from prior review's NOTE.
  Suggested fix: "The codereview marker is content-addressed by diff hash and persists across pushes (a failed network push does not force a re-review). Only the one-shot SKIP_MARKER created by `codereview-skip` is consumed on use."

### Fixes Applied

None this turn (re-review of an already-clean working tree; the BLOCK/WARN findings from the immediately-prior 2026-05-03 entry were auto-fixed in that turn and remain fixed; the two NOTEs are explicitly held for human triage per the skill's "Do not auto-fix these" rule).

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

(The previously-accepted `/tmp/.claude-codereview-<hash>` symlink-race risk is now remediated by the XDG migration and was removed from SECURITY.md last turn.)

---
*Prior review (2026-05-03): Verification re-review of the same 14-file working-tree slice that found 0 BLOCK + 0 WARN + 2 NOTE. Marker hash matched; tests 581/581 green; codefix-touched files (tests/lint-skills.sh, tests/test-pre-push-hook.sh) verified to hold up. Same two NOTEs (test mode bit; hooks/README.md inaccuracy) carried for human triage.*

<!-- REVIEW_META: {"date":"2026-05-03","commit":"8cb06bc","reviewed_up_to":"8cb06bc3379c8b934d2b2a2597fc9fd9006fa08d","base":"origin/main","tier":"full","block":0,"warn":0,"note":2} -->
