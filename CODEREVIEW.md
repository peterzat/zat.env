## Review -- 2026-04-10 (commit: 95188f9)

**Summary:** Full review of 1 unpushed commit (95188f9) adding `/spec plan` adoption mode and a PostToolUse `ExitPlanMode` handoff hook. Touches 6 files: README.md (handoff docs), claude/skills/spec/SKILL.md (new Step 3e, new Step 2 router branch, under-spec escape hatch, removed legacy advisory plan read), hooks/post-tool-exit-plan-mode.sh (new), hooks/README.md (docs), tests/lint-skills.sh (14 new structural checks), zat.env-install.sh (registers hook under PostToolUse with ExitPlanMode matcher). 250/250 tests pass. Security scan clean (0/0/0 over 3 changed files). Hook smoke-tested with valid, invalid, empty, and non-JSON stdin: always exits 0, only emits reminder on ExitPlanMode. Shellcheck clean. 14 new lint-skills.sh contract checks all pass.

**External reviewers:**
[qwen] Qwen/Qwen2.5-Coder-14B-Instruct-AWQ -- 5572 in / 5 out -- 27s
[qwen] No issues found.

### Findings

[NOTE] claude/skills/spec/SKILL.md:80 -- `plan` keyword router can swallow direct-spec descriptions
  Evidence: Step 2 router says `plan` or `plan <slug>` always wins. A user who types `/spec plan for authentication` meaning "spec out a plan for authentication" will route to Step 3e, which treats "for authentication" as a slug, fails to find `~/.claude/plans/for authentication.md`, and stops with an error. The router comment explicitly warns that keywords win, so this is a documented design choice, but the footgun is real for users who don't read the argument-hint.
  Suggested fix: None required. If this becomes a live pain point, consider teaching Step 3e to fall through to Step 3b when the slug contains whitespace or when the plan file does not exist AND the remaining arguments look like a prose description. For now, the error message is clear enough that users will self-correct.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-04-09, commit b309b86): Light review of SPEC.md proposal and review-file metadata updates. 0 BLOCK, 0 WARN, 0 NOTE.*

<!-- REVIEW_META: {"date":"2026-04-10","commit":"95188f9","reviewed_up_to":"95188f90ed357550efe1a72e2ae113bca3a2e48a","base":"origin/main","tier":"full","block":0,"warn":0,"note":1} -->
