# zat.env

<div align="center">
  <img src="zat-env.png" alt="Claude Code running on an iPhone" width="280">
  <br>
  <sub>Claude Code on an iPhone (ShellFish) with tmux, connected via Tailscale SSH to a Linux server in Germany</sub>
</div>

<br>

Minimal harness for verification-first autonomous coding with Claude Code. Verification quality, not prompt engineering, determines the ceiling on what agents can build. This repo implements the thinnest layer that matters: specs as the control plane, adversarial review as the verification loop, persistent artifacts as inter-session memory, and a pre-push gate that blocks unreviewed code from leaving the machine.

Clone this repo and run `zat.env-install.sh` to get spec-driven development, adversarial code review with builder/verifier separation, security auditing, architecture review, test strategy review, and a GitHub PR workflow as Claude Code skills, with a pre-push hook that gates `git push` on passing review. Optional multi-model reviewers (OpenAI, Google, local GPU) provide independent second opinions.

`zat.env-install.sh` is the only requirement: it wires skills, hooks, and conventions into any machine with git, jq, and Claude Code. `hw-bootstrap.sh` is optional and specific to [my always-on dev box](#current-hardware-hetzner-gex44) (a hosted dedicated bare-metal Linux server for GPU workloads with secure remote access). Skills are Markdown prompt files, hooks are bash scripts, conventions are plain text. Nothing is invasive: skills are opt-in (invoke them when you want them), and the pre-push gate has a bypass. Companion writing at [agent-hypervisor.ai](https://agent-hypervisor.ai).

If you're coming from [The Bitter Lesson of Agentic Coding](https://agent-hypervisor.ai/posts/bitter-lesson-of-agentic-coding/), this is the repo. The harness is deliberately minimal because the bitter lesson says it should be.

**Where this is headed.** Today a human is in the loop, reviewing outcomes and writing specs. What changes over time is not the architecture but the degree of autonomy: review/fix/review cycles that run without interruption, convergence detection, parallel agents on branches. See [Roadmap](#roadmap) for the progression.

<a id="spec-driven-iteration"></a>

**Spec-driven iteration.** Strong success criteria are the autonomy lever: they let agents loop independently because the agent (and the review skills) can verify "done" without asking. Weak or absent criteria force constant clarification — agents drift, optimize for making tests pass rather than solving the problem, and "works but not good enough" stays vague indefinitely. The spec is what keeps the agent (and the human) oriented: it defines what done looks like, gives review skills something to verify against, and lets a fresh session re-orient from disk without stale context.

A **turn** is one pass through the spec-implement-evaluate loop. One command drives the iteration loop: `/spec`. It's stateful, so the same invocation does different things depending on where the project is:

1. **Define.** `/spec <description>` (or just `/spec`) writes the acceptance criteria.
2. **Implement.** Intervene with manual direction as needed.
3. **Evolve.** `/spec` checks off what's done and reports what's left. Repeat 2-3 until all criteria are met.
4. **Close the turn.** Once the last criterion is checked, evolve mode runs a retrospective ("what did you learn?") and writes a proposal you can pick up next turn.
5. **Next turn.** `/spec` detects the proposal and uses it as the input brief automatically.

**Clear between turns.** Turn boundaries are a natural place to `/clear` the session (or quit and restart Claude Code). The proposal and SPEC.md are on disk, so a fresh session loses nothing and gains a clean context window, which is exactly what the "context pollution in loops" anti-pattern warns against.

**Capture deferred ideas in `BACKLOG.md`.** Turns surface good ideas that don't fit the current or next spec: alternatives considered and rejected for now, adjacent improvements, tangents worth remembering. Rather than bloat SPEC.md's out-of-scope section or lose them to context decay, write them to `BACKLOG.md` at the project root. `/spec` reads it when drafting (to avoid re-litigating decided trade-offs) and at turn close proposes deletions you apply manually by editing the file, so it does not grow monotonically. The backlog feature is optional. Create `BACKLOG.md` only when there is something to capture, not pre-emptively. Format and sweep mechanics are documented in the `/spec` skill.

Start every session with `/spec`. It re-orients from current state: picking up a proposal, reporting progress, or prompting you to define what to build. That costs less than trying to remember where things stand.

Each turn tightens quality. The spec prevents drift across sessions, gives review skills a contract to verify against, and makes "improve quality" a concrete, trackable activity rather than a vague aspiration. When a turn completes, evolve writes a proposal grounded in git history and current state, so the next turn starts with context instead of a blank slate. (See [Philosophy](#philosophy) for the design principles behind this.)

## Contents

- [Quick Start](#quick-start)
  - [What the install script does](#what-the-install-script-does)
- [Daily Workflow](#daily-workflow)
  - [Connecting](#connecting)
  - [Starting a project](#starting-a-project)
  - [zatmux](#zatmux)
- [Agentic Skills](#agentic-skills)
  - [Prompt Design Principles](#prompt-design-principles)
  - [`/spec`: Specification](#spec-specification)
  - [`/codereview`: Adversarial Code Review](#codereview-adversarial-code-review)
  - [`/security`: Security Review](#security-security-review)
  - [`/architect`: Architecture Review](#architect-architecture-review)
  - [`/tester`: Test Strategy Review](#tester-test-strategy-review)
  - [`/pr`: Pull Request Workflow](#pr-pull-request-workflow)
  - [Pre-Push Gate](#pre-push-gate)
  - [Severity Model](#severity-model)
  - [Persistent Review Files](#persistent-review-files)
  - [Cross-Skill Context Graph](#cross-skill-context-graph)
- [Coding Practices](#coding-practices)
- [Philosophy](#philosophy)
- [Theory of Autonomous Improvement](#theory-of-autonomous-improvement)
  - [Design Foundations](#design-foundations)
  - [The Autonomy Spectrum](#the-autonomy-spectrum)
  - [Anti-Patterns We Designed Against](#anti-patterns-we-designed-against)
- [Current Hardware: Hetzner GEX44](#current-hardware-hetzner-gex44)
  - [Machine Specs](#machine-specs)
  - [Setup From Scratch](#setup-from-scratch)
  - [Directory Overview](#directory-overview)
- [References](#references)
- [Roadmap](#roadmap)

---

## Quick Start

```bash
git clone git@github.com:peterzat/zat.env.git ~/src/zat.env
~/src/zat.env/zat.env-install.sh
# Restart Claude Code to pick up skills and hooks
```

This installs on any machine with git, jq, and Claude Code. It symlinks skills into `~/.claude/skills/`, registers hooks in `~/.claude/settings.json`, prunes stale hook entries, sets up git config, and symlinks helper scripts into `~/bin/`. Safe to re-run at any time.

**No hardcoded identity.** Git `user.name` and `user.email` are not stored in this repo. The install script prompts on first run and reuses the existing git config on subsequent runs. Override with `GIT_NAME=x GIT_EMAIL=y@z ./zat.env-install.sh`.

**Generated review files.** `CODEREVIEW.md`, `SECURITY.md`, `TESTING.md`, and `SPEC.md` in downstream project roots are produced by running `/codereview`, `/security`, `/tester`, and `/spec`. The skills that generate them live in `claude/skills/`. These files are working state, not documentation, and should be committed alongside the code they describe.

### What the install script does

The repo stays at `~/src/zat.env/` and remains part of the live system after install. Most configuration is symlinked rather than copied, so the repo and the active config are the same files.

**Symlinked into `~/.claude/` (live, `git pull` updates them immediately):**
- `~/.claude/CLAUDE.md` -> `claude/global-claude.md`
- `~/.claude/skills/spec/` -> `claude/skills/spec/`
- `~/.claude/skills/codereview/` -> `claude/skills/codereview/`
- `~/.claude/skills/codefix/` -> `claude/skills/codefix/`
- `~/.claude/skills/security/` -> `claude/skills/security/`
- `~/.claude/skills/architect/` -> `claude/skills/architect/`
- `~/.claude/skills/tester/` -> `claude/skills/tester/`
- `~/.claude/skills/pr/` -> `claude/skills/pr/`

**Registered as paths into the repo (live, `git pull` updates the content, no re-install needed):**
- `~/.gitconfig` gets `include.path` pointing at `gitconfig/aliases.gitconfig` and `core.excludesfile` pointing at `gitconfig/ignore-global`
- `~/.claude/settings.json` gets hook entries for `hooks/pre-push-codereview.sh` (codereview gate) and `hooks/allow-venv-source.sh` (venv activation auto-approve). Stale hook entries (pointing at scripts removed from the repo) are pruned automatically.
- `~/.claude/settings.json` gets a permissions block (defaultMode, allow list for common dev commands, deny list for dangerous patterns). This block is replaced on each install to prevent session-accumulated cruft.

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

## Daily Workflow

### Connecting
```bash
ssh peter@dev
# or: ssh peter@dev.emperor-exponential.ts.net
# or from phone via any SSH client (ShellFish, Termius, etc.)
```

### Starting a project
```bash
# Clone a repo and start a tmux session for it
git clone git@github.com:peterzat/myrepo.git ~/src/myrepo
cd ~/src/myrepo
zatmux
```

### zatmux

Tmux session toggle. Optional convenience for tmux users, not required for any of the agentic skills.

Attach from outside tmux, detach from inside:

```bash
cd ~
zatmux                  # attach or create the "shellfish-1" session
zatmux                  # (inside tmux) detach

cd ~/src/ranking
zatmux                  # attach or create a "ranking" session
zatmux                  # (inside tmux) detach
```

Designed around ShellFish (iOS SSH client), which auto-creates a tmux session called `shellfish-1`. Running `zatmux` from `~/` gets you into that session whether it already exists or not. Running it again from inside any tmux session detaches cleanly without killing the session.

If you disconnect (SSH drop, laptop closes), the tmux session keeps running. Come back later with `zatmux` from the same directory, or use `tmux attach -t <name>` and `tmux list-sessions` directly.

---

## Agentic Skills

Global skills are installed by `zat.env-install.sh` and available in all Claude Code sessions. Each skill runs as a forked subagent with its own context window, starts from scratch, and gathers everything it needs from the codebase. Full instructions live in `claude/skills/<name>/SKILL.md`.

| Skill | Command | Invocation | Purpose |
|-------|---------|------------|---------|
| Spec | [`/spec`](claude/skills/spec/SKILL.md) | Manual only | Define acceptance criteria before implementation |
| Code Review | [`/codereview`](claude/skills/codereview/SKILL.md) | Auto (pre-push) + manual | Adversarial review of uncommitted changes |
| Security | [`/security`](claude/skills/security/SKILL.md) | Manual + chained from codereview | Security audit (full repo or changes-only) |
| Architect | [`/architect`](claude/skills/architect/SKILL.md) | Manual only | Strategic architecture review (10 dimensions, HEALTHY/WATCH/ACT) |
| Tester | [`/tester`](claude/skills/tester/SKILL.md) | Manual only | Test strategy assessment |
| Pull Request | [`/pr`](claude/skills/pr/SKILL.md) | Manual only | Create, inspect, or merge GitHub PRs |

### Prompt Design Principles

All skills share a set of prompt design principles informed by community research on AI code review agents. These principles are embedded directly in each SKILL.md:

- **Precision over recall.** Every false positive wastes human attention. Skills only report findings they have high confidence in.
- **Evidence grounding.** Every finding must cite a specific file and line. If the finding depends on code outside the diff, the skill must read that code first. No speculation about unverified behavior.
- **Halt on uncertainty.** Below 80% confidence, the skill omits the finding or flags it as uncertain. Guessing is worse than silence.
- **Empty report is valid.** A clean report means the code is clean. Skills never manufacture findings to fill a template.
- **No style policing.** Formatting, naming, and aesthetic preferences are not findings unless they indicate a functional or structural problem.
- **Scoped context reads.** When reading persistent files from prior runs, skills focus on the most recent entry, unresolved BLOCKs, and the metadata footer. Historical entries older than the current branch's base commit are skipped.

These principles address the most common failure mode of AI review agents: generating noise that erodes trust. Industry experience with AI code review tools consistently shows that precision-biased instructions (focus on logic and security, not style) dramatically improve developer action rates on AI-generated findings.

Beyond content-level instructions, skills use Claude Code's `effort` frontmatter field to match reasoning depth to task criticality. `/spec`, `/codereview`, `/security`, and `/architect` all set `effort: max` in their frontmatter, which tells the harness to use high-effort adaptive reasoning for the entire skill execution. Each of these skills also includes a structured pressure-test step after analysis but before writing findings, verifying that conclusions are grounded and severity levels are calibrated. Convention files like `global-claude.md` describe the same analytical rigor as a behavioral norm, so routine turns outside skills are not over-indexed.

### [`/spec`](claude/skills/spec/SKILL.md): Specification

**Persona:** Principal Product Manager.

**Trigger:** Manual only (`/spec`). Not auto-invoked.

**What it does:**

Defines what done looks like before implementation begins. The output is `SPEC.md`: a verification contract with concrete acceptance criteria that an agent or human can check off. The value of a spec is the acceptance criteria. Everything else (numbered requirements, phased task lists, Given/When/Then ceremony) is optional and only added if the user asks for it.

Four modes:
- **Interview mode** (`/spec new` or first run): asks the user focused questions about goals and acceptance criteria, then writes SPEC.md
- **Direct mode** (`/spec <description>`): reads the codebase, drafts acceptance criteria for the described feature, pressure-tests them, and writes SPEC.md. Also activates automatically when SPEC.md contains a proposal section (see propose mode), using the proposal as the input brief.
- **Evolve mode** (`/spec` with existing SPEC.md): assesses progress against current criteria, checks off met criteria, and reports progress. When all criteria are met, runs the turn-boundary transition: asks a retrospective ("what did you learn during this turn?"), then generates a proposal for the next turn grounded in git history and current state.
- **Propose mode** (`/spec propose`): reads the current spec and git history, generates a proposal for the next turn (what happened, key questions, suggested directions), and writes it to SPEC.md for discussion. Useful when evolve was skipped or when pivoting mid-turn.

`SPEC.md` uses the same rolling format as other persistent files: current entry, one-line prior summary, structured metadata footer (`<!-- SPEC_META: {...} -->`). Each entry covers one unit of work, not the entire project.

**Framework-informed context.** `/spec` reads the zat.env README in addition to the project's own files. Relevant philosophy, coding practices, anti-patterns, and design principles are extracted and carried into SPEC.md's Context section, so the coding agent has them available during implementation without needing to read zat.env itself. This is selective, not wholesale: only points relevant to the specific unit of work are included.

**Pressure test.** When writing new acceptance criteria (interview, direct, or post-completion evolve mode), a structured pressure-test checkpoint reviews drafted criteria for missing edge cases, unstated assumptions, unspecified failure behavior, and over-specification before writing SPEC.md. This step is skipped for routine evolve-mode check-offs where criteria are unchanged. The skill runs at `effort: max` via frontmatter to ensure deep reasoning across all steps.

**What it does NOT do:** generate code, write tests, or run the test suite. It defines the contract. Implementation follows separately.

**Typical workflow:** See [Spec-driven iteration](#spec-driven-iteration) for the full turn-based workflow.

You can also run `/spec propose` at any time to generate a proposal without waiting for all criteria to be met. This is useful for pivoting mid-turn or generating a status snapshot.

For external or cloned projects, SPEC.md describes what you are building or changing right now, not what the project is (that's README territory).

**Complements Claude Code's plan mode.** Plan mode and `/spec` serve different phases of the same work and have a documented handoff. Plan mode is Claude Code's built-in exploratory thinking space: read-only, multi-turn, no persistent artifact, good for "I don't know what I want yet." `/spec` is the commit point: it writes a persistent SPEC.md with testable acceptance criteria, integrates with review skills, and drives the implementation loop. When a plan mode session turns out to be bigger than one-off scratch thinking, exit plan mode and run `/spec plan` to adopt the saved plan as the spec brief (or `/spec plan <slug>` to pick a specific earlier plan). In the reverse direction, if you invoke `/spec` with a brief too vague to produce verifiable criteria, the skill stops and tells you to explore in plan mode first. A PostToolUse hook on `ExitPlanMode` prints a reminder about `/spec plan` every time you leave plan mode so the handoff is visible rather than something to remember.

**Design intent.** Agents without acceptance criteria optimize for "make tests pass" rather than "solve the problem." In autonomous loops, the spec is the artifact that answers "what should I be building?" when the agent starts a fresh session. All review skills read SPEC.md when it exists: `/codereview` checks spec alignment, `/tester` checks whether tests cover the criteria, `/architect` evaluates whether the architecture can support the criteria, `/security` uses the spec for scope awareness.

### [`/codereview`](claude/skills/codereview/SKILL.md): Adversarial Code Review

**Persona:** Principal Software Engineer, adversarial stance.

**Trigger:** Runs automatically before any `git push` (via the pre-push hook gate). Also invocable manually.

**Tiered review.** After gathering the diff, the skill classifies changes as **light** (plain docs only: `.md`, `.txt`, `.gitignore`, `.gitconfig`) or **full** (any code or configuration files). Configuration formats (`.json`, `.yaml`, `.toml`, etc.) get full review because they are often operationally live. Light review skips the test suite, security chain, external reviewers, and fix loop. This keeps docs-only pushes fast while maintaining the full pipeline for code and config changes.

**Refresh review optimization.** When a prior CODEREVIEW.md exists with `block: 0` and the reviewed commit is an ancestor of HEAD, the skill performs an incremental review scoped to files changed since the prior review. This keeps iterative fix-and-review cycles fast without re-evaluating the entire diff.

**Full review pipeline:**
1. Reads prior review state from CODEREVIEW.md, SECURITY.md, TESTING.md, and SPEC.md (scoped reads)
2. Checks for a prior successful review (refresh detection); if eligible, scopes to changed-since files only
3. Gathers all uncommitted/staged changes via `git diff`; reads full changed files for context
4. Classifies review tier (light or full)
5. Runs the project's test suite (if one exists) to capture a baseline
6. Reviews for correctness, code quality, solution approach, spaghetti detection (mixed concerns in one commit), regression risk, and spec alignment (if SPEC.md exists)
7. Chains to `/security` scoped to files changed since the last security scan (or since upstream if no prior scan). If no code files changed since the prior scan, carries forward existing findings instead of re-invoking.
8. Reports findings as BLOCK / WARN / NOTE with evidence citations
9. Runs optional external reviewers (OpenAI, Google, local GPU) via `review-external.sh` if configured; findings tagged with provider name
10. Delegates BLOCK/WARN fixes to `/codefix`, a separate skill that runs in its own forked context (builder/verifier separation, up to 3 fix/re-review cycles)
11. Re-runs tests after each fix cycle; stops if tests regress
12. Writes a content-addressed marker file so the pre-push hook allows the next `git push`
13. Updates `CODEREVIEW.md` with a dated entry and structured metadata footer

**Pressure test (full review only).** After evaluating all review dimensions and before writing findings, a structured pressure-test checkpoint verifies bugs are confirmed rather than suspected, checks that regression risk claims trace actual callers, filters style-as-substance false positives, and reconsiders solution approach. Skipped for light reviews. The skill runs at `effort: max` via frontmatter.

**Builder/verifier separation.** The reviewer never fixes code itself. When BLOCK or WARN findings exist, it writes CODEREVIEW.md and delegates to `/codefix`, a separate skill that runs in its own forked context with no memory of the review's reasoning. Codefix reads findings as a spec and applies minimal fixes. The reviewer then re-evaluates independently. No agent grades its own work.

**External reviewers (optional).** When API keys are configured in `~/.config/claude-reviewers/.env`, the codereview skill pipes the diff through `review-external.sh` to get independent findings from OpenAI and/or Google models. A local GPU reviewer (Qwen2.5-Coder-14B via [qwen-2.5-localreview](https://github.com/peterzat/qwen-2.5-localreview)) is also supported: useful as a fast second opinion at zero API cost, though the 14B model produces more false positives than cloud models and should not be treated as authoritative. Findings are tagged with the provider name. All external reviewers fail open: missing config, empty input, API errors, or absent local setup produce no findings. Runs once at initial review, not during fix/re-review cycles.

**Review pipeline sequencing.** Claude Code's built-in review runs first (serial), then all configured external reviewers (cloud and local) run in parallel, then findings are merged. The serial-first design is intentional: Claude Code's review consumes the user's Anthropic plan (Pro, Max) without API token costs, but it runs inline and cannot be parallelized with external calls without significant orchestration complexity. Users on direct Claude API tokens (enterprise deployments) could instead add Claude as a peer external reviewer alongside OpenAI and Google in `review-external.sh`, eliminating the serialization delay at the cost of API token consumption. For plan-based subscribers the serial approach is the better trade-off.

**Key guard:** Never deletes, skips, or weakens existing tests to make them pass. Fixes the code, not the tests.

### [`/security`](claude/skills/security/SKILL.md): Security Review

**Persona:** Principal Security Engineer.

**Trigger:** Manual invocation, or chained automatically from `/codereview`.

**Scope:** Controlled via arguments. `/security` reviews the full repo. `/security changes-only` focuses on the current diff. `/security path/to/file` reviews a specific file.

**What it does:**
1. Reads prior security state from SECURITY.md, CODEREVIEW.md, and SPEC.md (scoped reads)
2. Scopes the review based on arguments
3. Reviews across 8 dimensions: secret leaks (including git history), input/output sanitization (with data flow tracing), auth/authz, dependency supply chain, infrastructure security, AI-specific risks (prompt injection, unvalidated LLM output), data exposure, and PII in source
4. Reports findings with concrete attack vectors. "An attacker could theoretically..." without specifying how they reach the code path is not a finding.
5. Updates `SECURITY.md` with dated findings, resolved/open status, and accepted risks

**Pressure test.** Before writing findings, a structured pressure-test verifies attack vectors are reachable (not assumed), rechecks dimensions where nothing was found, calibrates severity levels, and confirms git history was checked for leaked secrets. The skill runs at `effort: max` via frontmatter.

### [`/architect`](claude/skills/architect/SKILL.md): Architecture Review

**Persona:** Senior Architecture Review Board.

**Trigger:** Manual only (`/architect`). Not auto-invoked. Supports focused deep-dives: `/architect deps`, `/architect ops`, `/architect <topic>`.

**What it does:**
1. Reads all four persistent files (CODEREVIEW.md, SECURITY.md, TESTING.md, SPEC.md)
2. Explores the codebase: README, directory structure, languages, frameworks, entry points, dependency manifests, CI/CD configs, onboarding docs
3. Evaluates 10 dimensions in two groups:
   - **Design Quality:** structural clarity, appropriate complexity, scale alignment, dependency health (includes outdated packages, license risks, bloat, upgrade paths, vendor lock-in), extensibility
   - **Strategic Fitness:** consistency, business goal alignment, technology selection, operational fitness, developer experience
4. Reports per dimension with HIGH / MEDIUM / LOW priority, or "Nothing to flag"
5. Produces a Strategic Summary with a board recommendation: HEALTHY / WATCH / ACT
6. Produces no persistent file (terminal node; see [Cross-Skill Context Graph](#cross-skill-context-graph))

**Pressure test.** Six pressure-test questions recalibrate assessments against the project's actual scale and goals, verify that complexity concerns name concrete costs, check extensibility recommendations against evidence of anticipated changes, distinguish transitional inconsistency from architectural drift, require evidence of friction before recommending technology changes, and calibrate operational expectations to the deployment model. The skill runs at `effort: max` via frontmatter.

**"No strategic concerns at this time"** is a valid and expected outcome. Most codebases have sound architecture.

### [`/tester`](claude/skills/tester/SKILL.md): Test Strategy Review

**Persona:** Principal Software Design Engineer in Test (SDE/T).

**Trigger:** Manual only (`/tester`). Not auto-invoked.

**What it does:**
1. Reads prior assessment from TESTING.md, SECURITY.md, CODEREVIEW.md, and SPEC.md (scoped reads)
2. Discovers test infrastructure: test files, frameworks, CI/CD configs, coverage tools, pre-commit hooks, deployment configs
3. Evaluates 9 dimensions: test coverage strategy (are the right things tested?), automation maturity, automatic test execution (tests that must be run manually are often not run), CI/CD integration, framework choices, fixture management, flaky test patterns, missing test categories, and development loop cadence (whether test timing supports autonomous iteration)
4. Reports findings as BLOCK / WARN / NOTE. Does not write or run individual tests.
5. Updates `TESTING.md` with dated assessment and status of prior recommendations

**"This is fine for now"** is valid. A new prototype with a few pytest files and no CI is fine. A production API with no integration tests is not. The assessment is always proportional to the project's maturity and goals.

### [`/pr`](claude/skills/pr/SKILL.md): Pull Request Workflow

**Trigger:** Manual only (`/pr`). Not auto-invoked.

**What it does:**

Five modes dispatched by argument:

- `/pr` or `/pr <branch-name>` -- create a PR. If on `main`, creates a feature branch:
  when a branch name is given, uses it with an appropriate prefix (`feat/`, `fix/`, `docs/`);
  when no branch name is given, derives one from the commit message (lowercased, hyphenated,
  with the same prefix convention). Checks for an existing PR on the branch (idempotent;
  will not create duplicates). Composes the title from commit messages (single commit: uses
  the commit message; multiple commits: writes a concise summary under 70 chars) and the
  body from review file metadata.
- `/pr status` -- show the current branch's PR state, CI checks, and merge readiness
- `/pr <number>` -- inspect a specific PR and summarize review comments
- `/pr merge` -- verify REVIEW_META in CODEREVIEW.md (block: 0, reviewed commit is ancestor
  of HEAD), check GitHub merge readiness, then `gh pr merge --squash --delete-branch`
- `/pr list` -- list open PRs for the repo

**Auto-composed PR descriptions.** The skill reads metadata footers from CODEREVIEW.md,
SECURITY.md, TESTING.md, and SPEC.md to populate a review status table and spec summary
in the PR body. Review files written by other skills become the PR description with no
extra work.

**Review gate on merge.** `/pr merge` verifies that CODEREVIEW.md shows a passing review
(`block: 0`) covering the current code, then checks GitHub merge readiness: CI checks
must pass, the PR must be mergeable (no conflicts), and no pending or change-requested
reviews. A PR cannot be merged through this skill without passing both the review gate
and remote checks.

**Design intent.** Right now, `/pr` is primarily a convenience for composing PR descriptions
and running `gh pr create`. Direct-to-main remains the default solo workflow, and PRs are
opt-in. The longer-term purpose is to establish PRs as the coordination primitive for
autonomous agent loops (see [Design Foundations](#design-foundations)). Terminal node
in the context graph: reads review metadata, produces no persistent file.

### Pre-Push Gate

A Claude Code `PreToolUse` hook (configured in `~/.claude/settings.json`) intercepts every `git push` command. The push is blocked unless `/codereview` has been run and passed on the current diff.

**Gate condition:** all BLOCK items resolved and tests have not regressed. Unresolved WARNs are reported but do not block the push.

**Flow:**
1. Claude attempts `git push`
2. Hook reads the JSON payload from stdin and checks if the command is `git push`
3. Hook checks for a marker file at `/tmp/.claude-codereview-<project-hash>`
4. Marker contains a diff hash from the passing review: `sha256sum` of `git diff <upstream>` (excluding review output files), truncated to 16 hex chars. This makes the marker content-addressed: tied to the exact diff that was reviewed, not just "some review happened."
5. If marker exists and hash matches current diff, push proceeds
6. Otherwise, push is blocked; Claude is instructed to run `/codereview`

The marker is per-project (scoped by git root path hash) and content-addressed. It persists after a successful push so that a network error or remote rejection does not force a full re-review. Making any code change after a passing review invalidates the hash and requires a new review.

**"Push now" bypass.** Say "push now" to skip codereview for a single push. Claude creates a one-time bypass marker and pushes immediately. This is a human escape valve for when the full review pipeline is not needed.

### Severity Model

All skills use a consistent three-level severity model:

| Level | Meaning | Gates push? | Action |
|-------|---------|-------------|--------|
| **BLOCK** | Must fix before pushing | Yes | Auto-fixed by /codefix; others report to human |
| **WARN** | Should fix; significant gap | No | Auto-fixed by /codefix; others report to human |
| **NOTE** | Informational; improvement opportunity | No | Reported only, never auto-fixed |

The pre-push gate passes when all BLOCKs are resolved and tests have not regressed. Unresolved WARNs are reported but do not block the push. Findings carried forward from a prior review retain their original severity unless the human explicitly adds them to the Accepted Risks section of CODEREVIEW.md.

### Persistent Review Files

Four skills write per-project files to the project root. These files are working state, not documentation. They serve as inter-session memory: each skill invocation reads relevant files to avoid re-reporting resolved issues and to track whether recommendations were adopted. Each file ends with a structured metadata comment (e.g., `<!-- REVIEW_META: {...} -->`) that enables future tooling for convergence detection and trending.

| File | Written by | Contents |
|------|-----------|----------|
| `SPEC.md` | `/spec` | Current acceptance criteria, goal, context |
| `BACKLOG.md` | `/spec` (optional) | Deferred proposals register: ideas considered and deferred, with revisit criteria |
| `CODEREVIEW.md` | `/codereview` | Dated review history, findings, fixes applied |
| `SECURITY.md` | `/security` | Security findings, resolved issues, accepted risks |
| `TESTING.md` | `/tester` | Test strategy assessment, recommendation status |

### Cross-Skill Context Graph

Skills read each other's persistent files to share context. The reading graph has cycles (e.g., /spec reads CODEREVIEW.md while /codereview reads SPEC.md), but amplification is bounded by three mechanisms: (1) scoped reads (most recent entry, unresolved BLOCKs, and metadata footer only, not full history), (2) terminal nodes (architect and pr produce no persistent files, breaking feedback loops), and (3) independent severity assessment (each skill evaluates from its own analysis, not by inheriting other skills' findings).

```
                    SPEC.md (upstream of all review skills)
                       |
                       v
spec        -> writes SPEC.md (reads CODEREVIEW.md, TESTING.md for context)
codereview  -> reads SPEC.md, SECURITY.md, TESTING.md
security    -> reads SPEC.md, CODEREVIEW.md
tester      -> reads SPEC.md, SECURITY.md, CODEREVIEW.md
architect   -> reads all four (terminal node, produces no persistent file)
pr          -> reads all four metadata footers (terminal node, produces no persistent file)
```

SPEC.md sits upstream of all review skills as the intent declaration. Review skills read it to check alignment, coverage, and scope, but never modify it. Architect and pr are terminal nodes: their output informs human decisions and does not feed back into automated review. This prevents recommendations from becoming automatic codereview criteria without deliberate human adoption.

---

## Coding Practices

These instructions are embedded in [`claude/global-claude.md`](claude/global-claude.md) and active in every Claude Code session on this machine. They are the operational translation of the philosophy above into day-to-day coding behavior.

- Work in small, committable increments. Get one thing working before adding the next. Do not build scaffolding for features that are not needed yet.
- Before implementing changes, verify the project builds and existing tests pass. Fix pre-existing failures before adding new work.
- When adding or changing functionality, write or update tests in the same increment. If the project has no test infrastructure, add a minimal test runner first.
- Run the test suite (or the relevant subset) after each functional change. Do not stack multiple untested changes.
- When fixing a bug, change only what is necessary. Do not refactor surrounding code or improve unrelated code in the same change.
- If a change causes previously passing tests to fail, revert it and try a different approach. Do not modify tests to accommodate a regression.
- If two consecutive fix attempts fail, stop, revert to the last working state, and re-evaluate the approach.
- Before switching tasks or when context grows large, write key decisions and current state to a file (commit message, README, or project-specific doc). Prefer restarting with a written plan over continuing with a long, stale context.
- Do not push, open PRs, or modify remote state unless explicitly asked. Committing is local and reversible; pushing is a shared-state action for the user to decide.


These practices are deliberately minimal. Shorter, more specific instructions outperform comprehensive ones for AI agents: as instruction volume grows, compliance with any single instruction drops (instruction dilution). Each bullet targets a specific failure mode that agents cannot reliably self-correct without explicit guidance. If a practice can be enforced by tooling (linting, hooks, tests), it belongs in tooling, not here.

---

## Philosophy

**Claude Code as the primary development tool.** This environment is built for long autonomous coding sessions where Claude reviews its own work, fixes issues, and iterates. Skills, hooks, and conventions provide the structure: adversarial review before pushing, quantitative signals to detect convergence, and circuit breakers to cap runaway loops.

**Always-on, never a snowflake.** Long agentic loops need an always-reachable machine: sessions that survive SSH disconnects, overnight jobs that keep running, an environment tuned for the work. But a hand-configured machine is a liability. Everything must be reproducible: `hw-bootstrap.sh` provisions bare metal, `zat.env-install.sh` installs the agentic layer, and the combination recovers the full environment from scratch. Any hardware that meets the minimum spec and is reachable via Tailscale works.

**Verification over prompting.** The quality of automated verification determines the ceiling of what agents can build. A well-designed test suite and review loop is worth more than a better prompt.

**Two kinds of enforcement.** Some safety properties are enforced by code (the pre-push hook blocks pushes without a matching diff hash, allowed-tools prevents codereview from using Edit). Others are enforced by prompt instructions (the 3-cycle fix limit, "never fix code yourself," the finding format contract between codereview and codefix). Prompt-enforced properties are non-deterministic: the LLM usually follows them, but compliance is not guaranteed. This is a deliberate trade-off. Hard-coding every constraint would make the system rigid and the skills unable to adapt. Instead, zat.env uses hard gates for irreversible actions (pushing code) and prompt instructions for everything else, with structural tests (`tests/lint-skills.sh`) that verify the contracts between prompted and hard-coded components have not drifted apart. When a new constraint is added, the question is: what is the cost of the LLM not following this instruction? If the answer is "code reaches the remote repository unchecked," it needs a hard gate. If the answer is "a review finding gets mis-categorized," a prompt instruction with a structural lint check is sufficient.

**Prompts must earn their keep.** Every instruction in a skill or convention competes for the model's attention with every other instruction (the curse of instructions: compliance with any single rule drops as the count grows). When adding or maintaining a prompt, ask two questions: what model behavior is this supposed to change, and how would I know if it's working? Instructions that cannot answer both are the first to delete. This posture is why coding practices are deliberately minimal, why skills load on demand rather than sitting in the always-on context, and why most safety properties live in hooks rather than prose — enforcement is verifiable, prompt instructions are not. It also sets the bar for new additions: a proposed instruction must name the failure mode it prevents and be falsifiable enough that a future review can tell whether it is still earning its slot.

**Spec is code.** For agentic coding, a spec is not documentation. It is the verification contract that defines what done looks like. Without acceptance criteria, agents optimize for passing tests rather than solving the problem. A well-written acceptance criterion is worth more than a well-written prompt, because it tells the agent (and the review loop) what to verify. SPEC.md sits upstream of all review skills: codereview checks spec alignment, tester checks criteria coverage, architect evaluates whether the architecture serves the spec's goals. In autonomous loops, the spec is what lets a fresh agent session re-orient from disk and pick up where the last session left off. When a turn completes, the spec skill writes a proposal grounded in git history and current state, so the next turn inherits concrete context rather than starting cold.

**Precision over recall.** False positives erode trust in automated review faster than false negatives. Every review skill is designed to stay silent when it has nothing to say. "No issues found" is the correct and expected outcome for quality code.

**Elements of autonomy.** Four things work together to enable long-running coding loops without human intervention per-cycle: adaptive reasoning effort (`effort: max` frontmatter on review and spec skills ensures deep analysis at critical decision points), spec-driven development (concrete acceptance criteria that tell the agent what to build and when it is done, with turn-boundary proposals that carry context forward), role-based agents (skills with distinct personas that review, verify, and gate each other's work), and artifact-based memory (SPEC.md, CODEREVIEW.md, SECURITY.md, TESTING.md are checked into git and survive across sessions, so a fresh agent can re-orient from disk). Remove any one element and the loop degrades: without specs, agents drift; without review agents, quality drops; without artifacts, sessions lose continuity; without effort control, critical analysis is shallow.

**Autonomy spectrum.** Start supervised (Claude proposes, human reviews). Grow toward autonomous operation with guardrails: adversarial review skills, pre-push hook gates, structured constraints.

**Portable by design.** This setup is coupled to Claude Code and Ubuntu Linux, both first-rate for agentic workloads. Beyond those two choices, everything is portable: skills are Markdown, hooks are bash, conventions are plain text. If Claude Code gains a serious competitor or a different model pulls ahead, the work to port is swapping skill invocation syntax and hook registration, not rethinking the architecture.

**Grow incrementally.** Start simple. Add complexity only when earned by real use cases.

**Improvements flow upstream.** zat.env is a shared, evolving system. Skills, hooks, and conventions are symlinked into every project, so improvements compound across all current and future work. When a downstream project reveals a skill gap, prompt issue, or missing convention, the fix is made in the zat.env repo, never patched locally in a downstream project. The feedback loop: stop, note the issue, switch to zat.env to make the fix, return to the downstream project. Local patches (per-project memory overrides, inline edits to symlinked files) help one project while the same issue persists everywhere else.

---

## Theory of Autonomous Improvement

### Design Foundations

The design is grounded in two Anthropic Engineering papers: Carlini's [parallel Claude compiler](https://www.anthropic.com/engineering/building-c-compiler) (16 agents, 100K lines of Rust, verification quality as the ceiling on output quality) and Rajasekaran's [harness design for long-running development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (separate generation from evaluation, even when the same model does both). Applied here: invest in verification before investing in prompts. A well-designed review loop is worth more than a better system prompt.

See [The Bitter Lesson of Agentic Coding](https://agent-hypervisor.ai/posts/bitter-lesson-of-agentic-coding/) for the full argument: why agents cannot one-shot complex projects, how spec-driven turns solve the drift problem, and why minimal harness design follows from the bitter lesson.

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

**Circular amplification.** A NOTE becomes a BLOCK through cross-skill contamination (codereview flags something, security escalates it, architect recommends refactor, codereview flags code for not following the recommendation). Countered by: scoped reads (most recent entry only), terminal nodes (architect produces no persistent file), independent severity assessment.

**Auto-fix oscillation.** Fix A breaks B, fix B reintroduces A. Countered by: builder/verifier separation (codefix runs in a separate forked context from the reviewer), one-issue-per-fix cap, 20-line-per-fix cap, 3-cycle limit, independent re-review after each fix cycle.

**Stale context poisoning.** Persistent files describing code that no longer exists. Countered by: commit-hash-scoped metadata, skip entries older than base commit, keep only current entry + prior summary.

**Spec-less loops.** Agent loops without acceptance criteria optimize for test-passing rather than problem-solving. The agent may write code that satisfies the test suite but misses the actual goal, or drift away from the original intent over multiple iterations. Countered by: SPEC.md with concrete acceptance criteria that define what done looks like; codereview checks spec alignment; fresh agent sessions re-orient from the spec rather than relying on stale context.

**Context loss at turn boundaries.** A turn completes, the agent says "done," and the next session starts with no memory of what was learned. Rejected approaches get re-tried, surprises get re-discovered, shifted priorities get forgotten. Countered by: evolve mode's retrospective prompt captures learnings while the conversation is still live, and the proposal carries forward a grounded summary of what happened and what to tackle next. The proposal lives in SPEC.md on disk, so a fresh session inherits it without depending on conversation memory.

**Placeholder implementations.** Agent writes code that compiles and passes type checks but does not implement the actual logic (empty function bodies, hardcoded return values, `TODO` stubs). Common in self-healing loops where the agent optimizes for "make the tests pass" rather than "solve the problem." Countered by: test suites that verify behavior (not just compilation), baseline snapshot diffing to catch suspiciously small deltas, and human checkpoint intervals in loop orchestration.

**Context pollution in loops.** Each loop iteration accumulates file reads and tool results. By iteration 4-5, the context window is saturated with stale information from earlier attempts, degrading output quality. Countered by: fresh agent sessions per iteration (progress lives in files and git, not context), scoped reads of persistent review files (most recent entry only), and convergence-based early termination.

**Regression snowballing.** In a loop without baseline snapshots, pre-existing failures get attributed to the agent's changes, triggering fix attempts for code the agent didn't break. The fixes introduce real regressions, compounding the problem. Countered by: baseline state capture before any changes, regression defined as "worse than baseline" (not "any failures"), and hard stops when test count decreases between iterations.

**Local patching of shared conventions.** Fixing a skill deficiency or convention gap in a per-project memory file or local CLAUDE.md rather than in zat.env. The fix helps one project while the same issue persists in every other project. Countered by: the shared system boundary rule in global-claude.md (do not modify symlinked files from downstream), and the principle that skill behavioral corrections belong in skill definitions, not memory files.

---

## Current Hardware: Hetzner GEX44

The agentic workflow runs on any Linux machine with sufficient resources and a Tailscale connection. The Hetzner GEX44 was selected because it keeps a dedicated GPU box running 24/7 at practical cost. If needs change, the hardware can be swapped without changing any of the agentic tooling.

The only hard networking requirement is Tailscale. All access goes through the Tailscale mesh: SSH, Claude Code remote sessions, everything. The bootstrap script configures Tailscale as one of its first steps.

There's no real difference between a hosted dev box like this and a physical machine in your closet, as long as it's always on and securely reachable over SSH.

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

**Networking and access:**
- **Public DNS**: `dev.agent-hypervisor.ai` (A record to Hetzner public IP)
- **Tailscale**: hostname `dev`, tailnet `emperor-exponential.ts.net`, FQDN `dev.emperor-exponential.ts.net`
- **Access pattern**: Mac/iPad connects via Tailscale to `dev:PORT` for web UIs (Jupyter, Gradio, FastAPI, etc.)
- **Bind address**: always `0.0.0.0` (not `127.0.0.1`) so Tailscale clients can reach services
- **Public exposure**: `dev.agent-hypervisor.ai:PORT` for webhook callbacks or temporary demos only
- **No reverse proxy**: services bind directly to ports
- **Firewall (UFW)**: active; deny incoming, allow SSH (22/tcp) and all on tailscale0

These are per-machine values. See `claude/references/networking.md` for the full conventions.

### Setup From Scratch

Two scripts take a bare Hetzner Ubuntu 22.04 install to a fully provisioned agentic dev box: `hw-bootstrap.sh` handles system packages, NVIDIA drivers, CUDA, Docker, Tailscale, and Claude Code. `zat.env-install.sh` wires skills, hooks, and conventions into the live system. The process requires two bootstrap runs (one before and one after the NVIDIA driver install and reboot) plus a manual driver selection step.

See [docs/hardware-setup.md](docs/hardware-setup.md) for the full step-by-step walkthrough.

### Directory Overview

Post-install layout (annotated):

```
~/
├── bin/                              # Helper scripts (symlinked into ~/bin by install)
│   ├── claude-fixed-reasoning        # Launch claude with fixed thinking budget (no adaptive)
│   ├── codereview-skip               # Create one-time bypass marker for pre-push gate
│   ├── review-external.sh            # External multi-model reviewer (stdin diff, stdout findings)
│   └── zatmux                        # Attach/create tmux session based on current dir
│
├── data/                             # Shared large datasets and model files (not in git)
│
├── src/
│   └── zat.env/                      # This repo: cross-project config and tooling
│       ├── README.md                 # This file
│       ├── CLAUDE.md                 # How to work on the zat.env repo itself
│       ├── .gitignore
│       ├── hw-bootstrap.sh           # Bare machine -> usable dev box
│       ├── zat.env-install.sh        # Wire this repo's config into the live system
│       ├── claude/
│       │   ├── global-claude.md      # Machine-wide Claude conventions (symlinked below)
│       │   ├── references/           # Detailed reference docs (read on demand, not always-on)
│       │   │   ├── networking.md     # Tailscale, DNS, bind addresses, firewall
│       │   │   └── ml-gpu.md         # VRAM, TDP, Docker GPU, CUDA
│       │   └── skills/               # Global Claude Code skills (symlinked below)
│       │       ├── spec/             # /spec: specification and acceptance criteria
│       │       │   └── SKILL.md
│       │       ├── codereview/       # /codereview: adversarial code review
│       │       │   └── SKILL.md
│       │       ├── codefix/          # /codefix: fix review findings (invoked by codereview)
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
│       ├── docs/
│       │   └── hardware-setup.md     # Full hardware provisioning walkthrough
│       ├── hooks/
│       │   ├── README.md             # Hook documentation
│       │   ├── allow-venv-source.sh  # Auto-approves venv activation past safety prompt
│       │   ├── post-tool-exit-plan-mode.sh  # Reminds user to use /spec plan after exiting plan mode
│       │   └── pre-push-codereview.sh  # Blocks git push without prior codereview
│       ├── tests/
│       │   ├── README.md               # Test documentation: lint checks and manual scenario traces
│       │   ├── run-all.sh              # Run all test suites with combined summary
│       │   ├── lint-skills.sh          # Structural lint for skills and hooks (230 checks)
│       │   ├── test-pre-push-hook.sh   # Pre-push hook behavioral tests (39 checks)
│       │   └── test-review-external.sh # Guard logic and output contract tests (35 checks)
│
├── .bashrc                           # Updated: PATH, CUDA_HOME, PIP_REQUIRE_VIRTUALENV
├── .tmux.conf                        # Mouse, scrollback, window numbering
├── .gitconfig                        # Updated by install: user, includes, excludesfile
│
├── .claude/
│   ├── CLAUDE.md -> ~/src/zat.env/claude/global-claude.md   # Symlink: machine-wide conventions
│   ├── settings.json                 # Global Claude Code permissions + hooks
│   └── skills/                       # Symlinks to skill directories in this repo
│       ├── spec       -> ~/src/zat.env/claude/skills/spec/
│       ├── codereview -> ~/src/zat.env/claude/skills/codereview/
│       ├── codefix    -> ~/src/zat.env/claude/skills/codefix/
│       ├── security   -> ~/src/zat.env/claude/skills/security/
│       ├── architect  -> ~/src/zat.env/claude/skills/architect/
│       ├── tester     -> ~/src/zat.env/claude/skills/tester/
│       └── pr         -> ~/src/zat.env/claude/skills/pr/

└── .cache/
    ├── huggingface/                  # Shared HF model cache (never override HF_HOME per-project)
    └── pip/                          # Shared pip cache (don't purge casually; torch is 2GB+)
```

**Per-project review files** (written by skills into the project root, not this repo):
```
~/src/<project>/
├── SPEC.md          # Written by /spec: acceptance criteria for current unit of work
├── BACKLOG.md       # Written by /spec (optional): deferred proposals register
├── CODEREVIEW.md    # Written by /codereview: dated review history with metadata
├── SECURITY.md      # Written by /security: security findings and accepted risks
└── TESTING.md       # Written by /tester: test strategy assessment
```

---

## References

Papers and posts that inform the design of this setup, particularly around long-running autonomous coding loops.

- [Building a C Compiler with a Team of Parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler) (Carlini, Anthropic, Feb 2026). 16 parallel Claude agents build a 100K-line C compiler passing 99% of GCC's torture tests, demonstrating that verification quality (test suites, not prompts) is the ceiling on autonomous output quality.

- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (Anthropic, Nov 2025). Techniques for enabling agents to work across multiple context windows: initializer agents, incremental progress patterns, and artifact-based memory. The direct inspiration for the skill/hook/artifact architecture in this repo.

- [Harness Design for Long-Running Application Development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Anthropic, Mar 2026). Multi-agent architecture (Planner/Generator/Evaluator) for extended autonomous sessions, with the evaluator loop modeled on adversarial training. Supports the design of `/codereview` and `/security` as adversarial gates.

- [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents) (Anthropic, Dec 2024). Foundational taxonomy of agent design patterns (prompt chaining, routing, orchestrator-workers, evaluator-optimizer). Argues for simplicity: start with the least complex pattern that works, add structure only when needed.

- [The Bitter Lesson of Agentic Coding](https://agent-hypervisor.ai/posts/bitter-lesson-of-agentic-coding/) (Zatloukal, Apr 2026). The design philosophy behind zat.env: invest in verification and goal-setting, not implementation control. Applies Sutton's bitter lesson to harness design, with the Carlini and Rajasekaran papers as the technical foundation.

- [Curse of Instructions](https://openreview.net/forum?id=R6q67CDBCH) (ICLR 2026). LLM ability to follow all N instructions simultaneously degrades as p^N. The reason global-claude.md is kept short and skills load on demand rather than sitting in the always-on context.

- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) (Anthropic). Official guidance on CLAUDE.md structure, what to include (build commands, project-specific conventions), and what to omit (things Claude already knows).

---

## Roadmap

### Next up

- `/verify` skill: execute the project's test suite as ground truth signal
- Worktree-based A/B testing, quantitative trending, branch workflow aliases
- Loop orchestrator and circuit breakers for autonomous review/fix cycles

### Future

- Autonomous review/fix/review loops with convergence detection and circuit breakers
- Worktree-based A/B testing: verify changes in isolation before merging
- Carlini-style parallel agents: each on its own branch, PRs as coordination boundaries, CI as the independent verification signal
- Fleet coordination: humans set goals and review outcomes, agents handle everything in between. More on this at [agent-hypervisors](https://agent-hypervisor.ai/posts/agent-hypervisors/).

### Done (v1.3)

- [x] Builder/verifier separation: `/codefix` skill runs in a separate forked context; `/codereview` no longer fixes its own findings
- [x] External multi-model reviewers: `review-external.sh` pipes diff to OpenAI/Google/local GPU, called synchronously by `/codereview`, fail-open
- [x] Structural lint suite (215 checks across 21 categories) covering builder/verifier separation, marker contracts, agent boundary risks, concurrency safety, and cross-skill field identity
- [x] `/spec` direct mode fix: write SPEC.md immediately instead of asking for confirmation in a forked context that cannot do multi-turn
- [x] Install script prunes stale hook entries from settings.json on re-run
- [x] Prompt/infrastructure boundary documented (CLAUDE.md for developers, README for users)
- [x] Test runner (`tests/run-all.sh`) with combined summary across all suites
- [x] Plan-mode handoff: `/spec plan [<slug>]` adopts a saved plan as the spec brief, pressure-tests outcomes into verifiable criteria, and writes SPEC.md. PostToolUse hook on `ExitPlanMode` prints a reminder about `/spec plan` so the handoff is visible. `/spec` with an under-specified brief now suggests exploring in plan mode first. Supersedes the earlier advisory plan read in Step 1.

### Done (v1.2)

- [x] Turn-based development loop: `/spec` evolve mode now runs a turn-boundary transition when all criteria are met (retrospective question, proposal generation, "run `/spec` to start the next turn")
- [x] Propose mode (`/spec propose`): generate a next-turn proposal grounded in git history and current spec state, independent of conversation memory
- [x] Stale proposal guard: when a proposal exists with 5+ commits since its date, flag it for confirmation before consuming
- [x] Proposal-as-input-brief: `/spec` with no arguments auto-detects a proposal section and enters direct mode using it as the input brief
- [x] "Context loss at turn boundaries" anti-pattern documented with mitigation
- [x] Advisory plan file reading: `/spec` checks `~/.claude/plans/` for recent planning context
- [x] `/spec` documented as replacement for Claude Code's built-in plan mode
- [x] Development loop cadence dimension added to `/tester` skill
- [x] Shared system boundary and upstream fix pattern documented in global conventions
- [x] Memory section added to global conventions with promotion guidance
- [x] Global permissions allowlist/denylist managed by install script
- [x] Pre-push hook: bypass marker consumed on use; "push now" bypass for trivial changes
- [x] Hero image updated (iPhone with tmux via ShellFish)
- [x] Pre-push hook skips codereview gate for tag-only pushes
- [x] Coding practice: do not push or modify remote state without explicit user instruction

### Done (v1.1)

- [x] Reduce global-claude.md instruction density: trim redundant directives, shorten to what the model actually needs
- [x] Extract reference files: networking and ML/GPU details moved to `claude/references/` (read on demand, not always loaded)
- [x] Skill frontmatter: add `argument-hint` and `effort:high` across skills for better Claude Code integration
- [x] Hook `if`-field filtering: install script now writes conditional hooks (push-only filtering) instead of relying on in-script guards
- [x] README trajectory summary: added design philosophy paragraph explaining where zat.env is headed
- [x] Documentation consistency: firewall status, coding practices, and directory overview kept in sync across all files

### Done (v1.0)

- [x] Machine provisioning script (`hw-bootstrap.sh`)
- [x] Install script wiring (`zat.env-install.sh`): git config, CLAUDE.md symlink, skills, hooks
- [x] Global git conventions (aliases, ignore-global)
- [x] Machine-wide Claude conventions (`claude/global-claude.md`)
- [x] Adversarial code review (`/codereview`) with pre-push hook gate
- [x] Security review (`/security`) with persistent `SECURITY.md`
- [x] Architecture review (`/architect`)
- [x] Test strategy review (`/tester`) with persistent `TESTING.md`
- [x] Content-addressed push gate (diff hash + project hash)
- [x] Auto-fix with escalating conservatism and 3-iteration cap
- [x] Spec-driven development (`/spec`) with persistent `SPEC.md` and cross-skill integration
- [x] Cross-skill context graph with bounded amplification prevention
- [x] Prompt design: precision bias, evidence grounding, confidence thresholds, halt conditions
- [x] GitHub PR workflow (`/pr`): create, inspect, and merge PRs with auto-composed descriptions from review metadata

---

Copyright 2026 Peter Zatloukal. Licensed under the [Apache License, Version 2.0](LICENSE).
