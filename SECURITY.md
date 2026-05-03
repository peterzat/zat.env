## Security Review — 2026-05-03 (scope: paths)

**Summary:** Reviewed `bin/codereview-marker`, `bin/codereview-skip`, `bin/review-external.sh`, `hooks/pre-push-codereview.sh`, `tests/lint-skills.sh`, `tests/test-codereview-marker.sh`, `tests/test-pre-push-hook.sh`, `tests/test-review-external.sh`. The marker scheme has been migrated from `/tmp/.claude-codereview-<hash>` to `${XDG_CACHE_HOME:-${HOME}/.cache}/claude-codereview/` (mode 0700, per-user); `marker_dir()` chmods on every call so the directory permissions cannot drift open. This closes the previously-accepted symlink-race risk on multi-user hosts. Verified by inspection that `marker_dir()`, `marker_path()`, `skip_path()` all live behind the per-user 0700 dir; `bin/codereview-skip`'s `touch` is no longer at a predictable `/tmp` path. The pre-push hook now fails closed (`exit 2`) on any unexpected `codereview-marker` error, eliminating the prior silent-bypass when the script was missing from PATH. The hook still passes through pushes outside any git repo (`git rev-parse --show-toplevel || exit 0`), correct since the gate only applies inside projects. Test suite uses only `mktemp -d` scratch dirs and unsets `OPENAI_API_KEY`/`GEMINI_API_KEY` before each case to avoid environment leakage. Test placeholder API keys (`sk-invalid-test-key`, `fake-google-key`, `sk-test-key`) are obvious non-secrets. The fake `python3` shim in `tests/test-review-external.sh` lives in a `mktemp -d` venv (mode 0700) and is removed after use. Lint script remains literal-pattern only with no eval/source of extracted values. No secrets in git history of any in-scope file.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): A combined branch-and-tag push containing a `v[0-9]` token would skip the codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN; explicitly accepted.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when those providers are configured. Secrets accidentally committed to the diff would be exposed to the providers. This is the script's explicit purpose; the user opts in by configuring API keys.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` (mode 0444) to any local user during the curl invocation window. Not exploitable on this single-user dev box (only UID 1000 exists, all sessions belong to `peter`). Mitigation on a multi-user host would require switching to `--header-file` or piping headers via `-K` config-file. Recorded for awareness, not actioned.

---
*Prior review (2026-05-01, scope: paths): Reviewed `bin/review-external.sh`, `tests/test-review-external.sh`, and `tests/lint-skills.sh`. 0 findings; verified `--check` adds no new attack surface, bc arithmetic immune to shell escape, all temp files via mktemp with EXIT-trap cleanup that waits on background PIDs.*

<!-- SECURITY_META: {"date":"2026-05-03","commit":"8cb06bc3379c8b934d2b2a2597fc9fd9006fa08d","scope":"paths","scanned_files":["bin/codereview-marker","bin/codereview-skip","bin/review-external.sh","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/test-codereview-marker.sh","tests/test-pre-push-hook.sh","tests/test-review-external.sh"],"block":0,"warn":0,"note":0} -->
