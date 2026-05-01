# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.

### tester-design-testing-meta
- **One-line description:** `/tester design` writes the durable contract section to TESTING.md but does not produce a TESTING_META footer; only audit mode does. Cross-skill consumers of TESTING.md metadata (e.g., `/pr` reading review metadata for PR descriptions) cannot tell from metadata alone that a design contract exists in the file. Adding a design-mode TESTING_META (with fields like `contract_shape`, `line_count`, `rollout_count`, `contract_date` rather than the audit's block/warn/note counters) would close this gap.
- **Why deferred:** Out of scope for the current /tester design D.4/D.5.5/D.6 ordering fix turn (SPEC 2026-05-01). No current consumer breaks today (`/pr` and others handle absent TESTING.md and absent metadata gracefully); the contract is human-readable in TESTING.md.
- **Revisit criteria:** A skill or workflow needs to programmatically detect "this project has a design contract" without reading TESTING.md content, OR `/pr`'s PR-description generation grows logic that would benefit from contract metadata, OR a downstream user reports the gap.
- **Origin:** spec 2026-05-01
