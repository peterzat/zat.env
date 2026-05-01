## Review -- 2026-05-01 (commit: 0ec93bb)

**Review scope:** Refresh review. Focus: CLAUDE.md and README.md (new working-tree edits since prior review). Already-reviewed (re-checked for interactions only): claude/skills/tester/SKILL.md, tests/lint-skills.sh. Prior review (same commit, working-tree diff) had 0 BLOCK / 0 WARN / 2 NOTE; both prior NOTEs are addressed by these working-tree changes.

**Summary:** CLAUDE.md bullet (3) and (4) under "Tester/spec cross-skill contracts" rewritten to reflect the new D.4-drafts / D.6-writes split, and README.md lines 316 and 685 expanded from "before BACKLOG.md mutates" to "before any TESTING.md or BACKLOG.md mutation" with a sentence explaining the draft/write split. Both updates are factually accurate per the current claude/skills/tester/SKILL.md prose. `tests/run-all.sh` passes with the 510-check baseline preserved (no new lint added in this slice). External reviewer (openai o3) emitted two BLOCK-tagged findings on tests/lint-skills.sh; both are false positives, downgraded with rationale.

**External reviewers:**
[openai] o3 (high) -- 5445 in / 2749 out / 2624 reasoning -- ~$.0538

### Findings

[NOTE] (openai) tests/lint-skills.sh:1135 and :1163 -- Reviewer flagged `${TESTER_D5_LINE}` / `${TESTER_D6_LINE}` as unbound under `set -u`; verified false positive
  Evidence: o3 emitted `[BLOCK]` on both lines claiming the variables are referenced without being set. Both variables are unconditionally assigned at lines 1022 and 1024 of the same script (`grep -n ... | head -1 | cut -d: -f1`). Under `set -u`, `[[ -n "${VAR}" ]]` succeeds on an empty-but-set variable; only truly unset variables trigger `unbound variable`. The 510/510 test run confirms execution is clean. No code change warranted.
  Suggested fix: None. Findings preserved in this report for audit trail per the provider-tag preservation rule.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:111): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **Predictable `/tmp/.claude-codereview-<8hex>` marker path** (`bin/codereview-marker`, `bin/codereview-skip`, `hooks/pre-push-codereview.sh`): Marker write follows symlinks at the predictable path; on a single-user dev box with sticky `/tmp` and non-secret payload, exploitation requires a co-resident UID.

---
*Prior review (2026-05-01): full review of claude/skills/tester/SKILL.md (D.4/D.5.5/D.6 draft-then-write split), tests/lint-skills.sh (3 new structural checks), and SPEC.md replacement turn. 0 BLOCK / 0 WARN / 2 NOTE on CLAUDE.md and README.md drift, both scoped out of that turn and addressed by this refresh.*

<!-- REVIEW_META: {"date":"2026-05-01","commit":"0ec93bb","reviewed_up_to":"0ec93bbabd6c23e76b9eb833563d05e80b8ddaaa","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":1} -->
