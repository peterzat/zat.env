## Review — 2026-10-01 (commit: 55694b7)

**Review scope:** Refresh review. Focus: 4 file(s) changed since prior review (commit 93127a9), the whole unpushed diff (one commit, 4fa79f5). 0 already-reviewed file(s).

**Summary:** Adds Claude Code's built-in `/code-review high` as a second, independent finder in /codereview (launched after Step 3, collected at Step 5.6, classified in Step 6), with README, CLAUDE.md, and lint. This review is the step's first live run. tests/run-all.sh 707/707 before the fix loop, 708/708 after (one new lint check). Three WARNs fixed in one /codefix cycle (55694b7). /security (paths: tests/lint-skills.sh) found 0 BLOCK / 0 WARN / 1 NOTE.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 10 findings, 10 kept after Step 6 (one folded into W2, one into W1); 121 s, finished about 10 minutes before /security.

### Findings

[WARN, fixed in 55694b7] claude/skills/codereview/SKILL.md:512 — Step 6's rule for classifying built-in findings omits three checks the inline review's own findings get: confirmation against the code, the Accepted Risks downgrade, and the refresh-review scope (also claude-code)
  Evidence: The built-in reviews the whole `@{upstream}...HEAD` range and, at `high`, does not verify its findings. Step 1 downgrades findings listed in Accepted Risks to NOTE, but only for the prior entry's findings; nothing applies that to a built-in finding that re-raises an accepted risk (for example the venv hook outside auto mode, or the interpreter grants), so it can be classified WARN and sent to /codefix, which would change behavior the user chose to keep. On a refresh review the inline review checks already-reviewed files only for interactions (dimension 5), but a built-in finding in such a file is classified as new. Confidence: medium.
  Suggested fix: Extend the Step 6 paragraph: confirm each built-in finding against the code before classifying it, and classify one you cannot confirm as NOTE; a finding that matches an Accepted Risks entry is a NOTE, as in Step 1; on a refresh review, a finding in an already-reviewed file is kept above NOTE only if it concerns an interaction with the new changes.

[WARN, fixed in 55694b7] claude/skills/codereview/SKILL.md:486 — The Step 5.6 read `jq -r '.result // empty'` ignores `.is_error`, so a failed `claude -p` run whose JSON carries an error message in `.result` is passed on as review output (claude-code)
  Evidence: With `--output-format json`, an API error, overload, or prompt-too-long failure produces `{"is_error": true, "result": "API Error: ..."}`; the read prints the message, the result is non-empty, and Step 5.6 treats it as findings rather than recording `Failed (skipped).`. Lint pins the launch (tests/lint-skills.sh:917) but not this read or the `rm -f` cleanup, so the pair can drift. Confidence: high on the mechanism.
  Suggested fix: Read with `jq -r 'select(.is_error | not) | .result // empty' <output-file>; rm -f <output-file>` and add a lint check pinning that read.

[WARN, fixed in 55694b7] README.md:313 — "Both, like the external reviewers, fail open and run once per review" has an ambiguous subject; read after the preceding sentences, "Both" includes /codereview's own review, which does not fail open and is re-run in fix cycles (claude-code)
  Evidence: The paragraph describes the inline review and the built-in review; only the built-in fails open and runs once. Confidence: high.
  Suggested fix: "Like the external reviewers, the built-in review fails open and runs once per review."

[NOTE] claude/skills/codereview/SKILL.md:480 — Whether a forked /codereview (`context: fork`) can wait on a background Bash task without polling is unverified; this run executed inline, where the completion notice arrived normally (claude-code)
  Evidence: The built-in argues a forked agent's only way to wait is to end its turn, which could end the review early. Step 7 already relies on forks receiving completion notices for background skill forks, and an early end leaves no marker, so the push is blocked rather than passed. Confidence: medium-low.
  Suggested fix: Watch the first user-typed /codereview; if it ends early at Step 5.6, collect the built-in in the foreground there instead.

