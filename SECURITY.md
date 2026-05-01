## Security Review — 2026-05-01 (scope: paths)

**Summary:** Reviewed `bin/spec-backlog-apply.sh`, `tests/lint-skills.sh`, and `tests/run-all.sh`. No exploitable issues. The apply script's stdin-only manifest interface uses `printf '%s'` and `awk -v` string assignment (no `eval`, no command substitution from manifest input, no regex with attacker-controlled patterns), with file writes confined to `mktemp` plus `mv` to a hardcoded `BACKLOG.md` in cwd. Confirmed by direct exploit attempts that command substitution embedded in headings or append bodies is preserved as literal text and not executed. The lint script reads only repo-local paths derived from its own `dirname`, invokes only read-only tools (`grep`, `awk`, `sha256sum`, `shellcheck`), and writes nothing outside its own variables. The runner script hardcodes the four suite paths under `TESTS_DIR`. No secrets in the files or recent git history of these paths. All 456 checks pass across 4 suites.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:101): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-24, scope: paths): Reviewed `bin/spec-backlog-apply.sh`, `tests/lint-skills.sh`, `tests/run-all.sh`, `tests/test-spec-backlog-apply.sh`, and `zat.env-install.sh`. 0 findings. Apply script's `purge-origin` op used pure parameter expansion and awk `-v` string assignment; new behavioral test suite used `mktemp -d` with trapped cleanup; install script refused root and wrote only to user-owned dirs.*

<!-- SECURITY_META: {"date":"2026-05-01","commit":"47020150fbb3691a4cc3888cd8836a493826730e","scope":"paths","scanned_files":["bin/spec-backlog-apply.sh","tests/lint-skills.sh","tests/run-all.sh"],"block":0,"warn":0,"note":0} -->
