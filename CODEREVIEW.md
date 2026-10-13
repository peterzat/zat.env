## Review — 2026-10-13 (commit: 0ccfae7)

**Summary:** Refresh review of 0ccfae7, the one unpushed commit, which adds `**/.claude/settings.local.json` to gitconfig/ignore-global (the file `core.excludesfile` points at, zat.env-install.sh:76). Full tier: `codereview-marker surface` lists the file and it has none of the light-tier extensions. The rule is correct: in a scratch repo it ignored `.claude/settings.local.json` at the root and in a subdirectory and did not ignore `.claude/settings.json`. The commit message is accurate: Claude Code 2.1.296's append routine (read from the installed binary) runs `git check-ignore` first, skips when the exact `**/<path>` line is already present, and otherwise appends `\n**/.claude/settings.local.json\n` to `core.excludesfile`, which matches this diff byte for byte; ignore rules do not affect tracked files, and the marker hash, the uncommitted check, and the security surface read tracked files only. tests/run-all.sh 807/807 across 6 suites on Linux. /security scanned the five surface files changed since its last META commit (b065794 and 0ccfae7): no new findings, no secrets.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 4 findings, 2 kept after Step 6 (one merged with an inline finding, one NOTE). Dropped: "Claude Code's skip of an existing line is undocumented and could drift" (refuted: the append is gated on `git check-ignore`, so any matching rule suffices), and "the new line has no section comment" (style).

### Findings

Two NOTEs in this diff, no BLOCK or WARN. The open findings from the 2026-10-13 review of 6c9741a are carried forward below at their original severity; the code they cite has not changed since b065794. /security re-checked the five files in its scope on Linux and updated two entries (onFailure WARN, hook tokenizer NOTE); the others are carried without re-checking.

[NOTE] gitconfig/ignore-global:24 — The fix covers one of two paths Claude Code 2.1.296 appends to `core.excludesfile`, and that setting points at this tracked file, so the next append again dirties the tree and the pre-push `uncommitted` check refuses every push from zat.env (also claude-code)
  Evidence: the binary's append routine has a second caller, which passes `.claude/.cc-writes/` once per session when a staging directory is set up in a repo that does not already ignore `.claude/.cc-writes/sample-file.txt`; it would append `**/.claude/.cc-writes/`. No `.claude/.cc-writes` directory exists under ~/src yet, so whether that feature runs on this machine is unverified. The failure is fail-safe (the hook names the file). Confidence: high on the code path, low on when it fires.
  Suggested fix: Add `**/.claude/.cc-writes/` now, in that exact form so both of Claude Code's checks pass. The structural fix (point `core.excludesfile` at a user-owned file the installer seeds from the repo copy) changes install behavior for every adopter and requires a user decision.

[NOTE] gitconfig/ignore-global:24 — Nothing records why the line is there: unlike the other blocks it has no comment, and no lint check pins it. It looks redundant in this repo, whose .gitignore already ignores `.claude/`, so a later tidy-up could remove it and bring back the push refusal (claude-code)
  Evidence: gitconfig/ignore-global:23-24; .gitignore:18. Confidence: low that it matters.
  Suggested fix: Optional. A one-line comment naming Claude Code as the writer, or a sentence in CLAUDE.md's gitconfig bullet saying Claude Code appends to this file.

[WARN] zat.env-install.sh:320-337 — (security) A hook that times out, crashes, or cannot start does not block the tool call, and neither gate entry sets `"onFailure": "block"`, so the hook's exit-2 refusals hold only when it runs to completion. A 125 MB first push took 29.8 s on Windows against the 30 s timeout, and a moved checkout or a `$` or backtick in the repo path keeps the hook from starting. The Git Bash here-string hang that also led here was fixed in b065794. Re-checked on Linux at 0ccfae7: still present, with three Linux triggers (a moved checkout exits 127, an unreadable marker file makes `cat` at hooks/pre-push-codereview.sh:297 exit 1, a command of about 400 to 720 KB outlasts the timeout).
  Evidence: SECURITY.md 2026-10-13 (both entries); the Claude Code 2.1.296 binary documents `'continue'` as the default ("the action goes ahead"); the live ~/.claude/settings.json carries b065794's quoted commands and no `onFailure`.
  Suggested fix: Requires a user decision (changes the gate for every project). Add `"onFailure": "block"` to both gate entries (needs Claude Code 2.1.295 or later; how an older client treats the field is unverified) and raise the timeout so a large first push is not refused once failure blocks.

