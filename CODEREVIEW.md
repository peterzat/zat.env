## Review — 2026-08-03 (commit: 8b2e838)

**Summary:** Light review (docs only): claude/global-claude.md, one Writing Style bullet reworded on top of the prior entry's decoration ban. The clarification states that plain bulleted lists are fine and the ban targets decoration (emoji, checkmarks, `- [x]` task-list checkboxes), closing an over-broad reading that could have discouraged list markers generally. The SPEC.md acceptance-criteria carve-out is preserved verbatim and still matches the single functional check-off instruction at claude/skills/spec/SKILL.md:151. No links altered, no secrets in prose. tests/run-all.sh: 633/633 green across 5 suites, so no lint-pinned phrase drifted.

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
*Prior review (2026-08-03, commit 4390a41): Light review of the checkbox removal (49 README roadmap task-list checkboxes converted to plain bullets, count verified against the section inventory) and the global-claude.md decoration ban; 0 BLOCK / 0 WARN / 0 NOTE.*

<!-- REVIEW_META: {"date":"2026-08-03","commit":"8b2e838","reviewed_up_to":"8b2e838e9797377fba0324f6f48fc227615295f1","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
