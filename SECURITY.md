## Security Review — 2026-04-10 (scope: paths)

**Summary:** Reviewed three files: `hooks/post-tool-exit-plan-mode.sh`, `tests/lint-skills.sh`, and `zat.env-install.sh`. The plan-mode hook reads JSON from stdin via `jq -r`, compares the extracted tool name with bash `[[ ]]`, and emits a static single-quoted heredoc with no expansion surface — no injection path. The lint script operates purely over repo-local files using grep/sed/jq/shellcheck; no network, no writes, no attacker-controlled input. The installer's jq invocations interpolate only hardcoded event names (`PreToolUse`, `PostToolUse`) into jq query strings (not shell) and pass user-derived values like `${basename_script}`, `${HOOK_COMMAND}`, `${GIT_NAME}`, `${GIT_EMAIL}` via `--arg` or as single arguments to safe commands. Symlink replacement guards on `-L` before `rm`; regular files at target paths are either backed up (`CLAUDE.md.bak`) or replaced (under `~/bin/`, user-owned space). The reviewer `.env` template is written via a single-quoted heredoc (no expansion), empty of real credentials, with comment placeholders only. No secrets in source or git history (2-3 commits per file). No findings.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:34): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.

---
*Prior review (2026-04-09, scope: paths): Reviewed review-external.sh, lint-skills.sh, test-review-external.sh, zat.env-install.sh. No secrets, no injection paths, no findings.*

<!-- SECURITY_META: {"date":"2026-04-10","commit":"95188f90ed357550efe1a72e2ae113bca3a2e48a","scope":"paths","scanned_files":["hooks/post-tool-exit-plan-mode.sh","tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":0,"note":0} -->
