# zat.env

Reproducible dev environment for Peter Zatloukal (peterzat). This repo captures everything needed to turn a bare Hetzner GEX44 into a fully configured, always-on agentic coding box.

> **Generated review files.** `CODEREVIEW.md`, `SECURITY.md`, and `TESTING.md` in this repo root are produced by running `/codereview`, `/security`, and `/tester` against zat.env itself. The skills that generate them live in `claude/skills/`. In downstream projects, these same files are written to the project root and should be committed alongside the code they review.

> **No hardcoded identity.** Git `user.name` and `user.email` are not stored in this repo. The install script prompts on first run and reuses the existing git config on subsequent runs. Override with `GIT_NAME=x GIT_EMAIL=y@z ./zat.env-install.sh`.

---

## What is zat.env?

`zat.env` is the single source of truth for the machine environment: configuration, conventions, tooling scripts, and setup instructions. Individual projects live in their own repos under `~/src/`; this repo handles only cross-project infrastructure.

Setup is two-phase:
1. **`bootstrap-GEX44.sh`**: run on bare Ubuntu to install system packages, NVIDIA drivers, Docker, Tailscale, Claude Code, etc.
2. **`zat.env-install.sh`**: run after cloning this repo to wire config into the live system (git config, symlinks, skills, hooks)

The install script is portable. It's safe to run on any machine where you use Claude Code, not just the GEX44.

---

## Philosophy / Goals

**Always-on cloud dev box.** The GEX44 runs 24/7. State persists. Sessions survive disconnects. This is not a laptop you close; it's a server you connect to.

**Thin client model.** Laptop and phone are just terminals. All development happens on the GEX44 via Tailscale SSH. No local dev, no syncing, no "works on my machine."

**Agentic coding first.** Claude Code is the primary development tool, not a chat assistant. The environment is optimized for long agentic coding loops: persistent sessions, GPU access, project isolation.

**Autonomy spectrum.** Start supervised (Claude proposes, Peter reviews). Grow toward autonomous operation with guardrails: adversarial review skills, pre-push hook gates, structured constraints. The environment should evolve to support increasing autonomy safely without losing control.

**Verification over prompting.** Inspired by Carlini's C compiler work (2026): the quality of automated verification determines the ceiling of what agents can build. A well-designed test suite and review loop is worth more than a better prompt. If the verifier is wrong, the agent solves the wrong problem.

**Convergence through constraints.** Even Opus 4.6 can't one-shot complex projects. Progress comes from iterative loops with guardrails: review, fix, re-review, with quantitative signals to detect convergence and circuit breakers to prevent infinite loops. The loop is the product, not the single invocation.

**Precision over recall.** False positives erode trust in automated review faster than false negatives. Every review skill is designed to stay silent when it has nothing to say. "No issues found" is the correct and expected outcome for quality code.

**Multiple concurrent projects.** Each project gets its own venv, tmux session, and git repo. They're independently runnable. The long-term goal is multiple simultaneous agentic sessions across projects.

**GPU as a coding tool.** The RTX 4000 SFF Ada (20GB VRAM, 70W TDP) is not for production training. It's for in-loop experimentation: A/B testing local models, running inference during development, rapid iteration.

**Reproducibility over snowflakes.** bootstrap + zat.env = full recovery from bare metal. Projects are in GitHub. No hand-crafted state that can't be recreated.

**Secrets discipline.** Credentials never in repos. `.env` files always gitignored. Use environment variables or a secrets manager.

**Grow incrementally.** Start simple. Add complexity only when earned by real use cases. Avoid premature abstraction.

---

## Machine Specs

| Spec       | Value                                                         |
|------------|---------------------------------------------------------------|
| CPU        | Intel Core i5-13500 (14 cores: 6P+8E, 20 threads)            |
| GPU        | NVIDIA RTX 4000 SFF Ada (20GB ECC GDDR6, 6144 CUDA cores, 192 Tensor cores, 70W TDP) |
| RAM        | 64 GB DDR4                                                    |
| Storage    | 2 x 1.92 TB NVMe SSD, RAID-1 (~1.92 TB usable)              |
| Network    | 1 Gbit/s, unlimited traffic                                   |
| OS         | Ubuntu 22.04.2 LTS                                            |
| Python     | 3.10 (system); projects always use per-project venvs          |
| Provider   | Hetzner dedicated (GEX44), Falkenstein DC                     |

