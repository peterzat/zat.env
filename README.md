# zat.env

Reproducible dev environment for Peter Zatloukal (peterzat). This repo captures everything needed to turn a bare Hetzner GEX44 into a fully configured, always-on agentic coding box.

---

## What is zat.env?

`zat.env` is the single source of truth for the machine environment — configuration, conventions, tooling scripts, and setup instructions. Individual projects live in their own repos under `~/src/`; this repo handles only cross-project infrastructure.

Setup is two-phase:
1. **`bootstrap-GEX44.sh`** — run on bare Ubuntu to install system packages, NVIDIA drivers, Docker, Tailscale, Claude Code, etc.
2. **`zat.env-install.sh`** — run after cloning this repo to wire config into the live system (git config, symlinks)

---

## Philosophy / Goals

**Always-on cloud dev box.** The GEX44 runs 24/7. State persists. Sessions survive disconnects. This is not a laptop you close — it's a server you connect to.

**Thin client model.** Laptop and phone are just terminals. All development happens on the GEX44 via Tailscale SSH. No local dev, no syncing, no "works on my machine."

**Agentic coding first.** Claude Code is the primary development tool, not a chat assistant. The environment is optimized for long agentic coding loops — persistent sessions, GPU access, project isolation.

**Autonomy spectrum.** Start supervised (Claude proposes, Peter reviews). Grow toward autonomous operation with guardrails — adversarial review hooks, structured constraints. The environment should evolve to support increasing autonomy safely without losing control.

**Multiple concurrent projects.** Each project gets its own venv, tmux session, and git repo. They're independently runnable. The long-term goal is multiple simultaneous agentic sessions across projects.

**GPU as a coding tool.** The RTX 4000 SFF Ada (20GB VRAM, 70W TDP) is not for production training. It's for in-loop experimentation — A/B testing local models, running inference during development, rapid iteration. Use it freely during coding sessions.

**Reproducibility over snowflakes.** bootstrap + zat.env = full recovery from bare metal. Projects are in GitHub. No hand-crafted state that can't be recreated.

**Access from anywhere.** Tailscale mesh network. SSH from laptop or phone. `claude` for full sessions, `/rc` for quick remote check-ins.

**Secrets discipline.** Credentials never in repos. `.env` files always gitignored. Use environment variables or a secrets manager. Tailscale-scoped access where possible.

**Grow incrementally.** Start simple. Add complexity only when earned by real use cases. Avoid premature abstraction.

---

## Machine Specs

| Spec       | Value                                                         |
|------------|---------------------------------------------------------------|
| CPU        | Intel Core i5-13500 (14 cores: 6P+8E, 20 threads)            |
| GPU        | NVIDIA RTX 4000 SFF Ada — 20GB ECC GDDR6, 6144 CUDA cores, 192 Tensor cores, 70W TDP |
| RAM        | 64 GB DDR4                                                    |
| Storage    | 2 × 1.92 TB NVMe SSD, RAID-1 (~1.92 TB usable)               |
| Network    | 1 Gbit/s, unlimited traffic                                   |
| OS         | Ubuntu 22.04.2 LTS                                            |
| Python     | 3.10 (system) — projects always use per-project venvs         |
| Provider   | Hetzner dedicated (GEX44), Falkenstein DC                     |

**GPU notes:**
- 20GB VRAM fits ~7–8B parameter models natively; ~32B quantized (IQ4_XS ≈ 16–17 GB)
- 70W TDP is the low-power SFF variant — good for inference and experimentation, limited for heavy training
- Use `--gpus all` for Docker GPU access; always `--shm-size=8g` or `--ipc=host` for PyTorch DataLoader

**Hetzner notes:**
- Networking uses a /32 point-to-point config with `on-link: true` gateway routing — do not modify netplan without understanding this
- Cryptocurrency mining is strictly prohibited (Hetzner will terminate the account)

---

## Setup From Scratch

Starting from a bare Ubuntu 22.04.2 LTS install with SSH access:

```bash
# 1. Copy bootstrap script to the machine and run it
scp bootstrap-GEX44.sh user@<ip>:~/
ssh user@<ip>
bash ~/bootstrap-GEX44.sh

# 2. Reboot (required after NVIDIA driver install)
sudo reboot

# 3. Re-run bootstrap to complete CUDA + NVIDIA Container Toolkit setup
bash ~/bootstrap-GEX44.sh

# 4. Authenticate Tailscale
sudo tailscale up --ssh
# or with an auth key:
sudo tailscale up --ssh --authkey=tskey-xxxxx

# 5. From here on, connect via Tailscale SSH
ssh user@<tailscale-hostname>

# 6. Set up SSH key for GitHub, then clone and install zat.env
git clone git@github.com:peterzat/zat.env.git ~/src/zat.env
~/src/zat.env/zat.env-install.sh

# 7. Authenticate Claude Code
claude
```

