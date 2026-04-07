## Review -- 2026-04-06 (commit: 952d999)

**Summary:** Reviewed uncommitted changes to README.md, codereview SKILL.md, and security SKILL.md. Changes rename "Cross-Skill Reading DAG" to "Cross-Skill Context Graph" (acknowledging cycles in the reading graph) and add security scope coverage verification to prevent skipping re-scans when a prior changes-only scan did not cover all needed files. One WARN found: heading format template in security SKILL.md omitted the new `paths` scope.

### Findings

[WARN] claude/skills/security/SKILL.md:160 -- Heading format template missing `paths` scope
  Evidence: SECURITY_META template was updated to `"scope":"full|changes-only|paths"` and prose describes three scopes, but the markdown heading template still read `scope: full|changes-only`.
  Suggested fix: Add `|paths` to the heading template.

### Fixes Applied

1. [WARN] Updated heading template in security SKILL.md from `scope: full|changes-only` to `scope: full|changes-only|paths` (line 160).

### Accepted Risks

None.

---
*Prior review (2026-04-03, commit b63683b): Refresh review of venv-source hook and spec proposal prompt. Two findings (unregistered hook, prefix-match command injection). Both auto-fixed.*

<!-- REVIEW_META: {"date":"2026-04-06","commit":"952d999","reviewed_up_to":"952d9991283f6403487d30d9eebac86fc0dd80a9","base":"origin/main","tier":"full","block":0,"warn":0,"note":0} -->
