# zat.env

Framework for autonomous agentic coding including adversarial guardrails and memory-based improvement loops. Clone this repo and run `zat.env-install.sh` on any machine to get adversarial code review, security auditing, architecture review, and test strategy review as Claude Code skills, with a pre-push hook that gates `git push` on passing review.

An isolated, always-on hardware instance is a critical ingredient for serious agentic work. Long sessions need to survive SSH disconnects. Overnight autonomous jobs need to keep running without a laptop in the way. The environment needs to be deeply tuned: GPU drivers, CUDA toolchain, shared model caches, project conventions baked into every Claude session. But a hand-configured machine is a liability. `bootstrap-GEX44.sh` provisions a bare server from scratch; `zat.env-install.sh` wires the agentic layer onto any machine after that. Together they mean full recovery from bare metal is two scripts and a reboot.

Running long agentic loops requires a minimum hardware spec: enough VRAM for local model inference, enough RAM for concurrent sessions, and enough CPU for sustained throughput. See [Current Hardware: Hetzner GEX44](#current-hardware-hetzner-gex44) for the current hardware choice and rationale.

## Contents

- [Philosophy](#philosophy)
- [Environment Coupling and Portability](#environment-coupling-and-portability)
- [Coding Practices](#coding-practices)
- [Quick Start](#quick-start)
- [Agentic Skills](#agentic-skills)
  - [`/codereview`: Adversarial Code Review](#codereview-adversarial-code-review)
  - [`/security`: Security Review](#security-security-review)
  - [`/architect`: Architecture Review](#architect-architecture-review)
  - [`/tester`: Test Strategy Review](#tester-test-strategy-review)
  - [`/pr`: Pull Request Workflow](#pr-pull-request-workflow)
  - [Pre-Push Gate](#pre-push-gate)
- [Theory of Autonomous Improvement](#theory-of-autonomous-improvement)
- [Current Hardware: Hetzner GEX44](#current-hardware-hetzner-gex44)
- [Roadmap](#roadmap)

> **Generated review files.** `CODEREVIEW.md`, `SECURITY.md`, and `TESTING.md` in this repo root are produced by running `/codereview`, `/security`, and `/tester` against zat.env itself. The skills that generate them live in `claude/skills/`. In downstream projects, these same files are written to the project root and should be committed alongside the code they review.

> **No hardcoded identity.** Git `user.name` and `user.email` are not stored in this repo. The install script prompts on first run and reuses the existing git config on subsequent runs. Override with `GIT_NAME=x GIT_EMAIL=y@z ./zat.env-install.sh`.

---

## Philosophy

**Claude Code as the primary development tool.** This environment is built for long autonomous coding sessions where Claude reviews its own work, fixes issues, and iterates. Skills, hooks, and conventions provide the structure: adversarial review before pushing, quantitative signals to detect convergence, and circuit breakers to cap runaway loops.

**Always-on, never a snowflake.** Long agentic loops need an always-reachable machine: sessions that survive SSH disconnects, overnight jobs that keep running, an environment tuned for the work. But a hand-configured machine is a liability. Everything must be reproducible: `bootstrap-GEX44.sh` provisions bare metal, `zat.env-install.sh` installs the agentic layer, and the combination recovers the full environment from scratch. Any hardware that meets the minimum spec and is reachable via Tailscale works.

**Verification over prompting.** Inspired by Carlini's [C compiler work](https://www.anthropic.com/engineering/building-c-compiler) (Anthropic, 2026): the quality of automated verification determines the ceiling of what agents can build. A well-designed test suite and review loop is worth more than a better prompt.

**Precision over recall.** False positives erode trust in automated review faster than false negatives. Every review skill is designed to stay silent when it has nothing to say. "No issues found" is the correct and expected outcome for quality code.

**Autonomy spectrum.** Start supervised (Claude proposes, human reviews). Grow toward autonomous operation with guardrails: adversarial review skills, pre-push hook gates, structured constraints.

**Reproducibility.** `bootstrap-GEX44.sh` + `zat.env-install.sh` = full recovery from bare metal. `zat.env-install.sh` alone = agentic skills on any machine.

**Grow incrementally.** Start simple. Add complexity only when earned by real use cases.

## Environment Coupling and Portability

This setup is deliberately coupled to two choices: **Claude Code** as the agent runtime and **Ubuntu Linux** as the operating environment. Both are first-rate for this kind of work. Linux is the natural substrate for server-side agentic workloads: ubiquitous, scriptable, and what the majority of CI systems, containers, and cloud instances run. Claude Code is built from the ground up for autonomous agent loops -- hooks, skills, persistent context, and structured tool use are first-class citizens, not add-ons. The underlying model, Claude Opus 4.6, is the current best-in-breed coding model, and Anthropic's agent-first design philosophy is reflected throughout the tooling.

Beyond those two couplings, the approach is portable by design. The skills are Markdown prompt files. The hooks are bash scripts. The conventions are plain text embedded in CLAUDE.md. The adversarial review pattern, verification-over-prompting principle, autonomy spectrum, and reproducible environment philosophy translate directly to other agent runtimes (Codex CLI, Goose, Antimatter, or whatever emerges next), other operating systems (the shell scripts port to macOS and Windows with minimal effort), and any model with comparable coding ability. Nothing here depends on a vendor API, a proprietary file format, or a platform primitive that isn't available elsewhere.

In practice: if Claude Code gains a serious competitor or a different model pulls ahead, the work to port is swapping the skill invocation syntax and the hook registration format -- not rethinking the architecture.

## Coding Practices

These instructions are embedded in `claude/global-claude.md` and active in every Claude Code session on this machine. They are the operational translation of the philosophy above into day-to-day coding behavior.

- Work in small, committable increments. Get one thing working before adding the next. Do not build scaffolding for features that are not needed yet.
- When adding or changing functionality, write or update tests in the same increment. If the project has no test infrastructure, add a minimal test runner first.
- Run the test suite (or the relevant subset) after each functional change. Do not stack multiple untested changes.
- When fixing a bug, change only what is necessary. Do not refactor surrounding code or improve unrelated code in the same change.
- If a change causes previously passing tests to fail, revert it and try a different approach. Do not modify tests to accommodate a regression.
- Before switching tasks or when context grows large, write key decisions and current state to a file (commit message, README, or project-specific doc). Prefer restarting with a written plan over continuing with a long, stale context.

These practices are deliberately minimal. Shorter, more specific instructions outperform comprehensive ones for AI agents: as instruction volume grows, compliance with any single instruction drops (instruction dilution). Each bullet targets a specific failure mode that agents cannot reliably self-correct without explicit guidance. If a practice can be enforced by tooling (linting, hooks, tests), it belongs in tooling, not here.

## Quick Start

```bash
git clone git@github.com:peterzat/zat.env.git ~/src/zat.env
~/src/zat.env/zat.env-install.sh
# Restart Claude Code to pick up skills and hooks
```

This installs on any machine with git, jq, and Claude Code. It symlinks skills into `~/.claude/skills/`, wires the pre-push hook into `~/.claude/settings.json`, and sets up git config. Safe to re-run at any time.

### What the install script does

The repo stays at `~/src/zat.env/` and remains part of the live system after install. Most configuration is symlinked rather than copied, so the repo and the active config are the same files.

**Symlinked into `~/.claude/` (live — `git pull` updates them immediately):**
- `~/.claude/CLAUDE.md` → `claude/global-claude.md`
- `~/.claude/skills/codereview/` → `claude/skills/codereview/`
- `~/.claude/skills/security/` → `claude/skills/security/`
- `~/.claude/skills/architect/` → `claude/skills/architect/`
- `~/.claude/skills/tester/` → `claude/skills/tester/`
- `~/.claude/skills/pr/` → `claude/skills/pr/`

**Registered as paths into the repo (live — `git pull` updates the content, no re-install needed):**
- `~/.gitconfig` gets `include.path` pointing at `gitconfig/aliases.gitconfig` and `core.excludesfile` pointing at `gitconfig/ignore-global`
- `~/.claude/settings.json` gets a pre-push hook entry with the path to `hooks/pre-push-codereview.sh`

**Re-run `zat.env-install.sh` when:**
- A new skill is added to `claude/skills/` (the symlink for the new skill won't exist yet)
- A new hook is added to `hooks/` (it won't be registered in `settings.json` yet)
- The repo is moved to a different path (all registered paths need updating)

**Updating:**
```bash
cd ~/src/zat.env && git pull
# Re-run install only if new skills or hooks were added:
./zat.env-install.sh
```

---

## Agentic Skills

Five global skills are installed by `zat.env-install.sh` and available in all Claude Code sessions. Each skill runs as a forked subagent with its own context window, starts from scratch, and gathers everything it needs from the codebase. Full instructions live in `claude/skills/<name>/SKILL.md`.

| Skill | Command | Invocation | Purpose |
|-------|---------|------------|---------|
| Code Review | [`/codereview`](claude/skills/codereview/SKILL.md) | Auto (pre-push) + manual | Adversarial review of uncommitted changes |
| Security | [`/security`](claude/skills/security/SKILL.md) | Manual + chained from codereview | Security audit (full repo or changes-only) |
| Architect | [`/architect`](claude/skills/architect/SKILL.md) | Manual only | Architecture fitness assessment |
| Tester | [`/tester`](claude/skills/tester/SKILL.md) | Manual only | Test strategy assessment |
| Pull Request | [`/pr`](claude/skills/pr/SKILL.md) | Manual only | Create, inspect, or merge GitHub PRs |

### Prompt Design Principles

All five skills share a set of prompt design principles informed by community research on AI code review agents. These principles are embedded directly in each SKILL.md:

- **Precision over recall.** Every false positive wastes human attention. Skills only report findings they have high confidence in. Fewer than 2 issues indicates quality code.
- **Evidence grounding.** Every finding must cite a specific file and line. If the finding depends on code outside the diff, the skill must read that code first. No speculation about unverified behavior.
- **Halt on uncertainty.** Below 80% confidence, the skill omits the finding or flags it as uncertain. Guessing is worse than silence.
- **Empty report is valid.** A clean report means the code is clean. Skills never manufacture findings to fill a template.
- **No style policing.** Formatting, naming, and aesthetic preferences are not findings unless they indicate a functional or structural problem.
- **Scoped context reads.** When reading persistent files from prior runs, skills focus on the most recent entry, unresolved BLOCKs, and the metadata footer. Historical entries older than the current branch's base commit are skipped.

These principles address the most common failure mode of AI review agents: generating noise that erodes trust. Industry experience with AI code review tools consistently shows that precision-biased instructions (focus on logic and security, not style) dramatically improve developer action rates on AI-generated findings.

### [`/codereview`](claude/skills/codereview/SKILL.md): Adversarial Code Review

**Persona:** Principal Software Engineer, adversarial stance.

**Trigger:** Runs automatically before any `git push` (via the pre-push hook gate). Also invocable manually.

**Tiered review.** After gathering the diff, the skill classifies changes as **light** (docs/config only: `.md`, `.json`, `.yaml`, etc.) or **full** (any code files). Light review skips the test suite, security chain, auto-fix loop, and fix verification. This keeps doc-only pushes fast while maintaining the full pipeline for code changes.

**Full review pipeline:**
1. Reads prior review state from CODEREVIEW.md, SECURITY.md, and TESTING.md (scoped reads)
2. Gathers all uncommitted/staged changes via `git diff`; reads full changed files for context
3. Classifies review tier (light or full)
4. Runs the project's test suite (if one exists) to capture a baseline
5. Reviews for correctness, code quality, solution approach, spaghetti detection (mixed concerns in one commit), and regression risk
6. Chains to `/security changes-only` for a focused security review of the same diff
7. Reports findings as BLOCK / WARN / NOTE with evidence citations
8. Auto-fixes BLOCK and WARN items with **escalating conservatism**: iteration 1 fixes normally (one issue at a time, max 20 lines per fix); iteration 2 requires explaining why the prior fix failed before retrying; iteration 3 stops and reports to the human
9. Re-runs tests after fixing; reverts any fix that causes test regression
10. Writes a content-addressed marker file so the pre-push hook allows the next `git push`
11. Updates `CODEREVIEW.md` with a dated entry and structured metadata footer

**Key guard:** Never deletes, skips, or weakens existing tests to make them pass. Fixes the code, not the tests.

### [`/security`](claude/skills/security/SKILL.md): Security Review

**Persona:** Principal Security Engineer.

**Trigger:** Manual invocation, or chained automatically from `/codereview`.

**Scope:** Controlled via arguments. `/security` reviews the full repo. `/security changes-only` focuses on the current diff. `/security path/to/file` reviews a specific file.

**What it does:**
1. Reads prior security state from SECURITY.md and CODEREVIEW.md (scoped reads)
2. Scopes the review based on arguments
3. Reviews across 7 dimensions: secret leaks (including git history), input/output sanitization (with data flow tracing), auth/authz, dependency supply chain, infrastructure security, AI-specific risks (prompt injection, unvalidated LLM output), and data exposure
4. Reports findings with concrete attack vectors. "An attacker could theoretically..." without specifying how they reach the code path is not a finding.
5. Updates `SECURITY.md` with dated findings, resolved/open status, and accepted risks

### [`/architect`](claude/skills/architect/SKILL.md): Architecture Review

**Persona:** Principal Architect.

**Trigger:** Manual only (`/architect`). Not auto-invoked.

**What it does:**
1. Reads all three persistent files (CODEREVIEW.md, SECURITY.md, TESTING.md) as the terminal node in the cross-skill reading DAG
2. Explores the codebase: README, directory structure, languages, frameworks, entry points, dependency manifests
3. Evaluates 7 dimensions: structural clarity, appropriate complexity (over-engineering is as bad as under-engineering), scale alignment, dependency health, extensibility, consistency, and business goal alignment
4. Reports per dimension with HIGH / MEDIUM / LOW priority, or "Nothing to flag"
5. Produces no persistent file (deliberate; see Cross-Skill Reading DAG below)

**"Nothing to add at this time"** is a valid and expected outcome. Most codebases have sound architecture.

### [`/tester`](claude/skills/tester/SKILL.md): Test Strategy Review

**Persona:** Principal Software Design Engineer in Test (SDE/T).

**Trigger:** Manual only (`/tester`). Not auto-invoked.

**What it does:**
1. Reads prior assessment from TESTING.md, SECURITY.md, and CODEREVIEW.md (scoped reads)
2. Discovers test infrastructure: test files, frameworks, CI/CD configs, coverage tools, pre-commit hooks, deployment configs
3. Evaluates 8 dimensions: test coverage strategy (are the right things tested?), automation maturity, automatic test execution (tests that must be run manually are often not run), CI/CD integration, framework choices, fixture management, flaky test patterns, and missing test categories
4. Reports findings as BLOCK / WARN / NOTE. Does not write or run individual tests.
5. Updates `TESTING.md` with dated assessment and status of prior recommendations

**"This is fine for now"** is valid. A new prototype with a few pytest files and no CI is fine. A production API with no integration tests is not. The assessment is always proportional to the project's maturity and goals.

### [`/pr`](claude/skills/pr/SKILL.md): Pull Request Workflow

**Trigger:** Manual only (`/pr`). Not auto-invoked.

**What it does:**

Five modes dispatched by argument:

- `/pr` or `/pr <branch-name>` — create a PR. If on `main`, checks out a feature branch
  first. Checks for an existing PR on the branch (idempotent; will not create duplicates).
  Composes the title from commit messages and the body from review file metadata.
- `/pr status` — show the current branch's PR state, CI checks, and merge readiness
- `/pr <number>` — inspect a specific PR and summarize review comments
- `/pr merge` — verify the codereview marker, then `gh pr merge --squash --delete-branch`
  and return to main
- `/pr list` — list open PRs for the repo

**Auto-composed PR descriptions.** The skill reads `<!-- REVIEW_META: {...} -->` footers
from CODEREVIEW.md, SECURITY.md, and TESTING.md to populate a review status table in the
PR body. Zero extra work: review files written by other skills become the PR description.

**Review gate on merge.** `/pr merge` performs the same diff-hash check as the pre-push
hook. A PR cannot be merged through this skill without a passing `/codereview`.

**Design intent.** Right now, `/pr` is primarily a convenience: it saves the mechanical
work of composing a PR description and running `gh pr create` by hand. Direct-to-main
remains the default solo workflow, and PRs are opt-in.

The longer-term purpose is to establish PRs as the coordination primitive for autonomous
agent loops. When multiple agents work in parallel -- each on its own branch -- PRs become
the natural handoff point: agent A opens a PR, agent B reviews it via `--from-pr`, a
coordinator merges when review passes. This is one of the key techniques in the Carlini C
compiler work, where pull requests served as the synchronization boundary between parallel
agent sessions. See [The Carlini Principle](#the-carlini-principle) for the background.
This coordination pattern is on the long-term roadmap; the skill is the foundation.

This skill is the terminal node added to the cross-skill reading DAG (like `/architect`):
reads review metadata, produces no persistent file.

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

**"Push now" bypass.** Say "push now" to skip codereview for a single push. Claude creates a one-time bypass marker and pushes immediately. Useful for docs-only or trivial changes where the full review pipeline is overkill.

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
pr          -> reads all three metadata footers (terminal node, produces no persistent file)
```

Architect and pr are terminal nodes: their output informs human decisions and does not feed back into automated review. This prevents recommendations from becoming automatic codereview criteria without deliberate human adoption.

---

## Theory of Autonomous Improvement

This section documents the design philosophy behind the agentic skill system and the long-term vision for autonomous coding loops.

### The Carlini Principle

In February 2026, Nicholas Carlini at Anthropic [built a complete C compiler](https://www.anthropic.com/engineering/building-c-compiler) using 16 parallel Claude Opus 4.6 agents running in an infinite loop. 100,000 lines of Rust, 3,982 commits, ~$20,000 in API costs, 2 weeks. No human wrote code.

The key insight: the quality ceiling of agent-built software is determined by the quality of the verification loop, not the quality of the prompt. Designing good test suites and review feedback loops matters more than crafting better instructions.

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

**Placeholder implementations.** Agent writes code that compiles and passes type checks but does not implement the actual logic (empty function bodies, hardcoded return values, `TODO` stubs). Common in self-healing loops where the agent optimizes for "make the tests pass" rather than "solve the problem." Countered by: test suites that verify behavior (not just compilation), baseline snapshot diffing to catch suspiciously small deltas, and human checkpoint intervals in loop orchestration.

**Context pollution in loops.** Each loop iteration accumulates file reads and tool results. By iteration 4-5, the context window is saturated with stale information from earlier attempts, degrading output quality. Countered by: fresh agent sessions per iteration (progress lives in files and git, not context), scoped reads of persistent review files (most recent entry only), and convergence-based early termination.

**Regression snowballing.** In a loop without baseline snapshots, pre-existing failures get attributed to the agent's changes, triggering fix attempts for code the agent didn't break. The fixes introduce real regressions, compounding the problem. Countered by: baseline state capture before any changes, regression defined as "worse than baseline" (not "any failures"), and hard stops when test count decreases between iterations.

## Current Hardware: Hetzner GEX44

The hardware below is the current choice, not a permanent one. The agentic workflow described above runs on any Linux machine with sufficient resources and a Tailscale connection -- on-premises hardware, a homelab server, or any other dedicated box works equally well.

The Hetzner GEX44 was selected for now because it combines a 14-core CPU, 64 GB RAM, and an NVIDIA RTX 4000 SFF Ada with 20 GB VRAM in a single dedicated (not shared) machine. That's enough VRAM for 7-8B parameter models natively, or ~32B quantized, which covers the majority of local inference use cases. Hetzner's pricing makes it practical to keep running 24/7, which is the main operational requirement. The GPU is the primary differentiator over cheaper CPU-only options. If needs change (larger models, more parallelism, on-prem preference), the hardware can be swapped out without changing any of the agentic tooling.

The only hard networking requirement is Tailscale. All access to the machine goes through the Tailscale mesh: SSH, Claude Code remote sessions, everything. On-premises hardware behind NAT works fine as long as Tailscale is installed. The bootstrap script configures Tailscale as one of its first steps.

### Machine Specs

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

### Setup From Scratch

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

---

### Directory Overview

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
│       │       ├── tester/           # /tester: test strategy review
│       │       │   └── SKILL.md
│       │       └── pr/               # /pr: GitHub PR workflow
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
│       ├── tester     -> ~/src/zat.env/claude/skills/tester/
│       └── pr         -> ~/src/zat.env/claude/skills/pr/
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

### Daily Workflow

#### Connecting
```bash
ssh peter@<tailscale-hostname>
# or from phone via any SSH client
```

#### Starting a project
```bash
# Clone an existing repo and open a persistent claude session
ccproj myrepo git@github.com:peterzat/myrepo.git

# Create a new project from scratch
newproj my-new-thing
```

#### tmux and persistent sessions
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
- [x] GitHub PR workflow (`/pr`): create, inspect, and merge PRs with auto-composed descriptions from review metadata

### Future (v2+)

**Near-term (high value, incremental):**
- **`/verify` skill**: executes the project's test suite as ground truth; factual signal to complement opinion-based review
- **Worktree-based A/B testing**: before applying a fix, create a worktree, run tests in isolation, compare against main branch before merging; `/pr` gains worktree awareness to handle branch/push correctly in worktree context
- **Quantitative trending**: parse structured metadata footers, track BLOCK/WARN/NOTE counts over sessions, detect convergence or regression
- **Branch workflow aliases**: `git feat <name>` (create feature branch), `git done` (merge + delete local-only branch)

**Medium-term (autonomous loops):**
- **Loop orchestrator** (`/review-loop`): run codereview, fix, codereview in a loop until converging or hitting max iterations; auto-create PR via `/pr` when loop converges. Community-validated by Huntley's [Ralph Wiggum technique](https://ghuntley.com/ralph/) (`while :; do cat PROMPT.md | claude-code ; done`) and Carlini's parallel agent loops. Progress must persist in files and git, not in context, so each fresh agent can re-orient from disk. Design around known failure modes (see [Anti-Patterns](#anti-patterns-we-designed-against)).
- **Loop circuit breakers**: max-iteration cap (configurable, default ~5), regression detection (test count must not decrease between iterations), convergence detection (if BLOCK count is not decreasing, stop), and human checkpoint intervals (pause for approval every N iterations or after any BLOCK auto-fix fails). Without these, loops degrade into placeholder implementations or oscillating fixes.
- **Baseline snapshots**: before touching code, record current build/test/lint state (exit codes, test counts, diagnostic counts). After changes, diff against baseline. Distinguishes "I broke this" from "this was already broken." Inspired by Anvil's [Forge protocol](https://github.com/burkeholland/anvil). Supports loop reliability by giving each iteration a clean regression signal.
- **Remote agent PR review**: `/schedule` trigger runs `claude --from-pr <url> --print` with `/codereview` against open PRs, posts results as PR comments; decouples authoring and review sessions
- **Inter-session coordination**: lockfiles for persistent review files, session discovery, conflict-safe append-only updates for concurrent sessions
- **Alignment checks**: periodic re-read of original task specification during long loops to detect intent drift
- **Progressive disclosure**: reference files (`skills/<name>/references/`) for dimension details as skill prompts grow

**Long-term (multi-agent):**
- **Agent-per-PR pattern**: each agent works in its own worktree on its own branch, opens a PR via `/pr` when done; a coordinator agent reviews and merges
- **GitHub Actions CI**: justified at this point for independent test signal across multiple agent PRs; branch protection on main replaces local pre-push hook as the gate
- **Cross-project awareness**: architect and security read persistent files from sibling projects under `~/src/` to detect dependency-chain risks
- **Long-running loop orchestration**: Carlini-style infinite loops with CI enforcement for complex projects. Key design inputs from the ecosystem: Carlini used lock files for task claiming (no central orchestrator), GCC as a differential testing oracle for independent verification, and test output designed for agent consumption (sparse, pre-computed statistics, fast sampling modes). Huntley's experience shows these loops work well for tasks with automatic verification (bugfixes, migrations, coverage expansion) but fail for judgment calls or ambiguous requirements. Operator skill in designing the verification harness determines outcomes.
- **Multi-agent coordination**: multiple Claude sessions across projects with shared task pools and message passing
- **Monitoring / dashboards**: visibility into running agent sessions, GPU utilization, loop progress

**Agent framework portability:**
- **Evaluate agent wrappers**: explore framework-agnostic agent runtimes -- Goose (Block's open-source CLI agent, designed around extensions rather than vendor primitives), Amp Code, Aider, and others. The skills are Markdown prompt files and the hooks are shell scripts; most of the architecture should port with changes to invocation syntax only. Worth benchmarking against Claude Code on representative tasks to understand what, if anything, is lost. Longer-term, a portable skill format (or a thin adapter layer) would let the agentic tooling here survive model and runtime churn without a full rewrite.
- **Agent-per-PR multi-agent Carlini loop**: full implementation of the pattern from the C compiler paper -- parallel agents on branches, PRs as synchronization boundaries, coordinator agent merging via `/pr`, with GitHub Actions providing the independent verification signal that makes the loop trustworthy at scale.

**Infrastructure:**
- **Project templates**: versioned starter files for Python ML projects, API services, general Python
- **Dependency auditor** (`/deps`): dependency health, outdated packages, license risks, bloat, upgrade paths
