# tests/

Structural lint and manual verification for zat.env skills and hooks. Run after any skill or hook change.

## Automated: `lint-skills.sh`

```bash
tests/lint-skills.sh
```

44 checks across 8 categories:

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

## Manual: scenario traces after skill changes

These flows have had bugs and cannot be verified by grep. Walk through them after changing skill logic.

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
