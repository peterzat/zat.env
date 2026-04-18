## Review -- 2026-04-18 (commit: 9e5a160)

**Summary:** Light review of an uncommitted README.md change (+2/-0 lines). The diff adds a single "Clear between turns." paragraph between the 5-step turn enumeration and the "Start every session with `/spec`" line. Claims verified: `/clear` is a Claude Code built-in, the proposal and SPEC.md live on disk (README lines 30-31, 200-202), the "context pollution in loops" anti-pattern is quoted verbatim (present at README:495), and the related "Context loss at turn boundaries" anti-pattern (README:491) already covers the mitigation the new paragraph relies on (retrospective + proposal on disk). No anchor damage: `<a id="spec-driven-iteration"></a>` remains at line 21, reference at line 212 still resolves. No new markdown links. No secret leaks. CODEREVIEW.md co-modification is a self-update from a prior review cycle.

**External reviewers:**
Skipped (light review).

### Findings

No issues found.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-18, commit 9e5a160): Light review of the single unpushed commit modifying README.md (intro reorder and "Prompts must earn their keep" Philosophy paragraph). 0/0/0.*

<!-- REVIEW_META: {"date":"2026-04-18","commit":"9e5a160","reviewed_up_to":"9e5a1601822afe2f734e5dff555dbccf159718bd","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
