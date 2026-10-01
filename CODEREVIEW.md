## Review — 2026-10-01 (commit: 5695fb9)

**Review scope:** Refresh review. Focus: 10 file(s) changed since prior review (commit 20a4c6c): the prompt-audit fixes (dd22b6d), /spec proposal handling without a mid-run confirmation (022d646), five BACKLOG.md entries (3e6f9f4), and the v1.5 documentation fold-in (f541aa2). 0 already-reviewed file(s). One fix cycle (5695fb9), re-reviewed.

**Summary:** Prompt-audit edits to the codereview, security, spec, and tester skills with matching lint and README changes; /spec now consumes a stale proposal and regenerates an existing one without asking; README's Done (v1.5) covers the audit and the post-tag work. tests/run-all.sh 700/700 before and after the fix cycle. /security (paths: bin/codereview-skip, tests/lint-skills.sh, tests/test-review-external.sh) found 0 BLOCK / 0 WARN / 3 NOTE and confirmed the prior WARN on predictable /tmp test paths fixed.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 8 findings, 7 kept after Step 6 (the em-dash finding dropped as a writing convention).

### Findings

[WARN, fixed in 5695fb9] README.md:769 — The audit narrative miscounts the human review: it says one flagged item was made into a fix and five were deferred, but two flagged items were fixed (the /spec confirmations and the bin/codereview-skip usage comment), and BACKLOG.md got four audit-derived entries plus one (the Gemini default) from a code-review NOTE. Line 770 also says the removed history "stays in CLAUDE.md", which holds for /codereview's but not for /spec's removed plan-read history
  Evidence: dd22b6d changed bin/codereview-skip:12 (audit flag L7); 3e6f9f4's gemini-stable-model-default entry has Origin "CODEREVIEW.md (2026-10-01 NOTE on review-external.sh)". CLAUDE.md does not mention the advisory plan read. This text is the source for the v1.5 release notes. Confidence: high.
  Suggested fix: Line 769: "he accepted all ten proposed edits, turned two flagged items into fixes, and deferred the remaining flags to `BACKLOG.md` with revisit criteria (...), alongside a stable Gemini default from code review." Line 770: "That was one of the flagged items made into a fix" and "the history stays in CLAUDE.md and git history."

[WARN, fixed in 5695fb9] claude/skills/spec/SKILL.md:93 — A stale proposal is now consumed without confirmation, so Step 3g step 2 applies its Backlog Sweep deletions, which were classified against project state 5 or more commits old (claude-code)
  Evidence: Step 2 routes a stale proposal to Step 3g; Step 3g step 2 pipes one `delete:` per Backlog Sweep line to spec-backlog-apply.sh. Before 022d646 the user could re-propose first. The sweep only proposes deleting entries that clearly contradicted state then, and deletions are reversible via git when BACKLOG.md is committed, so the impact is limited. Confidence: high on the mechanism.
  Suggested fix: Without asking, have the stale check re-test each Backlog Sweep deletion against the current state with the Step 3c.5 rules before Step 3g applies it, drop any that no longer clearly hold, and report the dropped ones in the Step 5 output.

[WARN, fixed in 5695fb9] claude/skills/tester/SKILL.md:460 — The D.5.5 checklist example "greenfield seed (52 lines)" re-anchors the ~50-line cap that dd22b6d removed, and the new lint pattern does not catch it (claude-code)
  Evidence: Examples are matched closely by current models; the always-on checklist shows a number next to 50 as the model case. The format block below it already shows `(<N> lines)`. Confidence: medium.
  Suggested fix: Remove the concrete example line, or replace "(52 lines)" with a placeholder.

[NOTE] claude/skills/spec/SKILL.md:248 — Regenerating an existing proposal carries forward only the Retrospective and user replies, so the old proposal's Backlog Sweep and Revisit candidates subsections drop out (Step 3c.5 runs only at turn close) (claude-code)
  Evidence: Low impact: dropped sweep deletions leave entries in BACKLOG.md (the safe direction), and revisit candidates resurface at the next turn-close sweep. Confidence: medium.
  Suggested fix: Carry those two subsections forward as well.

[NOTE] claude/skills/tester/SKILL.md:51 — "State uncertainty" records an uncertain gap as a NOTE, which can under-rate a serious gap whose only uncertainty is whether it was intentional (claude-code)
  Evidence: The previous rule ended the forked run with no report at all, so this is still an improvement. Design mode emits no severities, so the rule has no target there. Confidence: medium.
  Suggested fix: Rate the gap by its impact if accidental and state that intent could not be determined.

[NOTE] claude/skills/spec/SKILL.md:96 — The staleness note and the "proposal was replaced" note are specified only in Step 2 and Step 3d; Step 5's summary templates have no slot for them and no lint check requires them (claude-code)
  Suggested fix: Add both notes to Step 5's mode-specific summaries.

[NOTE] tests/lint-skills.sh:768 — The no-mid-run-confirmation guard matches two exact, case-sensitive phrasings, so a reworded wait would pass (claude-code)
  Suggested fix: Match case-insensitively, or accept that the guard pins only the removed text.

