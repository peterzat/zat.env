## Spec — 2026-04-08 — External multi-model code review

**Goal:** Add optional independent reviewers (OpenAI, Google) that review the same diff alongside Claude's /codereview, as a thin synchronous extension with fail-open semantics.

### Acceptance Criteria

- [x] A single script `bin/review-external.sh` exists that reads a unified diff from stdin and writes findings to stdout. No other new scripts or hooks are added.
- [x] Each finding line in stdout is prefixed with the provider name (e.g., `[openai]`, `[google]`) so the codereview skill can attribute them.
- [x] Cost information (token counts, estimated cost) is written to stderr, not stdout, so callers can log it without parsing findings.
- [x] The script reads API keys and configuration from `~/.config/claude-reviewers/.env`. If no keys are configured (file missing or all keys empty), the script exits 0 with no stdout output.
- [x] If a provider API call fails (network error, auth error, timeout), that provider is skipped and review continues. The script never exits non-zero due to a provider failure.
- [x] The script enforces a per-provider timeout (configurable, with a sensible default) so a hung API call does not block the review indefinitely.
- [x] The codereview skill calls the script synchronously (once, at initial review) and appends any stdout findings to its report. The call does not appear in fix/re-review cycles (Step 7).
- [x] `zat.env-install.sh` symlinks the script into ~/bin/ (already handled by the existing bin/* loop). No new hooks are registered.
- [x] When no external reviewers are configured or the script produces no output, codereview proceeds identically to today with no visible change in behavior or output format.

### Context

Replaces the previous external reviewer implementation (commits 8c80c58..d558b53) which used pre/post hooks, /tmp coordination files, a separate orchestrator script, and async post-merge into CODEREVIEW.md. That approach required a same-day repair commit and was identified as overcomplicated relative to the repo's simplicity standard. This redesign preserves the same feature (multi-model review) with a synchronous stdin/stdout interface and no hook machinery.

Prior art: `~/.config/claude-reviewers/.env` config file format from the previous implementation.

---
*Prior spec (2026-04-08): External multi-model code review. 9/9 criteria met.*

### Proposal (2026-04-09)

**What happened:** The external multi-model reviewer was rebuilt from scratch as a single synchronous script (`bin/review-external.sh`), replacing the overcomplicated hook-based approach from the prior attempt. The script reads a diff from stdin, calls OpenAI and Google APIs in parallel, and writes attributed findings to stdout with cost info to stderr. The codereview skill calls it once at initial review (Step 5.5). Alongside this, the v1.3 milestone was completed: builder/verifier separation with `/codefix`, the structural lint suite expanded to 222 checks across 21 categories, the test runner was added, and prompt/infrastructure boundary contracts were documented. The repo now has a comprehensive test and lint foundation.

In parallel, documentation was significantly improved: README rewritten for completeness and flow, CLAUDE.md audience split formalized, coding practices kept in sync, and the directory overview was updated. The review pipeline sequencing (serial Claude then parallel external) was documented as intentional design.

**Questions and directions:**

1. **Deterministic marker write.** TODO.md identifies the highest-value next improvement: moving the push marker write from an LLM-interpreted bash snippet to a `bin/write-review-marker.sh` script. This would eliminate the riskiest prompt/infrastructure boundary (LLM deviation from the snippet breaks the push gate) and let us remove 5+ structural lint checks that currently compare bash snippets between skill and hook. The `codereview-skip` script already demonstrates this pattern.

2. **Pre-push hook dry-run testing.** Also in TODO.md: adding a `--verify` flag to the pre-push hook would enable integration testing of marker matching, hash computation, and skip marker consumption without actually pushing. This would replace several grep-based structural checks with behavioral verification.

3. **Downstream validation.** The full pipeline (install, codereview, codefix, external reviewers, push gate) has been tested within zat.env itself but not yet on a downstream project. Running `/codereview` on a real project would verify the wiring works end-to-end.

4. **v2 direction: /verify or loop orchestrator.** The roadmap lists `/verify` (test suite execution as ground truth) and loop orchestration as next milestones. The marker script (item 1) is a prerequisite for reliable autonomous loops since a flaky push gate would break the loop.

<!-- SPEC_META: {"date":"2026-04-08","title":"External multi-model code review","criteria_total":9,"criteria_met":9} -->
