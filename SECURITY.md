## Security Review — 2026-03-28 (scope: changes-only)

**Summary:** Reviewed unpushed commit 55db1ee (add /spec skill, SPEC.md DAG integration, settings.local.json permission additions). One WARN finding: a leaked internal token in a permission entry. No secret leaks, no injection vectors, no auth issues.

### Findings

[WARN] .claude/settings.local.json:64 — Internal token leaked into permission allow-list
  Attack vector: The entry `Bash(__NEW_LINE_aecef3170d13e358__ echo:*)` appears to be a Claude Code internal newline encoding that was auto-accepted as a permission. While the glob pattern (`echo:*`) limits execution to echo commands, the token itself is an implementation detail that should not be persisted in configuration. No direct exploitability, but it indicates the permission auto-accept captured a malformed entry.
  Evidence: Line 64 of `.claude/settings.local.json`: `"Bash(__NEW_LINE_aecef3170d13e358__ echo:*)"`. Other entries in the same commit (lines 65-71) are narrow `sed -n` and `Read` permissions that appear intentional.
  Remediation: Remove the `Bash(__NEW_LINE_aecef3170d13e358__ echo:*)` entry from the allow list. If an echo permission is needed, add a clean `Bash(echo:*)` entry instead.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh:275, README.md:3, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.

---
*Prior review (2026-03-28, changes-only): Reviewed WebFetch permission additions and review metadata updates. No issues.*

<!-- SECURITY_META: {"date":"2026-03-28","commit":"55db1ee","scope":"changes-only","block":0,"warn":1,"note":0} -->