[NOTE] tests/lint-skills.sh:1539 — The why-deferred check passes when "boilerplate" appears anywhere in D.5, and D.5 now quotes the boilerplate phrase itself, which a literal-following model can copy (claude-code)
  Suggested fix: Drop the quoted phrase from claude/skills/tester/SKILL.md:418 ("A reason that would fit every entry is boilerplate, not a reason.").

[NOTE] bin/codereview-skip:22 — (security) The skip marker never expires and is not tied to a diff; the hook's tag-only exit runs before the skip check, and a push from the user's own terminal never reaches the hook, so a leftover marker lets a later, unreviewed agent push through without notice
  Evidence: SECURITY.md 2026-10-01, reproduced in a scratch repo with synthetic hook input (a 30-day-old marker still worked). Predates this diff; this diff changed only the usage comment. Confidence: high on the mechanism, low on frequency.
  Suggested fix: Have codereview-skip store `codereview-marker hash` and the hook honor the marker only on a match, or add an age limit.

[NOTE] bin/codereview-skip:18 — (security) The comment's claim that the 0700 parent directory makes a plain touch safe is not enforced: marker_dir runs in a command substitution where set -e is off, so a failed chmod is ignored, and touch follows a symlink
  Evidence: SECURITY.md 2026-10-01. Exposure needs XDG_CACHE_HOME in a directory another account can write; not the case on this host. Predates this diff.
  Suggested fix: Check ownership in marker_dir and create the marker with noclobber (`set -C`).

[NOTE] (carried forward) bin/review-external.sh:144 — gemini_thinking chooses thinkingLevel or thinkingBudget from the shape of GEMINI_EFFORT, not the model; a level sent to a pinned gemini-2.5 model may be rejected, and the 32768 default budget exceeds gemini-2.5-flash's cap (claude-code)
  Evidence: The budget default for every 2.5 model predates this diff (the old default applied to any model). Whether 2.5 models accept thinkingLevel was not verified. Confidence: medium-low.
  Suggested fix: For gemini-2.5 models map a level to a budget, and cap the flash default at 24576.