---

## Directory Overview

Post-install layout (annotated):

```
~/
├── bin/                              # Project management helper scripts (from bootstrap)
│   ├── ccproj                        # Clone a repo and open a tmux/claude session
│   ├── newproj                       # Init a new project and open a tmux/claude session
│   ├── projattach                    # Reattach to an existing project tmux session
│   └── projls                        # List all running tmux sessions
│
├── data/                             # Shared large datasets and model files (not in git)
│
├── src/
│   └── zat.env/                      # This repo — cross-project config and tooling
│       ├── README.md                 # This file
│       ├── CLAUDE.md                 # How to work on the zat.env repo itself
│       ├── .gitignore
│       ├── bootstrap-GEX44.sh        # Bare machine → usable dev box
│       ├── zat.env-install.sh        # Wire this repo's config into the live system
│       ├── .claude/
│       │   └── settings.local.json   # Repo-scoped Claude Code permissions
│       ├── claude/
│       │   └── global-claude.md      # Machine-wide Claude conventions (symlinked below)
│       ├── gitconfig/
│       │   ├── aliases.gitconfig     # Git aliases, included via ~/.gitconfig
│       │   └── ignore-global         # Global gitignore, referenced via ~/.gitconfig
│       ├── hooks/
│       │   └── README.md             # Future: adversarial review git hooks
│       └── templates/
│           └── README.md             # Future: project scaffolding templates
│
├── .bashrc                           # Updated: PATH, CUDA_HOME, PIP_REQUIRE_VIRTUALENV
├── .tmux.conf                        # Mouse, scrollback, window numbering
├── .gitconfig                        # Updated by install: user, includes, excludesfile
│
├── .claude/
│   ├── CLAUDE.md -> ~/src/zat.env/claude/global-claude.md   # Symlink: machine-wide conventions
│   └── settings.json                 # Global Claude Code permissions
│
└── .cache/
    ├── huggingface/                  # Shared HF model cache (never override HF_HOME per-project)
    └── pip/                          # Shared pip cache (don't purge casually — torch is 2GB+)
```

---

## Daily Workflow

### Connecting
```bash
ssh peter@<tailscale-hostname>
# or from phone via any SSH client
```

### Starting a project
```bash
# Clone an existing repo and open a persistent claude session
ccproj myrepo git@github.com:peterzat/myrepo.git

# Create a new project from scratch
newproj my-new-thing
```

### tmux and persistent sessions
`~/src/` is just a directory — you can clone or create repos there however you like. `ccproj` and `newproj` are specifically for when you want a **persistent named terminal session** tied to a project.

When you run `ccproj ranking ...`:
1. The repo is cloned to `~/src/ranking`
2. A tmux session named `ranking` is created with `claude` running inside it
3. If you disconnect (SSH drop, laptop closes), the session keeps running — Claude keeps coding

Come back later with:
```bash
projattach ranking      # reattach to the ranking session
projls                  # see all running sessions
```

Only projects you're actively working on have tmux sessions. Sessions are cheap — they're just persistent terminal windows, not services. Kill them with `tmux kill-session -t ranking` when done.

For a quick one-off exploration, skip tmux entirely:
```bash
cd ~/src/some-repo
claude
```

### GPU usage
```bash
# Check GPU status
nvidia-smi

# Docker with GPU
docker run --rm --gpus all --shm-size=8g <image>

# In-project: install pytorch with CUDA in the project venv
source .venv/bin/activate
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
```

---

## Roadmap / Future Ideas

- **Adversarial review via git hooks** — Claude reviews its own work before commits; catches regressions and design issues
- **Long-running loop orchestration** — structured control for extended agentic runs (goose.ai or similar)
- **Project templates with real scaffolding** — versioned starter files for Python ML projects, API services, etc.
- **Custom Claude Code slash commands** — project-specific or global shortcuts for common workflows
- **Multi-agent coordination** — multiple Claude sessions across projects that can communicate or share results
- **Monitoring / dashboards** — visibility into running agent sessions, GPU utilization, loop progress
