# CLAUDE.md — zat.env repo

This is the `zat.env` repo: a reproducible Claude Code harness — skills, hooks, conventions, and an install script that wires them into the live system. For what the system does and how downstream users adopt it, see [README.md](README.md). For machine-wide Claude conventions active in every session, see [`claude/global-claude.md`](claude/global-claude.md) (symlinked to `~/.claude/CLAUDE.md`).

This file is for developers modifying this repo: what each piece is, what must stay in sync, how to test changes.

## What this repo contains

- `zat.env-install.sh` — wires this repo's config into the live system (git config, symlinks, skills, hooks). Idempotent; safe to re-run.
- `hw-bootstrap.sh` — optional system provisioning (apt packages, NVIDIA drivers, Docker, Tailscale, Claude Code). Targets Ubuntu 22.04 dev boxes; downstream adopters typically don't need it.
- `claude/global-claude.md` — machine-wide Claude conventions
- `claude/references/` — detailed reference docs (networking, ML/GPU) read on demand
- `claude/skills/` — global Claude Code skills: `/spec` (with `backlog` and `plan` subcommands), `/codereview`, `/codefix`, `/security`, `/architect`, `/tester`, `/pr`
- `bin/` — helper scripts: `review-external.sh` (multi-model reviewer, stdin diff → stdout findings), `spec-backlog-apply.sh` (deterministic BACKLOG.md mutator), `codereview-marker` (single-source codereview push marker hash/write/path), `codereview-skip` (one-shot push-gate bypass), `claude-fixed-reasoning` (launcher with non-adaptive thinking), `zatmux` (tmux session toggle)
- `gitconfig/` — versioned git aliases and global gitignore, included via `~/.gitconfig`
- `hooks/` — Claude Code hooks: `pre-push-codereview.sh` (gates `git push` on passing review), `allow-venv-source.sh` (auto-approves venv activation), `post-tool-exit-plan-mode.sh` (reminds about `/spec plan` after exiting plan mode)
- `tests/` — structural lint and behavioral tests; `tests/run-all.sh` runs every suite
- `docs/` — extended walkthroughs (e.g., `hardware-setup.md`)

## Working on this repo

**Shell scripts** (`hw-bootstrap.sh`, `zat.env-install.sh`, `bin/*`):
- Must be idempotent — safe to run multiple times
- Use `set -euo pipefail` at the top
- Guard installs with existence checks (`command -v`, `[[ -d ... ]]`, etc.)
- Print `==> Section name` banners so output is scannable

**Skill files** (`claude/skills/<name>/SKILL.md`):
- Self-contained prompt; YAML frontmatter then Markdown
- Skills must be self-sufficient — they start with empty context and gather their own information
- Keep each SKILL.md under ~500 lines; use `references/` subdirectory if details grow
- After modifying any skill or hook, run `tests/run-all.sh` to check structural consistency

**Hook scripts** (`hooks/*.sh`):
- Idempotent and side-effect-free other than blocking/allowing the action
- Exit 0 = allow, exit 2 = block (stderr is shown to Claude)
- Registered in `~/.claude/settings.json` by `zat.env-install.sh`

**gitconfig files**:
- `gitconfig/aliases.gitconfig` uses `[alias]` block — plain git alias syntax
- `gitconfig/ignore-global` is a plain gitignore file (no ini sections)

**README.md vs. CLAUDE.md audience split** — CLAUDE.md is for developers working on this repo: what to check, what must stay in sync, how to test. README.md is for downstream users: how the system works, the design philosophy, what to expect. They serve different purposes and should not repeat each other. Operational guidance (contract points, lint instructions) goes in CLAUDE.md. Conceptual explanations (enforcement model, trade-offs) go in README.md. Keep the directory overview section in README.md updated whenever the repo structure changes.

**Coding Practices sync** — the `## Coding Practices` section in `README.md` is a verbatim copy of the bullet points in `claude/global-claude.md`. Whenever `global-claude.md`'s Coding Practices section changes, update `README.md` to match.

**Prompt/infrastructure boundary** — this repo has two kinds of logic: deterministic (hook scripts, helper scripts, marker files) and instructed (skill prompts interpreted by the LLM). They interact at specific contract points where prose and code must stay in sync. `tests/lint-skills.sh` enforces each one:

