# CLAUDE.md — zat.env repo

This is the `zat.env` repo: Peter Zatloukal's reproducible dev environment configuration for a Hetzner GEX44.

For machine-wide conventions that apply to all projects, see `claude/global-claude.md` (symlinked to `~/.claude/CLAUDE.md`).

## What this repo contains

- `bootstrap-GEX44.sh` — system provisioning script (apt packages, NVIDIA drivers, Docker, Tailscale, Claude Code)
- `zat.env-install.sh` — wires this repo's config into the live system (git config, symlinks)
- `claude/global-claude.md` — machine-wide Claude conventions
- `gitconfig/` — versioned git aliases and global gitignore, included via `~/.gitconfig`
- `hooks/` — future home for reusable git hooks (adversarial review, etc.)
- `templates/` — future home for project scaffolding templates

## Working on this repo

**Shell scripts** (`bootstrap-GEX44.sh`, `zat.env-install.sh`, `bin/*`):
- Must be idempotent — safe to run multiple times
- Use `set -euo pipefail` at the top
- Guard installs with existence checks (`command -v`, `[[ -d ... ]]`, etc.)
- Print `==> Section name` banners so output is scannable

**gitconfig files**:
- `gitconfig/aliases.gitconfig` uses `[alias]` block — plain git alias syntax
- `gitconfig/ignore-global` is a plain gitignore file (no ini sections)

**README.md** — keep the directory overview section updated whenever the repo structure changes.

## What NOT to put here

- Project-specific code, configs, or dependencies — those belong in each project's own repo
- Secrets or credentials of any kind
- Large files (models, datasets) — those go in `~/data/`
