## Security Review — 2026-04-21 (scope: paths)

**Summary:** Reviewed `bin/spec-backlog-apply.sh` and `zat.env-install.sh`. No exploitable issues found. The apply script consumes a stdin manifest with pure parameter expansion (no `eval`), passes captured strings to `awk` via `-v` (string assignment, not code), and writes only to the literal filename `BACKLOG.md` via `mktemp` + `mv`. The install script refuses to run as root, derives all writes to user-owned directories (`~/.claude`, `~/bin`, `~/.config/claude-reviewers`), passes user-derived strings to `jq` via `--arg`, and the reviewer `.env` template holds placeholders only. No network calls, no credential surface, no exposed input from external attackers.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:101): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-19, scope: paths): Reviewed `bin/spec-backlog-apply.sh` and `tests/lint-skills.sh`. No findings. Apply script uses pure parameter expansion and awk -v string assignment; lint script reads only repo-local files with hardcoded patterns.*

<!-- SECURITY_META: {"date":"2026-04-21","commit":"538ce88c3273f83c3834cf65d82063bbe8234c0b","scope":"paths","scanned_files":["bin/spec-backlog-apply.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
