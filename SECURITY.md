## Security Review — 2026-06-29 (scope: paths)

**Summary:** Reviewed `hw-bootstrap.sh` at HEAD a07c9df (full file). No new security
issues. Every potential concern maps to a previously reviewed and accepted risk: the
first-party `curl | bash` vendor installers (NodeSource, Tailscale, Claude Code), the
predictable `/tmp/cuda-keyring.deb` download path, and repo-wide PII. APT third-party
repos (gh, NVIDIA Container Toolkit) use `signed-by=` pinned keyrings, the correct
pattern. No hardcoded secrets in the file or its git history; the only token-shaped
string is the `tskey-xxxxx` documentation placeholder (line 268). `docker` group
membership (line 196) is root-equivalent but intrinsic to the single-user dev-box
target and unchanged from prior accepted state.

### Findings

No security issues identified in the reviewed scope.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted. (The current `hw-bootstrap.sh` itself uses `${USER}`/`${HOME}` and contains no hardcoded PII.)
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale line 200, Claude Code line 208): Remote code execution by design over HTTPS to first-party vendor domains; the documented purpose of a bootstrap script. Not checksum-pinned, consistent with the accepted-risk philosophy for first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:183-188): `curl -o /tmp/cuda-keyring.deb` then `sudo dpkg -i` of a predictable path. TOCTOU vector only on a multi-user host; immaterial on the documented single-user target (`/tmp` sticky bit, only UID 1000). Recorded by the 2026-06-03 entry; line reference refreshed from the prior 163-168.
- **Pre-push gate detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix); `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass the advisory codereview gate. Accepted under the advisory-gate threat model (the human operator can bypass trivially and the misses are visible in the transcript); the hook is intentionally simple, biased toward over-detection. Out of scope for this path-scoped review; retained from the 2026-06-11 entry.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose; the user opts in by configuring API keys. Out of scope for this review; retained.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl invocation window. Not exploitable on this single-user dev box. Out of scope for this review; retained.

---
*Prior review (2026-06-11, scope: paths): Reviewed `hooks/pre-push-codereview.sh`, `tests/lint-skills.sh`, and `tests/test-pre-push-hook.sh` at 85189b4 (push-gate detection hardening). 0 BLOCK / 0 WARN / 1 NOTE. The hook parses the inspected command as text only (no eval/exec), fails closed on a missing or broken `codereview-marker`, and the one NOTE (heuristic push detection missing wrapper/prefix invocations) was recorded as an accepted advisory-gate limit.*

<!-- SECURITY_META: {"date":"2026-06-29","commit":"a07c9dffe3f69cc02bc3fac3e90a57e1ba211918","scope":"paths","scanned_files":["hw-bootstrap.sh"],"block":0,"warn":0,"note":0} -->
