# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.

### deterministic-marker-write
- **One-line description:** Convert codereview's Step 8 marker write (and the related UPSTREAM derivations in Step 2 refresh detection and Step 5.5 external reviewers) from LLM-interpreted bash snippets to a deterministic `bin/` script that codereview invokes for marker write and the pre-push hook invokes for hash recomputation (one dual-mode script, or a write/verify pair — implementation choice). Eliminates the LLM-split-Bash-call failure mode where `${UPSTREAM}` is lost between separate Bash tool calls and the marker silently falls through to the empty-tree hash (observed in PanelForge: codereview wrote empty-tree hash, hook computed real-diff hash, push blocked silently). Codereview and the hook share byte-for-byte identical UPSTREAM= derivations on paper, so the divergence is purely a shell-state-loss artifact across separate Bash tool invocations.
- **Why deferred:** Out of scope for the current /tester design hardening from PanelForge feedback turn (SPEC 2026-05-01) which is locked to skill-prompt edits in `claude/skills/tester/SKILL.md`. This direction is a separate workstream (touches `bin/`, `claude/skills/codereview/SKILL.md`, `hooks/pre-push-codereview.sh`, plus lint coverage) and warrants its own spec. First identified as the "highest-value next improvement" in the 2026-04-09 spec's proposal section before being deferred in favor of /tester design.
- **Revisit criteria:** The codereview→push hash mismatch is observed again on any project, OR the /tester design hardening turn lands and clears the SPEC.md slot, OR the codereview SKILL.md is materially edited for any reason (the touch is an opportunity to bundle the script extraction).
- **Origin:** spec 2026-05-01
