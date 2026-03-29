## Security Review — 2026-03-28 (scope: changes-only)

**Summary:** Reviewed uncommitted changes: five new domain-scoped WebFetch permissions in settings.local.json, plus review metadata updates in CODEREVIEW.md and SECURITY.md. No security issues identified.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh:275, README.md:3, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted. The current commit reduces PII surface by removing hardcoded email from install script and global-claude.md.

---
*Prior review (2026-03-28, changes-only): Reviewed WebFetch permission addition and review metadata updates. No issues.*

<!-- SECURITY_META: {"date":"2026-03-28","commit":"e11695f","scope":"changes-only","block":0,"warn":0,"note":0} -->