[WARN] hooks/pre-push-codereview.sh — (security) The gate hashes the checked-out branch and allows on a match or on "nothing to review", whatever refs the push names; `git push origin <other>` and `<other>:main` were re-reproduced as allowed on 2026-10-13
  Evidence: SECURITY.md 2026-10-13. Pre-existing hook logic, the same-repo sibling of BACKLOG push-gate-pushed-repo.
  Suggested fix: Requires a user decision. Gate pushes whose refspec sources are not the current branch, HEAD, or a tag, or move to a git-native pre-push hook, which receives the exact refs.

[WARN] hooks/pre-push-codereview.sh — (security) The hook judges the repo as it is before the command runs, so `git merge feat && git push` (re-reproduced 2026-10-13), `git cherry-pick feat && git push`, or edit, commit, and push in one Bash call on a clean branch are allowed
  Suggested fix: Requires a user decision. Block a command where another statement precedes `git push`, or move to a git-native pre-push hook.

[WARN] bin/codereview-marker:162-178 — (security) A submodule with `ignore = all` hides its pointer changes from `git diff`, so the marker hash, the uncommitted check, the security surface, and the review diff all miss them
  Suggested fix: Requires a user decision. Add `--ignore-submodules=dirty` to the script's diffs and the codereview skill's review diffs.

[WARN] claude/skills/pr/SKILL.md:184-191 — (security) /pr merge accepts a review of any ancestor of local HEAD and never compares the remote PR head with local HEAD (carried, not re-checked this run)
  Suggested fix: Requires a user decision. Require no non-review-file change since `reviewed_up_to` and a remote head equal to local HEAD.

[WARN] claude/skills/codereview/SKILL.md:269-277 — (security) The light tier still treats `.txt` and `.gitconfig` as plain documentation, so a diff limited to `gitconfig/aliases.gitconfig` or a downstream `requirements*.txt` or `CMakeLists.txt` skips /security, tests, and external reviewers
  Suggested fix: Requires a user decision (tiering policy for every project). Drop `.txt` and `.gitconfig` from the light tier, and update README and the lint pin.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425 — (security) CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed, and the review diff excludes those files
  Suggested fix: Requires a user decision. Take the full tier and read prior META from the base when a commit not authored by the operator touched the review files.

[WARN] claude/global-claude.md:108 — (security) The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW. The rule now also loads on Windows, where windows.md says networking.md (the only place the firewall assumption is written) does not apply
  Suggested fix: Requires a user decision (machine-wide networking convention). Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW; scope the rule to the Linux box.

[NOTE] hooks/pre-push-codereview.sh:63-73, 89, 142 — (security) The hook's tokenizing time grows with the square of the command length, so a long command passes the 30 s timeout (fail open without onFailure). Restated by /security on Linux at 0ccfae7: the cost is `_normalize_ops` (six bash pattern substitutions, quadratic in bash 5.1, run three times per hook call), not the process-substitution read. 500 KB took 14.7 s, 750 KB 32.0 s, and operator-dense text passes 30 s near 400 KB; Git Bash measured 34.5 s at 500 KB. Needs over 100k tokens in one tool call.
  Suggested fix: Normalize once in main and pass the tokens to both functions, padding operators in one linear pass (`tr '\n' ';' | sed 's/[;|&()]/ & /g'` gave identical tokens in 19 ms at 500 KB); the in-process split proposed last time is no faster on Linux. Or refuse a recognized push whose command exceeds a fixed size. Add 65,600-byte and 500 KB test cases.

