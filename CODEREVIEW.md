## Review — 2026-10-01 (commit: 2f556b0)

**Review scope:** Refresh review. Focus: 6 file(s) changed since prior review (commit c6e5cab): API keys passed to curl through a file descriptor with tests and lint pins (5a1a7aa), and the v1.5 documentation fold-in (2f556b0). 0 already-reviewed file(s).

**Summary:** review-external.sh now hands each provider's API key to curl as `-H @<(printf ...)` instead of a command-line argument, which any local account could read in /proc/<pid>/cmdline on this host (no hidepid) while a review ran; the fake curl records curl's arguments and headers so the tests check both, and lint pins the form. A live run through a curl shim showed only `@/dev/fd/63` in curl's arguments and the API accepted the header. This resolves the prior NOTE on the single-user premise and retires the curl `-H` Accepted Risk. tests/run-all.sh 709/709. /security (paths: bin/review-external.sh, tests/lint-skills.sh, tests/test-review-external.sh) found 0 BLOCK / 0 WARN / 3 NOTE, all carried forward, and confirmed the fix (no key in 4,953 reads of every process command line; real curl 7.81 sent the header once).

**External reviewers:**
[openai] gpt-6.1-sol (high) -- 3756 in / 469 out / 459 reasoning -- ~$0.0122
[openai] No issues found.

