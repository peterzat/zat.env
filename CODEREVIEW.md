## Review -- 2026-04-16 (commit: b6d7af5)

**Review scope:** Refresh review. Focus: 2 uncommitted files (`tests/lint-skills.sh`, `zat.env-install.sh`) plus 1 already-reviewed file re-checked for regressions (README.md). Prior review at commit 453c3f4 covered the pre-push hook tokenizer and README restructure; all unchanged code since then has been pushed.

**Summary:** Two uncommitted edits: (1) `zat.env-install.sh` bumps `effortLevel` from `"high"` to `"xhigh"` (the new level introduced in Claude Code v2.1.111 for Opus 4.7) and adds `Bash(nvidia-smi)` and `Bash(shellcheck *)` to the allow list. (2) `tests/lint-skills.sh` broadens the hook-trace guard patterns from literal strings to regex wildcards (`hook.*trace`, `TEMPORARY.*REMOVE`) so future trace-code variants are caught, not just the specific strings from the last incident. Lint passes all 230 checks. Tests 304/304 pass. Security scan clean (0/0/0 over `tests/lint-skills.sh` and `zat.env-install.sh`). External reviewers (openai o3, qwen) both returned "No issues found."

**External reviewers:**
[openai] o3 (high) -- 1359 in / 3504 out / 3328 reasoning -- ~$.0573
[qwen] Qwen/Qwen2.5-Coder-14B-Instruct-AWQ -- 1398 in / 5 out -- 3s (warm)

### Findings

No issues found.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-15, commit 453c3f4): Refresh review of pre-push hook tokenizer rewrite and README restructure. Caught and removed an uncommitted diagnostic trace (BLOCK), updated lint patterns (WARN), refreshed README directory overview (WARN). Final state: 0 BLOCK, 0 WARN, 1 NOTE (documented `cmd;git push` tokenizer limitation).*

<!-- REVIEW_META: {"date":"2026-04-16","commit":"b6d7af5","reviewed_up_to":"b6d7af55b9731d6f1541fadff2b0865a3c1dbc8a","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