**GPU notes:**
- 20GB VRAM fits ~7-8B parameter models natively; ~32B quantized (IQ4_XS = 16-17 GB)
- 70W TDP is the low-power SFF variant. Good for inference and experimentation, limited for heavy training.
- Use `--gpus all` for Docker GPU access; always `--shm-size=8g` or `--ipc=host` for PyTorch DataLoader

**Hetzner notes:**
- Networking uses a /32 point-to-point config with `on-link: true` gateway routing. Do not modify netplan without understanding this.
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

# 8. Start a new Claude session to pick up installed skills
```

**Updating zat.env on any machine:**
```bash
cd ~/src/zat.env && git pull && ./zat.env-install.sh
# Restart Claude to pick up any skill or hook changes
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
│   └── zat.env/                      # This repo: cross-project config and tooling
│       ├── README.md                 # This file
│       ├── CLAUDE.md                 # How to work on the zat.env repo itself
│       ├── .gitignore
│       ├── bootstrap-GEX44.sh        # Bare machine -> usable dev box
│       ├── zat.env-install.sh        # Wire this repo's config into the live system
│       ├── .claude/
│       │   └── settings.local.json   # Repo-scoped Claude Code permissions
│       ├── claude/
│       │   ├── global-claude.md      # Machine-wide Claude conventions (symlinked below)
│       │   └── skills/               # Global Claude Code skills (symlinked below)
│       │       ├── codereview/       # /codereview: adversarial code review
│       │       │   └── SKILL.md
│       │       ├── security/         # /security: security audit
│       │       │   └── SKILL.md
│       │       ├── architect/        # /architect: architecture review
│       │       │   └── SKILL.md
│       │       └── tester/           # /tester: test strategy review
│       │           └── SKILL.md
│       ├── gitconfig/
│       │   ├── aliases.gitconfig     # Git aliases, included via ~/.gitconfig
│       │   └── ignore-global         # Global gitignore, referenced via ~/.gitconfig
│       ├── hooks/
│       │   ├── README.md             # Hook documentation
│       │   └── pre-push-codereview.sh  # Blocks git push without prior codereview
│       └── templates/
│           └── README.md             # Future: project scaffolding templates
│
├── .bashrc                           # Updated: PATH, CUDA_HOME, PIP_REQUIRE_VIRTUALENV
├── .tmux.conf                        # Mouse, scrollback, window numbering
├── .gitconfig                        # Updated by install: user, includes, excludesfile
│
├── .claude/
│   ├── CLAUDE.md -> ~/src/zat.env/claude/global-claude.md   # Symlink: machine-wide conventions
│   ├── settings.json                 # Global Claude Code permissions + pre-push hook
│   └── skills/                       # Symlinks to skill directories in this repo
│       ├── codereview -> ~/src/zat.env/claude/skills/codereview/
│       ├── security   -> ~/src/zat.env/claude/skills/security/
│       ├── architect  -> ~/src/zat.env/claude/skills/architect/
│       └── tester     -> ~/src/zat.env/claude/skills/tester/
│
└── .cache/
    ├── huggingface/                  # Shared HF model cache (never override HF_HOME per-project)
    └── pip/                          # Shared pip cache (don't purge casually; torch is 2GB+)
```

**Per-project review files** (written by skills into the project root, not this repo):
```
~/src/<project>/
├── CODEREVIEW.md    # Written by /codereview: dated review history with metadata
├── SECURITY.md      # Written by /security: security findings and accepted risks
└── TESTING.md       # Written by /tester: test strategy assessment
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
`~/src/` is just a directory. You can clone or create repos there however you like. `ccproj` and `newproj` are specifically for when you want a **persistent named terminal session** tied to a project.

When you run `ccproj ranking ...`:
1. The repo is cloned to `~/src/ranking`
2. A tmux session named `ranking` is created with `claude` running inside it
3. If you disconnect (SSH drop, laptop closes), the session keeps running. Claude keeps coding.

Come back later with:
```bash
projattach ranking      # reattach to the ranking session
projls                  # see all running sessions
```

---

## Agentic Skills

Four global skills are installed by `zat.env-install.sh` and available in all Claude Code sessions. Each skill runs as a forked subagent with its own context window, starts from scratch, and gathers everything it needs from the codebase. Full instructions live in `claude/skills/<name>/SKILL.md`.

