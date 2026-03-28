# CLAUDE.md — zat.env repo

This is the `zat.env` repo: Peter Zatloukal's reproducible dev environment configuration for a Hetzner GEX44.

For machine-wide conventions that apply to all projects, see `claude/global-claude.md` (symlinked to `~/.claude/CLAUDE.md`).

## What this repo contains

- `bootstrap-GEX44.sh` — system provisioning script (apt packages, NVIDIA drivers, Docker, Tailscale, Claude Code)
- `zat.env-install.sh` — wires this repo's config into the live system (git config, symlinks, skills, hooks)
- `claude/global-claude.md` — machine-wide Claude conventions
- `claude/skills/` — global Claude Code skills: `/codereview`, `/security`, `/architect`, `/tester`
- `gitconfig/` — versioned git aliases and global gitignore, included via `~/.gitconfig`
- `hooks/` — Claude Code hooks; `pre-push-codereview.sh` gates git push on passing `/codereview`
- `templates/` — future home for project scaffolding templates

## Working on this repo

**Shell scripts** (`bootstrap-GEX44.sh`, `zat.env-install.sh`, `bin/*`):
- Must be idempotent — safe to run multiple times
- Use `set -euo pipefail` at the top
- Guard installs with existence checks (`command -v`, `[[ -d ... ]]`, etc.)
- Print `==> Section name` banners so output is scannable

**Skill files** (`claude/skills/<name>/SKILL.md`):
- Each skill is a self-contained prompt; starts with YAML frontmatter then Markdown instructions
- Skills must be self-sufficient — they start with empty context and gather their own information
- Keep each SKILL.md under ~500 lines; use `references/` subdirectory if details grow

**Hook scripts** (`hooks/*.sh`):
- Must be idempotent and have no side effects other than blocking/allowing the action
- Exit 0 = allow, exit 2 = block (stderr is shown to Claude)
- Registered in `~/.claude/settings.json` by `zat.env-install.sh`

**gitconfig files**:
- `gitconfig/aliases.gitconfig` uses `[alias]` block — plain git alias syntax
- `gitconfig/ignore-global` is a plain gitignore file (no ini sections)

**README.md** — keep the directory overview section updated whenever the repo structure changes.

**Coding Practices sync** — the `## Coding Practices` section in `README.md` is a verbatim copy of the bullet points in `claude/global-claude.md`. Whenever `global-claude.md`'s Coding Practices section changes, update `README.md` to match.

## What NOT to put here

- Project-specific code, configs, or dependencies — those belong in each project's own repo
- Secrets or credentials of any kind
- Large files (models, datasets) — those go in `~/data/`