[NOTE] hooks/pre-push-codereview.sh:4-7 — The header still says the hook is installed "as a PreToolUse hook on Bash ... with an "if" filter on Bash(git push*)"; it is now also registered for the PowerShell tool.
  Suggested fix: Mention the PowerShell entry.

[NOTE] hooks/README.md:98 — The manual test recipe says `echo '{}' | bash .../pre-push-codereview.sh` "should block (no marker)", but `{}` has no command, which reads as "not a push" and exits 0 (before and after this diff). Pre-existing.
  Suggested fix: Use a payload with `{"tool_input":{"command":"git push"}}`.

[NOTE] hooks/pre-push-codereview.sh:198 — An empty payload still fails open: `jq` exits 0 with no output on empty input, so the command reads as empty and the hook exits 0. Truncated JSON now fails closed (jq exit 5). Claude Code always sends a payload, so reachability is low; since the hook runs only for commands already matched as `git push*`, an empty command could be refused too.
  Suggested fix: Optionally treat an empty INVOKED_CMD as a refusal.

[NOTE] tests/test-pre-push-hook.sh:577 — PATH_SANITIZED keeps jq's directory, so where jq lives in ~/bin next to codereview-marker the "codereview-marker missing" test fails falsely (loud, not silent) (also claude-code)
  Suggested fix: Build a temp directory that links only `git` and `jq`.

[NOTE] zat.env-install.sh:12 — `CYGWIN*` maps to windows, but Cygwin reads `CYGWIN=winsymlinks:...`, not `MSYS`, and Cygwin's own symlinks pass the `[[ -L ]]` probe while native programs such as Claude Code may not follow them (also claude-code)
  Suggested fix: Drop `CYGWIN*` from the case (Claude Code requires Git Bash), or set `CYGWIN=winsymlinks:nativestrict` as well.

[NOTE] zat.env-install.sh:105 — Skill directories copied by a pre-nativestrict Windows install are not symlinks, so every re-run prints "exists and is not a symlink — skipping" and leaves the frozen copies; ~/.claude/CLAUDE.md and ~/bin entries are replaced (claude-code)
  Suggested fix: On Windows, tell the user to delete the copies, or replace a directory whose contents match the repo skill.

[NOTE] hooks/pre-push-codereview.sh:208 — The CR fix is repeated per consumer (hook, installer `tr -d '\r'`, windows.md advice); `jq -b` stops CRLF at the source (claude-code)
  Suggested fix: Optional. Verify the oldest supported jq accepts `-b` first (Ubuntu 22.04 ships jq 1.6; `--binary` may be newer, confidence low).

[NOTE] zat.env-install.sh:388 — The shadow warning compares path strings, so an earlier PATH entry that is another spelling of ~/bin (a symlinked HOME) warns about a copy that does not exist (claude-code)
  Suggested fix: Compare with `[[ "${FOUND_MARKER}" -ef "${BIN_DIR}/codereview-marker" ]]`.

[NOTE] bin/review-external.sh:276-278 — (security) Without `bc`, the cost expression is pasted into the awk program text, where `system()` would run; `_count` and the price literals are the only guard, and the hostile-value test covers only OpenAI `input_tokens`. The awk branch runs only on hosts without bc, so on Linux only the lint pin covers it.
  Suggested fix: Pass the operands with `-v` and keep the expression fixed, or add hostile-value tests for every token count; add a test that shadows `bc` so the awk branch runs everywhere.

[NOTE] hooks/pre-push-codereview.sh:92 — (security) `git.exe push` is not gated on Windows: `Bash(git push*)` does not match it and the walker recognizes only a bare `git` token; /security pushed a scratch repo this way. The Windows form of the absolute-path case in the accepted "detection is heuristic" risk; BACKLOG push-gate-wrapped-push-detection does not name it (also claude-code)
  Suggested fix: Requires a user decision: accept it under the existing risk, or treat `git.exe` as `git` in the walker and add `Bash(git.exe push*)` entries.

