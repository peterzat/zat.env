# tests/

Structural lint and manual verification for zat.env skills and hooks. Run after any skill or hook change.

## Automated: `lint-skills.sh`

```bash
tests/lint-skills.sh
```

75 checks across 12 categories:

| Category | What it catches |
|----------|----------------|
| META field cross-references | Field read by one skill missing from the writing skill's template |
| Gate condition alignment | Hook, skill, and README disagreeing on what blocks a push |
| PR merge gate | Regression to marker-file check (broken post-push), missing GitHub state checks |
| Security chain coverage | Missing coverage verification before skipping /security |
| Builder/verifier separation | Codereview with Edit/Write tools, codefix with Skill invocations, missing delegation |
| Codereview/codefix handoff | Step 6.5 preliminary write, cycle limit, finding format agreement, no-modify rule |
| External reviewer integration | Step 5.5 exists, references script, light-review skip, once-only, provider tags |
| Codereview bypass removed | Bypass instructions reappearing in skill frontmatter |
| Accepted Risks consistency | Missing Accepted Risks section in codereview or security templates |
| Skill frontmatter | Missing required fields (name, description, context) |
| Shellcheck | Static analysis of all .sh files (when shellcheck is installed) |

## `test-review-external.sh`

```bash
tests/test-review-external.sh
```

13 checks covering guard logic and output contract for `bin/review-external.sh`:

| Category | What it catches |
|----------|----------------|
| Empty stdin | Script must exit 0 with no output |
| No/empty config | Missing or empty `.env` file must exit 0 silently |
| Empty API keys | Keys set to empty string must not trigger API calls |
| Invalid API key | Must fail open (exit 0, error on stderr, no stdout) |
| Shellcheck | Static analysis of the script |
| Stdin interface | Script must not require positional arguments |

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

**Codereview/codefix delegation (codereview Steps 6.5-7):**
1. BLOCK or WARN findings exist: write preliminary CODEREVIEW.md (Step 6.5)
2. Invoke /codefix in forked context; it reads CODEREVIEW.md as spec
3. Re-review modified files after codefix; check for resolved/new findings
4. Update CODEREVIEW.md with new findings before next /codefix cycle
5. Stop after 3 cycles or if tests regress

**PR merge (pr merge mode):**
1. Gate uses REVIEW_META from CODEREVIEW.md (not marker file, which is invalidated by pushing)
2. block: 0 and reviewed_up_to is ancestor of HEAD
3. Then checks GitHub: mergeable, statusCheckRollup, reviewDecision
4. Blocks on: not MERGEABLE, CI failure, CHANGES_REQUESTED, REVIEW_REQUIRED

**Carry-forward severity (codereview Step 1):**
1. Finding in Accepted Risks = downgrade to NOTE
2. Finding NOT in Accepted Risks = re-report at original severity
3. Accepted Risks section carried forward across reviews
