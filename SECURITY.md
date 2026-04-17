## Security Review — 2026-04-16 (scope: paths)

**Summary:** Reviewed `tests/lint-skills.sh` and `zat.env-install.sh`. No exploitable issues found. The install script writes only under the user's own directories, uses `jq --arg` for user-derived strings, and the `.env` template contains placeholder keys only (no real secrets). The lint script reads repo files and runs shellcheck; no network, no external input. Prior finding (world-readable trace log in pre-push hook) was resolved before this review and the lint patterns that guard against regression were broadened in the uncommitted diff.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:101): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-15, scope: paths): Reviewed four files including hooks/pre-push-codereview.sh and tests/lint-skills.sh. One WARN: leftover diagnostic trace in the hook wrote every Bash command to a world-readable /tmp log, and the lint patterns meant to catch it used wrong strings. Resolved in subsequent commits; trace file removed and lint patterns broadened.*

<!-- SECURITY_META: {"date":"2026-04-16","commit":"b6d7af55b9731d6f1541fadff2b0865a3c1dbc8a","scope":"paths","scanned_files":["tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