**Built-in review:**
`/code-review high`: 3 findings, 2 kept after Step 6 (both folded into the inline review's matching findings; the stale SECURITY.md Accepted Risk finding dropped as a review-output file, and /security had already retired that entry).

### Findings

[NOTE] bin/review-external.sh:318 — `-H @<(...)` needs curl 7.55 or later; older curl sends a literal `@/dev/fd/63` header and gets a 401, and a curl that cannot read the descriptor fails into the "API call failed (network error)" branch because stderr goes to /dev/null, so either way the cause is misreported (also claude-code)
  Evidence: Ubuntu 22.04 ships curl 7.81 and macOS ships 8.x, so the supported platforms are covered; both failure modes fail open with a stderr line. /security confirmed an unreadable header leads to a request without it and a 401. Confidence: high on the mechanism, low likelihood.
  Suggested fix: Optionally note the curl 7.55 requirement in README's platform section.

[NOTE] tests/lint-skills.sh:1020 — The negative pin matches only the old `-H "Authorization: Bearer ${` and `-H "x-goog-api-key: ${` forms, so `--header`, a bare `$api_key`, a missing space after the colon, or Gemini's `?key=` URL parameter would put the key back in curl's arguments and still pass (also claude-code)
  Evidence: The positive pins at 1022-1025 and the fake-curl tests (which check curl's arguments for the key) cover both current providers; the fake-curl test would catch the URL form. Confidence: high, low impact.
  Suggested fix: Optionally flag any curl argument line containing `api_key}` or `$api_key` outside a `printf` in `<(...)`.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:434 — The 360000 ms timeout in Steps 5.5 and E.4 covers only the script's default REVIEW_TIMEOUT; a larger REVIEW_TIMEOUT set in ~/.config/claude-reviewers/.env (documented in the script header, sourced at bin/review-external.sh:122) brings the cut-off back, and the "300 seconds" in the Step 5.5 prose is not lint-checked against the script (also claude-code)
  Evidence: The lint pin at tests/lint-skills.sh:1004 compares each step's ms value with `REVIEW_TIMEOUT:-300` only. The install template does not set REVIEW_TIMEOUT, and the Bash tool caps a foreground call at 600000 ms, so overrides above about 570 s cannot be covered anyway. Confidence: high on the mechanism, low impact.
  Suggested fix: Add one sentence to Step 5.5: raise the Bash timeout to cover a larger REVIEW_TIMEOUT in the reviewer .env, up to the tool's 600000 ms; have the lint also match the prose's seconds value against the script default.

[NOTE] (carried forward) tests/lint-skills.sh:1010 — The timeout pin sets a lower bound (REVIEW_TIMEOUT default plus 30 s) but no upper bound, so raising the script default past 570 s would make lint demand a Bash timeout above the tool's 600000 ms maximum (claude-code)
  Evidence: Hypothetical until the default changes. Confidence: high on the mechanism, low likelihood.
  Suggested fix: Also fail when the ms value exceeds 600000.

[NOTE] (carried forward) tests/test-review-external.sh:838 — The OpenAI price tests use 100k and 1M input tokens, so an off-by-one at the 272000 boundary (`-ge` for `-gt`) would pass; the Gemini tests have the same gap at 200000 (claude-code)
  Evidence: A mistyped threshold such as 27200 would be caught by the 100k fixture. Cost-display only. Confidence: high, low impact.
  Suggested fix: Optional: add 272000 (short) and 272001 (long) fixtures.

[NOTE] (carried forward) bin/review-external.sh:359 — Each GPT-6 price row repeats an inline if/else for the long tier, as call_google does, although every current tier is 2x input and 1.5x output (claude-code)
  Evidence: The ratio is a property of today's prices, not of the pricing model; explicit rows match the provider pricing pages line for line and stay correct when a future model's ratio differs. Confidence: high.
  Suggested fix: None recommended.

[NOTE] (carried forward) bin/review-external.sh:357 — (security) The `[[ "${input_tokens}" -gt 272000 ]]` comparison evaluates its operands arithmetically, which runs a command substitution hidden in an array subscript; line 463 has the same pattern for Gemini
  Evidence: SECURITY.md 2026-10-01, re-confirmed at 2f556b0: safe because `_count` (line 278, applied at 349) turns any non-integer into 0 first; a mutant that skipped `_count` ran an injected command and the suite still passed, since the hostile-token test's payload targets bc only. No hostile Gemini count is tested.
  Suggested fix: Use a payload such as `PATH[$(: > ${TEST_DIR}/ran)]` in that test, assert the file was not created, add a Gemini case, and name the comparison in `_count`'s comment.

[NOTE] (carried forward) bin/review-external.sh:372 — (security) Control characters in provider output reach the terminal unchanged; a carriage return and erase-line sequence in a finding can make a BLOCK display as a harmless NOTE (same for the Google and local loops and in demux at 581-595)
  Evidence: SECURITY.md 2026-10-01, reproduced with a stub curl and re-confirmed at 2f556b0. Whether these models emit such bytes, and how Claude Code renders them, was not verified. Confidence: high on the mechanism, low exploitability.
  Suggested fix: Strip control characters in demux with `LC_ALL=C tr -d '\000-\010\013-\037\177'` and add a test.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:472 — The Step 5.6 tree-change reading misses a re-edit of an already fully staged file, an edit to an untracked file, and an edit committed during the run (openai, from the 2026-10-01 external-only run on v1.4..HEAD)
  Evidence: `git status --porcelain` keeps the same status code in each case and the unstaged `git diff` is empty or unchanged.
  Deferred to BACKLOG.md (builtin-review-tree-fingerprint).
  Suggested fix: Add `git rev-parse HEAD`, `git diff HEAD`, and untracked file contents to both readings, and update the lint pin at tests/lint-skills.sh:944.

[NOTE] (carried forward) claude/skills/spec/SKILL.md:248 — Regenerating an existing proposal carries forward only the Retrospective and user replies, so the old proposal's Backlog Sweep and Revisit candidates subsections drop out (Step 3c.5 runs only at turn close) (claude-code)
  Evidence: Low impact: dropped sweep deletions leave entries in BACKLOG.md (the safe direction), and revisit candidates resurface at the next turn-close sweep. Confidence: medium.
  Suggested fix: Carry those two subsections forward as well.

[NOTE] (carried forward) claude/skills/tester/SKILL.md:51 — "State uncertainty" records an uncertain gap as a NOTE, which can under-rate a serious gap whose only uncertainty is whether it was intentional (claude-code)
  Evidence: The previous rule ended the forked run with no report at all, so this is still an improvement. Design mode emits no severities, so the rule has no target there. Confidence: medium.
  Suggested fix: Rate the gap by its impact if accidental and state that intent could not be determined.

[NOTE] (carried forward) claude/skills/spec/SKILL.md:96 — The staleness note and the "proposal was replaced" note are specified only in Step 2 and Step 3d; Step 5's summary templates have no slot for them and no lint check requires them (claude-code)
  Suggested fix: Add both notes to Step 5's mode-specific summaries.

[NOTE] (carried forward) tests/lint-skills.sh:768 — The no-mid-run-confirmation guard matches two exact, case-sensitive phrasings, so a reworded wait would pass (claude-code)
  Suggested fix: Match case-insensitively, or accept that the guard pins only the removed text.

[NOTE] (carried forward) tests/lint-skills.sh:1566 — The why-deferred check passes when "boilerplate" appears anywhere in D.5, and D.5 now quotes the boilerplate phrase itself, which a literal-following model can copy (claude-code)
  Suggested fix: Drop the quoted phrase from claude/skills/tester/SKILL.md:418 ("A reason that would fit every entry is boilerplate, not a reason.").

[NOTE] (carried forward) bin/codereview-skip:22 — (security) The skip marker never expires and is not tied to a diff; the hook's tag-only exit runs before the skip check, and a push from the user's own terminal never reaches the hook, so a leftover marker lets a later, unreviewed agent push through without notice
  Evidence: SECURITY.md 2026-10-01, reproduced in a scratch repo with synthetic hook input (a 30-day-old marker still worked). Confidence: high on the mechanism, low on frequency.
  Deferred to BACKLOG.md (skip-marker-bound-to-diff).
  Suggested fix: Have codereview-skip store `codereview-marker hash` and the hook honor the marker only on a match, or add an age limit.

[NOTE] (carried forward) bin/codereview-skip:18 — (security) The comment's claim that the 0700 parent directory makes a plain touch safe is not enforced: marker_dir runs in a command substitution where set -e is off, so a failed chmod is ignored, and touch follows a symlink
  Evidence: SECURITY.md 2026-10-01. Exposure needs XDG_CACHE_HOME in a directory another account can write; not the case on this host.
  Suggested fix: Check ownership in marker_dir and create the marker with noclobber (`set -C`).

[NOTE] (carried forward) bin/review-external.sh:144 — gemini_thinking chooses thinkingLevel or thinkingBudget from the shape of GEMINI_EFFORT, not the model; a level sent to a pinned gemini-2.5 model may be rejected, and the 32768 default budget exceeds gemini-2.5-flash's cap (claude-code)
  Evidence: The budget default for every 2.5 model predates the refresh (the old default applied to any model). Whether 2.5 models accept thinkingLevel was not verified. Confidence: medium-low.
  Suggested fix: For gemini-2.5 models map a level to a budget, and cap the flash default at 24576.

[NOTE] (carried forward) tests/test-review-external.sh:883 — The hostile-token test detects a regression by elapsed time, but nothing bounds the run, so a regression would hang the suite rather than fail the check (claude-code)
  Suggested fix: Bound the run (the script's own TIMEOUT_CMD pattern), so a hang becomes a failure.

[NOTE] (carried forward) bin/review-external.sh:168 — `--check` prints an invalid GEMINI_EFFORT but still counts Google as configured and exits 0, so /codereview external's pre-flight passes for a provider the real run will skip (claude-code)
  Evidence: The same behavior existed before the refresh with a non-numeric budget. Confidence: high on the mechanism, low impact.
  Suggested fix: Do not count Google as configured when its thinking setting is invalid.

[NOTE] (carried forward) bin/review-external.sh:285 — `_redact` has no word boundary, so words containing "sk-" (for example "task-" or "risk-") in provider error text are partly redacted (also claude-code)
  Evidence: Cosmetic; it only affects error text. BSD sed lacks `\b`, so the fix needs a portable boundary such as `(^|[^A-Za-z0-9])`. A live OpenAI 401 on 2026-10-01 was redacted correctly.
  Suggested fix: Anchor the match on a non-alphanumeric character or line start.

[NOTE] (carried forward) bin/review-external.sh:465 — The Gemini price table has no gemini-2.5-flash rate and there is no o3-priced fallback, so those models log cost "?" (claude-code)
  Evidence: Deliberate: the old flash rates were stale and the o3 fallback mispriced every unknown model. "?" is honest. Confidence: high.
  Suggested fix: None, or add verified rates for models in actual use.

[NOTE] (carried forward) tests/lint-skills.sh:294 — The double-count fix leaves 28 failure branches that update FAILS and TOTAL inline and print by hand, duplicating fail() (claude-code)
  Suggested fix: Replace those branches with `fail "..."`.

[NOTE] (carried forward) bin/review-external.sh:151 — gemini_thinking accepts `minimal`, which the header, the install template, and the validation message do not list (claude-code)
  Suggested fix: Document `minimal`, or drop it, since Pro models do not accept it.

[NOTE] (carried forward) tests/test-review-external.sh:112 — (security) The invalid-key tests call the real OpenAI and Google APIs from the repo root, so each run sends the unpushed commit subjects to both providers without opt-in (same at 287-294)
  Evidence: SECURITY.md 2026-10-01, re-confirmed at 2f556b0 with a recording curl stub; with curl stubbed the suite passed 78/78. Low impact.
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

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:489 — Whether a forked /codereview (`context: fork`) can wait on a background Bash task without polling is unverified; the last three runs executed inline, where the completion notice arrived normally (claude-code)
  Evidence: The built-in argues a forked agent's only way to wait is to end its turn, which could end the review early. Step 7 already relies on forks receiving completion notices for background skill forks, and an early end leaves no marker, so the push is blocked rather than passed. Confidence: medium-low.
  Suggested fix: Watch the first user-typed /codereview; if it ends early at Step 5.6, collect the built-in in the foreground there instead.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:475 — Launching after Step 3 means the built-in never overlaps the test run, so a slow test suite can push its completion past Steps 4 and 5 (claude-code)
  Evidence: By design: launching after the tests avoids two test runs colliding on ports, databases, or temp files (user decision 2026-10-01). In this run it finished before /security.
  Suggested fix: None now; revisit if Step 5.6 waits become common.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:479 — `2>/dev/null` discards the built-in's stderr, so a recurring failure (expired auth, a changed CLI flag) shows only as `Failed (skipped).` with no reason (claude-code)
  Suggested fix: Send stderr to a sibling mktemp file and record its first line on failure.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:479 — The built-in resolves its own scope; on a first push it reviews only the last commit while the gate covers the whole tree, and the Step 9 line does not say so (claude-code)
  Evidence: Coverage gap only; the inline review covers the full scope. README documents the scope difference.
  Suggested fix: Have the Step 9 "Built-in review" line note the range the built-in reported reviewing when it differs from the gate's base.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md — The skill is 683 lines against the CLAUDE.md guideline of about 500; deferred to BACKLOG.md (skill-size-references-split) (claude-code)
  Suggested fix: Move Step 5.6's launch and collect mechanics, or other long sections, to claude/skills/codereview/references/.

[NOTE] (carried forward) hooks/allow-venv-source.sh:12 — (security) The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Evidence: SECURITY.md 2026-10-01: "Auto", " auto", null, and a missing field each got allow; test line 63 pins allow for a missing field (kept on purpose for pre-auto-mode behavior). The value forked skills receive was not verified, though this session's transcript records the mode as `auto`. Confidence: high on mechanism, low that any current context sends something other than "auto".
  Suggested fix: Approve only for an explicit list of modes (default, acceptEdits, plan, dontAsk, bypassPermissions) and make no decision otherwise; update test line 63 and the lint pin at tests/lint-skills.sh:1309.

[NOTE] (carried forward) zat.env-install.sh:114 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod at :155; it holds only commented template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:184 — (carried forward) Deny entries accumulate across installs; removing one requires editing settings.json. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward) hw-bootstrap.sh:197 — (carried forward, security) Docker group membership lets anything running as the user, including the agent, obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

None in this run. The prior NOTE on the single-user premise behind the curl `-H` Accepted Risk was resolved before review by 5a1a7aa, and that Accepted Risk is retired below.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit c6e5cab): Refresh review of the external reviewer Bash timeout, the GPT-6 long-context price tier and the cost's leading zero, two BACKLOG.md entries, and the v1.5 documentation fold-in; no BLOCK or WARN; 0 BLOCK / 0 WARN / 35 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"2f556b0","reviewed_up_to":"2f556b0f22291b1f0b81bb376e23f10c9cb42937","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":36} -->