| Skill | Command | Invocation | Purpose |
|-------|---------|------------|---------|
| Code Review | `/codereview` | Auto (pre-push) + manual | Adversarial review of uncommitted changes |
| Security | `/security` | Manual + chained from codereview | Security audit (full repo or changes-only) |
| Architect | `/architect` | Manual only | Architecture fitness assessment |
| Tester | `/tester` | Manual only | Test strategy assessment |

### Prompt Design Principles

All four skills share a set of prompt design principles informed by community research on AI code review agents. These principles are embedded directly in each SKILL.md:

- **Precision over recall.** Every false positive wastes human attention. Skills only report findings they have high confidence in. Fewer than 2 issues indicates quality code.
- **Evidence grounding.** Every finding must cite a specific file and line. If the finding depends on code outside the diff, the skill must read that code first. No speculation about unverified behavior.
- **Halt on uncertainty.** Below 80% confidence, the skill omits the finding or flags it as uncertain. Guessing is worse than silence.
- **Empty report is valid.** A clean report means the code is clean. Skills never manufacture findings to fill a template.
- **No style policing.** Formatting, naming, and aesthetic preferences are not findings unless they indicate a functional or structural problem.
- **Scoped context reads.** When reading persistent files from prior runs, skills focus on the most recent entry, unresolved BLOCKs, and the metadata footer. Historical entries older than the current branch's base commit are skipped.

These principles address the most common failure mode of AI review agents: generating noise that erodes trust. Graphite's research on AI code review showed that adding a single precision-bias instruction moved developer action rates from ~25% to 52%, matching human reviewers.

### `/codereview`: Adversarial Code Review

**Persona:** Principal Software Engineer, adversarial stance.

**Trigger:** Runs automatically before any `git push` (via the pre-push hook gate). Also invocable manually.

**What it does:**
1. Reads prior review state from SECURITY.md and TESTING.md (scoped reads)
2. Gathers all uncommitted/staged changes via `git diff`; reads full changed files for context
3. Runs the project's test suite (if one exists) to capture a baseline
4. Reviews for correctness, code quality, solution approach, spaghetti detection (mixed concerns in one commit), and regression risk
5. Chains to `/security changes-only` for a focused security review of the same diff
6. Reports findings as BLOCK / WARN / NOTE with evidence citations
7. Auto-fixes BLOCK and WARN items with **escalating conservatism**: iteration 1 fixes normally (one issue at a time, max 20 lines per fix); iteration 2 requires explaining why the prior fix failed before retrying; iteration 3 stops and reports to the human
8. Re-runs tests after fixing; reverts any fix that causes test regression
9. Writes a content-addressed marker file so the pre-push hook allows the next `git push`
10. Updates `CODEREVIEW.md` with a dated entry and structured metadata footer

**Key guard:** Never deletes, skips, or weakens existing tests to make them pass. Fixes the code, not the tests.

### `/security`: Security Review

**Persona:** Principal Security Engineer.

**Trigger:** Manual invocation, or chained automatically from `/codereview`.

**Scope:** Controlled via arguments. `/security` reviews the full repo. `/security changes-only` focuses on the current diff. `/security path/to/file` reviews a specific file.

**What it does:**
1. Reads prior security state from SECURITY.md and CODEREVIEW.md (scoped reads)
2. Scopes the review based on arguments
3. Reviews across 7 dimensions: secret leaks (including git history), input/output sanitization (with data flow tracing), auth/authz, dependency supply chain, infrastructure security, AI-specific risks (prompt injection, unvalidated LLM output), and data exposure
4. Reports findings with concrete attack vectors. "An attacker could theoretically..." without specifying how they reach the code path is not a finding.
5. Updates `SECURITY.md` with dated findings, resolved/open status, and accepted risks

### `/architect`: Architecture Review

**Persona:** Principal Architect.

**Trigger:** Manual only (`/architect`). Not auto-invoked.

**What it does:**
1. Reads all three persistent files (CODEREVIEW.md, SECURITY.md, TESTING.md) as the terminal node in the cross-skill reading DAG
2. Explores the codebase: README, directory structure, languages, frameworks, entry points, dependency manifests
3. Evaluates 7 dimensions: structural clarity, appropriate complexity (over-engineering is as bad as under-engineering), scale alignment, dependency health, extensibility, consistency, and business goal alignment
4. Reports per dimension with HIGH / MEDIUM / LOW priority, or "Nothing to flag"
5. Produces no persistent file (deliberate; see Cross-Skill Reading DAG below)

**"Nothing to add at this time"** is a valid and expected outcome. Most codebases have sound architecture.

