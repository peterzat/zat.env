## Review — 2026-08-03 (commit: ecea95b)

**Summary:** Light review (docs only): README.md roadmap reset for the v1.4 release. The since-v1.3 accumulation moves to a Done (v1.4) section; the stale Next up entries (/verify, loop orchestrator, worktree A/B testing, all shelved or locked out) are replaced by the multi-dev arc (merge-safe review artifacts, PR-side review, server-side gate, issue-backed backlog, none scheduled); a Direction statement is added to the Roadmap, and the top-of-README teaser and autonomy-spectrum position paragraph are updated to match. Verified: no intra-doc links reference the renamed section anchors (grep for #next-up/#future/#done-v1/#since-v1 is empty), the agent-hypervisors link is preserved in the new Future bullet, the Roadmap region reads intro > Direction > Next up > Future > Done (v1.4) > Done (v1.3) with intact heading levels and spacing, the five Done (v1.4) bullets are byte-identical to the former Since v1.3 list, and the "drafted and shelved twice" claim matches history (v2.0 /loop spec adopted at b5bf210, shelved at 6092677; /verify implementation discarded 2026-05-27 without landing). "v1.4 is the most recent tag" becomes true when this release pass tags this commit, the same pattern used for the v1.1 roadmap commit. No secrets in prose. tests/run-all.sh: 633/633 green across 5 suites.

**External reviewers:**
Skipped (light review).

### Findings

No issues found.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-08-03, commit 2646eff): Refresh review of the subagent completion-delivery guard (codereview Step 7 no-polling rule, lint anchors, CLAUDE.md contract point); 0 BLOCK / 0 WARN / 0 NOTE, scoped security scan of tests/lint-skills.sh clean.*

<!-- REVIEW_META: {"date":"2026-08-03","commit":"ecea95b","reviewed_up_to":"ecea95bdbc583bc1fa5b578964a141278fd69024","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