[NOTE] claude/skills/codereview/SKILL.md:238, 471 — (security) A `.gitattributes` `-diff` or `binary` attribute on a text file shows it as "Binary files differ" to the inline and external reviewers; the marker hash still covers its content, so the gate holds
  Suggested fix: Add `--text` (or `-a`) to the review diffs.

[NOTE] bin/codereview-marker:131 — `in_surface` keeps agent-instruction markdown only by filename or a `.claude/` path, so a skill's `references/*.md` and `claude/references/*.md` (read through global-claude.md) count as plain docs; the new claude/references/windows.md was left out of this run's scan list (read anyway; benign) (claude-code, also security)
  Suggested fix: Also keep `*/references/*.md` and markdown under zat.env's `claude/` tree, or invert the rule and drop only known prose paths (README*, docs/, CHANGELOG*).

[NOTE] claude/skills/codereview/SKILL.md:274 — The prose lists of agent-instruction markdown in Step 2 and Step 5 (line 395), and README, omit CLAUDE.local.md, which `in_surface` keeps (claude-code)
  Suggested fix: Add CLAUDE.local.md to both prose lists and README.

[NOTE] claude/skills/codereview/SKILL.md:597 — `git stash create` and `codereview-marker surface <PRE_FIX>` ignore untracked files, so a codefix edit to a new untracked file gets no post-fix /security pass (claude-code)
  Suggested fix: Soften the sentence to tracked changes, or list untracked files changed since PRE_FIX as well.

[NOTE] claude/skills/codereview/SKILL.md:339 — /security starts before Step 3, so its verification runs can overlap the project's test suite. Confidence: low.
  Suggested fix: None now; revisit if a downstream test run collides with a /security reproduction.

[NOTE] claude/skills/codereview/SKILL.md:460 — (security) The secret-in-diff guard depends on a step that reports secrets, and in a full-tier review no step looks in plain markdown, so a key added to a README beside a code change still goes to OpenAI and Google
  Suggested fix: Grep the exact Step 5.5 diff for key patterns before sending.

[NOTE] claude/skills/codereview/SKILL.md:405 — (security) The model pastes SECURITY_META's commit value into `codereview-marker surface <meta-commit>`, so a planted `$(...)` would run before the script's leading-dash check
  Suggested fix: Extract the commit inside the command with a hex-only `grep -oP`, and update the lint pin.

[NOTE] claude/skills/pr/SKILL.md:152 — (security) The PR template passes commit-derived text in double-quoted `--title`/`--body` arguments, where backticks or `$(...)` run as commands
  Suggested fix: Write the body with a quoted heredoc and pass `--body-file`.

[NOTE] claude/skills/spec/SKILL.md:8 — (security) /spec is inline and model-invocable, and its `allowed-tools` grants unprompted Bash(*), Write, and Edit for the rest of the invoking turn. Confidence: medium.
  Suggested fix: Narrow /spec's grant and let Write and Edit fall to the session's rules.

[NOTE] (carried forward, security) hooks/pre-push-codereview.sh — BACKLOG-deferred gate gaps, re-confirmed 2026-10-13: the skip marker never expires and is not tied to a diff (skip-marker-bound-to-diff); marker_dir ignores mkdir/chmod failure and checks no owner or symlink, and `chmod` does nothing on Windows (marker-dir-ownership-check); the hook evaluates the cwd repo, not the pushed one (push-gate-pushed-repo); a secret committed then deleted in the pushed range is never reviewed (push-gate-net-diff-secret). The jq fail-open gap is resolved by this diff.
  Suggested fix: As recorded in each BACKLOG.md entry.

[NOTE] (carried forward, security) bin/review-external.sh:365 — The `-gt 272000` comparison is an arithmetic context that would run a command substitution in an array subscript; `_count` makes it safe, but no test covers this sink (Gemini comparison at 471 the same)
  Suggested fix: Use a `PATH[$(: > ${TEST_DIR}/ran)]` payload in the hostile-token test, assert no file, add a Gemini case.

