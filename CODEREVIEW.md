## Review -- 2026-04-19 (commit: da77a90)

**Review scope:** Refresh review. Focus: 4 files changed since prior review (commit 9e5a160): `BACKLOG.md` (deleted in working tree), `CLAUDE.md`, `README.md`, `claude/skills/spec/SKILL.md`, `tests/lint-skills.sh`. No already-reviewed files to check.

**Summary:** Reviewed 15 commits plus uncommitted changes implementing the BACKLOG.md convention in the /spec skill and its supporting lint/docs. Key additions: auto-apply of Backlog Sweep deletions on next /spec (moving away from the edit-only handoff), ACTIVE-annotation replacement (vs double-append) for revisit candidates, `/spec backlog clear` reset path, opt-in framing, staleness-prompt at N>15, and an updated CLAUDE.md contract-points entry plus README roadmap line. Uncommitted delete of BACKLOG.md removes a self-referential meta-entry now that the underlying adherence fixes are committed. Lint suite passes (321/321). The stale `Step 3.6` cross-reference was correctly rewritten to `Steps 3a/3b/3e` to match where overlap-scan logic actually lives.

**External reviewers:**
[openai] o3 (high) -- 5786 in / 2958 out / 2816 reasoning -- ~$.0577
[qwen] Qwen/Qwen2.5-Coder-14B-Instruct-AWQ -- 5907 in / 5 out -- 27s

### Findings

No issues found.

The two BLOCK findings from openai against `tests/lint-skills.sh:560` and `:562` were false positives: they claimed the patterns `'"Added `<short name>` to BACKLOG.md'` and `'"Cleared N entries from BACKLOG.md'` start with a stray single-quote that would prevent grep from matching. Verified by running the lint suite (both checks pass) and by inspecting the exact bytes: each pattern is a well-formed bash single-quoted string where the opening `'` pairs with the closing `'` around a literal `"Added ...BACKLOG.md` sequence. Backticks inside single quotes are literal in bash. qwen correctly reported no issues.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-18): Light review of a single README.md paragraph addition about `/clear` between turns. 0/0/0.*

<!-- REVIEW_META: {"date":"2026-04-19","commit":"da77a90","reviewed_up_to":"da77a9093c627458feb019df034882192215ad8e","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
