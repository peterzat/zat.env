## Review -- 2026-05-01 (commit: ba621cf)

**Review scope:** Refresh review. 8 file(s) modified since the prior review (`reviewed_up_to=4702015`, current HEAD=ba621cf): committed delta `ba621cf` (already covered in the 2026-05-01 prior turn) plus working-tree changes to `BACKLOG.md`, `CLAUDE.md`, `SPEC.md`, `claude/skills/codereview/SKILL.md`, `hooks/pre-push-codereview.sh`, `tests/lint-skills.sh`, `tests/run-all.sh`, and the two new untracked files `bin/codereview-marker` and `tests/test-codereview-marker.sh`. README.md and CLAUDE.md were also touched by this turn's auto-fix. All focus-set files reviewed at full depth.

**Summary:** Implements SPEC.md 2026-05-01 ("Deterministic codereview marker write/verify script"). New `bin/codereview-marker` (3-subcommand: `hash` / `write` / `path`) encapsulates `PROJ_HASH`, `UPSTREAM` derivation (with three-case fallback `@{upstream}` -> `origin/<branch>` -> empty-tree), the excluded-files diff, and the marker file path. `hooks/pre-push-codereview.sh` calls `codereview-marker hash` instead of recomputing inline; codereview SKILL.md's Steps 2 / 5.5 / 8 are restructured so no multi-statement bash block sets `UPSTREAM=` and references `${UPSTREAM}` later (Step 8 reduced to `codereview-marker write`, Steps 2 / 5.5 use self-contained one-liners with the fallback chain inlined). New `tests/test-codereview-marker.sh` (33 checks) exercises the four upstream cases plus stability and write/path subcommands; lint section rewritten to enforce script invocation by bare name on both sides and absence of inline `UPSTREAM=` / `sha256sum...cut -c1-16` patterns. CLAUDE.md's marker-hash bullet rewritten to describe the script as the single source of truth. All 504 checks pass across 5 suites (33 new from test-codereview-marker.sh; lint suite net +25 checks; prior 456 baseline preserved with intentional anchor updates). Security scan of all 7 changed non-doc files: 0 findings.

**External reviewers:**
[openai] o3 (high) -- 7184 in / 9199 out / 8960 reasoning -- ~$.1596

(External reviewer produced 3 BLOCK findings claiming nested double quotes inside `$(...)` are invalid bash; verified empirically that bash handles each `$(...)` as a fresh quoting context — outputs match expected. False positives, dismissed. The reviewer's WARN about hook fail-open on unexpected non-zero exits is recorded as NOTE below.)

### Findings

[NOTE] (openai) hooks/pre-push-codereview.sh:165-168 -- Hook allows the push when `codereview-marker hash` exits with any non-zero code other than 2 (i.e., 1 = "not in a git repo" already handled above; any other unexpected failure). The fail-open behavior is logged to stderr but does not block.
  Evidence: lines 165-168 explicitly handle `${HASH_EC} -ne 0` by exiting 0. The script's documented exit codes are 0/1/2 with 1 already handled at line 134-137 of the hook (no-git-repo). Any other exit code (e.g., from `set -euo pipefail` tripping on git/sha256/cut failures) results in the gate being bypassed.
  Why NOTE not WARN: the fail-open is a deliberate tradeoff. The hook is advisory (user can run `codereview-skip` or use `--no-verify`) and is the second line of defense after codereview itself; failing closed on rare unexpected git states would block legitimate pushes. Worth being aware of, not worth changing.

[NOTE] claude/skills/codereview/SKILL.md:265-268 -- Step 5.5's `COST_LOG=$(mktemp ...)` ... `2>"${COST_LOG}"` ... `cat "${COST_LOG}"` ... `rm -f "${COST_LOG}"` is a four-line bash block that uses a shell variable across lines, exhibiting the same LLM-split-Bash-call vulnerability pattern as the now-fixed UPSTREAM cases. The spec criterion 4 was scoped to UPSTREAM specifically; COST_LOG was not in scope.
  Evidence: SKILL.md line 265 binds `COST_LOG`; line 266 references `${COST_LOG}` in a redirect; lines 267-268 read and remove the file via `${COST_LOG}`. Splitting this block across two Bash tool calls would lose `${COST_LOG}` in the second call (the `2>"${COST_LOG}"` redirect would write to an empty path, silently losing the cost log; the subsequent `cat` would also fail).
  Why NOTE: the spec explicitly narrowed to UPSTREAM; this is a future spec evolution opportunity, not a regression introduced by this turn. The vulnerability has not been observed in practice (unlike UPSTREAM, which surfaced in PanelForge).

### Fixes Applied

- [WARN] README.md:570 / CLAUDE.md:14 -- Added `codereview-marker` entry to both directory listings (README's bin/ tree gained an alphabetically positioned line at 571; CLAUDE.md's bin/ overview gained the entry between spec-backlog-apply.sh and codereview-skip). Mirrors the spec-backlog-apply.sh precedent (commit d3599155 added the README tree entry the same turn the script landed).

### Accepted Risks

None.

---
*Prior review (2026-05-01): /tester design hardening from PanelForge feedback. 0 findings; 504 (was 456) checks pass. The committed delta `ba621cf` was reviewed in that turn.*

<!-- REVIEW_META: {"date":"2026-05-01","commit":"ba621cf","reviewed_up_to":"ba621cfd2fdb0e6760afc1d2f2d54cc27613e6e2","base":"origin/main","tier":"refresh","block":0,"warn":1,"note":2} -->
