## Review — 2026-08-20 (commit: 9c5ed5b)

**Summary:** Full-depth review of the macOS portability commit (bash 3.2 array guards, BSD `stat` fallback, `gtimeout` fallback, `${USER}` to `${HOME}` in the reviewer `.env` template, install-time PATH warning, README Platform support section). The commit's own edits verified correct on real bash 3.2.57. The review then found that `tests/run-all.sh` was reporting a false green on macOS: `lint-skills.sh` aborted on GNU-only `grep -oP` after 137 of 394 checks, and the runner discarded suite exit codes, so 395 checks were silently skipped while the runner printed `All 238 checks passed across 5 suites` and exited 0. Both BLOCKs are fixed and verified; the suite now reports 636/636 across 5 suites. Three pre-existing security WARNs from the same-day `/security` scan are recorded and deferred to a follow-up commit as unrelated to macOS portability.

**External reviewers:**
None configured.

### Findings

All findings in this section were fixed in this run. See Fixes Applied.

[BLOCK] tests/run-all.sh:22 — suite exit codes discarded, turning a dead suite into a green run
  Evidence: `output=$(bash "${script}" 2>&1) || true`. A suite that aborts prints no summary line, so neither regex matched, `pass=0 fail=0`, `TOTAL_FAIL` stayed 0, and the runner printed "All N checks passed" and exited 0. Confirmed by arithmetic: 63+69+64+42 = 238, the reported total, with `lint-skills.sh` contributing nothing.
  Impact: `/codereview` Step 8 gates the push marker on "tests did not regress", so a dead suite could green-light a push.

[BLOCK] tests/lint-skills.sh:520,521,528,529 — `grep -oP` is GNU-only and aborted the suite on macOS
  Evidence: `grep: invalid option -- P` from BSD grep; `set -euo pipefail` exited the script with status 2 after 137 of 394 checks, skipping the REVIEW_META, sweep-manifest, tester/spec contract, and shellcheck sections.

[WARN] tests/lint-skills.sh:1039 — `grep -zqE` is GNU-only and produced a false FAIL on macOS
  Evidence: GNU `-z` means null-data; BSD/macOS `-z` does not, so the multi-line match could never succeed. It reported "External-Only Mode footer missing the no-mutation disclaimer" when the footer at codereview/SKILL.md Step E.5 is present and correct.

[WARN] README.md:95 — "no GNU-only syntax" claim was contradicted by the findings above
  Resolved by fixing them; no edit was required. Re-verified by sweeping all tracked scripts for GNU-only patterns. See the residual NOTE below for one remaining imprecision in the same sentence.

[WARN] tests/lint-skills.sh — the three portability guards added by this commit had no lint pin
  Evidence: zero matches for `stat -f`, `%Lp`, `gtimeout`, `TIMEOUT_CMD`, or the `[@]+` array idiom. On Linux all three guards are no-ops, as the commit's own comments state, so reverting one failed no test on the primary development platform.

### Deferred to follow-up commit

Pre-existing and unrelated to macOS portability; bundling them would mix concerns. Recorded in SECURITY.md by the 2026-08-20 scan.

[WARN] zat.env-install.sh:98-122 — reviewer credential file created world-readable
  No `chmod` or `umask` anywhere in the script. Verified on this host: directory 0755, file 0644, while the non-secret marker cache dir gets 0700 via bin/codereview-marker:76. That file is the documented home for OPENAI_API_KEY and GEMINI_API_KEY. Fix: chmod 700 the directory and 600 the file unconditionally.

[WARN] bin/review-external.sh:63,76 then 172 — `--range` reaches `git log` unvalidated (option injection)
  Both parse branches reject only the empty string; line 172 is `git log --oneline "${RANGE}"`, so a value starting with `-` is parsed as an option. Independently reproduced: `git log --oneline --output=<path>` truncates and overwrites an arbitrary file. The only current validation is prose in codereview SKILL.md Step E.2, which is LLM-executed and not an enforcement boundary, precisely the split CLAUDE.md says belongs in the script. Fix: reject a leading dash at parse time.

