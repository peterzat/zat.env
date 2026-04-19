## Security Review — 2026-04-19 (scope: paths)

**Summary:** Reviewed `bin/spec-backlog-apply.sh` and `tests/lint-skills.sh`. No exploitable issues found. The apply script reads a manifest from stdin produced by `/spec`, parses op lines with pure parameter expansion (no `eval`), and passes captured strings to `awk` via `-v` (string assignment, not code). Writes are constrained to the literal filename `BACKLOG.md` via `mktemp` + `mv`; the manifest cannot redirect output or inject awk code through the `hdr == t` comparison or `print` concatenation. The lint script reads only repo-local files, uses hardcoded `grep -qE` patterns with the `--` option terminator, and runs `shellcheck` on its own scripts. No network, no external-input consumption, no credential surface.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:101): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-19, scope: paths): Reviewed `tests/lint-skills.sh` and `zat.env-install.sh`. No findings. Install script writes only under user-owned directories, passes user-derived strings through `jq --arg`, and the reviewer `.env` template holds placeholders only. Lint script reads repo-local files only with no external input.*

<!-- SECURITY_META: {"date":"2026-04-19","commit":"5c2ce36a8cfb8846fd6faf3ff3864b8736959ddf","scope":"paths","scanned_files":["bin/spec-backlog-apply.sh","tests/lint-skills.sh"],"block":0,"warn":0,"note":0} -->
