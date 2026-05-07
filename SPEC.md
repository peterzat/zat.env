## Spec — 2026-05-07 — v2.0 autonomy foundations: /loop bookkeeping

**Goal:** Land the foundational pieces of the autonomy v2.0 design from `~/.claude/plans/let-s-discuss-and-plan-gleaming-shamir.md`: a deterministic `LOOPS.md` mutator (`bin/loop-state.sh`), single-sourced halt-reason and format references, and a minimal `/loop` skill with `start` / `status` / `end` subcommands. This turn ships bookkeeping only — no autonomous turn execution. The smallest end-to-end coherent deliverable: a user can mark loops in `LOOPS.md` and git, autonomy mechanics arrive in subsequent turns of the same v2.0 program of work.

### Acceptance Criteria

- [ ] **`bin/loop-state.sh` deterministic LOOPS.md mutator with stdin manifest.** Reads ops from stdin (one per line, plus block ops where needed), mutates `LOOPS.md` in place, creates the file with a `# Loops` header if absent. Recognized ops: `start: <mode>/<theme-slug> | <commit-sha>`, `turn-record: <N>/<total> | <commit-sha> | <result>`, `halt: <reason> | <detail>`, `close: <commit-sha> | <outcome>`, `abandon`. Edge cases: empty stdin → exit 0 (no-op); unknown op → log warning to stderr and continue; malformed line for known op → exit non-zero with diagnostic; `start` while an Active loop exists → exit non-zero with diagnostic; `halt` with reason not in halt-vocabulary → exit non-zero. Multiple ops in one manifest run in parse order. Mirrors the `bin/spec-backlog-apply.sh` pattern (heredoc on stdin, deterministic mutation, no LLM-executed file edits to the artifact).

- [ ] **LOOPS.md schema and halt-reason vocabulary single-sourced under `claude/skills/loop/references/`.** `claude/skills/loop/references/loops-format.md` documents the canonical schema: Active loop block (`Started`, `Theme`, `Mode`, `Budget`, `Last halt`, `Last heartbeat`, `Last commit`), Turn log entry format (heading `### Turn N (timestamp) — commit <sha>` plus body), Closed loops section. `claude/skills/loop/references/halt-vocabulary.md` enumerates allowed halt-reason strings, at minimum: `revert`, `revert-thrash`, `codereview-block`, `tester-d55-flag`, `token-budget`, `turn-cap`, `no-progress`, `context-overflow`, `user-end`, `user-abandon`. `bin/loop-state.sh` derives its halt-reason whitelist by reading `claude/skills/loop/references/halt-vocabulary.md` (or its installed path), not by carrying a duplicate hard-coded list; lint asserts no drift between script and reference.

- [ ] **`/loop` skill provides `start` / `status` / `end` subcommands; nothing autonomous.** New skill `claude/skills/loop/SKILL.md` with frontmatter (`argument-hint` advertising the three subcommands) and `Bash(*)` permission only (no Edit/Write — `LOOPS.md` mutations flow through the script). Subcommands:
    - `/loop start <mode> "<theme>"` where `<mode>` ∈ {`semi`, `full`}. Validates we are in a git repo, generates a slug from the theme, pipes a `start` op to `bin/loop-state.sh`, then commits `LOOPS.md` with the canonical start-loop body (mode, theme, budget, halt conditions, loop tag), then creates a `loop/YYYY-MM-DD-<theme-slug>` annotated tag at the start commit. Refuses with a diagnostic if an Active loop already exists in `LOOPS.md`.
    - `/loop status` reads `LOOPS.md` and prints the Active loop block, or `No active loop.` if none.
    - `/loop end` pipes a `close` op to `bin/loop-state.sh` for the active loop, commits the resulting `LOOPS.md` change, creates a `loop-end/YYYY-MM-DD-<theme-slug>` tag at the close commit, and prints a summary. Refuses if no Active loop.
    The skill performs no autonomous turn execution: no auto-`/clear`, no auto-revert, no `/tester` integration, no halt enforcement, no per-turn flow. SKILL.md does not advertise such behaviors.

- [ ] **`tests/run-all.sh` succeeds with new behavioral test and lint.** New `tests/test-loop-state.sh` covers: lifecycle (`start` → `turn-record` → `halt` → `close` produces a `LOOPS.md` whose structure matches the documented schema); empty stdin no-op; unknown op writes warning to stderr and continues; malformed line for known op exits non-zero; `start` when an Active loop exists exits non-zero; `halt` with vocab miss exits non-zero; `abandon` op closes the active loop without requiring a commit-sha. New `tests/lint-loop.sh` asserts: `bin/loop-state.sh` exists, is executable, references `claude/skills/loop/references/halt-vocabulary.md` (or its install location) rather than hard-coding the halt list; the schema doc and halt-vocab doc both exist at their canonical paths; `claude/skills/loop/SKILL.md` exists, advertises `start` / `status` / `end` in `argument-hint`, mentions all three subcommands in the body, does NOT contain phrases that imply autonomous turn execution (e.g., `auto-revert`, `auto /clear`, `per-turn flow`) — anti-overclaim guard. Both tests are invoked from `tests/run-all.sh`.

