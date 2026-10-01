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

### spec-interview-mode-in-fork
- **One-line description:** `/spec` interview mode (Step 3a, reached by `/spec new` or by `/spec` in a project with no SPEC.md) asks 3-5 questions and waits for answers, but the skill runs in a fork that ends when it asks. The answers land in the main thread, which has to re-invoke `/spec <answers>` (direct mode) on its own.
- **Why deferred:** Current practice adopts plan-mode plans with `/spec plan` or passes a pressure-tested brief to direct `/spec`, so interview mode is rarely used. The stale-proposal and existing-proposal confirmations, the same defect class, were fixed in 022d646.
- **Revisit criteria:** Interview mode gets used and the answer round-trip misroutes or drops the answers, OR a new user's first `/spec` in a fresh project lands in interview mode and stalls.
- **Origin:** ad-hoc (prompt audit 2026-10-01)

### gemini-stable-model-default
- **One-line description:** `bin/review-external.sh` defaults Gemini to `gemini-3.1-pro-preview`. A preview model can be withdrawn on short notice, and a retired default shows up only as an API-error line in the cost log. Switch the default (and the price `case` in `call_google`, plus the install template) to the stable 3.x Pro ID.
- **Why deferred:** Google has not published a stable 3.x Pro model ID; the preview is its named replacement for gemini-2.5-pro.
- **Revisit criteria:** Google publishes a stable Gemini 3.x Pro model ID, OR the preview default starts returning errors in the `/codereview` cost log.
- **Origin:** CODEREVIEW.md (2026-10-01 NOTE on review-external.sh)
