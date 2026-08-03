## Review — 2026-08-03 (commit: 2646eff)

**Review scope:** Refresh review. Focus: 3 files changed since prior review (commit f94582b): `claude/skills/codereview/SKILL.md`, `tests/lint-skills.sh`, `CLAUDE.md`. 0 already-reviewed files. tests/run-all.sh: 633/633 green across 5 suites (630 baseline plus the 3 lint checks added by this change).

**Summary:** Subagent completion-delivery guard, prompted by a downstream OrgSmith incident (an improvised `until ! pgrep -f "codefix" ...; do sleep 10; done` background loop whose pgrep matched its own command line and ran orphaned for 20+ hours). Step 7 of /codereview now states that codefix completion arrives from the harness (direct Skill result or task notification), forbids polling, and extends the rule to the Step 5 /security invocation; lint-skills.sh pins the three anchor phrases; CLAUDE.md documents the contract point. Verified: all three anchors sit on single lines in the SKILL.md wrap, the pre-existing pinned sentence "After codefix completes, re-review" is untouched and its lint check still passes, the new lint comment's pgrep example is inert (comment only), and the CLAUDE.md bullet's claims match the lint checks exactly. Security ran a scoped scan of tests/lint-skills.sh (the one non-md file in the diff): 0 BLOCK / 0 WARN / 0 NOTE. This review's own /security wait exercised the new rule: the fork ran in the background and the result arrived by task notification, no polling.

**External reviewers:**
None configured.

### Findings

No issues found.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-06-29, commit f94582b): Pre-push gate auto-run wording plus external-reviewer no-config output; 1 BLOCK found and auto-fixed in-turn (the bypass documented as a combined `codereview-skip && git push`, which the hook blocks), 1 carried NOTE (hardcoded home path in tests/test-pre-push-hook.sh:127; that file is outside this diff, so the NOTE lives on in SECURITY.md history rather than as a current finding).*

<!-- REVIEW_META: {"date":"2026-08-03","commit":"2646eff","reviewed_up_to":"2646effa2670dd8431a3cf027d78c496cf5ba9d7","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