### `/tester`: Test Strategy Review

**Persona:** Principal Software Design Engineer in Test (SDE/T).

**Trigger:** Manual only (`/tester`). Not auto-invoked.

**What it does:**
1. Reads prior assessment from TESTING.md, SECURITY.md, and CODEREVIEW.md (scoped reads)
2. Discovers test infrastructure: test files, frameworks, CI/CD configs, coverage tools, pre-commit hooks, deployment configs
3. Evaluates 8 dimensions: test coverage strategy (are the right things tested?), automation maturity, automatic test execution (tests that must be run manually are often not run), CI/CD integration, framework choices, fixture management, flaky test patterns, and missing test categories
4. Reports findings as BLOCK / WARN / NOTE. Does not write or run individual tests.
5. Updates `TESTING.md` with dated assessment and status of prior recommendations

**"This is fine for now"** is valid. A new prototype with a few pytest files and no CI is fine. A production API with no integration tests is not. The assessment is always proportional to the project's maturity and goals.

### Pre-Push Gate

A Claude Code `PreToolUse` hook (configured in `~/.claude/settings.json`) intercepts every `git push` command. The push is blocked unless `/codereview` has been run and passed on the current diff.

**Flow:**
1. Claude attempts `git push`
2. Hook reads the JSON payload from stdin and checks if the command is `git push`
3. Hook checks for a marker file at `/tmp/.claude-codereview-<project-hash>`
4. Marker contains the diff hash (first 16 chars of `git diff HEAD | sha256sum`) from the passing review. This makes the marker content-addressed: it's tied to the exact diff that was reviewed, not just "some review happened."
5. If marker exists and hash matches current diff, push proceeds; marker is deleted
6. Otherwise, push blocked; Claude instructed to run `/codereview`

The marker is per-project (scoped by git root path hash) and single-use. Making new changes after a passing review requires a new review before the next push.

### Severity Model

All skills use a consistent three-level severity model:

| Level | Meaning | Action |
|-------|---------|--------|
| **BLOCK** | Must fix before pushing / shipping | Auto-fixed by codereview; others report to human |
| **WARN** | Should fix; significant gap | Auto-fixed by codereview; others report to human |
| **NOTE** | Informational; improvement opportunity | Reported only, never auto-fixed |

### Persistent Review Files

Three skills write per-project files to the project root. These files are working state, not documentation. They serve as inter-session memory: each skill invocation reads relevant files to avoid re-reporting resolved issues and to track whether recommendations were adopted. Each file ends with a structured metadata comment (`<!-- REVIEW_META: {...} -->`) that enables future tooling for convergence detection and trending.

| File | Written by | Contents |
|------|-----------|----------|
| `CODEREVIEW.md` | `/codereview` | Dated review history, findings, fixes applied |
| `SECURITY.md` | `/security` | Security findings, resolved issues, accepted risks |
| `TESTING.md` | `/tester` | Test strategy assessment, recommendation status |

### Cross-Skill Reading DAG

Skills read each other's persistent files in a directed acyclic graph to prevent amplification loops:

```
codereview  -> reads SECURITY.md, TESTING.md
security    -> reads CODEREVIEW.md
tester      -> reads SECURITY.md, CODEREVIEW.md
architect   -> reads all three (terminal node, produces no persistent file)
```

Architect is the terminal node: its output informs human decisions and does not feed back into automated review. This prevents architectural recommendations from becoming automatic codereview criteria without deliberate human adoption.

---

## Theory of Autonomous Improvement

This section documents the design philosophy behind the agentic skill system and the long-term vision for autonomous coding loops.

### The Carlini Principle

In February 2026, Nicholas Carlini (Anthropic) built a complete C compiler using 16 parallel Claude Opus 4.6 agents running in an infinite loop. 100,000 lines of Rust, 3,982 commits, ~$20,000 in API costs, 2 weeks. No human wrote code.

The key insight: **the primary skill for a 10x developer isn't their ability to solve a complex bug. It's their ability to design the automated testing rigs and feedback loops that allow sixteen parallel instances of a model to solve it.**

Applied here: invest in verification (review skills, test suites, feedback loops) before investing in prompts. A well-designed review loop is worth more than a better system prompt.

### Why Agents Can't One-Shot Complex Projects

Even Opus 4.6 cannot reliably one-shot complex projects. This is not a model limitation to be overcome; it's a fundamental property of complex systems. The solution is structure:

