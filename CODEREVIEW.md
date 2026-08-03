## Review — 2026-08-03 (commit: 4390a41)

**Summary:** Light review (docs only): README.md and claude/global-claude.md. The 49 task-list checkboxes in README's five Done sections (v1.4 through v1.0) are converted to plain bullets; the count matches the section inventory exactly (5+9+15+6+14) and grep confirms zero `[x]` remain, so the replace touched nothing outside the roadmap. The Writing Style section in global-claude.md is hardened: emoji, checkmarks, and decorative glyphs are never wanted (the prior rule allowed emoji "unless requested"), with `- [x]` task-list checkboxes named as decoration and one documented exception, SPEC.md acceptance criteria, where check-off is the tracking mechanism. Verified the exception matches the single functional check-off instruction at claude/skills/spec/SKILL.md:151; arrows in technical notation (CLAUDE.md, hooks/README.md, skill files) are prose notation, not decoration, and are unaffected. No links altered, no secrets in prose. tests/run-all.sh: 633/633 green across 5 suites, so no lint-pinned phrase drifted.

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
*Prior review (2026-08-03, commit ecea95b): Light review of the v1.4 README roadmap reset (Direction statement, multi-dev Next up, Done (v1.4) section); 0 BLOCK / 0 WARN / 0 NOTE.*

<!-- REVIEW_META: {"date":"2026-08-03","commit":"4390a41","reviewed_up_to":"4390a41c2606ef01d51939d2fdf30e9dd2df4a3b","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