[NOTE] (carried forward, security) tests/test-review-external.sh:112 — The invalid-key tests call the real OpenAI and Google APIs from the repo root, sending unpushed commit subjects without opt-in (same at 287-294); on Windows they now reach the providers, since the stdin key handoff works there
  Suggested fix: Run them against the suite's fake curl with FAKE_CODE=401.

[NOTE] (carried forward) bin/review-external.sh:326, 430 — `-H @-` needs curl 7.55 or later; older curl misreports the failure (also claude-code)
  Suggested fix: Optionally note the curl 7.55 requirement in README's platform section.

[NOTE] (carried forward) tests/lint-skills.sh — The negative pin on API keys in curl arguments matches only the old `-H "Authorization: Bearer ${` and `-H "x-goog-api-key: ${` forms (also claude-code)
  Suggested fix: Optionally flag any curl argument line containing `api_key}` or `$api_key` outside the `printf` that feeds stdin.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:467 — The 360000 ms timeout in Steps 5.5 and E.4 covers only the script's default REVIEW_TIMEOUT; the "300 seconds" prose is not lint-checked (also claude-code)
  Suggested fix: Say to raise the Bash timeout for a larger REVIEW_TIMEOUT, up to 600000 ms; have lint match the prose's seconds value.

[NOTE] (carried forward) tests/lint-skills.sh — The timeout pin sets a lower bound but no upper bound (claude-code)
  Suggested fix: Also fail when the ms value exceeds 600000.

[NOTE] (carried forward) tests/test-review-external.sh:838 — The price tests miss the 272000 and 200000 tier boundaries (claude-code)
  Suggested fix: Optional: add boundary fixtures.

[NOTE] (carried forward) bin/review-external.sh:367 — Each GPT-6 price row repeats an inline long-tier if/else (claude-code)
  Suggested fix: None recommended.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:520 — The Step 5.6 tree-change reading misses a re-edit of a fully staged file, an edit to an untracked file, and an edit committed during the run (openai). Deferred to BACKLOG.md (builtin-review-tree-fingerprint).
  Suggested fix: Add `git rev-parse HEAD`, `git diff HEAD`, and untracked file contents to both readings.

[NOTE] (carried forward) claude/skills/spec/SKILL.md:248 — Regenerating an existing proposal drops the old proposal's Backlog Sweep and Revisit candidates subsections (claude-code)
  Suggested fix: Carry those two subsections forward as well.

[NOTE] (carried forward) claude/skills/tester/SKILL.md:51 — "State uncertainty" records an uncertain gap as a NOTE, which can under-rate a serious gap whose only uncertainty is intent (claude-code)
  Suggested fix: Rate the gap by its impact if accidental and state that intent could not be determined.

[NOTE] (carried forward) claude/skills/spec/SKILL.md:96 — The staleness and "proposal was replaced" notes have no slot in Step 5's summary templates and no lint check (claude-code)
  Suggested fix: Add both notes to Step 5's mode-specific summaries.

[NOTE] (carried forward) tests/lint-skills.sh — The no-mid-run-confirmation guard matches two exact, case-sensitive phrasings (claude-code)
  Suggested fix: Match case-insensitively, or accept that the guard pins only the removed text.

[NOTE] (carried forward) tests/lint-skills.sh — The why-deferred check passes when "boilerplate" appears anywhere in D.5, and D.5 quotes the boilerplate phrase itself (claude-code)
  Suggested fix: Drop the quoted phrase from claude/skills/tester/SKILL.md.

[NOTE] (carried forward) bin/review-external.sh:144 — gemini_thinking chooses thinkingLevel or thinkingBudget from the shape of GEMINI_EFFORT, not the model, and the 32768 default budget exceeds gemini-2.5-flash's cap (claude-code)
  Suggested fix: For gemini-2.5 models map a level to a budget, and cap the flash default at 24576.

[NOTE] (carried forward) tests/test-review-external.sh:883 — The hostile-token test detects a regression by elapsed time with no bound on the run (claude-code)
  Suggested fix: Bound the run with the script's TIMEOUT_CMD pattern.

