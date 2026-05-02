## Spec — 2026-05-01 — /codereview external mode

**Goal:** Add a new `external` mode to `/codereview` that pipes an arbitrary git diff (default: `<upstream>..HEAD`; explicit refs and ranges supported) to the configured external reviewers (OpenAI, Google, local Qwen) and prints findings to the terminal. No CODEREVIEW.md write, no push marker, no `/codefix`, no Claude internal review, no `/security`, no test-suite run. Use case: span-of-release second opinions like `/codereview external v1.3` and pre-PR cross-model audits, where the full-review path is overkill or wrongly scoped.

### Acceptance Criteria

- [ ] **External-only mode runs reviewers and produces no persistent mutations.** With at least one provider configured, `/codereview external [args]` pipes the resolved diff to `bin/review-external.sh` once, prints findings + cost lines + a footer disclaiming CODEREVIEW.md/marker/codefix mutation, and exits. After the run: CODEREVIEW.md is byte-identical to before; the file at `$(codereview-marker path)` is byte-identical (or absent if it was absent before); no git-tracked source file is modified; `/codefix` is not invoked.

- [ ] **No-config invocation fails loudly before any reviewer call.** When the env file at `${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}` lacks all of `OPENAI_API_KEY`, `GEMINI_API_KEY`, and the (`LOCAL_REVIEW_SCRIPT` + `LOCAL_REVIEW_VENV` + script-file-exists) triple, `/codereview external` stops before any diff computation with a one-line message that names the env file path and at least one missing variable. No `[openai]` / `[google]` / `[qwen]` line appears in output.

- [ ] **Range argument supports the four canonical forms and refuses bogus or empty ranges.** `/codereview external` (no args) reviews `<upstream>..HEAD` using the same upstream-resolution chain as `bin/codereview-marker` (`@{upstream}` → `origin/<current-branch>` → empty tree). `/codereview external <ref>` reviews `<ref>..HEAD`. `/codereview external <from>..<to>` and `/codereview external <from>...<to>` use the range verbatim. Unresolvable ref → stops with a "Cannot resolve" message; empty resolved diff → stops with an "Empty diff" message. Reviewers are not invoked in either failure case.

- [ ] **Marker-collision warning fires only on the default range.** When `bin/codereview-marker hash` exits 0 and its output equals the contents of the file at `$(codereview-marker path)`, `/codereview external` (no args) prints a one-line warning to the user before invoking reviewers; the same condition with an explicit range argument does NOT print the warning. Neither variant prompts the user for confirmation.

- [ ] **`bin/review-external.sh --check` reports providers and preserves the default fail-open path.** No providers configured: `review-external.sh --check` exits 1 with stderr containing the literal "No external reviewers configured" and the env file path. At least one provider configured: exits 0 with exactly one stderr line per provider naming the model. Default no-flag path (`review-external.sh < /dev/null`) with no providers still exits 0 silently — the fail-open contract that `/codereview` Step 5.5 depends on is preserved.

- [ ] **Full Review Mode behavior is unchanged.** `/codereview` with no arguments executes the existing Steps 1-9: reads context files, runs Claude's review, runs the test suite, invokes `/security`, runs external reviewers, writes CODEREVIEW.md, writes the push marker via `codereview-marker write`, can loop into `/codefix`. The pre-push hook gate continues to function. Existing tests in `tests/test-codereview-marker.sh`, `tests/test-pre-push-hook.sh`, and the full-review lint checks pass without modification.

- [ ] **`tests/run-all.sh` succeeds with new lint and behavioral checks added.** New lint in `tests/lint-skills.sh`: (a) `/codereview` frontmatter `argument-hint` advertises the external mode; (b) Step 0 dispatch block exists with both an empty-args branch and an `external` branch; (c) External-Only Mode section with a Step E.1 that invokes `review-external.sh --check`; (d) External-Only Mode body contains neither `codereview-marker write` nor `/codefix` invocation; (e) `bin/review-external.sh` contains both `--check` handling AND the silent-exit-0 fallback for the default no-flag path. New behavioral tests in `tests/test-review-external.sh` cover the four `--check` cases (empty config exits 1; one provider exits 0 with one line; three providers exits 0 with three lines; default no-flag empty-stdin no-config still exits 0 silently).

- [ ] **CLAUDE.md and README.md document the new mode.** CLAUDE.md gains an "External-only review pre-flight contract" bullet under "Prompt/infrastructure boundary" naming the dual-path contract (silent-exit-0 default vs. fail-loud `--check`) and the "no marker write in external mode" invariant. README.md's External Reviewers section gains a paragraph naming `/codereview external [<ref>|<range>]`, providing at least one example invocation (e.g. `/codereview external v1.3`), and explicitly noting the "no CODEREVIEW.md / no marker / no /codefix" semantics.

