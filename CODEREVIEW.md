## Review — 2026-05-03 (commit: 9533660)

**Review scope:** Refresh review. Focus: 12 file(s) changed since prior review (commit 8cb06bc). Same 12 files vs upstream — the prior review's work and this turn's work both land on the new commit 9533660. tests/run-all.sh: 583/583 green across 5 suites (was 581; +2 for the new `--range ""` regression test).

**Summary:** This commit closes the codereview turn that hardens the push gate (XDG cache + fail-closed semantics), plumbs `--range` end-to-end into `/codereview external`, and resolves the two NOTEs from the prior verification review. The bytes reviewed at the previous turn's security scan (`SECURITY_META.commit = 8cb06bc`, scope=paths) included the XDG migration + fail-closed code uncommitted; that exact code is now committed in 9533660. The session's additions on top of the prior scan are bin/review-external.sh +6 lines (defensive `--range ""` rejection) and tests/test-review-external.sh chmod + ~30 lines (regression test) — no new attack surface. SECURITY.md findings carried forward 0/0/0.

**External reviewers:**
Skipped silently (review-external.sh produced empty output; no providers configured in `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` on this host).

### Findings

[NOTE] SPEC.md:8 -- /codereview external SPEC_META reports `criteria_met: 0` but the unpushed commits satisfy all 8 acceptance criteria
  Evidence: SPEC.md acceptance criteria boxes are all `[ ]` and the metadata footer reads `"criteria_met":0`. The unpushed commits (06cc69e, 096866f, 8cb06bc, 9533660) implement: (1) External-Only Mode + Step E.1-E.5 with no marker / no codefix invariants; (2) `review-external.sh --check` fail-loud on empty config naming the env file path; (3) four canonical range forms + bogus/empty rejection; (4) marker-collision warning gated on default range; (5) `--check` provider reporting + default fail-open preserved; (6) full-review path unchanged (REVIEW_META intact, hook still gates pushes); (7) lint and behavioral tests present and green; (8) CLAUDE.md "External-only review pre-flight contract" bullet and README.md "External-only mode" paragraph + Roadmap entry. Status is stale, not misaligned -- the code matches the spec.
  Suggested fix: run `/spec` after the push to evolve the spec, mark all 8 criteria met, run the turn-close retrospective, and produce a proposal for the next turn.

### Fixes Applied

None this turn -- the two NOTEs from the prior review (`tests/test-review-external.sh` not executable; `hooks/README.md:22` factually wrong about marker consumption) were addressed by edits in commit 9533660 alongside the marker XDG hardening, fail-closed gate, `--range` plumbing, and refreshed README test counts and Roadmap entries.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Tag-bypass regex in pre-push hook** (hooks/pre-push-codereview.sh:113): Combined branch+tag push could skip codereview gate. Defense-in-depth gap, not actively exploitable since the hook is advisory and user-controlled.
- **API key in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh:246, 337`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box. Recorded by SECURITY.md 2026-05-03 entry.

---
*Prior review (2026-05-03): Verification re-review of the same 14-file working-tree slice plus a side-effect audit on the External-Only Mode commits. 0 BLOCK / 0 WARN / 2 NOTE; both NOTEs (test mode bit, hooks/README.md "marker is consumed on push" inaccuracy) explicitly held for human triage and are now resolved by commit 9533660.*

<!-- REVIEW_META: {"date":"2026-05-03","commit":"9533660","reviewed_up_to":"9533660bf47dd056ae8779f8a60eda708cfbac73","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":1} -->
