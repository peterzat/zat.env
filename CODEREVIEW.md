## Review — 2026-03-28 (commit: 55db1ee)

**Summary:** Reviewed 1 unpushed commit adding `/spec` skill (SKILL.md), integrating SPEC.md into the reading DAG of all existing skills (codereview, security, architect, tester, pr), updating diff-hash exclusions in pre-push hook and codereview/pr marker scripts, and documenting the skill in README.md and CLAUDE.md. Also removes Machine table and Hetzner/Networking section from global-claude.md (deduplication, info retained in README.md). Full review applied (shell scripts modified).

### Findings

[WARN] .claude/settings.local.json:64-71 — Session-auto-accepted permission detritus committed to the repo
  Evidence: Malformed `Bash(__NEW_LINE_aecef3170d13e358__ echo:*)` token, double-slash `Read(//home/...)` path, and six hardcoded `sed -n` line-range commands auto-accepted during the session that created the spec skill. None of these are meaningful persistent permissions.
  Suggested fix: Remove all 8 entries (lines 64-71).

[NOTE] claude/global-claude.md — Machine table and Hetzner/Networking section removed from global context
  Evidence: These sections were removed from global-claude.md (loaded in every project). The information is retained in README.md, but README.md is only loaded in the zat.env project. Other projects on this machine will no longer see machine specs or the netplan warning in their Claude context.

### Fixes Applied

- Removed 8 auto-accepted permission entries from `.claude/settings.local.json` (lines 64-71): malformed newline token, double-slash Read path, and hardcoded sed line-range commands.

---
*Prior review (2026-03-28, commit 01cdb1e): Light review of README anti-patterns and roadmap expansion. No issues found.*

<!-- REVIEW_META: {"date":"2026-03-28","commit":"55db1ee","block":0,"warn":1,"note":1} -->
