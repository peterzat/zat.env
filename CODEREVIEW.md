## Review — 2026-06-11 (commit: 6092677)

**Review scope:** Light review (docs-only). The push-gate scope diff against origin/main, excluding SPEC.md/CODEREVIEW.md/SECURITY.md/TESTING.md, is a single plain-documentation file: BACKLOG.md. SPEC.md changed in the same commit but is outside review scope by the standard exclusions (and is itself docs). Test-suite run, /security chain, external reviewers, and fix loop are skipped per the light-review tier. For the record, the main session ran tests/run-all.sh independently: 630/630 green across 5 suites.

**Summary:** Shelves the unimplemented v2.0 /loop foundations. BACKLOG.md drops its 7 loop-specific entries (all Origin: plan let-s-discuss-and-plan-gleaming-shamir), each predicated on a foundation spec that was written 2026-05-07 but never built, leaving the single unrelated tester-design-testing-meta entry. In the same commit, SPEC.md (out of review scope) moves to a "no active spec" state, recording the shelved spec as a prior-spec footer breadcrumb pointing at b5bf210.

**External reviewers:**
Skipped (light review).

### Findings

No issues found. The removal is internally consistent: the surviving tester-design-testing-meta entry references none of the removed loop entries; the removed entries' cross-references were confined to one another and are gone together; no other tracked file references the removed entry slugs; and there are no secrets in the changed prose.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-06-11, commit 85189b4): Full/refresh review hardening the pre-push gate's push detection against operator/newline/subshell glue and tag-only false-positive bypasses, with the shared push-detection walk single-sourced and lint-guarded. 0 BLOCK / 0 WARN / 2 NOTE, both advisory-gate heuristic limits recorded as accepted risks.*

<!-- REVIEW_META: {"date":"2026-06-11","commit":"6092677","reviewed_up_to":"60926776380ab4847eb4b0c27afec6a2ec487750","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
