## Security Review — 2026-08-03 (scope: paths)

**Summary:** Reviewed `tests/lint-skills.sh` (full file, 1528 lines) at HEAD 2646eff.
0 BLOCK / 0 WARN / 0 NOTE. The script is a read-only structural lint: it derives
REPO_DIR from its own location, takes no arguments, greps repo-internal files against
hardcoded patterns, and writes no files (no temp files, no redirects except /dev/null),
so there is no injection, symlink, or TOCTOU sink. File content is only ever data to
grep/sed/awk/printf; the sed line-range variables come from `grep -n | cut -d: -f1`
(digits or empty, guarded with `[[ -n ]]`). shellcheck runs behind a `command -v` guard
on absolute `/`-prefixed paths, so no option injection. No secrets or PII in the file or
its last three history commits (history grep hits are commit-message prose). Many of its
checks are themselves security regression guards (hook fail-closed branch, no inline
/tmp marker paths, builder/verifier tool separation), so the file is net
security-positive. One lint-precision gap noted in passing, not a finding: the awk
guard for `exit` inside review-external.sh provider functions misses a bare `exit` at
end-of-line; it guards availability of an advisory tool, not a security boundary.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted. (The current `hw-bootstrap.sh` itself uses `${USER}`/`${HOME}` and contains no hardcoded PII.)
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale line 200, Claude Code line 208): Remote code execution by design over HTTPS to first-party vendor domains; the documented purpose of a bootstrap script. Not checksum-pinned, consistent with the accepted-risk philosophy for first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:183-188): `curl -o /tmp/cuda-keyring.deb` then `sudo dpkg -i` of a predictable path. TOCTOU vector only on a multi-user host; immaterial on the documented single-user target (`/tmp` sticky bit, only UID 1000). Recorded by the 2026-06-03 entry; line reference refreshed from the prior 163-168.
- **Pre-push gate detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix); `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass the advisory codereview gate. Accepted under the advisory-gate threat model (the human operator can bypass trivially and the misses are visible in the transcript); the hook is intentionally simple, biased toward over-detection. Retained from the 2026-06-11 entry.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose; the user opts in by configuring API keys. Out of scope for this review; retained.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl invocation window. Not exploitable on this single-user dev box. Out of scope for this review; retained.

---
*Prior review (2026-06-29, scope: paths): Reviewed `hooks/pre-push-codereview.sh` and `tests/test-pre-push-hook.sh` at 4fa3ca5. 0 BLOCK / 0 WARN / 1 NOTE: hardcoded `/home/peter/src/zat.env` path in a test fixture (tests/test-pre-push-hook.sh:127), informational owner-identity disclosure only; remediation (genericize or fold into the accepted PII risk) still open. All error paths in the hook verified fail-closed; marker paths single-sourced under the per-user 0700 XDG cache dir.*

<!-- SECURITY_META: {"date":"2026-08-03","commit":"2646effa2670dd8431a3cf027d78c496cf5ba9d7","scope":"paths","scanned_files":["tests/lint-skills.sh"],"block":0,"warn":0,"note":0} -->