- **Marker hash computation.** Codereview Step 8 writes the push marker via `codereview-marker write`; the pre-push hook reads the current hash via `codereview-marker hash` and compares it to the marker file. Both sites invoke the same `bin/codereview-marker` script, so PROJ_HASH derivation, UPSTREAM resolution (with the `@{upstream}` → `origin/<branch>` → empty-tree fallback chain), sha256 truncation, and the exclusion list are single-sourced. Lint enforces that neither the SKILL.md nor the hook carries inline `UPSTREAM=`, `${UPSTREAM}`, or `sha256sum ... cut` patterns — they belong in the script. The previous parallel-bash-snippet contract drifted silently in PanelForge when the LLM split codereview's Step 8 snippet across multiple Bash tool calls (shell variables don't persist across Bash tool invocations, so `${UPSTREAM}` went empty in the second call and the marker fell through to the empty-tree hash); the script eliminates that failure mode by making the whole computation one bash invocation regardless of how the LLM partitions its calls.
- **REVIEW_META field names.** Codereview writes a JSON footer; refresh detection (Step 2) and `/pr merge` grep for specific field names. Renaming a field silently breaks the readers.
- **Skip marker path.** `bin/codereview-skip` and the pre-push hook must use identical path templates and PROJ_HASH derivation.
- **Builder/verifier tool boundary.** Codereview has `Bash(*)` but no Edit/Write (verifier-only); codefix has Edit but no Write (modifies existing code, does not create files). The "Never fix code yourself" instruction (codereview, in Prompt Design Principles) and the explicit do-not-modify list (codefix) are the only guards against `sed -i` or shell-redirect bypass. Writer skills (`/spec`, `/tester`, `/security`) carry Write/Edit because they create and update working documents — `/tester` in particular had Write/Edit added when `/tester design` landed so it could write the durable contract section of TESTING.md. All BACKLOG.md mutations by `/spec` and `/tester` still flow through `spec-backlog-apply.sh` (see the Sweep manifest bullet); Write/Edit on BACKLOG.md from inside a skill is a regression.
- **BACKLOG.md prompt contracts.** Three intra-spec producer/consumer handoffs with no runtime gate: `### Backlog Sweep` (produced in Step 3c.5, consumed in Step 3g, summarized in Step 5); `### Revisit candidates` (produced in Step 3d, consumed in Step 3g); and the four-field entry template (`One-line description`, `Why deferred`, `Revisit criteria`, `Origin`) duplicated between Step 3c and the BACKLOG.md Format section. A subsection rename or field rename in one site silently misses entries in the other.
- **Sweep manifest stdin interface.** Spec Step 3g and `/tester design` Step D.6 pipe manifests to `bin/spec-backlog-apply.sh` via heredoc; the script parses `delete:`, `adopt:`, `purge-origin:`, and `append:` / `end-append` ops and mutates BACKLOG.md deterministically. All BACKLOG.md mutations flow through the script; no Write/Edit on BACKLOG.md from inside the skills. This split exists precisely so LLM non-compliance on state-mutation edits cannot silently rot BACKLOG.md: the skill decides; the script executes. Op prefixes, the `end-append` delimiter, and the annotation regex (`(ACTIVE in spec YYYY-MM-DD)`) must stay identical between skill and script. `purge-origin`'s carve-out for ACTIVE-annotated entries lives in the script's awk and is what lets `/tester design` dedup prior rollout entries without destroying adopted work. `append:`'s same-name collision check (with or without annotation) is the gate that stops `/tester design` from producing duplicate headings on revision.
- **External-only review pre-flight contract.** `/codereview external` Step E.1 invokes `review-external.sh --check`; the script's `--check` mode reads the same `~/.config/claude-reviewers/.env` and applies the same `HAS_OPENAI`/`HAS_GOOGLE`/`HAS_LOCAL` derivation as its default stdin-reading mode, so a config edit affects both paths identically. The default no-flag invocation must remain fail-open (silent exit 0) so the full `/codereview` Step 5.5 stays fail-open when reviewers are unconfigured; only `--check` flips to fail-loud (exit 1). The External-Only Mode body must NOT contain `codereview-marker write` (the push marker is gating-review-only) or invoke `/codefix` (external mode is analysis-only), and the user-visible footer must explicitly disclaim CODEREVIEW.md / marker / codefix mutation so the user does not confuse external mode with the gate semantics of full review. `tests/lint-skills.sh` enforces argument-hint advertising the mode, the Step 0 dispatch branches, the Step E.1 `--check` invocation, the no-marker / no-codefix invariants in the External-Only Mode body, and the disclaimer prose. The `--check` and silent-exit-0 fallback are both lint-asserted in `bin/review-external.sh`, with provider `call_*` functions structurally pinned to `return` (not `exit`) so a single provider failure cannot abort the parallel run.
- **Tester/spec cross-skill contracts.** Four contact points where `/tester` prose must agree with `/spec` prose (or with itself). (1) The BACKLOG.md four-field entry template is duplicated in `/spec` (Step 3c and BACKLOG.md Format section) and `/tester` (Design Mode Step D.5); a field rename in any one site breaks consumers. (2) `tester design YYYY-MM-DD` is a canonical Origin form listed in `/spec`'s BACKLOG.md Format and emitted by `/tester design`; drift on either side means tester entries look ad-hoc to `/spec`'s sweep and overlap scans. (3) `# Durable test-architecture contract` is the exact H1 heading `/tester` Design Mode Step D.6 step 1 writes (Step D.4 only drafts in memory; the actual write moved to D.6 to make D.5.5 a true pre-mutation gate) and `/tester` audit Step 5 preserves; a rename in one site means audit mode stops preserving the contract. (4) `/tester design` Step D.5.5 posts a fixed five-component pre-apply checklist (signals fingerprint, contract shape + line count, rollout count + justification, per-entry overlap scan, conditional SPEC tension) to the user before any TESTING.md or BACKLOG.md mutation in Step D.6; the checklist is always-on, the SPEC tension component is flag-not-block, and `tests/lint-skills.sh` enforces all five component names, both guards, and the D.4-drafts/D.6-writes ordering (D.4 has no imperative-write phrasing; D.6 step 1 owns the H1-replace revision-behavior text). This is the user's only course-correct surface for proportionality and overlap calls; silent drift on a component name or on the always-on/flag-not-block guards or on the ordering shrinks that surface.

When editing any skill, hook, or bin script, run `tests/run-all.sh` afterward. If you add a new contract point (new marker, new cross-skill field, new shared path), add a corresponding lint check.

**Upstream fix pattern** — when an issue is discovered while working on a downstream project (skill produces wrong output, convention is missing, prompt needs adjustment), the fix is made in this repo, never patched locally in a downstream project. Changes to skills, hooks, and global-claude.md affect every project on the machine, so always confirm the intended change with the user before editing. Test the fix by re-running the skill or checking global-claude.md in a downstream project session. The goal is that improvements compound: every fix benefits all future projects.

## What NOT to put here

- Project-specific code, configs, or dependencies — those belong in each project's own repo
- Secrets or credentials of any kind
- Large files (models, datasets) — those go in `~/data/`
