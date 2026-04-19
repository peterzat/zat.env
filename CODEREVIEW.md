## Review -- 2026-04-19 (commit: 984da28)

**Review scope:** Refresh review. Focus: 2 files changed since prior review (commit 5c2ce36): `CLAUDE.md`, `bin/spec-backlog-apply.sh`. 3 already-reviewed files (`README.md`, `claude/skills/spec/SKILL.md`, `tests/lint-skills.sh`) unchanged since prior review — no regression check needed.

**Summary:** Reviewed 1 unpushed commit (984da28) that absorbs the prior review's 1 WARN and 2 NOTEs. Changes: (1) CLAUDE.md:51 Step 3b→3g consumer-location fix (WARN absorbed); (2) CLAUDE.md:52 annotation-lint wording tightened from "annotation format on both sides" to "the script-side annotation regex" (NOTE absorbed, accuracy fix); (3) bin/spec-backlog-apply.sh:12 docstring whitespace fix `adopt:  ` → `adopt: ` (NOTE absorbed, aligns with parser's single-space strip). All 334 lint/behavioral checks pass. Security: no re-scan needed — only docstring whitespace change since last scan (commit 5c2ce36), attack surface unchanged. External reviewers returned 3 openai findings against spec-backlog-apply.sh; all pressure-tested and rejected (two restate the prior-absorbed NOTE on strict parsing; one claimed the `|`-split breaks on pipe-containing headings, empirically false due to `%`/`##` greedy-split asymmetry). qwen returned no issues.

**External reviewers:**
[openai] o3 (high) -- 6139 in / 10451 out / 10240 reasoning -- ~$.1778
[qwen] Qwen/Qwen2.5-Coder-14B-Instruct-AWQ -- 6214 in / 5 out -- 6s (warm)

### Findings

No issues found.

The three openai WARN findings against `bin/spec-backlog-apply.sh` (single-space strip, trailing-whitespace intolerance, pipe-in-heading split) were pressure-tested. Findings 1 and 2 restate the strict-parser design choice the prior review's NOTE already surfaced and the current commit absorbed by fixing the docstring rather than widening the parser — an intentional interface-strictness decision. Finding 3 was empirically disproved: `adopt: foo | bar | 2026-04-19` against a `### foo | bar` entry annotates correctly because `${spec_line% | *}` is non-greedy (takes shortest suffix match) while `${spec_line##* | }` is greedy (takes longest prefix match), so the two together pin the final ` | ` as the date separator.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-19): Refresh review of 5 files introducing deterministic BACKLOG sweep apply script and Step 3g relocation. 1 WARN and 2 NOTEs. All absorbed in commit 984da28.*

<!-- REVIEW_META: {"date":"2026-04-19","commit":"984da28","reviewed_up_to":"984da2864bc143a9a90966a44cea5a7dff9e9cf9","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
