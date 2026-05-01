## Security Review — 2026-05-01 (scope: paths)

**Summary:** Reviewed `bin/codereview-marker` (new, untracked), `bin/spec-backlog-apply.sh`, `hooks/pre-push-codereview.sh`, `tests/lint-skills.sh`, `tests/run-all.sh`, `tests/test-codereview-marker.sh` (new, untracked), and `tests/test-spec-backlog-apply.sh`. No exploitable issues. The new `bin/codereview-marker` script consistently double-quotes all variable expansions; verified by direct attempt that branch names containing `$(...)` command substitution and `$((...))` arithmetic expansion are treated as inert literals at every reference site, and `git diff` output is piped to `sha256sum` without shell interpolation. The script's marker write at the predictable `/tmp/.claude-codereview-<8hex>` path uses the same redirect pattern already present in the previously-reviewed `bin/codereview-skip` `touch` and the hook's marker read, on a single-user dev box (one regular UID in `/etc/passwd`) with a sticky-bit `/tmp` (1777). No new attack surface vs. the accepted baseline. The pre-push hook's edits limit themselves to replacing inline UPSTREAM/sha256 logic with a `codereview-marker hash` call and adding an exit-2 fall-through (allow-on-empty-diff); the tokenizer-based push detection and the documented tag-bypass limitation are unchanged from prior reviews. The lint and test scripts use `mktemp -d` with trapped cleanup, hardcoded repo-relative paths derived from `$(dirname)`, and no shell interpolation of attacker-controlled input. All scripts pass `shellcheck -S warning`. No secrets in file contents; new files have no git history.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:111): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN.
- **Predictable `/tmp/.claude-codereview-<8hex>` marker path** (`bin/codereview-marker`, `bin/codereview-skip`, `hooks/pre-push-codereview.sh`): The marker write follows symlinks at the predictable path, which on a multi-user host could let another local user pre-create a symlink that the marker write then targets (writing 16 hex chars + newline to the followed target). On this single-user dev box with sticky `/tmp`, exploitation requires a co-resident UID; the write payload is non-secret. Continuity with the previously-reviewed `codereview-skip` `touch` pattern; not flagged as a new finding.

---
*Prior review (2026-05-01, scope: paths): Reviewed `bin/spec-backlog-apply.sh`, `tests/lint-skills.sh`, and `tests/run-all.sh`. 0 findings. Apply script's stdin-only manifest interface used `printf '%s'` and `awk -v` string assignment with no `eval` and no command substitution from manifest input; lint and runner read only repo-local paths.*

<!-- SECURITY_META: {"date":"2026-05-01","commit":"ba621cfd2fdb0e6760afc1d2f2d54cc27613e6e2","scope":"paths","scanned_files":["bin/codereview-marker","bin/spec-backlog-apply.sh","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/run-all.sh","tests/test-codereview-marker.sh","tests/test-spec-backlog-apply.sh"],"block":0,"warn":0,"note":0} -->