[NOTE] (carried forward) bin/review-external.sh:168 — `--check` prints an invalid GEMINI_EFFORT but still counts Google as configured and exits 0 (claude-code)
  Suggested fix: Do not count Google as configured when its thinking setting is invalid.

[NOTE] (carried forward) bin/review-external.sh:291 — `_redact` has no word boundary, so "task-" or "risk-" in error text is partly redacted (also claude-code)
  Suggested fix: Anchor the match on a non-alphanumeric character or line start.

[NOTE] (carried forward) bin/review-external.sh:472 — The Gemini price table has no gemini-2.5-flash rate and no fallback, so those models log cost "?" (claude-code)
  Suggested fix: None, or add verified rates for models in actual use.

[NOTE] (carried forward) tests/lint-skills.sh — 28 failure branches update FAILS and TOTAL inline, duplicating fail() (claude-code)
  Suggested fix: Replace those branches with `fail "..."`.

[NOTE] (carried forward) bin/review-external.sh:151 — gemini_thinking accepts `minimal`, which the header, install template, and validation message do not list (claude-code)
  Suggested fix: Document `minimal`, or drop it.

[NOTE] (carried forward, security) zat.env-install.sh:200, 208 — Each settings.json rewrite moves a new .tmp file into place, so a 0600 settings.json returns at the default umask (same at every later rewrite). Now also in SECURITY.md; not reachable on this host (home 0750, no other group members)
  Suggested fix: `umask 077` at the top of the script.

[NOTE] (carried forward) bin/review-external.sh — The default Gemini model is a preview that can be withdrawn on short notice. Deferred to BACKLOG.md (gemini-stable-model-default).
  Suggested fix: Switch to the stable 3.x Pro ID when Google publishes one.

[NOTE] (carried forward, security) hw-bootstrap.sh:48 — ImageMagick installs with the stock coder policy, which still allows the SVG and MVG coders
  Suggested fix: Optionally install a raster-only coder allowlist.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:493 — Launching the built-in after Step 3 means it never overlaps the test run (by design, user decision 2026-10-01) (claude-code)
  Suggested fix: None now; revisit if Step 5.6 waits become common.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:511 — `2>/dev/null` discards the built-in's stderr, so a recurring failure shows only as `Failed (skipped).` (claude-code)
  Suggested fix: Send stderr to a sibling mktemp file and record its first line on failure.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:511 — The built-in resolves its own scope; on a first push it reviews only the last commit while the gate covers the whole tree (claude-code)
  Suggested fix: Have the Step 9 "Built-in review" line note the range the built-in reported when it differs from the gate's base.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md — The skill is 742 lines against the CLAUDE.md guideline of about 500. Deferred to BACKLOG.md (skill-size-references-split) (claude-code)
  Suggested fix: Move Step 5.6's mechanics or other long sections to claude/skills/codereview/references/ (and add references/*.md to the security surface first).

[NOTE] (carried forward, security) hooks/allow-venv-source.sh:12 — The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Suggested fix: Approve only for an explicit list of modes and make no decision otherwise.

[NOTE] (carried forward) zat.env-install.sh:151 — The reviewer .env exists at the process umask for an instant on first creation; it holds only template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:221 — Deny entries accumulate across installs; deliberate, since deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward, security) hw-bootstrap.sh:197 — Docker group membership lets anything running as the user obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

Resolved since the prior review: the (regression risk) NOTE that the Windows port's suite had run only on Windows. tests/run-all.sh passed 807/807 on Linux in this run, and the live ~/.claude/settings.json carries b065794's quoted hook commands, so the installer has been re-run here.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-13, commit 35a2fbf): Light review of README's Windows section rewrite, which resolved the 6c9741a review's README.md:167-169 NOTE; no new findings, and 0 BLOCK / 8 WARN / 54 NOTE carried from the Windows port review.*

<!-- REVIEW_META: {"date":"2026-10-13","commit":"0ccfae7","reviewed_up_to":"0ccfae7caabed5316aeb8a2849f1203c340c6fc8","base":"origin/main","tier":"refresh","block":0,"warn":8,"note":55} -->
