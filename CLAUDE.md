# CLAUDE.md — zat.env repo

This is the `zat.env` repo: a reproducible Claude Code harness — skills, hooks, conventions, and an install script that wires them into the live system. For what the system does and how downstream users adopt it, see [README.md](README.md). For machine-wide Claude conventions active in every session, see [`claude/global-claude.md`](claude/global-claude.md) (symlinked to `~/.claude/CLAUDE.md`).

This file is for developers modifying this repo: what each piece is, what must stay in sync, how to test changes.

## What this repo contains

- `zat.env-install.sh` — wires this repo's config into the live system (git config, symlinks, skills, hooks). Idempotent; safe to re-run.
- `hw-bootstrap.sh` — optional system provisioning (apt packages, NVIDIA drivers, Docker, Tailscale, Claude Code). Targets Ubuntu 22.04 dev boxes; downstream adopters typically don't need it.
- `claude/global-claude.md` — machine-wide Claude conventions
- `claude/references/` — detailed reference docs (networking, ML/GPU) read on demand
- `claude/skills/` — global Claude Code skills: `/spec` (with `backlog` and `plan` subcommands), `/codereview`, `/codefix`, `/security`, `/architect`, `/tester`, `/pr`
- `bin/` — helper scripts: `review-external.sh` (multi-model reviewer, stdin diff → stdout findings), `spec-backlog-apply.sh` (deterministic BACKLOG.md mutator), `codereview-skip` (one-shot push-gate bypass), `claude-fixed-reasoning` (launcher with non-adaptive thinking), `zatmux` (tmux session toggle)
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

- **Marker hash computation.** Codereview Step 8 writes the push marker; the pre-push hook recomputes the same hash independently. PROJ_HASH derivation, sha256 truncation, and the file exclusion list must match across both sites — drift means the review passes but the push is blocked.
- **REVIEW_META field names.** Codereview writes a JSON footer; refresh detection (Step 2) and `/pr merge` grep for specific field names. Renaming a field silently breaks the readers.
- **Skip marker path.** `bin/codereview-skip` and the pre-push hook must use identical path templates and PROJ_HASH derivation.
- **Builder/verifier tool boundary.** Codereview and codefix have `Bash(*)` but no Edit/Write. The "Never fix code yourself" instruction (codereview, in Prompt Design Principles) and the explicit do-not-modify list (codefix) are the only guards against `sed -i` or shell-redirect bypass.
- **BACKLOG.md prompt contracts.** Three intra-spec producer/consumer handoffs with no runtime gate: `### Backlog Sweep` (produced in Step 3c.5, consumed in Step 3g, summarized in Step 5); `### Revisit candidates` (produced in Step 3d, consumed in Step 3g); and the four-field entry template (`One-line description`, `Why deferred`, `Revisit criteria`, `Origin`) duplicated between Step 3c and the BACKLOG.md Format section. A subsection rename or field rename in one site silently misses entries in the other.
- **Sweep manifest stdin interface.** Spec Step 3g pipes a manifest to `bin/spec-backlog-apply.sh` via heredoc; the script parses `delete:` and `adopt:` ops and mutates BACKLOG.md deterministically. This split exists precisely so LLM non-compliance on state-mutation edits cannot silently rot BACKLOG.md: the skill decides; the script executes. Op prefixes and the annotation regex (`(ACTIVE in spec YYYY-MM-DD)`) must stay identical between skill and script.

When editing any skill, hook, or bin script, run `tests/run-all.sh` afterward. If you add a new contract point (new marker, new cross-skill field, new shared path), add a corresponding lint check.

**Upstream fix pattern** — when an issue is discovered while working on a downstream project (skill produces wrong output, convention is missing, prompt needs adjustment), the fix is made in this repo, never patched locally in a downstream project. Changes to skills, hooks, and global-claude.md affect every project on the machine, so always confirm the intended change with the user before editing. Test the fix by re-running the skill or checking global-claude.md in a downstream project session. The goal is that improvements compound: every fix benefits all future projects.

## What NOT to put here

- Project-specific code, configs, or dependencies — those belong in each project's own repo
- Secrets or credentials of any kind
- Large files (models, datasets) — those go in `~/data/`
