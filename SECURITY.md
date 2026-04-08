## Security Review — 2026-04-08 (scope: paths)

**Summary:** Reviewed six files: the external reviewer script, install script, test infrastructure (lint, runner, external reviewer tests), and .gitignore. No secrets in source or git history. Config sourcing in review-external.sh reads only from user-controlled paths. LLM response output is regex-filtered before reaching stdout. All temp files use mktemp. No findings.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-08, scope: paths): Reviewed bin/zatmux. No secrets or exploitable issues.*

<!-- SECURITY_META: {"date":"2026-04-08","commit":"2ae4a3afa2328444fac3f76ea220947ec488943d","scope":"paths","scanned_files":[".gitignore","bin/review-external.sh","tests/lint-skills.sh","tests/run-all.sh","tests/test-review-external.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