[WARN] zat.env-install.sh:160-197 — deny list does not constrain what the allow list grants
  Under `defaultMode: auto`, `Bash(python3 *)` auto-approves `python3 -c '<anything>'`; `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)` are equivalent. Deny entries are prefix matches, so `Bash(rm -rf *)` misses `rm -fr` and `rm -r -f`. README.md:161 calls it a "deny list for dangerous patterns", which overstates enforcement. The block also replaces `.permissions` wholesale each run, dropping hand-added user rules. Auto mode itself is deliberate design and is not the finding.

[NOTE] README.md:95 — "no macOS-specific code paths exist" is literally inaccurate
  `zat.env-install.sh:10` branches on `uname -s == Darwin`. It selects only the text of a jq install hint (`brew` vs `apt`), not behavior, and it is the sole remaining instance. The substantive part of the sentence (no GNU-only syntax, BSD fallbacks) is now accurate.

[NOTE] zat.env-install.sh:283-288 — PATH warning omits restarting Claude Code
  The warning says to open a new shell, but hooks run in Claude Code's process environment, captured at launch. README Platform support step 3 states this correctly; the install-time warning, which is what the user sees at the moment of failure, does not. Demonstrated live during this session.

[NOTE] bin/review-external.sh:307-313, 401-407, 462-468, 502-511 — third-party model output flows into CODEREVIEW.md and then into /codefix
  The `^\[(BLOCK|WARN|NOTE)\]` filter constrains line shape but not the free text after the tag. Requires attacker-authored code under review plus a compliant external model.

### Fixes Applied

- [BLOCK] tests/run-all.sh:20-44 — capture the suite exit code into `rc`; the "All N checks passed" branch now requires `rc == 0`, and a new else branch counts the suite itself as one failure, prints "SUITE FAILED: <name> produced no trustworthy summary line (exit N)", and appends "<name>(aborted)" to FAILED_SUITES.
- [BLOCK] tests/lint-skills.sh:520,521,528,529 — changed `grep -oP` to `grep -o`. All four patterns are literal strings, so `-P` was never needed.
- [WARN] tests/lint-skills.sh:1039 — replaced `grep -zqE` with `tr '\n' ' ' | grep -qE`; comment records why `-z` is not portable.
- [WARN] tests/lint-skills.sh:1485-1499 — added a "Cross-platform portability guards" section pinning the bash 3.2 array idiom in bin/spec-backlog-apply.sh, the `stat -c || stat -f` fallback in tests/test-codereview-marker.sh, and the gtimeout fallback in bin/review-external.sh.
- [WARN] README.md:95 — no edit required; resolved by the fixes above.

Verification performed by the reviewer, independently of the fixer:
- `tests/run-all.sh` reports 636/636 across 5 suites, exit 0, zero FAIL lines (was a false 238/238 with lint-skills.sh silently dead). 636 = the prior Linux baseline of 633 plus the 3 new pins.
- The three new pins match zero times against the pre-commit files (`git show 9c5ed5b^:...`), so they are real regression guards rather than tautologies.
- The run-all fix was negative-tested against synthetic suites: an aborting suite (exit 2, no summary) and a lying suite ("All 5 checks passed", exit 3) are both caught and named `(aborted)`; the normal-failure path is unchanged; the runner exits 1.
- shellcheck clean on both modified files.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:263, 354`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md; line references refreshed by the 2026-08-20 scan.

---
*Prior review (2026-08-03, commit 8b2e838): Light review of one Writing Style bullet in claude/global-claude.md clarifying that plain bulleted lists are fine and the ban targets decoration; 0 BLOCK / 0 WARN / 0 NOTE. That entry recorded "633/633 green across 5 suites", which was a Linux run; the same command on macOS reported 238/238 because of the two BLOCK findings above, both now fixed.*

<!-- REVIEW_META: {"date":"2026-08-20","commit":"9c5ed5b","reviewed_up_to":"9c5ed5b8f62da959b464407534b12393d9cc4352","base":"origin/main","tier":"full","block":0,"warn":3,"note":3} -->