[NOTE] claude/skills/codereview/SKILL.md:469 — Launching after Step 3 means the built-in never overlaps the test run, so a slow test suite can push its completion past Steps 4 and 5 (claude-code)
  Evidence: By design: launching after the tests avoids two test runs colliding on ports, databases, or temp files (user decision 2026-10-01). In this run it finished about 10 minutes before /security.
  Suggested fix: None now; revisit if Step 5.6 waits become common.

[NOTE] claude/skills/codereview/SKILL.md:472 — `2>/dev/null` discards the built-in's stderr, so a recurring failure (expired auth, a changed CLI flag) shows only as `Failed (skipped).` with no reason (claude-code)
  Suggested fix: Send stderr to a sibling mktemp file and record its first line on failure.

[NOTE] claude/skills/codereview/SKILL.md:472 — The built-in resolves its own scope; on a first push it reviews only the last commit while the gate covers the whole tree, and the Step 9 line does not say so (claude-code)
  Evidence: Coverage gap only; the inline review covers the full scope. README documents the scope difference.
  Suggested fix: Have the Step 9 "Built-in review" line note the range the built-in reported reviewing when it differs from the gate's base.

[NOTE] claude/skills/codereview/SKILL.md — The skill is now 672 lines against the CLAUDE.md guideline of about 500; this diff added 57 (claude-code)
  Suggested fix: Move Step 5.6's launch and collect mechanics, or other long sections, to claude/skills/codereview/references/.

[NOTE] tests/lint-skills.sh:146 — The light-review skip-list check uses an unescaped ERE (`skip Steps.*${step}`), so the check for Step 5 also matches "5.5" and dropping Step 5 from the list can still pass (claude-code)
  Evidence: Predates this diff; the new 5.6 entry is not affected.
  Suggested fix: Match each step as a whole list item, for example `[ ,]${step}[,) ]` with the dot escaped.

[NOTE] tests/lint-skills.sh:172 — (security) Two codefix role-separation guards always pass: line 172 hands `Skill(` to `grep -E`, which errors (exit 2) and `hasnt` counts as a pass; line 174 uses `\|`, a literal pipe in ERE. No check enforces that codefix lacks Write.
  Evidence: SECURITY.md 2026-10-01, mutation-tested. Predates this diff.
  Suggested fix: Make `hasnt` fail on grep exit 2 or higher; replace line 172 with `hasnt ... '^allowed-tools:.*(Skill|Write)'`; drop or narrow line 174.

[NOTE] tests/lint-skills.sh — (security) About 21 blocks increment the check count before calling `pass()`, which increments it again, so lint reports 456 checks where about 431 are distinct and the suite totals are inflated
  Evidence: SECURITY.md 2026-10-01. Predates this diff; the checks added here call pass/fail directly.
  Suggested fix: Remove the manual `TOTAL` increments in those blocks.

[NOTE] (security) The dev box runs service accounts besides peter (cloudflared-daydream, daydream-egress, daydream), and `/proc` does not hide one user's processes from another, so the Accepted Risks that assume a single-user host deserve a second look
  Evidence: SECURITY.md 2026-10-01. The API-key-in-cmdline exposure is inert while no external reviewer keys are configured.
  Suggested fix: Re-evaluate those acceptances.

[NOTE] (carried forward) hooks/allow-venv-source.sh:12 — (security) The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Evidence: SECURITY.md 2026-10-01: "Auto", " auto", null, and a missing field each got allow; test line 63 pins allow for a missing field (kept on purpose for pre-auto-mode behavior). The value forked skills receive was not verified, and the commit's live check cannot tell a hook allow from a classifier allow, though this session's transcript records the mode as `auto`. Confidence: high on mechanism, low that any current context sends something other than "auto".
  Suggested fix: Approve only for an explicit list of modes (default, acceptEdits, plan, dontAsk, bypassPermissions) and make no decision otherwise; update test line 63 and the lint pin at tests/lint-skills.sh:1225.

[NOTE] (carried forward) tests/README.md:11 — "Runs both suites" is stale (run-all.sh now runs 6), and the lint category table omits "Skill effort levels", "Uncommitted prior entry guard", and "Security guards" (tests/README.md:20)
  Evidence: tests/run-all.sh:50-55; `grep '^echo "==> ' tests/lint-skills.sh`. Confidence: high, low impact.
  Suggested fix: Say "Runs every suite" and add the missing table rows.

