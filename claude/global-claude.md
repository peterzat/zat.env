# Global Claude Conventions

This file is symlinked to `~/.claude/CLAUDE.md` and applies to all projects on this machine.

## Git Identity

All commits must be attributed solely to the configured `user.name`. Never add Co-Authored-By trailers. Identity is set by `zat.env-install.sh` (prompted on first run, reused from git config on subsequent runs).

## Shared System Boundary

Skills (`~/.claude/skills/`), hooks, and this file (`~/.claude/CLAUDE.md`) are symlinked
from `~/src/zat.env/`. Editing them in-place from a downstream project modifies the shared
system. When working on any project other than zat.env itself, do not modify these files.
If a skill produces wrong behavior or a convention needs updating, note the issue and defer
the fix to a zat.env session.

Memory file conventions are in the Memory section below. If a skill does the wrong thing,
the fix belongs in the skill definition in zat.env, not in a per-project memory file that
patches around the behavior.

## Memory

Memory persistence hierarchy, most to least durable:
1. CLAUDE.md (global + project) -- conventions, always loaded
2. Skills -- reusable prompts, shared across projects
3. Working documents (SPEC.md, TESTING.md, etc.) -- project state, read by skills on demand
4. Memory files -- cross-conversation context per project
5. Plans/Tasks -- current conversation only

Save to memory: user profile, feedback/corrections, external system pointers,
project context not derivable from code or git. Durable operational facts about a
project (required env setup, CI quirks, test prerequisites) belong in that project's
CLAUDE.md, not memory. Working documents are managed by their respective skills.
If MEMORY.md has more than 10 entries, review for staleness before adding more.
During review, check whether any memories contain durable facts that belong in the
project's CLAUDE.md; if so, promote and delete the memory.

## Specification Quality

When editing acceptance criteria outside `/spec`, apply the same pressure-test rigor the skill uses: what input breaks it, what assumptions are unstated, what failure behavior is unspecified. Do not remove, reword, or reorder acceptance criteria in SPEC.md; only check them off when verified.

## Coding Practices

- Work in small, committable increments. Get one thing working before adding the next.
  Do not build scaffolding for features that are not needed yet.
- Before implementing changes, verify the project builds and existing tests pass.
  Fix pre-existing failures before adding new work.
- When adding or changing functionality, write or update tests in the same increment.
  If the project has no test infrastructure, add a minimal test runner first.
- Run the test suite (or the relevant subset) after each functional change.
  Do not stack multiple untested changes.
- When fixing a bug, change only what is necessary. Do not refactor surrounding code
  or improve unrelated code in the same change.
- If a change causes previously passing tests to fail, revert it and try a different
  approach. Do not modify tests to accommodate a regression.
- If two consecutive fix attempts fail, stop, revert to the last working state, and
  re-evaluate the approach.
- Before switching tasks or when context grows large, write key decisions and current
  state to a file (commit message, README, or project-specific doc). Prefer restarting
  with a written plan over continuing with a long, stale context.
- Do not push, open PRs, or modify remote state unless explicitly asked. Committing
  is local and reversible; pushing is a shared-state action for the user to decide.

## Writing Style

When writing human-readable output (commit messages, review findings, explanations,
persistent files like SPEC.md/CODEREVIEW.md/SECURITY.md/TESTING.md, README content):

- Professional, direct, concise. State the point, then support it.
- No AI-voice patterns ("It's important to note that," "Let's," "Great question,"),
  no em-dashes (use commas, periods, or parentheses), no emoji unless requested.
- Prefer short declarative sentences. When uncertain, say so plainly.

## Python

- Always use `python3 -m venv .venv` per project. Never `pip install` outside a venv.
- `PIP_REQUIRE_VIRTUALENV=true` is set globally.
- System Python (3.10) is for tooling only.

## ML / GPU

20GB VRAM (RTX 4000 SFF Ada), 70W TDP. Large datasets and model files go in `~/data/`, not in project directories or git. For full conventions see `~/src/zat.env/claude/references/ml-gpu.md`.

## Networking

Tailscale hostname `dev`, bind services to `0.0.0.0`, UFW active. For full conventions see `~/src/zat.env/claude/references/networking.md`.

## Secrets

`.env` files are globally gitignored. Use environment variables or a secrets manager. Tailscale-scoped access preferred for internal services.
