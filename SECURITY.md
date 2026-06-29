## Security Review — 2026-06-29 (scope: paths)

**Summary:** Reviewed `hooks/pre-push-codereview.sh` and `tests/test-pre-push-hook.sh`
at HEAD 4fa3ca5. 0 BLOCK / 0 WARN / 1 NOTE. The hook parses the agent-supplied command
string as text only (tokenize + `case`/regex compare); it never `eval`/`exec`/`source`s
it (verified: the lone `source` grep hit is prose on line 77). All error paths fail
closed (exit 2) on a missing or broken `codereview-marker`; only genuine
not-a-push / not-in-a-repo / nothing-to-review states pass through (exit 0). The marker
and skip-marker paths are single-sourced from `codereview-marker` (out of scope) and
resolve to a per-user 0700 cache dir (`/home/peter/.cache/claude-codereview`), so the
old cross-user `/tmp` symlink race is gone. The only diff since the last review of these
files (85189b4) is cosmetic block-message wording plus the test's matching assertion;
the reworded message also stops printing the inline `codereview-skip` bypass recipe,
which is security-neutral-to-positive. All 69 hook tests pass. The one NOTE is a
hardcoded home path in a test fixture.

### Findings

[NOTE] tests/test-pre-push-hook.sh:127 — hardcoded owner home path `/home/peter/src/zat.env`
  Attack vector: None (informational PII). The string is an illustrative input to the
  `git -C <dir> push` detection test, run in a scratch non-git dir; the path is never
  opened and need not exist. It discloses the box username `peter` / home layout.
  Evidence: line 127 `"git -C /home/peter/src/zat.env push" \`. Present since f5e9082
  (2026-04-11); seen but not flagged by the 2026-06-11 review of this file.
  Remediation: genericize to a placeholder (e.g. `/tmp/repo` or `/home/user/repo`), the
  test is path-agnostic; or, if intentional, broaden the accepted owner-identity PII
  entry below to name the `peter` username / `/home/peter` home path explicitly so it is
  not re-surfaced. Same identity class already accepted for `peterzat`; severity is NOTE,
  not WARN, because it is the owner's own username in the owner's personal dotfiles repo.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted. (The current `hw-bootstrap.sh` itself uses `${USER}`/`${HOME}` and contains no hardcoded PII.)
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale line 200, Claude Code line 208): Remote code execution by design over HTTPS to first-party vendor domains; the documented purpose of a bootstrap script. Not checksum-pinned, consistent with the accepted-risk philosophy for first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:183-188): `curl -o /tmp/cuda-keyring.deb` then `sudo dpkg -i` of a predictable path. TOCTOU vector only on a multi-user host; immaterial on the documented single-user target (`/tmp` sticky bit, only UID 1000). Recorded by the 2026-06-03 entry; line reference refreshed from the prior 163-168.
- **Pre-push gate detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix); `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass the advisory codereview gate. Accepted under the advisory-gate threat model (the human operator can bypass trivially and the misses are visible in the transcript); the hook is intentionally simple, biased toward over-detection. Out of scope for this path-scoped review; retained from the 2026-06-11 entry.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose; the user opts in by configuring API keys. Out of scope for this review; retained.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl invocation window. Not exploitable on this single-user dev box. Out of scope for this review; retained.

---
*Prior review (2026-06-29, scope: paths): Reviewed `hw-bootstrap.sh` at a07c9df (full file). 0 BLOCK / 0 WARN / 0 NOTE. No new issues; every concern mapped to an accepted risk (first-party `curl | bash` vendor installers, predictable `/tmp/cuda-keyring.deb`, repo-wide PII). APT third-party repos use `signed-by=` pinned keyrings; no hardcoded secrets in the file or its git history.*

<!-- SECURITY_META: {"date":"2026-06-29","commit":"4fa3ca53f92524abd77c117dba78757acc88db1a","scope":"paths","scanned_files":["hooks/pre-push-codereview.sh","tests/test-pre-push-hook.sh"],"block":0,"warn":0,"note":1} -->
