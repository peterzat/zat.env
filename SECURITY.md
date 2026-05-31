## Security Review — 2026-05-31 (scope: paths)

**Summary:** Reviewed `bin/codereview-marker`, `tests/lint-skills.sh`, and `tests/test-codereview-marker.sh` at HEAD f0d7670 (adds the `base` subcommand and single-sources the review base). No security issues identified. `codereview-marker` takes a single positional subcommand dispatched through a fixed `case`; unknown or empty args fall through to `usage` (exit 1). No external/attacker-controlled input reaches a dangerous sink: `proj_hash` pipes `git rev-parse --show-toplevel` (a path the invoking user already controls) into `md5sum`, and `resolve_base`/`compute_hash` operate only on local git refs. Verified the gate-integrity path: a degraded `git diff` on line 106 could in principle hash empty output to `e3b0c44298fc1c14`, but it is guarded by the identical `git diff --quiet` check on line 102, and both the writer (codereview Step 8) and the verifier (pre-push hook line 179) call the same `compute_hash`, so any degenerate value is computed identically on both sides and the marker equality check still holds; not a bypass. Marker directory remains `${XDG_CACHE_HOME:-${HOME}/.cache}/claude-codereview/`, created and chmod 700 on every `marker_dir()` call (the hardening validated in the prior review). The lint script is literal-pattern grep/awk only with no `eval`/`source` of extracted values. The marker test suite passes (42/42) and uses `mktemp -d` scratch repos; its `path`/`write` assertions touch the real per-user 0700 cache dir and clean up with `rm -f`, which crosses no privilege boundary. No secrets in file contents or in the full git history of any in-scope file (apparent matches are the word "token" in git-push-tokenizer prose). Test git identity (`test@example` / `Test`) is a placeholder, not PII.

### Findings

No security issues identified.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): A combined branch-and-tag push containing a `v[0-9]` token would skip the codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled. Previously flagged as WARN; explicitly accepted.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when those providers are configured. Secrets accidentally committed to the diff would be exposed to the providers. This is the script's explicit purpose; the user opts in by configuring API keys.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): The header argument is visible in `/proc/<pid>/cmdline` (mode 0444) to any local user during the curl invocation window. Not exploitable on this single-user dev box (only UID 1000 exists, all sessions belong to `peter`). Mitigation on a multi-user host would require switching to `--header-file` or piping headers via `-K` config-file. Recorded for awareness, not actioned.

---
*Prior review (2026-05-03, scope: paths): Reviewed the eight files of the codereview-marker / pre-push-hook / review-external chain. 0 findings; confirmed the marker scheme moved from `/tmp` to a per-user 0700 `~/.cache` dir (closing the symlink race), the pre-push hook fails closed on unexpected `codereview-marker` error, and tests use mktemp scratch dirs with placeholder API keys.*

<!-- SECURITY_META: {"date":"2026-05-31","commit":"f0d767036c1115480e77a99be92c3c29a284e7ae","scope":"paths","scanned_files":["bin/codereview-marker","tests/lint-skills.sh","tests/test-codereview-marker.sh"],"block":0,"warn":0,"note":0} -->