[NOTE] (carried forward) tests/test-review-external.sh:848 — The hostile-token test detects a regression by elapsed time, but nothing bounds the run, so a regression would hang the suite rather than fail the check (claude-code)
  Suggested fix: Bound the run (the script's own TIMEOUT_CMD pattern), so a hang becomes a failure.

[NOTE] (carried forward) bin/review-external.sh:168 — `--check` prints an invalid GEMINI_EFFORT but still counts Google as configured and exits 0, so /codereview external's pre-flight passes for a provider the real run will skip (claude-code)
  Evidence: The same behavior existed before this diff with a non-numeric budget. Confidence: high on the mechanism, low impact.
  Suggested fix: Do not count Google as configured when its thinking setting is invalid.

[NOTE] (carried forward) bin/review-external.sh:284 — `_redact` has no word boundary, so words containing "sk-" (for example "task-" or "risk-") in provider error text are partly redacted (also claude-code)
  Evidence: Cosmetic; it only affects error text. BSD sed lacks `\b`, so the fix needs a portable boundary such as `(^|[^A-Za-z0-9])`.
  Suggested fix: Anchor the match on a non-alphanumeric character or line start.

[NOTE] (carried forward) bin/review-external.sh:456 — The new price tables drop the gemini-2.5-flash rate and the o3-priced fallback, so those models now log cost "?" (claude-code)
  Evidence: Deliberate: the old flash rates were stale and the o3 fallback mispriced every unknown model. "?" is honest. Confidence: high.
  Suggested fix: None, or add verified rates for models in actual use.

[NOTE] (carried forward) tests/lint-skills.sh:294 — The double-count fix leaves 28 failure branches that update FAILS and TOTAL inline and print by hand, duplicating fail() (claude-code)
  Suggested fix: Replace those branches with `fail "..."`.

[NOTE] (carried forward) bin/review-external.sh:151 — gemini_thinking accepts `minimal`, which the header, the install template, and the validation message do not list (claude-code)
  Suggested fix: Document `minimal`, or drop it, since Pro models do not accept it.

[NOTE] (carried forward) tests/test-review-external.sh:112 — (security) The invalid-key tests call the real OpenAI and Google APIs from the repo root, so each run sends the unpushed commit subjects to both providers without opt-in
  Evidence: SECURITY.md 2026-10-01, re-confirmed at f541aa2 with a recording curl stub. Predates this diff. Low impact.
  Suggested fix: Run them against the suite's fake curl with FAKE_CODE=401.

[NOTE] (carried forward) zat.env-install.sh:170 — (security) Each settings.json rewrite creates a new .tmp file and moves it into place, so a 0600 settings.json comes back at the default umask (0664 under umask 0002); same pattern at 224, 233, 249, 271, 288, 306
  Evidence: SECURITY.md 2026-10-01. Inert today: no secrets in settings.json and the home directory is 0750.
  Suggested fix: `umask 077` at the top of the script.

[NOTE] (carried forward) bin/review-external.sh — The default Gemini model, gemini-3.1-pro-preview, is a preview; a preview can be withdrawn on short notice, and a retired default would show only as an API-error line in the cost log
  Evidence: It is Google's named replacement for gemini-2.5-pro, whose access is limited to existing users. Confidence: medium.
  Deferred to BACKLOG.md (gemini-stable-model-default).
  Suggested fix: Switch to the stable 3.x Pro ID when Google publishes one.

[NOTE] (carried forward) hw-bootstrap.sh:48 — (carried forward, security) ImageMagick still installs with the stock coder policy; 6645cd1 makes the convention name the input format (`png:in.png`), which blocks a disguised SVG, but the policy itself still allows the SVG and MVG coders
  Suggested fix: Optionally install a raster-only coder allowlist in hw-bootstrap.sh.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:480 — Whether a forked /codereview (`context: fork`) can wait on a background Bash task without polling is unverified; this run executed inline, where the completion notice arrived normally (claude-code)
  Evidence: The built-in argues a forked agent's only way to wait is to end its turn, which could end the review early. Step 7 already relies on forks receiving completion notices for background skill forks, and an early end leaves no marker, so the push is blocked rather than passed. Confidence: medium-low.
  Suggested fix: Watch the first user-typed /codereview; if it ends early at Step 5.6, collect the built-in in the foreground there instead.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:469 — Launching after Step 3 means the built-in never overlaps the test run, so a slow test suite can push its completion past Steps 4 and 5 (claude-code)
  Evidence: By design: launching after the tests avoids two test runs colliding on ports, databases, or temp files (user decision 2026-10-01). In this run it finished about 10 minutes before /security.
  Suggested fix: None now; revisit if Step 5.6 waits become common.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:472 — `2>/dev/null` discards the built-in's stderr, so a recurring failure (expired auth, a changed CLI flag) shows only as `Failed (skipped).` with no reason (claude-code)
  Suggested fix: Send stderr to a sibling mktemp file and record its first line on failure.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:472 — The built-in resolves its own scope; on a first push it reviews only the last commit while the gate covers the whole tree, and the Step 9 line does not say so (claude-code)
  Evidence: Coverage gap only; the inline review covers the full scope. README documents the scope difference.
  Suggested fix: Have the Step 9 "Built-in review" line note the range the built-in reported reviewing when it differs from the gate's base.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md — The skill is 677 lines against the CLAUDE.md guideline of about 500; deferred to BACKLOG.md (skill-size-references-split) (claude-code)
  Suggested fix: Move Step 5.6's launch and collect mechanics, or other long sections, to claude/skills/codereview/references/.

[NOTE] (carried forward) (security) The dev box runs service accounts besides peter (cloudflared-daydream, daydream-egress, daydream), and `/proc` does not hide one user's processes from another, so the Accepted Risks that assume a single-user host deserve a second look
  Evidence: SECURITY.md 2026-10-01. The API-key-in-cmdline exposure is inert while no external reviewer keys are configured.
  Suggested fix: Re-evaluate those acceptances.

[NOTE] (carried forward) hooks/allow-venv-source.sh:12 — (security) The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Evidence: SECURITY.md 2026-10-01: "Auto", " auto", null, and a missing field each got allow; test line 63 pins allow for a missing field (kept on purpose for pre-auto-mode behavior). The value forked skills receive was not verified, and the commit's live check cannot tell a hook allow from a classifier allow, though this session's transcript records the mode as `auto`. Confidence: high on mechanism, low that any current context sends something other than "auto".
  Suggested fix: Approve only for an explicit list of modes (default, acceptEdits, plan, dontAsk, bypassPermissions) and make no decision otherwise; update test line 63 and the lint pin at tests/lint-skills.sh:1225.

[NOTE] (carried forward) zat.env-install.sh:114 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod at :155; it holds only commented template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:184 — (carried forward) Deny entries accumulate across installs; removing one requires editing settings.json. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward) hw-bootstrap.sh:197 — (carried forward, security) Docker group membership lets anything running as the user, including the agent, obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

- [WARN] README.md:769-770: the audit narrative says two flagged items became fixes and the remaining flags were deferred, with the Gemini default from code review; removed history stays in "CLAUDE.md and git history".
- [WARN] claude/skills/spec/SKILL.md:93: the stale proposal check re-tests each Backlog Sweep deletion against current state with the Step 3c.5 rules before Step 3g applies it, drops any that no longer hold, and names them in the Step 5 output; Step 3g step 2 excludes the dropped ones. (claude-code)
- [WARN] claude/skills/tester/SKILL.md:460: the D.5.5 example reads `greenfield seed (<N> lines)`. (claude-code)

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit 20a4c6c): Made the built-in review read-only with a tree-change check, moved test paths off predictable /tmp names, and fixed doc accuracy; five WARNs, all fixed; 0 BLOCK / 0 WARN / 22 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"5695fb9","reviewed_up_to":"5695fb96e588af34200cf2e71aa08aa26dc8a6e5","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":28} -->
