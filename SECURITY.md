## Security Review — 2026-06-03 (scope: paths)

**Summary:** Reviewed `hw-bootstrap.sh` at HEAD edfe7cb (the latest commit, which added the GitHub CLI and NodeSource Node.js install steps — not covered by the prior f0d7670 scan). It is a single-user Hetzner box provisioning script. No exploitable issues. The dominant surface is the intentional supply-chain pattern (vendor `curl | bash` installers and APT repo/keyring setup), all over HTTPS to first-party vendor domains; the gh and NVIDIA-container-toolkit APT keys are correctly pinned with `signed-by=`. No attacker-controlled input reaches any dangerous sink: there is no `eval`, no dynamic exec of fetched content beyond the intended vendor pipes, no permission widening to world-writable, and `.bashrc` mutations append literal strings under idempotency guards. The only hardening gap is the predictable `/tmp/cuda-keyring.deb` path (NOTE below), which is not reachable on the documented single-user target. No secrets in the file or in the full git history of either filename (`hw-bootstrap.sh` and its old name `bootstrap-GEX44.sh`); the sole `tskey-`/`authkey=` hit is the `tskey-xxxxx` placeholder in the Tailscale usage hint (line 248). PII references (`peterzat`) are an already-accepted risk.

### Findings

- **[NOTE] hw-bootstrap.sh:163-168 — CUDA keyring downloaded to a predictable `/tmp` path before `sudo dpkg -i`.**
  - Attack vector: `curl -fsSL ... -o /tmp/cuda-keyring.deb` writes a fixed, predictable path in world-writable `/tmp`, then `sudo dpkg -i /tmp/cuda-keyring.deb` installs it as root. A second local user could attempt to pre-stage or TOCTOU-swap the file between the download and the `dpkg` read to get a chosen `.deb` installed as root. Not reachable on the documented single-user Hetzner box (only UID 1000 / `peter` exists), and `/tmp`'s sticky bit prevents an attacker from deleting another user's file; this is the same single-user-host context under which the analogous `/proc/cmdline` curl-header exposure was recorded for awareness rather than actioned.
  - Evidence: `curl -fsSL https://developer.download.nvidia.com/.../cuda-keyring_1.1-1_all.deb -o /tmp/cuda-keyring.deb` (line 163-164) then `sudo dpkg -i /tmp/cuda-keyring.deb` (line 165).
  - Remediation: download to a private temp path, e.g. `keyring="$(mktemp)"; curl -fsSL ... -o "$keyring"; sudo dpkg -i "$keyring"; rm -f "$keyring"`. Only material on a multi-user host.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale line 180, Claude Code line 188): Remote code execution by design over HTTPS to first-party vendor domains. This is the documented purpose of a bootstrap script and the standard install path for these vendors; the user opts in by running the script. Not checksum-pinned, consistent with the accepted-risk philosophy for first-party supply-chain trust on this box.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): A combined branch-and-tag push containing a `v[0-9]` token would skip the codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when those providers are configured. Secrets accidentally committed to the diff would be exposed to the providers. This is the script's explicit purpose; the user opts in by configuring API keys.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl invocation window. Not exploitable on this single-user dev box. Recorded by the SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-05-31, scope: paths): Reviewed `bin/codereview-marker`, `tests/lint-skills.sh`, and `tests/test-codereview-marker.sh` at f0d7670 (the `base` subcommand single-sourcing the review base). 0 findings; confirmed no attacker-controlled input reaches a dangerous sink, the marker cache stays a per-user 0700 `~/.cache` dir, and the lint/test scripts use literal-pattern grep and mktemp scratch repos.*

<!-- SECURITY_META: {"date":"2026-06-03","commit":"edfe7cb37620637d9ac9544e956be68b93b2a8a5","scope":"paths","scanned_files":["hw-bootstrap.sh"],"block":0,"warn":0,"note":1} -->