[NOTE] (carried forward) zat.env-install.sh:229 — The comment, and README.md:768, state as fact that narrow allow rules such as `Bash(git *)` resolve before the auto-mode classifier
  Evidence: The auto-mode docs give `Bash(npm test)` as the narrow example; whether `Bash(git *)` counts as narrow was not confirmed. The setting is correct either way. Confidence: medium.
  Suggested fix: Hedge ("can resolve before the classifier") or confirm.

[NOTE] (carried forward) claude/skills/security/SKILL.md:23 — (carried forward) "is not a finding" (no attack path) and the BLOCK definition's "not a BLOCK" (line 116) leave unclear whether a partly traced vulnerability is dropped or reported as NOTE
  Suggested fix: A finding whose path you could not trace completely is a NOTE; a concern with no path at all is not a finding.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:43 — (carried forward) "Finish the run" lists finish points as if exhaustive; Step 0, Step 2 (empty diff), and Steps E.1 to E.3 legitimately stop earlier
  Suggested fix: Add "or where a step says to stop".

[NOTE] (carried forward) CLAUDE.md:53 — (carried forward) The "Uncommitted prior entry guard" bullet says /codereview checks `git status --porcelain` in Step 9; since a4e8a4e the reading is taken in Step 1 and Step 9 uses it
  Suggested fix: Say /codereview takes the reading in Step 1, before Step 6.5 writes a preliminary entry.

[NOTE] (carried forward) hw-bootstrap.sh:48 (with claude/global-claude.md:96) — (carried forward, security) ImageMagick's stock coder policy handles a `.png`-named SVG with the SVG coder, and the convention has Claude run `convert` on images it inspects
  Suggested fix: Use `convert png:in.png ...` in the convention, and/or install a raster-only coder allowlist.

[NOTE] (carried forward) bin/review-external.sh:306 — (carried forward, security) Provider-reported token counts reach `bc` unvalidated (also :400-410); a hostile provider response could hang the review
  Suggested fix: Validate the counts as digits before arithmetic.

[NOTE] (carried forward) bin/review-external.sh:522 — (carried forward, security) A status line carrying any `(provider)` tag still passes as that provider's finding; free text after a valid tag is unconstrained
  Suggested fix: Write each provider's stderr to its own file and tag at the demux.

[NOTE] (carried forward) bin/review-external.sh:292 — (carried forward) OpenAI `.error.message` is forwarded verbatim; on an auth failure a public key prefix plus four characters can reach CODEREVIEW.md. Inert while no provider is configured.
  Suggested fix: Redact key-shaped strings from provider error text.

[NOTE] (carried forward) zat.env-install.sh:114 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod at :155; it holds only commented template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:184 — (carried forward) Deny entries accumulate across installs; removing one requires editing settings.json. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward) hw-bootstrap.sh:197 — (carried forward, security) Docker group membership lets anything running as the user, including the agent, obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

- [WARN] claude/skills/codereview/SKILL.md:512 — Step 6 now confirms each built-in finding against the code (unconfirmed is NOTE), applies the Accepted Risks downgrade, and on a refresh review keeps a finding in an already-reviewed file above NOTE only if it concerns an interaction with the new changes. (also claude-code)
- [WARN] claude/skills/codereview/SKILL.md:486 — The Step 5.6 read is `jq -r 'select(.is_error | not) | .result // empty'`, so a failed run is recorded as `Failed (skipped).`; lint pins the read and cleanup line. (claude-code)
- [WARN] README.md:313 — "Like the external reviewers, the built-in review fails open and runs once per review." (claude-code)

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit 93127a9): Refresh review of the venv-hook change (no decision in auto mode) and its 13-check suite; 0 BLOCK / 0 WARN / 13 NOTE; chained activation outside auto mode recorded as an Accepted Risk per the user's decision.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"55694b7","reviewed_up_to":"55694b7f9909bfa82dbaa72d4260896bbe2b2219","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":22} -->
