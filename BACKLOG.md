# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.

### spec skill LLM-adherence hardening for BACKLOG operations
- **One-line description:** The spec skill's Step 3b mandated BACKLOG.md writes (sweep deletions, revisit-candidate annotations) and Step 8 report lines fail to fire reliably in live use; the LLM skips them even with numbered-step imperative phrasing.
- **Why deferred:** Five rounds of instruction tightening in session 2026-04-19 (reforge test bed) did not produce reliable adherence. Continuing to edit prompt text has diminishing returns. A different design is needed, likely moving the mechanical writes out of the prompt layer: e.g., a post-skill verification hook that reconciles `### Backlog Sweep` lines against BACKLOG.md, or a deterministic helper script the skill shells out to for deletions and annotations.
- **Revisit criteria:** The next `/spec` close-then-consume cycle in any downstream project shows the same adherence failures (sweep deletions not applied, ACTIVE annotation not written, no Step 5 report line); OR a concrete adherence-robust design is drafted and ready to discuss.
- **Origin:** ad-hoc, 2026-04-19.
