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
- **One-line description:** `claude/skills/codereview/SKILL.md` (~740 lines), `spec/SKILL.md` (~710), and `tester/SKILL.md` (~610) exceed CLAUDE.md's ~500-line guideline. First candidate: move spec's `## BACKLOG.md Format` section and manifest reference (end of the file) into `claude/skills/spec/references/`, moving the lint pins that grep it at the same time.
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

### push-gate-net-diff-secret
- **One-line description:** The push gate and `/codereview` see only the net diff against the base, so a secret committed and then deleted inside the pushed range is pushed in history but never reviewed. Have `/security` (or a deterministic check) scan the per-commit diffs of the pushed range for secret patterns.
- **Why deferred:** It needs a commit and a later deleting commit in the same unpushed range, and `/security` full audits already check git history for credential-handling files. Reported by a /security run during the 2026-10-02 /security-review measurement.
- **Revisit criteria:** A secret is found in pushed history that a review passed over, OR the gate starts reviewing per-commit diffs for another reason.
- **Origin:** ad-hoc (security-review measurement 2026-10-02)

### marker-dir-ownership-check
- **One-line description:** `bin/codereview-marker` `marker_dir` ignores `mkdir`/`chmod` failure and checks neither the directory's owner nor whether it is a symlink. Verify it is a real directory owned by the current user with mode 0700, and fail otherwise.
- **Why deferred:** The directory is under `${XDG_CACHE_HOME:-${HOME}/.cache}`, which other users cannot write with default permissions, so it is not exploitable on this host. Reported by a /security run during the 2026-10-02 /security-review measurement.
- **Revisit criteria:** The marker directory moves somewhere shared, OR a multi-user host with a writable cache path adopts zat.env, OR `codereview-marker` is reworked anyway.
- **Origin:** ad-hoc (security-review measurement 2026-10-02)

### push-gate-wrapped-push-detection
- **One-line description:** The pre-push gate misses a push wrapped in an interpreter or quotes, such as `bash -c "git push"`, `sh -lc 'git push'`, or `eval "git push"`. The hook's tokenizer splits inside quotes and reads `"git` and `push"`. Catching these means stripping quotes during normalization and treating interpreters as command prefixes, with regression cases for the wrapped forms and for the false positives quote stripping could invent.
- **Why deferred:** With Bash as the only shell tool the model has no reason to wrap a push. Kept out of the Windows-support change on 2026-10-13, and out of the 2026-11-03 gate fixes, because false positives now cost more: the push-first rule refuses a command outright, so a commit message that reads as a push could not be retried without moving it to a file.
- **Revisit criteria:** A wrapped push is seen skipping review, OR the PowerShell tool is enabled under zat.env, where `bash -lc "git push"` is the natural form.
- **Origin:** ad-hoc (Windows support 2026-10-13)


### push-gate-quoted-text-false-positive
- **One-line description:** The pre-push gate's tokenizer treats operator characters inside quotes as real, so text that only mentions a push reads as a real one when an operator character comes before it: a commit message or heredoc line, or a quoted grep alternation. Since the push-first rule these are refused outright rather than sent to review. `_quote_scan` reads quotes as the shell does, but not heredoc bodies, so skipping quoted text with it needs heredoc handling first. It would also lose the accidental detection of `bash -c "a; git push x"`.
- **Why deferred:** Found after the 2026-11-03 gate fixes passed their tests. It occurred four times that day, all in the session that made the fixes (a read-only grep and three review probes), and the refusal says how to recover. A tokenizer that understands heredocs deserves its own change and review.
- **Revisit criteria:** The refusal shows up on commands that are not pushes more than occasionally, outside sessions that work on the gate itself, OR a command that cannot reasonably move its text to a file is blocked, OR push-gate-wrapped-push-detection is picked up, since both change quote handling.
- **Origin:** ad-hoc (push gate fixes 2026-11-03)

### pr-merge-reviewed-changes-hash
- **One-line description:** `/pr merge` (`claude/skills/pr/SKILL.md`, review gate conditions 3 and 4) cannot tell a reviewed commit from one that reached the branch after the review, pulled from the PR or pushed with `codereview-skip`: condition 3 accepts any ancestor of HEAD and condition 4 compares only the remote and local heads. Candidate fix: `/codereview` records a hash of the reviewed changes in REVIEW_META and `/pr merge` requires `git diff <reviewed_up_to> HEAD` (review files excluded) to match it. The read the skill names for pulled changes should also take its range from commit heads (`git log -p --text ORIG_HEAD..HEAD` after a pull) rather than the pulled CODEREVIEW.md.
- **Why deferred:** It adds a REVIEW_META field and a new `/codereview`-to-`/pr` contract, and the hash has to survive the normal flow where `/codefix`'s fixes are committed after the review. No project merges PRs through `/pr` regularly yet, and the skill and README now state the gap.
- **Revisit criteria:** A project starts merging PRs through `/pr merge` with collaborators or bots committing to PR branches, OR the multi-dev PR-side review increment on the README roadmap starts.
- **Origin:** CODEREVIEW.md (2026-11-07 WARN on claude/skills/pr/SKILL.md)

### review-files-set-review-depth
- **One-line description:** `/codereview` reads its prior REVIEW_META and SECURITY_META from the working tree (`claude/skills/codereview/SKILL.md` Step 1 prior-findings read, Step 2 refresh detection, Step 5 security reuse, Step 6 Accepted Risks downgrade), and the review diff excludes CODEREVIEW.md and SECURITY.md, so a commit that edits those files decides how deeply the commits under review are read: it can anchor a refresh, mark findings accepted, or skip a security scan. Candidate fix: take the full tier, and read prior META and Accepted Risks from `git show "$(codereview-marker base):<file>"`, whenever a commit in the reviewed range touches a review file.
- **Why deferred:** It needs a hostile committer in the reviewed range; in single-operator use the review files change only through the skills. Reading META from the base changes refresh detection and the Accepted Risks flow together, which deserves its own turn and tests.
- **Revisit criteria:** A second contributor or a bot commits to branches this harness reviews, OR the merge-safe review artifacts increment on the README roadmap starts (it moves these files anyway).
- **Origin:** CODEREVIEW.md (2026-10-02 security WARN, carried through 2026-11-07)
