## Security Review — 2026-04-19 (scope: paths)

**Summary:** Re-reviewed `tests/lint-skills.sh` and `zat.env-install.sh`. No exploitable issues found. Neither file has uncommitted changes since the prior review. The install script continues to write only under the user's own directories, derives `REPO_DIR` from `BASH_SOURCE`, passes user-derived strings via `jq --arg`, and the `.env` template contains placeholder keys only (no real secrets). The lint script reads repo-local files and runs shellcheck; no network, no external input. Hardcoded loop values (`event in PreToolUse PostToolUse`) in the stale-hooks jq-program interpolation are not attacker-controlled.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:101): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-16, scope: paths): Reviewed the same two files. No findings. Install script writes only under user-owned directories, uses `jq --arg` for user-derived strings, and the reviewer `.env` template holds placeholders only. The lint script reads repo-local files with no external input. A prior diagnostic-trace WARN had already been resolved and regression-guard patterns broadened.*

<!-- SECURITY_META: {"date":"2026-04-19","commit":"da77a9093c627458feb019df034882192215ad8e","scope":"paths","scanned_files":["tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
