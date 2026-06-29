## Review — 2026-06-29 (commit: f94582b)

**Review scope:** Refresh review. Focus: 4 files changed since prior review (commit a07c9df): `hooks/pre-push-codereview.sh`, `claude/global-claude.md`, `claude/skills/codereview/SKILL.md`, `tests/test-pre-push-hook.sh`. 0 already-reviewed files. tests/run-all.sh: 630/630 green across 5 suites.

**Summary:** Two-commit workflow cleanup plus one in-turn fix. (1) Pre-push gate auto-run robustness: the hook block message now drives automatic `/codereview` ("without asking", "routine next step, not a choice to put to the user") and drops the inline skip recipe; a new `## Pre-push review gate` section in `global-claude.md` documents the behavior as a shared convention so it no longer depends on a per-machine memory. (2) External-reviewer output: `/codereview` Step 5.5 now collapses the no-reviewer case to a single `None configured.` line. Self-review caught one BLOCK (the relocated bypass was documented as a combined `&&` command, which the hook blocks for Claude-driven pushes); fixed in commit f94582b.

**External reviewers:**
None configured.

### Findings

One BLOCK found and fixed this turn (see Fixes Applied); no open issues remain. Plus one carried-forward NOTE from the security scan.

- [NOTE] tests/test-pre-push-hook.sh:127 — hardcoded `/home/peter/...` path discloses the box username (pre-existing line, not in this diff; same accepted-risk PII class as `peterzat`). From the Step 5 security scan (0 BLOCK / 0 WARN / 1 NOTE, 2026-06-29 SECURITY.md entry). Informational; no fix required.

### Fixes Applied

- [BLOCK] claude/global-claude.md — the relocated "push now" bypass was documented as the combined command `codereview-skip && git push`. For Claude-driven pushes that fails: the PreToolUse hook (`pre-push-codereview.sh:227`) evaluates the whole Bash command before `codereview-skip` runs, so the skip marker does not exist yet and the combined form blocks. Reworded to two separate commands (`codereview-skip` then `git push`) with an explicit warning against the `&&` form. Fixed via /codefix; 630/630 tests green after.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`; the hook is intentionally simple rather than embedding a shell parser, biased toward over-detection.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-06-29, commit a07c9df): Refresh review of the hw-bootstrap.sh NVIDIA DKMS-only fix. 0 BLOCK / 0 WARN / 0 NOTE.*

<!-- REVIEW_META: {"date":"2026-06-29","commit":"f94582b","reviewed_up_to":"f94582b19fe07547da6ff6a4c10641e71883b81c","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":1} -->
