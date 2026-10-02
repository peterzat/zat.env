# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.

### tester-design-testing-meta
- **One-line description:** `/tester design` writes the durable contract section to TESTING.md but does not produce a TESTING_META footer; only audit mode does. Cross-skill consumers of TESTING.md metadata (e.g., `/pr` reading review metadata for PR descriptions) cannot tell from metadata alone that a design contract exists in the file. Adding a design-mode TESTING_META (with fields like `contract_shape`, `line_count`, `rollout_count`, `contract_date` rather than the audit's block/warn/note counters) would close this gap.
- **Why deferred:** Out of scope for the current /tester design D.4/D.5.5/D.6 ordering fix turn (SPEC 2026-05-01). No current consumer breaks today (`/pr` and others handle absent TESTING.md and absent metadata gracefully); the contract is human-readable in TESTING.md.
- **Revisit criteria:** A skill or workflow needs to programmatically detect "this project has a design contract" without reading TESTING.md content, OR `/pr`'s PR-description generation grows logic that would benefit from contract metadata, OR a downstream user reports the gap.
- **Origin:** spec 2026-05-01


### retest-incident-prompt-guards
- **One-line description:** Re-test three guards written after incidents on earlier models and remove what no longer reproduces on the current one: the `/tester design` Step D.5.5 hard-gate anchors (`Do not invoke Edit, Write, or Bash` and the text-message framing, lint-pinned), the incident list in `/codereview` Step 2's "Do not improvise a narrower review" ("clone provenance", "faithful port of working code"), and `/spec` Step 1's "Plan files in `~/.claude/plans/` are NOT read here" (residue of the removed advisory plan read).
- **Why deferred:** The 2026-10-01 prompt audit rated all three low confidence. Removing a guard needs a behavioral probe, not a reading: a scratch `/tester design` run that still emits the checklist as visible text before any tool call, and a first-push `/codereview` that still reviews the whole tree.
- **Revisit criteria:** A `/tester design` or first-push `/codereview` run on the current model is available to serve as the probe, OR the next model generation ships and the prompt audit is re-run.
- **Origin:** ad-hoc (prompt audit 2026-10-01)

### architect-tester-recall-stance
- **One-line description:** `/architect` and `/tester` still open with "Precision over recall", while `/codereview` and `/security` moved to "report what you find, with your confidence" on 2026-10-01 after the escaped-bug comparison showed precision-biased prompts under-report. Decide whether the two strategy skills should follow.
- **Why deferred:** Their reports go straight to a human with no classification pass, and both carry proportionality reasons ("do not manufacture concerns"), so the review-prompt measurement does not transfer directly. The audit treated the split as task-scoped, not a conflict.
- **Revisit criteria:** An `/architect` or `/tester` report misses a gap that a later review or incident surfaces, OR either skill's output is seen hedging away a finding it had evidence for.
- **Origin:** ad-hoc (prompt audit 2026-10-01)

### skill-size-references-split
- **One-line description:** `claude/skills/codereview/SKILL.md` (~680 lines), `spec/SKILL.md` (~660), and `tester/SKILL.md` (~580) exceed CLAUDE.md's ~500-line guideline. First candidate: move spec's `## BACKLOG.md Format` section and manifest reference (end of the file) into `claude/skills/spec/references/`, moving the lint pins that grep it at the same time.
- **Why deferred:** The length is not causing errors, and the move touches lint contract pins (four-field template, manifest ops, canonical Origin forms). It is a refactor, not a fix.
- **Revisit criteria:** One of these skills grows further past the guideline, OR a session shows the model missing an instruction in the tail of one of them, OR the related lint pins are being reworked anyway.
- **Origin:** ad-hoc (prompt audit 2026-10-01)

### gemini-stable-model-default
- **One-line description:** `bin/review-external.sh` defaults Gemini to `gemini-3.1-pro-preview`. A preview model can be withdrawn on short notice, and a retired default shows up only as an API-error line in the cost log. Switch the default (and the price `case` in `call_google`, plus the install template) to the stable 3.x Pro ID.
- **Why deferred:** Google has not published a stable 3.x Pro model ID; the preview is its named replacement for gemini-2.5-pro.
- **Revisit criteria:** Google publishes a stable Gemini 3.x Pro model ID, OR the preview default starts returning errors in the `/codereview` cost log.
- **Origin:** CODEREVIEW.md (2026-10-01 NOTE on review-external.sh)

### skip-marker-bound-to-diff
- **One-line description:** `bin/codereview-skip` writes a skip marker that never expires and is not tied to a diff, and `hooks/pre-push-codereview.sh` honors it on the next push it gates. A tag-only push (the hook exits before its skip check) or a push from the user's own terminal (never seen by the hook) leaves the marker in place, so a later, unreviewed agent push goes through without notice. Store `codereview-marker hash` in the marker and honor it only when it matches the current diff, or add an age limit.
- **Why deferred:** It needs a stale marker plus a later agent push, which is rare in single-user use, and the gate is already advisory by Accepted Risk. The change touches the skip-path contract that lint pins in both scripts.
- **Revisit criteria:** A push is seen skipping review that nobody asked to skip, OR the gate is moved server-side or extended to other contributors, where an unscoped bypass matters more.
- **Origin:** CODEREVIEW.md (2026-10-01 security NOTE on bin/codereview-skip)

### builtin-review-tree-fingerprint
- **One-line description:** `/codereview` Step 5.6 discards the built-in review's findings if the tree changed while it ran, comparing `sha256sum` of `git status --porcelain` plus the unstaged `git diff` at launch and collect. That reading misses a re-edit of an already fully staged file (status stays `M `, unstaged diff stays empty), an edit to an untracked file (status stays `??`), and an edit committed during the run (clean at both readings). Add `git rev-parse HEAD`, `git diff HEAD` in place of `git diff`, and untracked file contents to both readings, and update the lint pin that matches the exact command.
- **Why deferred:** Surfaced as an OpenAI WARN during the 2026-10-01 external reviewer check, which was out of scope for a fix. The window is only the built-in's runtime, nothing in `/codereview` edits the tree before Step 5.6 collects, and the guard already catches ordinary edits to tracked files.
- **Revisit criteria:** A built-in review is accepted after the tree changed during its run, OR Step 5.6's launch and collect mechanics are reworked (for example by the skill-size-references-split move).
- **Origin:** ad-hoc (external reviewer check 2026-10-01)

### builtin-security-review-second-finder
- **One-line description:** Run Claude Code's built-in `/security-review` alongside `/security` as a second security finder, the way `/codereview` runs the built-in `/code-review`. Rejected on measurement.
- **Why deferred:** On 13 security defects that each escaped a zat.env review in zat.env, daydream, OrgSmith, PanelForge, and qwen-2.5-localreview (measured 2026-10-02, $97), `/security-review` caught 0 and the current `/security` caught 9 (2 partial); nothing was caught only by the built-in. The built-in surfaced 8 of the 13 and then dropped them under its fixed exclusions (hardening, secrets on disk, test files, log spoofing, trusted CLI and local input) or its 8/10 confidence cutoff, which are in its prompt and cannot be configured. It also reviews only `git diff origin/HEAD...`, takes no arguments, misses uncommitted changes, and fails outright in repos without `origin/HEAD` (10 of 12 local repos, including daydream and PanelForge).
- **Revisit criteria:** The built-in's prompt drops its exclusion list or confidence cutoff, OR it gains a diff target or file-list argument, OR a security defect escapes `/security` in a class the built-in is built for (server-side injection, authorization bypass, XSS), which this corpus did not contain.
- **Origin:** ad-hoc (security pipeline review 2026-10-02)
