## Review -- 2026-04-21 (commit: 538ce88)

**Review scope:** Refresh review. Focus: 1 file changed since prior review (commit 2cd4666) -- `zat.env-install.sh` (uncommitted). The previously-reviewed `claude/global-claude.md` change was committed as 538ce88; that file's content matches what was reviewed at 2cd4666. 0 already-reviewed files needed interaction-only checks.

**Summary:** New five-line "Customize for your machine" banner appended to `zat.env-install.sh` between the existing `==> Done` and `Verify:` blocks. Pure echo output pointing fresh installers at `claude/references/ml-gpu.md` and `claude/references/networking.md`; both files exist and already self-document as "machine-specific values, update for your hardware/machine." Banner pairs naturally with prior commit 538ce88 which dropped machine-specific values from the always-loaded `global-claude.md`. No variable interpolation, no command substitution, no logic, no functional change to install path. Idempotent. All 334 structural-lint and behavioral tests still pass. `/security` invoked on the two non-md files changed since the last security scan (`bin/spec-backlog-apply.sh` and `zat.env-install.sh`): 0 findings. External reviewers configured but no providers uncommented: ran silently, no output.

**External reviewers:**
None configured (PATH binary present, but no providers uncommented in `~/.config/claude-reviewers/.env`).

### Findings

No issues found.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-21): Light review of `claude/global-claude.md` editorial cleanup (drop machine-specific values from always-loaded summary, collapse duplicate Shared System Boundary forward-pointer). 0 findings.*

<!-- REVIEW_META: {"date":"2026-04-21","commit":"538ce88","reviewed_up_to":"538ce88c3273f83c3834cf65d82063bbe8234c0b","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