1. **Quantitative signals.** Not just "BLOCK/WARN/NOTE" in prose, but structured metadata (`<!-- REVIEW_META: {...} -->`) that enables convergence detection over time.
2. **Regression detection.** Run tests before and after fixes; revert if things get worse.
3. **Cycle detection.** Escalating conservatism on repeated fix attempts; stop after 3.
4. **Diminishing returns.** Skills are designed to report "nothing to add" when code is clean, rather than generating noise.

### The Autonomy Spectrum

```
Supervised          Claude proposes, Peter reviews and approves everything
    |
Gated               Pre-push hook ensures review passes before code leaves the machine
    |
Autonomous          Review skills run in loops; Claude fixes and iterates without interruption
    |
Multi-agent         Parallel Claude sessions across projects with shared verification state
```

The current system is at **Gated**. The skills and persistent files are the foundation for moving to **Autonomous**, where Claude can run `/codereview`, fix issues, and iterate without human intervention per-cycle, while the human reviews outcomes rather than individual steps.

### Anti-Patterns We Designed Against

**False positive factories.** Skills that manufacture findings to fill structured templates. Countered by: explicit precision-over-recall instructions, "no findings is valid" in every skill, evidence grounding requirement.

**Context exhaustion.** Agents that read too much and degrade quality as context fills. Countered by: scoped persistent file reads (most recent entry + BLOCKs + metadata footer only), prioritization of high-risk files for large diffs.

**Circular amplification.** A NOTE becomes a BLOCK through cross-skill contamination (codereview flags something, security escalates it, architect recommends refactor, codereview flags code for not following the recommendation). Countered by: directed acyclic reading DAG, architect produces no persistent file.

**Auto-fix oscillation.** Fix A breaks B, fix B reintroduces A. Countered by: escalating conservatism on iterations 2-3, one-issue-per-fix cap, 20-line-per-fix cap, stop after 3 attempts.

**Stale context poisoning.** Persistent files describing code that no longer exists. Countered by: commit-hash-scoped metadata, skip entries older than base commit, keep only current entry + prior summary.

---

## Roadmap

### Done (v1)

- [x] Machine provisioning script (`bootstrap-GEX44.sh`)
- [x] Install script wiring (`zat.env-install.sh`): git config, CLAUDE.md symlink, skills, hooks
- [x] Global git conventions (aliases, ignore-global)
- [x] Machine-wide Claude conventions (`claude/global-claude.md`)
- [x] Adversarial code review (`/codereview`) with pre-push hook gate
- [x] Security review (`/security`) with persistent `SECURITY.md`
- [x] Architecture review (`/architect`)
- [x] Test strategy review (`/tester`) with persistent `TESTING.md`
- [x] Content-addressed push gate (diff hash + project hash)
- [x] Auto-fix with escalating conservatism and 3-iteration cap
- [x] Cross-skill reading DAG with circular amplification prevention
- [x] Prompt design: precision bias, evidence grounding, confidence thresholds, halt conditions

### Future (v2+)

**Near-term (high value, incremental):**
- **`/verify` skill**: executes the project's test suite as ground truth; factual signal to complement opinion-based review
- **Worktree-based A/B testing**: before applying a fix, create a worktree, run tests in isolation, compare against main branch before merging
- **Quantitative trending**: parse structured metadata footers, track BLOCK/WARN/NOTE counts over sessions, detect convergence or regression

**Medium-term (autonomous loops):**
- **Loop orchestrator** (`/review-loop`): run codereview, fix, codereview in a loop until converging or hitting max iterations
- **Inter-session coordination**: lockfiles for persistent review files, session discovery, conflict-safe append-only updates for concurrent sessions
- **Alignment checks**: periodic re-read of original task specification during long loops to detect intent drift
- **Progressive disclosure**: reference files (`skills/<name>/references/`) for dimension details as skill prompts grow

**Long-term (multi-agent):**
- **Cross-project awareness**: architect and security read persistent files from sibling projects under `~/src/` to detect dependency-chain risks
- **Long-running loop orchestration**: Carlini-style infinite loops with CI enforcement for complex projects
- **Multi-agent coordination**: multiple Claude sessions across projects with shared task pools and message passing
- **Monitoring / dashboards**: visibility into running agent sessions, GPU utilization, loop progress

**Infrastructure:**
- **Project templates**: versioned starter files for Python ML projects, API services, general Python
- **Dependency auditor** (`/deps`): dependency health, outdated packages, license risks, bloat, upgrade paths

---
