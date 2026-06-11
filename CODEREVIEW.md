## Review — 2026-06-11 (commit: 85189b4)

**Review scope:** Refresh review. Focus: 3 file(s) changed since prior review (commit edfe7cb): `hooks/pre-push-codereview.sh`, `tests/lint-skills.sh`, `tests/test-pre-push-hook.sh`. Focus and full sets coincide (no already-reviewed-only files). The hook is a shell script and is the push gate itself, so full review tier (security chain + test suite). tests/run-all.sh: 630/630 green across 5 suites (+29 from new behavioral cases and the single-sourcing lint guard). shellcheck clean.

**Summary:** Hardens the pre-push gate's push detection against two bypass classes. (1) `is_git_push` tokenized on raw whitespace, so a shell separator without surrounding spaces (`;`, `&&`, `||`, `|`, `&`), a newline, or a subshell glued the git/push tokens to a neighbour and a real code push silently passed the gate; fixed by normalizing those forms to standalone tokens in `_normalize_ops`, biased toward over-detection. (2) `is_tag_only_push` scanned every token, so a stray version-like token anywhere (a commit message, an echo, an unrelated filename) made a code push look tag-only and skipped the gate; rewritten to judge each push by its own refspec arguments and to skip only when every push invocation in the command is tag-only. The shared push-detection walk is single-sourced in `_push_subcommand_indices` so the two detectors cannot drift, with a lint guard. This change resolves the prior "Tag-bypass regex in pre-push hook" accepted risk (the combined branch+tag / stray-token skip).

**External reviewers:**
Skipped silently (review-external.sh produced empty output; no providers configured in `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` on this host).

### Findings

0 BLOCK / 0 WARN / 2 NOTE. Both NOTEs are pre-existing heuristic limitations of an advisory gate, not introduced by this change, and are recorded as Accepted Risks rather than auto-fixed.

- [NOTE] hooks/pre-push-codereview.sh — tag recognition is name-based (`^v[0-9]` / `^refs/tags/`), so `is_tag_only_push` cannot distinguish a *branch* named like a version (e.g. `git push origin v2-rewrite`) from a real tag; that single-branch case is classified tag-only and skips the gate. Unchanged by this change and a strict improvement over the prior all-token scan (which skipped on a vN-looking token anywhere in the command). Closing it would require a git ref-type lookup (refs/heads vs refs/tags).
- [NOTE] hooks/pre-push-codereview.sh — `is_git_push` does not detect git reached via a wrapper or prefix: `env git push`, `command git push`, `bash -c "git push"`, `eval "git push"`, `/usr/bin/git push` (absolute path), `xargs git push`, `GIT_DIR=/x git push`. Each bypasses the gate. Surfaced by the independent `/security` pass; same accepted-risk class as above under the advisory-gate threat model.

### Fixes Applied

None. No BLOCK or WARN findings, so no `/codefix` cycle. The change under review is itself the fix for the operator/newline/subshell detection and the tag-only false-positive bypasses; its own regression and over-detection tests are part of the diff.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection. Supersedes the prior "Tag-bypass regex" risk, whose specific case (combined branch+tag, or a stray vN token elsewhere in the command) is now fixed by the conservative `is_tag_only_push` rewrite.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-06-03, commit edfe7cb): Refresh review of the gh + Node.js install steps added to hw-bootstrap.sh. 0 BLOCK / 0 WARN / 0 NOTE; independent /security pass 0/0/1 (predictable /tmp CUDA keyring path, immaterial on the single-user target).*

<!-- REVIEW_META: {"date":"2026-06-11","commit":"85189b4","reviewed_up_to":"85189b4bbbd19bc98ba1c7b59185c6fc1f68a794","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":2} -->
