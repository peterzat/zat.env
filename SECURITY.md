## Security Review — 2026-04-08 (scope: paths)

**Summary:** Reviewed bin/zatmux, a 36-line tmux session toggle script. Session names are derived from a constrained regex match on $PWD (only single path components under ~/src/), with dots replaced by underscores. No secrets, no external inputs beyond the working directory, no network activity, no injection paths. No findings.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-08, scope: paths): Reviewed five scripts (post-hook, lint-skills, install, review-external, orchestrator). No secrets or exploitable issues.*

<!-- SECURITY_META: {"date":"2026-04-08","commit":"7b901704bfd96abcbdd070cbbfe4de53076178ce","scope":"paths","scanned_files":["bin/zatmux"],"block":0,"warn":0,"note":0} -->
