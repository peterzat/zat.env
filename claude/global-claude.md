# Global Claude Conventions — GEX44 Dev Box

This file is symlinked to `~/.claude/CLAUDE.md` and applies to all projects on this machine.

## Git Identity

All commits must be attributed solely to the configured `user.name`. Never add Co-Authored-By trailers. Identity is set by `zat.env-install.sh` (prompted on first run, reused from git config on subsequent runs).

## Python

- Always use `python3 -m venv .venv` per project. Never `pip install` outside a venv.
- `PIP_REQUIRE_VIRTUALENV=true` is set globally — pip will refuse if no venv is active.
- `newproj` auto-creates `.venv` in new projects.
- Pin dependencies in `requirements.txt` or `pyproject.toml`.
- System Python (3.10) is for tooling only.

## Project Layout

- All projects live under `~/src/<name>/`
- Large datasets and shared model files go in `~/data/` — never inside project dirs, never in git
- Each project has its own git repo, venv, and (when running) tmux session

## ML / GPU Conventions

- **Shared HF cache**: `~/.cache/huggingface` — never override `HF_HOME` per-project; all projects share the same downloaded models
- **Model sizing**: 20GB VRAM fits ~7–8B models natively; ~32B quantized (IQ4_XS ≈ 16–17 GB)
- **70W TDP**: this GPU is for inference and experimentation, not heavy training — expect power throttling on sustained training workloads
- **Docker GPU**: always use `--gpus all --shm-size=8g` (or `--ipc=host`) for PyTorch DataLoader with num_workers > 0
- **gcc**: system gcc-11 is CUDA-compatible — do not install or switch gcc versions
- **CUDA_HOME**: `/usr/local/cuda`

## Claude Code Permissions

- Global settings: `~/.claude/settings.json`
- Repo-scoped settings: `.claude/settings.local.json` in each project (tracked in git)
- `defaultMode: auto` — uses AI classifier instead of per-command prompts; still blocks
  genuinely dangerous operations (curl-pipe-bash, force push to main, etc.)
- Skills declare `allowed-tools` in frontmatter for uninterrupted execution
- For narrow additional permissions, add `Bash(pattern:*)` to the `allow` list rather than
  widening defaultMode further

## Writing Style

When writing human-readable output (commit messages, review findings, explanations,
persistent files like SPEC.md/CODEREVIEW.md/SECURITY.md/TESTING.md, README content):

- Professional and direct. State the point, then support it.
- Concise. Cut filler words, throat-clearing, and redundant qualifications.
- No AI-voice patterns: avoid "It's important to note that," "It's worth mentioning,"
  "This is not X, it's Y" reframing, "Let's," "Great question," or similar preamble.
- No em-dashes. Use commas, periods, or parentheses instead.
- No emoji unless explicitly requested.
- Prefer short declarative sentences over long compound ones.
- When uncertain, say so plainly ("I'm not sure" or "this may be wrong") rather than
  hedging with weasel words.

## Coding Practices

- Work in small, committable increments. Get one thing working before adding the next.
  Do not build scaffolding for features that are not needed yet.
- When adding or changing functionality, write or update tests in the same increment.
  If the project has no test infrastructure, add a minimal test runner first.
- Run the test suite (or the relevant subset) after each functional change.
  Do not stack multiple untested changes.
- When fixing a bug, change only what is necessary. Do not refactor surrounding code
  or improve unrelated code in the same change.
- If a change causes previously passing tests to fail, revert it and try a different
  approach. Do not modify tests to accommodate a regression.
- Before switching tasks or when context grows large, write key decisions and current
  state to a file (commit message, README, or project-specific doc). Prefer restarting
  with a written plan over continuing with a long, stale context.

## Specification Quality

Acceptance criteria are the highest-leverage artifact in the workflow. Every review
skill reads them. When writing or substantially revising acceptance criteria (whether
via `/spec` or directly), pressure-test each criterion: what input breaks it, what
assumptions are unstated, what failure behavior is unspecified. Remove criteria that
prescribe implementation rather than verifiable behavior. The `/spec` skill sets
`effort: high` and includes a structured pressure-test step for this analysis;
apply the same rigor when editing criteria outside of `/spec`.

## Secrets

- Never commit secrets, credentials, or API keys
- `.env` files are globally gitignored
- Use environment variables or a secrets manager
- Tailscale-scoped access preferred for internal services

## Networking

Machine-specific values from the current setup. Update these if the machine, domain, or tailnet changes.

- **Public DNS**: `dev.agent-hypervisor.ai` (A record pointing to Hetzner public IP)
- **Tailscale hostname**: `dev` (short) / `dev.emperor-exponential.ts.net` (FQDN)
- **Tailnet**: `emperor-exponential.ts.net`

**Default access model: Tailscale.** All routine access (SSH, web UIs, APIs) goes through the Tailscale mesh. From a Mac or iPad, connect to `dev:PORT` or `dev.emperor-exponential.ts.net:PORT`. Public DNS is reserved for webhook callbacks, external demos, or anything that must be reachable from the open internet.

**Binding addresses for services:**

- Local dev server (no Docker): bind `0.0.0.0` so Tailscale clients can reach it. `127.0.0.1` is local-only.
- Docker containers: `-p PORT:PORT` (binds `0.0.0.0`). Never `-p 127.0.0.1:PORT:PORT` unless the service must be unreachable from Tailscale.
- Combine with `--gpus all --shm-size=8g` for GPU workloads (see ML/GPU Conventions).

**Public DNS (`dev.agent-hypervisor.ai`) use cases:**

- Webhook callbacks from external services (GitHub, Stripe, etc.)
- Temporary demos for external collaborators
- Keep public exposure brief. Stop or rebind the service when done.

**Firewall:** not explicitly configured by hw-bootstrap.sh. Hetzner may apply network-level rules (check Robot panel). Assume all ports on the public IP may be reachable unless verified otherwise.

**No reverse proxy.** Services bind directly to ports. If Caddy or nginx is added later, update this section.
