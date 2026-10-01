# tests/

Structural lint and manual verification for zat.env skills and hooks. Run after any skill or hook change.

## Running all tests

```bash
tests/run-all.sh
```

Runs every suite and reports a combined summary. This is the single command to verify the repo.

## Automated: `lint-skills.sh`

```bash
tests/lint-skills.sh
```

Checks by category:

| Category | What it catches |
|----------|----------------|
| META field cross-references | Field read by one skill missing from the writing skill's template |
| Gate condition alignment | Hook, skill, and README disagreeing on what blocks a push |
| PR merge gate | Regression to marker-file check (broken post-push), missing GitHub state checks |
| Security chain coverage | Delegation, META reading, three invocation paths, scope support, severity model |
| Codereview flow gating | Early exit, light review skip list (Steps 3, 5, 5.5, 5.6, 6.5, 7), refresh detection, config escalation |
| Builder/verifier separation | Codereview with Edit/Write tools, codefix with Skill invocations, missing delegation |
| Codereview/codefix handoff contracts | Step 6.5 gating, cycle limit, re-review/re-test, human escalation, finding format, codefix constraints |
| Marker file gating | Conditional write, hash exclusion/truncation/PROJ_HASH identity, skip marker consumed, codereview marker persists |
| REVIEW_META field contracts | Field name identity across codereview, refresh detection, /pr merge, README |
| Agent boundary risks | Never-fix rule position, codefix do-not-modify list, hook bypass safety, PROJ_HASH derivation |
| Output verdicts | Both verdict strings, template completeness, all 8 REVIEW_META fields |
| Carry-forward severity | Accepted Risks downgrade, re-report at original severity, no silent severity loss |
| Cross-skill context graph | SPEC.md reading, spec alignment, no-nag, architect terminal node, NOTE not auto-fixed |
| Plan-mode handoff contract | `/spec plan` routing and adoption, the ExitPlanMode reminder hook, and its registration |
| BACKLOG.md contracts | Backlog Sweep and Revisit subsections, the four-field entry template, and `spec-backlog-apply.sh` manifest ops |
| Finding standards | Review skills carry no separate re-check pass; evidence, severity, and coverage rules live in the main steps |
| Codefix constraints | One-fix-at-a-time, 20-line cap, syntax check, no self-evaluation, no re-running review |
| External reviewer integration | Step 5.5, script reference, gating, provider tags, cost log, template exit states, script contracts |
| Concurrency safety | mktemp usage, EXIT trap waits, PID capture, config override, no fixed /tmp paths |
| Codereview bypass removed | Bypass instructions not in skill frontmatter |
| Built-in review integration | Step 5.6 launch after Step 3, output redirected to a mktemp file and read only after completion, no polling, no re-run, Step 6 classification, CODEREVIEW.md line |
| Accepted Risks consistency | Missing Accepted Risks section in codereview or security templates |
| Skill effort levels | Frontmatter effort matches README; judgment skills set none; install seeds `effortLevel` and sets `classifyAllShell`; venv hook makes no decision in auto mode |
| Uncommitted prior entry guard | Rolling files check `git status` before condensing, carry an uncommitted entry forward, and keep a single META footer |
| Tester/spec cross-skill contracts | Durable-contract H1, `tester design` Origin form, and the `/tester design` pre-apply checklist components and guards |
| Cross-platform portability guards | bash 3.2 empty-array guards, BSD `stat` fallback, `gtimeout` fallback |
| Security guards | `--range` leading-dash rejection, reviewer credential modes, deny-list union, per-provider stdout/stderr capture and own-tag findings demux |
| Skill frontmatter | Missing required fields (name, description, context) |
| Shellcheck | Static analysis of every shell script in the repo |

Target files are checked for existence before grepping. A missing file (renamed skill, path typo) fails loudly rather than silently passing or failing.

## Automated: `test-review-external.sh`

```bash
tests/test-review-external.sh
```

Checks covering guard logic and output contract for `bin/review-external.sh`:

| Category | What it catches |
|----------|----------------|
| Empty stdin | Script must exit 0 with no output |
| No/empty config | Missing or empty `.env` file must exit 0 silently |
| Empty API keys | Keys set to empty string must not trigger API calls |
| Invalid API key | Must fail open (exit 0, error on stderr, no stdout) |
| Invalid GEMINI_EFFORT | A value that is neither a thinking level nor a number must fail open with a descriptive error |
| Fake-curl provider tests | Default models and Gemini thinking level or budget in the request, both Gemini price tiers, OpenAI cost without double-counted reasoning, non-numeric token counts, key redaction in API errors, and a tagged stderr line kept out of the findings |
| Both providers invalid | Both must error on stderr, exit 0, no stdout |
| Shellcheck | Static analysis of the script |
| Stdin interface | Script must not require positional arguments |

Tests use a temp directory (via CLAUDE_REVIEWER_ENV) and never touch the real config file.

## Automated: `test-allow-venv-hook.sh`

```bash
tests/test-allow-venv-hook.sh
```

Feeds PreToolUse payloads to `hooks/allow-venv-source.sh` and checks its decision:

| Case | Expected |
|------|----------|
| Venv activation, bare or `&& <next>` chained, outside auto mode | `permissionDecision: allow` |
| Same commands with `permission_mode: auto` | No decision, so the auto-mode classifier judges the whole command |
| No `permission_mode` field | `allow`, the behavior before auto mode existed |
| Unrelated commands, `;` chains, other venv paths, empty command | No decision |

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
