## Review — 2026-06-29 (commit: a07c9df)

**Review scope:** Refresh review. Focus: 1 file changed since prior review (commit 6092677): `hw-bootstrap.sh`. 0 already-reviewed files to check for interactions. tests/run-all.sh: 630/630 green across 5 suites.

**Summary:** Single-purpose fix to the NVIDIA driver-install path in `hw-bootstrap.sh`, mirroring GEX44-security-audit commit 5e85379. Adds an apt pin (`/etc/apt/preferences.d/no-precompiled-nvidia`, Pin-Priority -1) refusing the `linux-modules/objects/signatures-nvidia-*` precompiled per-kernel packages, written unconditionally before any NVIDIA install step, and rewrites the printed install instructions from `linux-modules-nvidia-590-server-$(uname -r)` to `nvidia-dkms-595-server`. Rebased onto origin/main, where it merged with the adjacent gh/Node install blocks (commit edfe7cb) added since the original commit; the merge is non-interacting (pin lands after gh/Node, before the NVIDIA driver check it guards). Verified empirically on the live GEX44: with the pin active, installing a precompiled module package fails ("no installation candidate", priority -1) while `nvidia-driver-595-server` still resolves via the unpinned DKMS alternative in its disjunctive Depends (pulls no `linux-modules-nvidia-*`). The pin does not block NVIDIA security updates: those flow through the DKMS/driver/libnvidia packages, which are unpinned.

**External reviewers:**
Skipped silently (review-external.sh produced empty output; no providers configured in `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` on this host).

### Findings

No issues. The apt-pin write (single-quoted heredoc + `sudo tee` + explicit `chmod 0644`) is injection-free and idempotent; the OR-Depends analysis confirms the pin neutralizes the precompiled alternatives without breaking the driver install; and the integration with the adjacent gh/Node blocks introduces no ordering or interaction regression. Security scan of the file: 0 BLOCK / 0 WARN / 0 NOTE (2026-06-29 SECURITY.md entry).

### Fixes Applied

None. No BLOCK or WARN findings.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-06-11, commit 6092677): Light review shelving the unimplemented v2.0 /loop foundations (BACKLOG.md dropped its 7 loop entries). 0 BLOCK / 0 WARN / 0 NOTE.*

<!-- REVIEW_META: {"date":"2026-06-29","commit":"a07c9df","reviewed_up_to":"a07c9dffe3f69cc02bc3fac3e90a57e1ba211918","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
