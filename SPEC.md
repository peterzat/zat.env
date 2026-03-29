## Spec — 2026-03-28 — Complete v1 skill suite and validate /spec integration

**Goal:** Wrap up the v1 milestone by validating that the newly added /spec skill works correctly, integrates with the existing skill DAG, and produces a well-formed SPEC.md. All core skills (spec, codereview, security, architect, tester, pr) are implemented and documented.

### Acceptance Criteria

- [x] `/spec` creates a well-formed SPEC.md with goal, acceptance criteria, context, and metadata footer
- [x] `/codereview` reads SPEC.md and reports spec alignment when reviewing changes
- [x] `/architect` reads SPEC.md and considers spec goals in its assessment
- [x] `/codereview` produces a clean review on a project without SPEC.md (no nagging)
- [x] README.md accurately reflects all 6 skills, the updated DAG, and persistent file descriptions
- [x] All diff hash exclusions (codereview, pr, pre-push hook) consistently exclude SPEC.md
- [x] `/spec` skill symlinked and available via `zat.env-install.sh`
- [x] Cross-skill reading DAG updated: SPEC.md upstream of all review skills
- [x] "Spec is code" philosophy documented in README

### Context

This is the final v1 checkpoint. The roadmap's near-term items (/verify, worktree A/B testing, quantitative trending, branch aliases) are candidates for the first v2 spec.

<!-- SPEC_META: {"date":"2026-03-28","title":"Complete v1 skill suite and validate /spec integration","criteria_total":9,"criteria_met":9} -->
