## Security Review — 2026-04-09 (scope: paths)

**Summary:** Reviewed four files: review-external.sh, lint-skills.sh, test-review-external.sh, and zat.env-install.sh. No secrets in source or git history (3 commits each). Config sourcing reads only from user-controlled paths. LLM response output regex-filtered to BLOCK/WARN/NOTE lines before propagation. All temp files use mktemp with EXIT trap cleanup. Local provider gates on script existence and venv python executability. Stale hook pruning uses jq --arg for safe interpolation. Cost calculation passes API token counts to bc, no shell injection path. API keys transmitted via HTTP headers, not URL parameters. JSON bodies constructed via jq --arg/--rawfile, preventing injection. No findings.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-09, scope: paths): Same four files. No secrets, no injection paths, no findings.*

<!-- SECURITY_META: {"date":"2026-04-09","commit":"e3f33b0de067e925f243cad556aa29b9e88ef7db","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/test-review-external.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
