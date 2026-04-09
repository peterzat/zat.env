## Security Review — 2026-04-09 (scope: paths)

**Summary:** Reviewed four files: review-external.sh, lint-skills.sh, test-review-external.sh, and zat.env-install.sh. No secrets in source or git history. Config sourcing reads only from user-controlled paths. LLM response output is regex-filtered (only BLOCK/WARN/NOTE lines pass to stdout). All temp files use mktemp. GEMINI_EFFORT validated as numeric. No findings.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-08, scope: paths): Reviewed six files including review-external.sh, install script, and test infrastructure. No findings.*

<!-- SECURITY_META: {"date":"2026-04-09","commit":"55f357087be573d471f7906b0f4e324a9cc3bca7","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/test-review-external.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
