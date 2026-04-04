## Security Review — 2026-04-03 (scope: changes-only)

**Summary:** No uncommitted or staged changes to review. Working tree is clean.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh:223, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-03, scope: hooks/pre-push-codereview.sh): One WARN for tag-bypass regex allowing combined branch+tag pushes to skip the codereview gate. No secrets or injection issues.*

<!-- SECURITY_META: {"date":"2026-04-03","commit":"b63683b","scope":"changes-only","block":0,"warn":0,"note":0} -->
