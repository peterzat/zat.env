# Global Claude Conventions — GEX44 Dev Box

This file is symlinked to `~/.claude/CLAUDE.md` and applies to all projects on this machine.

## Machine

| Spec     | Value                                                        |
|----------|--------------------------------------------------------------|
| CPU      | Intel Core i5-13500 (14 cores: 6P+8E, 20 threads)           |
| GPU      | NVIDIA RTX 4000 SFF Ada — 20GB ECC GDDR6, 70W TDP           |
| RAM      | 64 GB DDR4                                                   |
| Storage  | 2 × 1.92 TB NVMe SSD, RAID-1                                 |
| OS       | Ubuntu 22.04.2 LTS                                           |
| Python   | 3.10 system — always use per-project venvs                   |

## Git Identity

All commits must be attributed solely to peterzat. Never add Co-Authored-By trailers.

```
user.name  = peterzat
user.email = peter@zatloukal.com
```

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
- Default: grant narrow permissions — prefer `Bash(git:*)` over `Bash(*)`
- `Bash(git:*)` is allowed globally

## Hetzner / Networking

- Networking uses a /32 point-to-point setup with `on-link: true` gateway routing — never modify netplan without understanding this or you will lose network access
- Cryptocurrency mining is strictly prohibited by Hetzner (account termination)

## Secrets

- Never commit secrets, credentials, or API keys
- `.env` files are globally gitignored
- Use environment variables or a secrets manager
- Tailscale-scoped access preferred for internal services
