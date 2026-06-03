## Review — 2026-06-03 (commit: edfe7cb)

**Review scope:** Refresh review. Focus: 3 file(s) changed since prior review (commit f0d7670): `hw-bootstrap.sh`, `README.md`, `docs/hardware-setup.md`. Focus and full sets coincide (no already-reviewed-only files). `hw-bootstrap.sh` is a shell script, so full review tier (security chain + test suite). tests/run-all.sh: 601/601 green across 5 suites (unchanged; no test files touched).

**Summary:** Adds GitHub CLI (`gh`, via GitHub's pinned APT repo) and Node.js (NodeSource current LTS) install steps to `hw-bootstrap.sh`, placed before the NVIDIA driver check so both come up on run 1 (the run that exits at the driver step on a fresh box) and are skipped on run 2 via `command -v` guards. Docs synced: the README install summary and the walkthrough's run-1 summary now list `gh` and Node, and Phase 6 drops the now-redundant manual `gh` install block (the script installs it), leaving only `gh auth login`.

**External reviewers:**
Skipped silently (review-external.sh produced empty output; no providers configured in `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` on this host).

### Findings

No issues found. 0 BLOCK / 0 WARN / 0 NOTE. Both install blocks are the standard vendor-documented methods, idempotent under `command -v` guards, with the gh APT key pinned via `signed-by=`; placement before the NVIDIA check correctly lands them on run 1; the doc edits accurately track the new tool list and the removed manual step. Independent `/security` pass on `hw-bootstrap.sh` returned 0 BLOCK / 0 WARN / 1 NOTE — the one NOTE (CUDA keyring downloaded to a fixed `/tmp/cuda-keyring.deb` path, a TOCTOU vector only on a multi-user host) is pre-existing code outside this diff and immaterial on the documented single-user target; recorded in SECURITY.md, not auto-fixed. Spec note: orthogonal to the active v2.0 SPEC (provisioning maintenance, neither advancing nor contradicting a criterion).

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-05-31, commit f0d7670): Refresh review of the `codereview-marker base` single-sourcing change (Steps 2/5/5.5 routed through the shared base resolver, fixing the IC-Panel empty-diff failure mode). 0 BLOCK / 0 WARN / 0 NOTE; independent /security pass 0/0/0.*

<!-- REVIEW_META: {"date":"2026-06-03","commit":"edfe7cb","reviewed_up_to":"edfe7cb37620637d9ac9544e956be68b93b2a8a5","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
