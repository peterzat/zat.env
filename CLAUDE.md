# CLAUDE.md — zat.env repo

This is the `zat.env` repo: Peter Zatloukal's reproducible dev environment configuration for a Hetzner GEX44.

For machine-wide conventions that apply to all projects, see `claude/global-claude.md` (symlinked to `~/.claude/CLAUDE.md`).

## What this repo contains

- `hw-bootstrap.sh` — system provisioning script (apt packages, NVIDIA drivers, Docker, Tailscale, Claude Code)
- `zat.env-install.sh` — wires this repo's config into the live system (git config, symlinks, skills, hooks)
- `claude/global-claude.md` — machine-wide Claude conventions
- `claude/references/` — detailed reference docs (networking, ML/GPU) read on demand
- `claude/skills/` — global Claude Code skills: `/spec`, `/codereview`, `/codefix`, `/security`, `/architect`, `/tester`, `/pr`
- `bin/review-external.sh` — optional external multi-model reviewer (stdin diff, stdout findings)
- `gitconfig/` — versioned git aliases and global gitignore, included via `~/.gitconfig`
- `hooks/` — Claude Code hooks; `pre-push-codereview.sh` gates git push on passing `/codereview`

## Working on this repo

**Shell scripts** (`hw-bootstrap.sh`, `zat.env-install.sh`, `bin/*`):
- Must be idempotent — safe to run multiple times
- Use `set -euo pipefail` at the top
- Guard installs with existence checks (`command -v`, `[[ -d ... ]]`, etc.)
- Print `==> Section name` banners so output is scannable

**Skill files** (`claude/skills/<name>/SKILL.md`):
- Each skill is a self-contained prompt; starts with YAML frontmatter then Markdown instructions
- Skills must be self-sufficient — they start with empty context and gather their own information
- Keep each SKILL.md under ~500 lines; use `references/` subdirectory if details grow
- After modifying any skill or hook, run `tests/run-all.sh` to check structural consistency

**Hook scripts** (`hooks/*.sh`):
- Must be idempotent and have no side effects other than blocking/allowing the action
- Exit 0 = allow, exit 2 = block (stderr is shown to Claude)
- Registered in `~/.claude/settings.json` by `zat.env-install.sh`

**gitconfig files**:
- `gitconfig/aliases.gitconfig` uses `[alias]` block — plain git alias syntax
- `gitconfig/ignore-global` is a plain gitignore file (no ini sections)

**README.md vs. CLAUDE.md audience split** — CLAUDE.md is for developers working on this repo: what to check, what must stay in sync, how to test. README.md is for downstream users: how the system works, the design philosophy, what to expect. They serve different purposes and should not repeat each other. Operational guidance (contract points, lint instructions) goes in CLAUDE.md. Conceptual explanations (enforcement model, trade-offs) go in README.md. Keep the directory overview section in README.md updated whenever the repo structure changes.

**Coding Practices sync** — the `## Coding Practices` section in `README.md` is a verbatim copy of the bullet points in `claude/global-claude.md`. Whenever `global-claude.md`'s Coding Practices section changes, update `README.md` to match.

**Prompt/infrastructure boundary** — this repo has two kinds of logic: deterministic (hook scripts, helper scripts, marker files) and instructed (skill prompts interpreted by the LLM). These interact at specific contract points that must stay in sync:

- **Marker hash computation.** The codereview skill (Step 8) contains a bash snippet the LLM executes to write the push marker. The pre-push hook recomputes the same hash independently. If the PROJ_HASH derivation, sha256 truncation, or file exclusion list drifts between them, the review passes but the push is blocked. `tests/lint-skills.sh` extracts and compares these values.
- **REVIEW_META field names.** Codereview writes the JSON footer, refresh detection (Step 2) and /pr merge grep for specific field names. A renamed field breaks the readers silently. Lint checks verify field name identity across all three consumers.
- **Skip marker path.** The `codereview-skip` script and the pre-push hook must use identical path templates and PROJ_HASH derivation. Lint checks compare these.
- **Builder/verifier tool boundary.** Codereview cannot Edit/Write (enforced by allowed-tools), but has Bash(*). The "Never fix code yourself" instruction is the only guard against `sed -i`. It is positioned in Prompt Design Principles (before Step 1) so the LLM reads it early. Codefix similarly has Bash(*) and could modify CODEREVIEW.md via shell redirects; the do-not-modify list names each file explicitly.

When editing any skill, hook, or bin script, run `tests/run-all.sh` afterward. The structural checks verify these contracts have not drifted. If you add a new contract point (new marker, new cross-skill field, new shared path), add a corresponding lint check.

**Upstream fix pattern** — when an issue is discovered while working on a downstream project (skill produces wrong output, convention is missing, prompt needs adjustment), the fix is made in the zat.env repo, never patched locally in a downstream project. Changes to skills, hooks, and global-claude.md affect every project on the machine, so always confirm the intended change with the user before editing. Test the fix by re-running the skill or checking global-claude.md in a downstream project session. The goal is that improvements compound: every fix benefits all future projects.

## What NOT to put here

- Project-specific code, configs, or dependencies — those belong in each project's own repo
- Secrets or credentials of any kind
- Large files (models, datasets) — those go in `~/data/`