### Context

**Plan source.** Adopted from `~/.claude/plans/let-s-design-a-new-humming-peacock.md`. The plan contains additional prose recommendations (exact dispatch wording modeled on `/tester` Step 0, exact Step E.1-E.5 structure, exact natural-language normalization examples, exact CLAUDE.md bullet phrasing, exact README.md paragraph wording) that the implementing agent should consult; criteria above are the verifiable subset.

**Resolved design choices (from plan-mode discussion).**
- Marker collision behavior: warn-and-proceed without prompting. Rationale: any `[y/N]` prompt is paid every time someone uses the no-args form casually, even when re-running was the intent. Visible warning + cost log is enough signal.
- Output persistence: terminal-only, no new file. Rationale: keeps CODEREVIEW.md as the sole gating-review artifact; honors the "keep code flows consolidated" constraint. A `--save` flag can be added later without breaking the v1 contract if the need arises.
- No new top-level skill. Mode lives inside `/codereview` (mode dispatch on first token of `$ARGUMENTS`).

**Soft contract not gated by criteria.** The skill prose accepts natural-language range phrasings (e.g. "since v1.3" → `v1.3..HEAD`, "last 5 commits" → `HEAD~5..HEAD`, "between main and HEAD" → `main..HEAD`) and normalizes them before validation. This is interpretation by the LLM and cannot be lint-tested mechanically; the plan documents the canonical forms and natural-language examples the SKILL.md prose must include. Verify by manually invoking `/codereview external since v1.3` and checking the resolved range matches the canonical form.

**Files in scope.**
- `claude/skills/codereview/SKILL.md` — frontmatter `argument-hint`, new Step 0 dispatch, new "External-Only Mode" section with Steps E.1-E.5
- `bin/review-external.sh` — new `--check` flag (loads config without consuming stdin, prints providers to stderr, exits 0/1; default path silent-exit-0 preserved)
- `tests/lint-skills.sh` — five new lint checks (per criterion 7)
- `tests/test-review-external.sh` — four new behavioral tests (per criterion 7)
- `CLAUDE.md` — new "External-only review pre-flight contract" bullet
- `README.md` — extend External Reviewers paragraph

**Out of scope (deliberate v1 cuts; do not add).**
- `--save` / output-to-file flag.
- `--files <path>` filter.
- `--json` output.
- Automatic `/codefix` invocation in external mode.
- New top-level `/external-review` skill.
- Behavioral test that spawns the skill via subagent and greps its output (the structural lint plus manual run is the verification path; behavioral skill tests are real engineering work and not warranted here).

**Relevant zat.env practices.**
- Skill files self-contained and ≤ ~500 lines. Codereview SKILL.md is at 418 lines today; this turn adds Step 0 (~10 lines) and an External-Only Mode section (~40 lines). Watch the budget.
- Prompt/infrastructure boundary. The new `--check` flag is the deterministic side; the Step 0 dispatch and Steps E.1-E.5 are the instructed side. Lint enforces both.
- Builder/verifier tool boundary. `/codereview` keeps `Bash(*)` only (no Edit/Write); external mode uses Bash for diff and pipe, prints to terminal. No new tool permissions needed.
- Coding practices. Land in small committable increments: (1) `bin/review-external.sh --check` with its behavioral tests, (2) skill SKILL.md changes (frontmatter, Step 0, External-Only Mode section) with new lint, (3) docs (CLAUDE.md, README.md). Run `tests/run-all.sh` between increments.

**Validation path.** Lint (`tests/lint-skills.sh`) verifies prose structure; behavioral tests (`tests/test-review-external.sh`) verify `--check` exit codes; manual `/codereview external` run on a real project (zat.env itself, against the `v1.3` tag) verifies the user-visible behavior — terminal output, CODEREVIEW.md byte-equality before/after, marker file byte-equality before/after, range resolution for canonical and natural-language forms.

---
*Prior spec (2026-05-01): /tester design D.4/D.5.5/D.6 ordering fix. 6/6 criteria met. Restored Step D.5.5 as a true pre-mutation gate by removing the file-write semantic from D.4 (now drafts in memory) and consolidating the actual TESTING.md write into D.6 step 1; added 3 lint checks; 510-check baseline preserved.*

<!-- SPEC_META: {"date":"2026-05-01","title":"/codereview external mode","criteria_total":8,"criteria_met":0} -->