- [ ] **v1.3 regression: existing skills, hooks, and install behavior preserved.** No SKILL.md outside `claude/skills/loop/` is modified. No `hooks/*.sh` is modified. `zat.env-install.sh` modifications limited to whatever is needed to symlink the new skill into `~/.claude/skills/loop/` (if the existing skill loop is glob-driven, no change is required; otherwise a single additive entry). The full pre-existing test suite (everything except the two new tests) passes byte-identically. A project that never invokes `/loop` and has no `LOOPS.md` sees byte-identical behavior to v1.3 from `/spec`, `/codereview`, `/codefix`, `/tester`, `/security`, `/architect`, `/pr`, and the pre-push hook — no skill or hook reads `LOOPS.md` this turn.

- [ ] **CLAUDE.md and README.md document the new contract without overclaiming.** CLAUDE.md gains a new "Loop bookkeeping contract" bullet under "Prompt/infrastructure boundary" naming: LOOPS.md mutations flow exclusively through `bin/loop-state.sh` (no Write/Edit on LOOPS.md from inside skills, mirroring the BACKLOG mutator); halt-reason vocabulary single-sourced at `claude/skills/loop/references/halt-vocabulary.md`; loop tag naming convention (`loop/YYYY-MM-DD-<slug>`, `loop-end/YYYY-MM-DD-<slug>`); the script's stdin-manifest contract; lint enforcement via `tests/lint-loop.sh`. README.md's Roadmap "Since v1.3 (ongoing)" section gains exactly one new `[x]` bullet for the v2.0 foundations describing what landed (persistence contract, bookkeeping skill, lint and behavioral tests) and what is explicitly deferred (autonomous turn execution, /tester integration, hooks/loop-context-guard.sh, autonomy-aware modifications to the other skills). No other README section is modified — the Autonomy Spectrum diagram, Anti-Patterns, contents, "Next up" / "Future" lists, and prior `Done` sections all remain byte-identical this turn.

### Context

**Plan source.** Adopted from `~/.claude/plans/let-s-discuss-and-plan-gleaming-shamir.md`. The plan describes the *full* v2.0 release: three operational autonomy levels (supervised default, semi-auto with ≤5-turn budget, full-auto with token+turn+no-progress halts), per-turn auto-`/clear`, auto-revert policy, `/tester design` as periodic proxy refresh, hook-based compacting detection, autonomy-aware modifications to `/spec`, `/codereview`, `/codefix`, `/tester`, `/pr`, and a verification-of-release checklist. This spec is the *first turn* of that release, scoped to the foundation per zat.env's coding practices ("Work in small, committable increments. Get one thing working before adding the next. Do not build scaffolding for features that are not needed yet."). The implementing agent should consult the plan for design rationale on locked decisions (no `/verify` skill, `/loop` as a new top-level skill, git tags + LOOPS.md instead of SemVer, `/tester` cadence stale-design check, memory OFF inside loops) and for the eventual shape of subsequent turns; the criteria above are the verifiable subset deliverable in this turn.

