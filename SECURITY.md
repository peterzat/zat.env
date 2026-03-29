## Security Review — 2026-03-28 (scope: full)

**Summary:** Full repository review of the zat.env dev environment configuration repo. No BLOCK findings. Two NOTEs related to curl-pipe-shell install patterns and world-readable marker files. The prior WARN (internal token in settings.local.json) has been resolved.

### Findings

[NOTE] hw-bootstrap.sh:91,99 — Curl-pipe-shell install patterns for Tailscale and Claude Code
  Attack vector: A compromised CDN or DNS hijack could serve a malicious install script. The attacker would need to compromise tailscale.com or claude.ai infrastructure, or perform a MITM attack (mitigated by HTTPS/TLS). Both are first-party vendor-provided install methods and the standard way to install these tools.
  Evidence: Line 91: `curl -fsSL https://tailscale.com/install.sh | sh`; Line 99: `curl -fsSL https://claude.ai/install.sh | bash`
  Remediation: Optionally download scripts first and inspect before execution, or pin to a known-good hash. Acceptable as-is given these are vendor-recommended patterns run only during initial provisioning.

[NOTE] hooks/pre-push-codereview.sh:38 — Codereview marker files in /tmp are world-readable/writable
  Attack vector: Another user on the same machine could create or overwrite `/tmp/.claude-codereview-<hash>` with a valid diff hash, bypassing the codereview gate. Requires: (1) a multi-user system, (2) the attacker knowing the project hash and current diff hash. On a single-user dev box this is not exploitable.
  Evidence: Marker created at line 38 as `/tmp/.claude-codereview-${PROJ_HASH}` with default umask (observed 664 permissions). Skip marker at line 39 similarly world-writable.
  Remediation: If multi-user use is ever a concern, create markers in `$XDG_RUNTIME_DIR` (user-private tmpdir) instead of `/tmp`, or set `umask 077` before marker creation.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh:275, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.

---
*Prior review (2026-03-28, changes-only): Reviewed /spec skill addition. One WARN (internal token in settings.local.json permission list) found, since resolved in commit 6a84f2c.*

<!-- SECURITY_META: {"date":"2026-03-28","commit":"4566205","scope":"full","block":0,"warn":0,"note":2} -->
