## Test Strategy — 2026-04-07

**Summary:** Structural lint script (`tests/lint-skills.sh`) checks cross-skill consistency, gate condition alignment, and frontmatter validity. Manual scenario traces cover flow-level correctness that grep cannot catch. Run the lint after any skill or hook change.

### Automated: `tests/lint-skills.sh`

44 checks across 7 categories:

| Category | What it catches |
|----------|----------------|
| META field cross-references | Field read by one skill missing from the writing skill's template |
| Gate condition alignment | Hook, skill, and README disagreeing on what blocks a push |
| PR merge gate | Regression to marker-file check (broken post-push), missing GitHub state checks |
| Security chain coverage | Missing coverage verification before skipping /security |
| Codereview bypass removed | Bypass instructions reappearing in skill frontmatter |
| Accepted Risks consistency | Missing Accepted Risks section in codereview or security templates |
| Skill frontmatter | Missing required fields (name, description, context) |
| Shellcheck | Static analysis of all .sh files (when shellcheck is installed) |

### Manual: scenario traces after skill changes

These flows have had bugs and cannot be verified by grep. Walk through them mentally or on paper after changing skill logic.

**Push flow (pre-push hook):**
1. Hook receives JSON, extracts command, identifies git push
2. Checks skip marker (consumed on use) and codereview marker (content-addressed, persists)
3. Marker hash uses `git diff <upstream>`, not `git diff HEAD`
4. Marker persists after push (network retry safe)

**Security chain (codereview Step 5):**
1. No code changes + full scope = skip (safe)
2. No code changes + paths scope + scanned_files covers NEEDED = skip (safe)
3. No code changes + insufficient coverage = invoke /security on NEEDED (not fall through to item 4)
4. Code changes exist = compute SCAN_FILES from meta-commit and invoke /security
5. No valid META = compute SCAN_FILES from upstream and invoke /security

**PR merge (pr merge mode):**
1. Gate uses REVIEW_META from CODEREVIEW.md (not marker file, which is invalidated by pushing)
2. block: 0 and reviewed_up_to is ancestor of HEAD
3. Then checks GitHub: mergeable, statusCheckRollup, reviewDecision
4. Blocks on: not MERGEABLE, CI failure, CHANGES_REQUESTED, REVIEW_REQUIRED

**Carry-forward severity (codereview Step 1):**
1. Finding in Accepted Risks = downgrade to NOTE
2. Finding NOT in Accepted Risks = re-report at original severity
3. Accepted Risks section carried forward across reviews

### Prior assessment

Two NOTEs from /tester (2026-04-01): shellcheck as pre-commit gate, and install script idempotency smoke test. Both remain open as future considerations.

---
*Prior review (2026-04-01): No test infrastructure. Two NOTEs: shellcheck gate, idempotency smoke test.*

<!-- TESTING_META: {"date":"2026-04-07","commit":"93ba4e6","block":0,"warn":0,"note":2} -->