**Why this slice.** Foundation alone (mutator + references) is scaffolding without consumers; minimal-skill alone has no deterministic substrate. Together they form the smallest end-to-end coherent deliverable: a user can run `/loop start semi "<theme>"` and get an Active-loop record in `LOOPS.md`, a start commit, and an annotated git tag — useful for journaling and for future tooling that grep`s loop tags from history, even before autonomy execution lands. The mutator's op vocabulary is locked here, so subsequent turns can extend it (heartbeat updates, revert tracking, configurable budgets) and the skill can grow autonomy mechanics without breaking the schema or the lint baseline.

**Files in scope.**
- `bin/loop-state.sh` — new deterministic mutator
- `claude/skills/loop/SKILL.md` — new skill (start / status / end)
- `claude/skills/loop/references/loops-format.md` — schema spec
- `claude/skills/loop/references/halt-vocabulary.md` — halt-reason whitelist
- `tests/test-loop-state.sh` — behavioral
- `tests/lint-loop.sh` — structural
- `tests/run-all.sh` — invoke new tests
- `zat.env-install.sh` — only what's needed to symlink the new skill (likely no change if the existing loop is glob-driven)
- `CLAUDE.md` — Loop bookkeeping contract bullet
- `README.md` — single new `[x]` bullet under Roadmap "Since v1.3 (ongoing)"; no other section changes

**Out of scope (deferred to subsequent turns of v2.0; do not add).**
- Autonomous turn execution within a loop (per-turn flow, auto-`/clear` at turn boundary, auto-revert on test regression, halt enforcement, codereview-BLOCK termination behavior, no-progress detection, token budget enforcement)
- Modifications to `/spec`, `/codereview`, `/codefix`, `/tester`, `/pr` for autonomy awareness
- `hooks/loop-context-guard.sh` (compacting / token-budget detection from a hook event vs skill-side fallback — investigation item from the plan)
- `/loop resume` subcommand and the resume-prompt UI for new sessions discovering an active loop
- `/tester design` as periodic proxy refresh (stale-design check against last N=5 closed loops)
- README Autonomy Spectrum diagram overhaul to add operational levels (supervised / semi / full); the spectrum currently uses Supervised → Gated → Autonomous → Multi-agent, and the plan's operational-mode overlay belongs in the turn that ships autonomy execution
- Concurrent-session detection via `last-heartbeat` (the schema documents the field; the script supports it via `turn-record` op; the 30-min takeover/wait UI is skill-side and out of scope here)
- Configuration via env vars or per-project overrides (turn caps, token budgets) — hard-coded defaults are fine for the foundation
- Loop-aware `/pr` description rollup
- Integration test `tests/integration/loop-resume.sh` (covers `/loop resume`, deferred with that subcommand)

**Relevant zat.env practices.**
- Skill files self-contained and ≤ ~500 lines; references for detail. The new `/loop` SKILL.md should stay well under that budget; the autonomy mechanics added in subsequent turns will push toward the limit.
- Prompt/infrastructure boundary. The `/loop` skill (instructed) calls `bin/loop-state.sh` (deterministic) for all `LOOPS.md` mutations. Mirrors BACKLOG.md: skills decide, scripts execute. No Write/Edit on `LOOPS.md` from inside any skill.
- Builder/verifier tool boundary. `/loop` is orchestration: needs `Bash(*)` for the mutator, git commits, and tags; no Edit/Write tooling. The skill body must explicitly forbid LLM-executed `LOOPS.md` mutation.
- Coding practices. Land in small committable increments: (1) `bin/loop-state.sh` + behavioral test, (2) references files (`loops-format.md`, `halt-vocabulary.md`), (3) `/loop` SKILL.md + install wiring + lint, (4) docs (CLAUDE.md, README.md). Run `tests/run-all.sh` between increments. Verify the test suite is green before any change.
- Memory contract from the plan: memory is OFF inside loops; durable artifacts are the persistence path. This is design intent for the autonomous-execution turn; for this foundation turn it is documented but not enforced (no autonomous flow exists yet to enforce against).

**Validation path.**
- Behavioral test `tests/test-loop-state.sh` verifies the script's lifecycle and edge cases; run via `tests/run-all.sh`.
- Structural lint `tests/lint-loop.sh` verifies SKILL.md prose contains the three subcommands, lacks autonomy-execution claims, and that the script consults `halt-vocabulary.md` rather than hard-coding strings; run via `tests/run-all.sh`.
- Manual end-to-end on this repo after install: run `zat.env-install.sh`, restart the Claude session so `/loop` is discovered, then `/loop start semi "trial"` writes `LOOPS.md`, creates a start commit, creates a `loop/2026-05-07-trial` tag; `/loop status` shows the active loop; `/loop end` closes it and creates a `loop-end/2026-05-07-trial` tag. Verify with `git tag -l 'loop*'` and `git log --oneline | head`.
- v1.3 regression check: in this same repo, before installing, capture output of `/spec`, `/codereview` (no-args info), `/tester audit` against a known commit; after installing the new skill but with no `LOOPS.md` in the project, capture again; compare. Anything diverging is a regression to fix before merge.

---
*Prior spec (2026-05-01): /codereview external mode. 8/8 criteria met. New Step 0 dispatch on first arg token routes to External-Only Mode (Steps E.1-E.5) which runs configured external reviewers on a resolved diff and prints to terminal without mutating CODEREVIEW.md, the push marker, or invoking /codefix; `bin/review-external.sh` gained `--check` and `--range` flags; hardening landed alongside (marker dir moved to `${XDG_CACHE_HOME}/...`, pre-push hook fail-closed on script error, single-source skip-marker path).*

<!-- SPEC_META: {"date":"2026-05-07","title":"v2.0 autonomy foundations: /loop bookkeeping","criteria_total":6,"criteria_met":0} -->
