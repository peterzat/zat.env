## Review — 2026-05-31 (commit: f0d7670)

**Review scope:** Refresh review. Focus: 6 file(s) changed since prior review (commit 73f1d6b) — the f0d7670 shipping diff (`origin/main..HEAD`): `bin/codereview-marker`, `claude/skills/codereview/SKILL.md`, `tests/lint-skills.sh`, `tests/test-codereview-marker.sh`, `CLAUDE.md`, `README.md`. All reviewed at full depth; 0 already-reviewed-only files (the focus and shipping sets coincide here). tests/run-all.sh: 601/601 green across 5 suites (was 589; +5 marker base tests, +7 lint contract checks).

**Summary:** Single-sources the codereview review base through a new `codereview-marker base` subcommand (exposing the existing `@{upstream}` → `origin/<branch>` → empty-tree `resolve_base` chain), and routes Step 2 (review scope), Step 5 (security surface), and Step 5.5 (external reviewers) through it. Fixes the IC-Panel failure mode where a no-upstream first push resolved to an empty inline diff and read as "nothing to review" (Step 2) or silently skipped external review (Step 5.5): a first push now reviews the whole committed tree, and security routes to a docs-inclusive full audit rather than a paths scan that would exclude `.md`. Step 2 also gains an anti-spot-check guard (no hand-picked subset recorded as a clean review), scoped so it does not contradict the light-review, refresh-depth, or large-diff-triage rules below it. Adds `base` behavioral coverage across all three resolution cases and lint guards that the empty-tree case is named and that Steps 5/5.5 do not regress to the inline fallback. Developed with an extended manual adversarial pass that caught and fixed one defect (the Step 2 guard's unconditional "/security" and "every dimension" claims, which contradicted the light/refresh/large-diff rules) before this commit.

**External reviewers:**
Skipped silently (review-external.sh produced empty output; no providers configured in `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` on this host).

### Findings

No issues found. 0 BLOCK / 0 WARN / 0 NOTE. Independent `/security` pass on the three changed non-doc files returned 0/0/0: the `base` arm is read-only git with no new input/secret/network/eval surface, and the two test scripts have no production surface. Spec note: this change is orthogonal to the active SPEC (v2.0 `/loop` bookkeeping, not yet started) — independent gate maintenance, neither advancing nor contradicting a criterion. Its "no SKILL.md outside loop/" constraint scopes the future `/loop` implementation, not this commit.

### Fixes Applied

None. (The single defect found during development — the Step 2 guard contradiction — was corrected before commit, not via the fix loop.)

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-05-07, commit 73f1d6b): Refresh review gating `/tester design` Step D.5.5 against silent collapse into the D.7 post-mutation report (three model-compliance anchors plus lint). 0 BLOCK / 0 WARN / 0 NOTE; one WARN raised and fixed in the same turn.*

<!-- REVIEW_META: {"date":"2026-05-31","commit":"f0d7670","reviewed_up_to":"f0d767036c1115480e77a99be92c3c29a284e7ae","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
