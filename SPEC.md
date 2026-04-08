## Spec — 2026-04-08 — External multi-model code review

**Goal:** Add optional independent reviewers (OpenAI, Google) that review the same diff alongside Claude's /codereview, as a thin synchronous extension with fail-open semantics.

### Acceptance Criteria

- [ ] A single script `bin/review-external.sh` exists that reads a unified diff from stdin and writes findings to stdout. No other new scripts or hooks are added.
- [ ] Each finding line in stdout is prefixed with the provider name (e.g., `[openai]`, `[google]`) so the codereview skill can attribute them.
- [ ] Cost information (token counts, estimated cost) is written to stderr, not stdout, so callers can log it without parsing findings.
- [ ] The script reads API keys and configuration from `~/.config/claude-reviewers/.env`. If no keys are configured (file missing or all keys empty), the script exits 0 with no stdout output.
- [ ] If a provider API call fails (network error, auth error, timeout), that provider is skipped and review continues. The script never exits non-zero due to a provider failure.
- [ ] The script enforces a per-provider timeout (configurable, with a sensible default) so a hung API call does not block the review indefinitely.
- [ ] The codereview skill calls the script synchronously (once, at initial review) and appends any stdout findings to its report. The call does not appear in fix/re-review cycles (Step 7).
- [ ] `zat.env-install.sh` symlinks the script into ~/bin/ (already handled by the existing bin/* loop). No new hooks are registered.
- [ ] When no external reviewers are configured or the script produces no output, codereview proceeds identically to today with no visible change in behavior or output format.

### Context

Replaces the previous external reviewer implementation (commits 8c80c58..d558b53) which used pre/post hooks, /tmp coordination files, a separate orchestrator script, and async post-merge into CODEREVIEW.md. That approach required a same-day repair commit and was identified as overcomplicated relative to the repo's simplicity standard. This redesign preserves the same feature (multi-model review) with a synchronous stdin/stdout interface and no hook machinery.

Prior art: `~/.config/claude-reviewers/.env` config file format from the previous implementation.

<!-- SPEC_META: {"date":"2026-04-08","title":"External multi-model code review","criteria_total":9,"criteria_met":0} -->
