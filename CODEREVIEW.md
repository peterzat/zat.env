## Review -- 2026-04-19 (commit: 5c2ce36)

**Review scope:** Refresh review. Focus: 5 files changed since prior review (commit da77a90): `CLAUDE.md`, `README.md`, `bin/spec-backlog-apply.sh` (new), `claude/skills/spec/SKILL.md`, `tests/lint-skills.sh`. 0 already-reviewed files (prior review's diff was absorbed into origin/main).

**Summary:** Reviewed 2 unpushed commits (d359915, 5c2ce36) that introduce the deterministic BACKLOG sweep apply script (`bin/spec-backlog-apply.sh`), relocate proposal-consume logic from Step 3b to a new top-level Step 3g in the spec skill, add 14 new sweep-apply lint checks, and trim stale callouts. Script is well-defended (bidirectional annotation strip, fenced-code-aware count, fail-open on missing file, empty-manifest short-circuit, shellcheck clean). All 334 lint/behavioral checks pass baseline and after fix. External reviewers (openai o3-high, qwen-14B) returned "No issues found." Security chain: 0 BLOCK / 0 WARN / 0 NOTE on the updated scope. One WARN found (CLAUDE.md Step 3b/3g drift) and auto-fixed by /codefix; two NOTEs left for human consideration.

**External reviewers:**
[openai] o3 (high) -- 5909 in / 11858 out / 11840 reasoning -- ~$.2014
[qwen] Qwen/Qwen2.5-Coder-14B-Instruct-AWQ -- 5987 in / 5 out -- 27s

### Findings

[NOTE] bin/spec-backlog-apply.sh:12 -- docstring template shows `adopt:  <heading>` (two spaces) but the parser strips only one leading space.
  Evidence: Line 12 template uses two spaces after `adopt:` to visually align with `delete:`. Lines 40-41 strip only `${spec_line# }`. A user copy-pasting the docstring literally produces `MISS: adopt:  <heading>`. The SKILL.md caller (line 408) uses single-space and is unaffected.
  Suggested fix: Change line 12 to single space.

[NOTE] CLAUDE.md:52 vs tests/lint-skills.sh:632 -- annotation-format lint is asymmetric.
  Evidence: CLAUDE.md line 52 claims "annotation format on both sides" is lint-verified, but only the script side has a pattern check (line 632). If SKILL.md's annotation shape drifts, the failure surfaces at runtime rather than at lint time.
  Suggested fix: Add a SKILL.md-side lint check like `has "${SKILLS}/spec/SKILL.md" 'ACTIVE in spec YYYY-MM-DD' "spec: Step 3g annotation format matches script"`.

### Fixes Applied

[WARN] CLAUDE.md:51 -- "consumed in Step 3b" changed to "consumed in Step 3g" for both `### Backlog Sweep` and `### Revisit candidates` occurrences. Fix aligns the contract description with the actual consumer location (Step 3g), which is also what the very next bullet (line 52) already explicitly states.

### Accepted Risks

None.

---
*Prior review (2026-04-19): Refresh review of 4 files following the BACKLOG.md convention ship and lint/docs sync. 0 findings; openai false-positives (patterns starting with a stray single-quote) were correctly rejected.*

<!-- REVIEW_META: {"date":"2026-04-19","commit":"5c2ce36","reviewed_up_to":"5c2ce36a8cfb8846fd6faf3ff3864b8736959ddf","base":"origin/main","tier":"refresh","block":0,"warn":1,"note":2} -->
