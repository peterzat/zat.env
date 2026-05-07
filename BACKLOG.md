# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.

### tester-design-testing-meta
- **One-line description:** `/tester design` writes the durable contract section to TESTING.md but does not produce a TESTING_META footer; only audit mode does. Cross-skill consumers of TESTING.md metadata (e.g., `/pr` reading review metadata for PR descriptions) cannot tell from metadata alone that a design contract exists in the file. Adding a design-mode TESTING_META (with fields like `contract_shape`, `line_count`, `rollout_count`, `contract_date` rather than the audit's block/warn/note counters) would close this gap.
- **Why deferred:** Out of scope for the current /tester design D.4/D.5.5/D.6 ordering fix turn (SPEC 2026-05-01). No current consumer breaks today (`/pr` and others handle absent TESTING.md and absent metadata gracefully); the contract is human-readable in TESTING.md.
- **Revisit criteria:** A skill or workflow needs to programmatically detect "this project has a design contract" without reading TESTING.md content, OR `/pr`'s PR-description generation grows logic that would benefit from contract metadata, OR a downstream user reports the gap.
- **Origin:** spec 2026-05-01

### loop-resume-and-concurrent-sessions
- **One-line description:** `/loop resume` subcommand and resume-prompt UI (on new session in a project with an Active loop in LOOPS.md, post a structured AskUserQuestion choice — resume / end / abandon — before the first user prompt is processed; default if dismissed = stay paused), plus concurrent-session detection (Active-loop `last-heartbeat` field updated each turn; second session in same project offers wait or takeover-with-confirmation when heartbeat is fresh, treats stale heartbeat as abandoned and offers resume or end). Includes `tests/integration/loop-resume.sh` smoke test.
- **Why deferred:** Both behaviors are session-start integration outside the bookkeeping foundation; meaningful only once mid-loop interruption is realistic.
- **Revisit criteria:** Foundation closes; semi-auto execution lands; user reports a session restart that should have offered resume, or runs two sessions in the same project simultaneously.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-context-guard-hook
- **One-line description:** `hooks/loop-context-guard.sh`: detect compacting event or token-budget breach mid-tool-use, block with `exit 2`, signal halt-loop. Fallback if hook-side detection turns out to be infeasible: skill-side budget self-report at turn boundaries with halt at 70% of compact threshold.
- **Why deferred:** Plan flags this as an investigation item — whether Claude Code's hook event surface exposes context-size telemetry usable for this gate is an open question. Foundation slice does not need it to ship a deterministic mutator and bookkeeping skill.
- **Revisit criteria:** `loop-execution-semi-and-full`'s full-auto half lands and a real loop hits context overflow before its halt budget; OR Claude Code exposes a documented context-size telemetry signal usable from a hook.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-readme-autonomy-spectrum-overhaul
- **One-line description:** Extend `README.md` "Theory of Autonomous Improvement → The Autonomy Spectrum" subsection to document the three operational levels (supervised default = v1.3 behavior, semi-auto, full-auto) alongside the existing capability tiers (Supervised → Gated → Autonomous → Multi-agent). Add a sub-subsection on the loop bookkeeping contract (LOOPS.md schema, halt vocabulary, loop tag naming).
- **Why deferred:** Documenting operational levels in user-facing prose before the autonomous-execution code lands risks overclaim; foundation Roadmap entry is the safe v2.0 acknowledgment for this turn.
- **Revisit criteria:** At least one of `loop-execution-semi-and-full`'s halves shipped and a real loop has run end-to-end on a user project.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-tester-periodic-refresh
- **One-line description:** `/tester design` as periodic proxy refresh: at loop start in semi or full, check whether `TESTING.md`'s design contract section has been updated within the last N=5 closed loops in `LOOPS.md`. Surface a recommendation to the user (semi) or auto-schedule a `/tester design` turn at loop start (full, only when the loop's theme already touches `TESTING.md` scope).
- **Why deferred:** Heuristic that depends on (a) loop runtime existing and (b) accumulating closed-loop data in `LOOPS.md`.
- **Revisit criteria:** A project's `LOOPS.md` accumulates at least 5 closed loops and the user reports the design contract is starting to feel stale.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-config-env-vars
- **One-line description:** Per-project autonomy overrides via env vars in `CLAUDE.md` (e.g., `ZAT_LOOP_TURN_CAP_SEMI=3`, `ZAT_LOOP_TOKEN_HARD=70`). Hard-coded defaults in the `/loop` skill (semi turn cap 5, full turn cap 20, token budget 50% soft / 70% hard) cover the v2.0 baseline.
- **Why deferred:** Defaults are correct for first deployments; per-project tuning waits until a real project hits a default budget wall.
- **Revisit criteria:** A user project (e.g., daydream/) consistently runs against the default budget and the user wants to tune per-project without forking the skill.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-execution-semi-and-full
- **One-line description:** Autonomous turn execution in `/loop`: per-turn flow (read durable artifacts SPEC.md/BACKLOG.md/TESTING.md/CODEREVIEW.md/LOOPS.md → pick proposal from /spec or BACKLOG scoped to the loop's theme → implement → /tester signals → /codereview → atomic commit with `Loop: <mode>/<slug> turn N/M` footer → /clear → next turn) for semi-auto (5-turn budget, manual halts) and full-auto (turn cap default 20, no-progress detection, auto-revert, auto-/clear at every turn boundary, halts on revert-thrash / token budget / D.5.5 flag / codereview BLOCK after fix budget). Per-turn test invocation flows through `/tester` so projects with custom tier systems (e.g., daydream's `bin/game test short`) work without /loop knowing the entry point. Each turn emits start and end announcements as user-visible text messages, not buried in tool calls (hard contract enforced by `tests/lint-loop.sh`). Semi-auto halts present a structured AskUserQuestion choice scoped to the halt cause (revert → {continue same proposal / skip proposal / end loop}; codereview BLOCK → {run /codefix / end / escalate to user review}; D.5.5 flag → {acknowledge and continue / end loop / switch theme}); full-auto halts terminate with a verbose status report and wait. Likely splits into two implementation turns (semi first, full on top).
- **Why deferred:** Foundation slice (spec 2026-05-07) ships the durable persistence contract and bookkeeping skill before the runtime mechanics.
- **Revisit criteria:** Foundation spec closes with all 6 criteria met; user wants to run an autonomous loop on a real project (e.g., daydream/).
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir

### loop-autonomy-aware-skills
- **One-line description:** Autonomy-aware modifications to existing skills and shared conventions: `/spec` detects active loop via LOOPS.md, scopes proposal selection to theme, writes `Loop: <mode>/<slug> turn N/M` footer on turn-close commits; `/codereview` in full-auto writes halt reason to LOOPS.md and terminates loop after BLOCK with fix budget exhausted; `/codefix` atomic-commit-per-fix when invoked inside a loop; `/tester` D.5.5 flag terminates loop in full-auto (never bypassed, even by full-auto); `/pr` description rolls up the loop's turn log from `LOOPS.md`. Plus `claude/global-claude.md` Memory section gains a brief note: "Memory is OFF inside autonomy loops; durable artifacts are the persistence contract."
- **Why deferred:** Autonomy-aware behavior in the consuming skills is meaningless until a loop runtime exists.
- **Revisit criteria:** `loop-execution-semi-and-full` ships its semi-auto half and the per-turn flow needs the consuming skills to participate.
- **Origin:** plan let-s-discuss-and-plan-gleaming-shamir
