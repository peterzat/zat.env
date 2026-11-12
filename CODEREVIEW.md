## Review — 2026-11-12 (commit: 721b632)

**Summary:** Refresh review of the three unpushed commits on origin/main: c5bf5e6 gives each /security finding one Status line (found / last checked) and condenses carried NOTEs, 9787b0b keeps /security and /codefix in the foreground and stops /security from running suites or subagents, and 721b632 adds the "Bound a strong model" Philosophy paragraph to README. All 5 changed files (CLAUDE.md, README.md, the codefix and security skills, tests/lint-skills.sh) were in the focus set and reviewed at full depth; there was no already-reviewed set.
- **Findings.** One new WARN, fixed by one /codefix cycle (uncommitted): README.md:582 said forked skills never wait on background work, which is false for /codereview. The re-review confirmed the new wording; README.md is plain markdown, so the post-fix security surface was empty and no re-check ran. Eight new NOTEs, mostly gaps at the edges of the new Status-line and foreground rules.
- **Security.** /security scanned the 4 surface files changed since 1d1b5da: 0 BLOCK, 1 WARN (carried global-claude.md:108), 27 NOTE, three new, no secrets. SECURITY.md is rewritten under the new rules (Status lines, condensed carried NOTEs, 953 lines of history down to 406) and is uncommitted.
- **Tests.** tests/run-all.sh: 1214/1214 across 6 suites, before and after the fix.
- **Commit before pushing.** README.md (the fix), SECURITY.md, and CODEREVIEW.md are uncommitted; the push gate refuses while README.md is.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 7 findings, 6 kept after Step 6 (all NOTE; two merged into one entry, one merged with an inline finding), 1 dropped as style (line wrapping).

### Findings

No BLOCK findings. The new WARN is fixed (below); the carried WARN is held for a user decision.

[WARN] (carried forward) claude/global-claude.md:108 — (security) Requires a user decision; not for /codefix. The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW. The rule also loads on Windows, where windows.md says networking.md (the only place the firewall assumption is written) does not apply (carried, not re-checked).
  Suggested fix: Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW; scope the rule to the Linux box.

New this run:

[NOTE] claude/skills/security/SKILL.md:159-167 — (security) A carried NOTE is condensed to one sentence, and nothing tells a later scan to recover its full text from SECURITY.md's git history before re-checking it or calling it resolved. When its file comes back into scope, the scan re-checks the one-sentence version, so a NOTE that listed many cases (the hook-walker NOTE named about 40 push spellings) can be marked resolved after one is checked. Confidence: high on the mechanism, medium on impact (NOTEs only).
  Suggested fix: In the in-scope re-check bullet, say to read a condensed NOTE's last full version from SECURITY.md's history (for example `git log -p -S '<first line>' -- SECURITY.md`) before re-checking or resolving it.

[NOTE] claude/skills/security/SKILL.md:152-161 — (claude-code) The in-scope re-check bullet says to keep `found` and set `last checked`, but not to drop a `; carried, not re-checked` suffix, which the carry bullet treats as persistent ("unless it already ends that way"). The paragraph above says to replace the Status line and the template has no suffix, so a careful model drops it; a field-by-field edit keeps it, and the finding then reads as both checked and not re-checked. Confidence: medium.
  Suggested fix: Add "and drop any `; carried, not re-checked` suffix" to the in-scope bullet.

[NOTE] claude/skills/security/SKILL.md:148-150 — (claude-code) "Each sha is HEAD at that scan" does not identify the code the line numbers came from when the scan read an uncommitted tree, which post-fix mode always does, and gives no value in a repo with no commits. SECURITY_META's `commit` has the same property, so this matches the rest of the file. Confidence: high on the mechanism, low that it misleads.
  Suggested fix: Optional. Append `+ uncommitted` to the sha when files in scope have uncommitted changes, and say what to write before the first commit.

[NOTE] claude/skills/security/SKILL.md:169-172 — (claude-code) A legacy finding whose text gives no date gets the prior entry's date and commit as `found`, which understates its age. SECURITY.md's history usually has the real date; this run's /security used it for the settings.json umask NOTE. Confidence: low that it matters.
  Suggested fix: Optional. Take `found` from SECURITY.md's git history when it is cheap to find, falling back to the prior entry.

[NOTE] claude/skills/security/SKILL.md:190-204, README.md:393 — (claude-code) When SECURITY.md is uncommitted at the start of a scan, Step 5 still copies the whole prior file verbatim under `## Prior review carried forward`, old-format findings included, so across an uncommitted streak the file grows with the number of scans. README.md:393 says it now "grows with open findings rather than with the number of scans" without that condition. The guard predates this push, and the next run after a commit condenses normally. Confidence: high on the mechanism, low on frequency (SECURITY.md is normally committed between reviews).
  Suggested fix: Optional. Qualify the README sentence ("while SECURITY.md is committed between scans"), or migrate carried-forward findings to Status lines as well.

[NOTE] claude/skills/codefix/SKILL.md:30-36, 84-98, claude/skills/security/SKILL.md:40-43 — (also claude-code) "Run every command in the foreground" leaves two cases open. The Bash tool moves a command that passes its timeout (2 minutes by default) to the background, as claude/skills/codereview/SKILL.md:497-499 says, and neither skill says to stop it rather than wait on it, so a fork can still end its turn with background work running. And /codefix says a check too long for the foreground "is skipped and named in the report", but Step 4's template lists only fixed and skipped findings, so the check is dropped or reads as an unfixed finding (claude-code). Confidence: medium on the gap, low on occurrence (/security now runs short commands only; /codefix runs syntax checks).
  Suggested fix: Say that a command moved to the background is stopped and named as not run, and add a "Checks not run:" line to /codefix's Step 4 template.

[NOTE] claude/skills/security/SKILL.md:91-93, claude/skills/codefix/SKILL.md:73-74 — (security) The secret-history template `git log -p --follow -3 <file>` has no `--` before the path, and the path comes from the repo. A committed path starting with `--output=` makes git truncate a file the committer chooses; /security confirmed on git 2.34.1 that the command exits 128 but still empties an existing file. A name containing `$(...)`, backticks, or a single quote runs a command when pasted into the shell, and /codefix's syntax checks paste names the same way. Predates this push. The full chain (committing such a name, the model picking it as sensitive-looking) was not tested: the auto-mode classifier refused the scratch-repo commands. Confidence: high on the git behavior, low on likelihood.
  Suggested fix: Write the template as `git log -p --follow -3 -- '<file>'`, and have `codereview-marker surface` refuse names that start with `-` or hold shell metacharacters.

[NOTE] README.md:374, 582, CLAUDE.md:60 — Three figures for scan time now disagree on their face. README.md:374 gives /security a median of about 16 minutes (49 runs, three projects), CLAUDE.md:60 says about 23 minutes for a first pass, and README.md:582 says "a typical review's hour is the max-effort scan itself". 9787b0b's message reconciles them (the hour is two scans, 22 to 27 and 11 to 17 minutes, plus /codefix); the README does not. CLAUDE.md:60 also points to "the recall trade-off recorded under Skill effort levels", and that bullet records no trade-off; README.md:305 holds the rationale. Confidence: medium.
  Suggested fix: Optional. Write "a typical review's hour is mostly its two max-effort scans", and point CLAUDE.md:60 at README's effort paragraph.

[NOTE] claude/skills/codefix/SKILL.md:40-45 — (claude-code, also security; carried, re-reported) /codefix extracts every BLOCK and WARN in CODEREVIEW.md, including those under `## Prior review carried forward (uncommitted; not current findings)`. That block is a verbatim copy that never passed /codereview's Step 1 and Step 6 filters, so a stale BLOCK becomes a fix spec, and an uncommitted CODEREVIEW.md someone else left in the working tree can plant one (security). This push moved the lines only.
  Suggested fix: Have /codefix read only the current entry and skip the carried-forward block.

Carried forward from the 2026-11-07 review of 1d1b5da, still present, not re-checked this run:

[NOTE] claude/skills/codereview/SKILL.md:115-126, 148, 175 — (security, also claude-code) External-Only Mode pastes the range into shell commands: double-quoted in E.2, bare in E.3 and E.4. Git accepts `$(...)`, backticks, `;`, and `|` in branch names, so a branch someone else named can run a command. /security, on git 2.34.1 in a scratch repo: a branch `x$(touch${IFS}E2RAN)` ran `touch` inside E.2's quotes, and a branch `x;touch` passed E.2 (it resolves) and then split E.3's command at the `;`. The built-in found the benign form: a ref with spaces such as `HEAD@{2 days ago}` passes E.2's quoted check, then E.3's bare expansion splits it into three words, git fails, and the skill reports "Empty diff" for a range that has changes. Predates b8746a8. Needs external reviewers configured (E.1 stops the mode on this host). Confidence: high on the mechanism, low on likelihood.
  Suggested fix: In E.2, refuse an argument with characters outside letters, digits, and `._/~^@{}+-` (plus space for reflog dates) before running anything, then single-quote the placeholders in E.2, E.3, E.4, and `--range`, and pin both in lint.

[NOTE] claude/skills/codereview/SKILL.md:158-161, tests/lint-skills.sh:1376-1380 — E.3's scope summary ("N file(s) changed (+M / -K lines)") names no command, so the model improvises one, most likely `git diff --shortstat <range>` without `--end-of-options`. Lint's ban on a bare range matches only the literal `git diff <range>`: a `git diff --shortstat <range>` line added to the mode passes all three new checks (checked in memory). E.2 runs first and refuses a dash value, so this matters only when E.2 is skipped. Confidence: high on the gap, low on impact.
  Suggested fix: Give the command, `git diff --shortstat --end-of-options <range> -- <exclusions>`, and widen the ban to any `git diff` line whose `<range>` is not directly preceded by `--end-of-options `.

[NOTE] claude/skills/codereview/SKILL.md:119, 148, 175 — (claude-code) The E.2 and E.3 guards are still prose the model runs, which CLAUDE.md's External-only bullet says is not an enforcement boundary. A model that rebuilds the command from memory drops `--end-of-options`; lint pins the text, not the run.
  Suggested fix: Optional. Let review-external.sh (or codereview-marker) take `--range` and compute the diff itself behind its existing leading-dash check, so E.3 and E.4 sit behind one deterministic guard.

[NOTE] claude/skills/codereview/SKILL.md:148, 175 — (claude-code) `git diff --end-of-options` needs git 2.24 or later, and the repo states no git floor. On older git (Ubuntu 18.04 ships 2.17) E.3 reads the failure as an empty diff and reports "Nothing to review" for every range. Nothing else in the repo uses the flag. Every platform the README targets (Ubuntu 22.04's 2.34, current macOS and Git for Windows) is newer. Confidence: low that it matters.
  Suggested fix: Optional. State git 2.24 as the floor in README's platform section, or have E.3 distinguish a git error from an empty diff.

[NOTE] tests/lint-skills.sh:1368, 1376-1380 — (claude-code) The new checks fall back to line 1 when the External-Only Mode bounds are missing, so the negative "no bare `git diff <range>`" check passes without checking anything. The bounds check above fails explicitly in that case, and so do the two positive checks, so the suite still fails; the vacuous "ok" line is misleading only.
  Suggested fix: Optional. Wrap the three checks in the same `[[ -n START && -n END ]]` guard as the neighbouring checks.

[NOTE] claude/skills/codereview/SKILL.md:338-343 — Step 2's refresh focus set is every file changed since `reviewed_up_to`, not limited to the push diff. When the prior review predates the upstream, as here (03aacf2 is behind origin/main at c09fc07), it lists already-pushed files (README.md, bin/spec-backlog-apply.sh, the pr and spec skills) for full-depth review. The cost is extra reading, not missed review.
  Suggested fix: Optional. Define the focus set as FOCUS intersected with FULL.

Accepted Risks, reported as NOTE (deferred by the operator in 1d1b5da):

[NOTE] claude/skills/pr/SKILL.md:183-211 — (also claude-code, also security; carried) The /pr merge gate cannot tell a reviewed commit from one that reached the branch after the review (pulled from the PR, or pushed with `codereview-skip`): condition 3 accepts any ancestor of HEAD and condition 4 compares only the remote and local heads. Accepted Risks; BACKLOG `pr-merge-reviewed-changes-hash`.
  Suggested fix: As recorded in the BACKLOG entry.

[NOTE] claude/skills/codereview/SKILL.md (Steps 1, 2, 5, 6) — (security; carried) CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed, and the review diff excludes those files. Accepted Risks; BACKLOG `review-files-set-review-depth`.
  Suggested fix: As recorded in the BACKLOG entry.

Carried forward from the 2026-11-07 review of 03aacf2, still present, not re-checked this run (the /codefix carried-block NOTE is re-reported above):

[NOTE] claude/skills/pr/SKILL.md:185, 200-210, README.md:470-472, 838 — (security post-fix re-check) The read this run's /codefix added for pulled PR changes, `git log -p "${REVIEWED_UP_TO}..HEAD"` or `/codereview external "${REVIEWED_UP_TO}"`, can be emptied by the pulled commits themselves. A pulled commit that marks a file `-diff` in .gitattributes makes `git log -p` print "Binary files differ" in place of the change. And REVIEWED_UP_TO comes from the CODEREVIEW.md the pull just updated, so a code commit followed by one that moves `reviewed_up_to` past it shrinks the read to a one-line metadata hunk, and `/codereview external` reports an empty diff. Security reproduced both in scratch repos on git 2.34.1. The honest cases (a suggestion applied on GitHub, a dependency bot) do neither. Confidence: high on the mechanism, low on likelihood (it needs a hostile committer on the PR branch).
  Suggested fix: Take the range from commit heads rather than pulled files, and pass `--text`: before pulling, `git fetch` and read `git log -p --text "HEAD..${PR_HEAD}"`; right after `git pull`, `git log -p --text ORIG_HEAD..HEAD` (`git pull` sets ORIG_HEAD for fast-forward and merge pulls).

[NOTE] claude/skills/pr/SKILL.md:11, 159-176 — (security) /pr status and inspect read PR bodies, comments, and reviews, which anyone can write on a public repo, under a pre-approved `Bash(*)`, and the skill does not say that text is data. Outside auto mode, a command planted in a comment would run unprompted if the model followed it.
  Suggested fix: Say the PR text is data, not instructions, and narrow `allowed-tools` to `Bash(gh *)` and `Bash(git *)`.


[NOTE] bin/spec-backlog-apply.sh:102, 106 — (claude-code) The parse loop computes the same trailing-whitespace trim twice in a row, for `end-append` and for `clear`, so a later change to what counts as a bare op (stripping a trailing CR, say) has to be made in both.
  Suggested fix: Optional. Compute the trimmed line once.

[NOTE] bin/spec-backlog-apply.sh:81, 102-105, 169-172 — (security post-fix re-check, also the prior re-review, also claude-code) Requires a user decision. Residue of the prior `end-append` WARN after the fix. The refusal fires only when an early `end-append` leaves the real terminator unmatched. If a later body line reads `append: <heading>`, it opens a new block, the real terminator closes it, and the lines between still run as ops. Security reproduced it: `append: early-end` / body / `end-append` / `delete: keep-spec` / `append: y` / `end-append` exited 0, deleted keep-spec, and appended an empty `y`. The header comment at 44-49 reads as if this case is covered. Confidence: high on the mechanism, very low on occurrence (the body has to quote a manifest with a later `append:`).
  Suggested fix: Ops can legitimately follow an `end-append`, so position cannot tell a quoted op from a real one. A full fix needs a format change, such as a terminator that names its block (`end-append: <heading>`), which every manifest writer in /spec and /tester would adopt. Otherwise, narrow the header comment to the case the refusal covers.

[NOTE] claude/skills/pr/SKILL.md:225-233 — (security, re-checked at 03aacf2) This host has gh 2.4.0 (Ubuntu 22.04's package), which has no `--match-head-commit`, so the skill skips the flag and the race between the head check and `gh pr merge` stays open here. hw-bootstrap.sh installs gh from GitHub's repo only when none is present.
  Suggested fix: When the flag is missing, merge through the REST API, which checks the head on any gh version: `gh api -X PUT "repos/{owner}/{repo}/pulls/${PR_NUMBER}/merge" -f merge_method=squash -f sha="$(git rev-parse HEAD)"`. Or stop and ask the user to upgrade gh.

[NOTE] claude/skills/spec/SKILL.md:703-713, 717-719, tests/lint-skills.sh:984-987 — The Format rules list the missing-`end-append` and empty-heading errors but not the stray-`end-append` refusal, and the rule at 717-719 still says lines that are not an op are ignored outside a block. Lint pins the other two refusal messages but not this one. The behavioral test covers it, and a skill that sees the error stops and reports it.
  Suggested fix: Optional. Add the refusal to the Format rules and a `has` pin on `end-append outside an append block`.

[NOTE] bin/spec-backlog-apply.sh:155-167 — (claude-code) The clear-only guard counts only ops that parsed. A malformed op the parser drops (`adopt: foo|2026-05-01` without spaces around `|`, an empty `delete:`, a typo such as `delet: x`) does not count, so a stray `clear` beside only such lines still empties the register. It needs two mistakes in one manifest. Confidence: high on the mechanism, low on occurrence.
  Suggested fix: Refuse clear when any non-blank line other than `clear` sits outside an append block. The Format rules say unknown lines are ignored, so this narrows that rule for clear manifests only.

[NOTE] claude/skills/codereview/SKILL.md:566-572 — (claude-code, also security; security re-checked at 03aacf2) Requires a user decision. Sending findings outside the diff to /codefix (500153c, a deliberate choice) has two costs. A fix in a file the push does not touch bundles an unrelated change, against global-claude.md's "change only what is necessary" and Step 4's mixed-concern check (claude-code). And a carried finding's suggested fix is repo content (the prior CODEREVIEW.md entry, or a SECURITY.md finding carried without re-check), so a commit by someone else could plant a fix that lands outside its visible diff, with only the post-fix /security re-check and the re-review as filters (security).
  Suggested fix: Send a carried finding to /codefix only after this run confirms it against the code, with a fix the run derives itself.

[NOTE] claude/skills/spec/SKILL.md:258-260 — (claude-code) Step 3d's fallback for an invalid SPEC_META date, "the commits since SPEC.md last changed", usually starts after the turn's work, because evolve mode commits criterion check-offs to SPEC.md, so the proposal sees little or no history. It applies only when the date fails the format check.
  Suggested fix: Fall back to the commits since the SPEC.md commit that introduced the current entry, or skip the history and say so.

[NOTE] claude/skills/pr/SKILL.md:186-187 — (claude-code, reported again this run) PR_HEAD takes two gh calls; `gh pr view --json headRefOid --jq .headRefOid` returns the same SHA in one. When the branch has no PR, PR_NUMBER is empty, the second call hits the list endpoint, and jq fails, so the user is told to run /codereview rather than that there is no PR. The check still fails closed. The lint pin at tests/lint-skills.sh:101 fixes the longer form.
  Suggested fix: Optional. Use `headRefOid` and update the pin.

[NOTE] bin/spec-backlog-apply.sh:11-20, claude/skills/spec/SKILL.md:672-680 — The script's "Invocation:" example and the skill's Manifest format block list `clear` together with every other op, a manifest the script now refuses. The rules under each say clear runs alone.
  Suggested fix: Optional. Show `clear` as its own one-line manifest in both.

[NOTE] bin/spec-backlog-apply.sh:266, 366 — (security, carried from the 897b1a7 review; also claude-code) On a CRLF BACKLOG.md, `adopt:` rewrites the heading with an LF ending and `append:` adds LF-only lines, leaving mixed endings. Matching is unaffected. The CRLF adopt test greps only the LF form, so it passes either way (claude-code). Cosmetic.
  Suggested fix: Optional. Detect a CR on the first line and write CRLF to match.

Carried forward from the 2026-11-07 review of 897b1a7, verbatim, so "this run" in them means that review. Line numbers may have shifted.

[NOTE] bin/spec-backlog-apply.sh:159, 176-178, 203, 232, 288, 324, claude/skills/spec/SKILL.md:403-405, 571 — (also claude-code, also security; carried and extended) Fence tracking differs from what a markdown renderer shows in these cases:
  - A `~~~` or indented fence holding a `### ` example truncates the header at `clear`. Every line starting with three backticks toggles the state, so a four-backtick fence holding a three-backtick one closes early, and `clear` reports 2 entries and cuts the header inside the fence (claude-code, reproduced by the built-in).
  - An unclosed fence in the header hides every entry from every op: `clear` is a silent no-op (`CLEARED: 0 entries`, exit 0), `delete:` and `adopt:` MISS, `purge-origin:` purges nothing, and `append:` writes a duplicate heading. Before 897b1a7, delete, adopt, purge, and the append check ignored fences, so for those four this is new (claude-code calls it a regression). A `delete:` or `purge-origin:` can move an unclosed body fence into the header by removing every entry above it (security). No data is lost, and the trailing `BACKLOG.md: 0 entries` line shows it.
  - A project's own `## ` line directly above the first entry is dropped as an empty theme subhead.
  - Notes under a later `## ` theme are dropped, while notes under the first theme are kept.
  - Below the first entry, a fenced `### ` or `## ` is a heading again for every op, including `count_entries`, which at origin/main ignored it.
  The Format rules and the script comment describe the `## ` stripping; Step 3f and Step 5 do not.
  Suggested fix: Say in Step 3f that empty `## ` lines above the first entry are dropped, match a closing fence by the opener's character and length, treat `~~~` as a fence, and have the script warn when the header ends inside an open fence.

[NOTE] tests/lint-skills.sh:951-965, bin/spec-backlog-apply.sh:159-329 — (also claude-code) The header-only fence rule is copied, with small variations, into six awk programs (count_entries, clear, delete, adopt, purge, append), and the lint pins count matches. The first pin counts `!fence && /^### /` against a threshold of 5, but the script has 7 matches (delete and adopt carry it twice), so removing the guard from two ops still passes; this run removed it from clear and the append check in a copy and the count was exactly 5. Its comment says "Five gated matches". The second pin (5 of 5) catches a removal but not which op lost it. The behavioral tests cover each op, so a regression would still fail the suite.
  Suggested fix: Optional. Pin each op's guard by a line unique to it, or move the rule into one awk prelude (an `is_heading()` function) that each program includes.

[NOTE] bin/spec-backlog-apply.sh:56, 143-147 — (security, carried) The symlink guard checks only the last path component. Run from inside a tracked directory link (`cd app && spec-backlog-apply.sh`, with `app` linking outside the repo), the script creates and fills BACKLOG.md outside the repo. Every skill runs it from the project root. /security re-confirmed this run that `git rev-parse --show-prefix` fails (exit 128) in that case, so the suggested check would refuse it; it would not stop a run in another repo's root.
  Suggested fix: Refuse unless `git rev-parse --show-prefix` succeeds and prints nothing. That also blocks /spec outside a git repo, which needs a decision.

[NOTE] bin/spec-backlog-apply.sh:175, 186 — (also claude-code, carried) `clear` writes through `mktemp` and `mv`, so BACKLOG.md becomes 0600. The delete, adopt, and purge paths already did this; git does not track the read bits.
  Suggested fix: Optional. `cat "$tmp" > "$BACKLOG"` keeps the mode.

Carried forward from the 2026-11-03 review, verbatim. Line numbers may have shifted. Not re-checked this run.

[NOTE] (carried forward) hooks/pre-push-codereview.sh (working tree) 78-130, 233-260 — (also security) Fix-loop limits: trade-offs the fix cycles made, which the cycle limit leaves for a later change. Hook line numbers here are in the working tree.
  (a) A word over 1,024 characters that holds both quote kinds or a backslash still stops the fallback reading for the rest of the command. Spellings only that reading catches (`>/dev/null git push`, `A="x it's y" git push`) are missed after it, as they were at origin/main and 8e8dee7. /security's real run sent a commit this way.
  (b) The heredoc tracking stops at its bounds: 16 open quoted heredocs, 16 markers on a line, and a delimiter word over 256 characters. Past them it reads the command as f564cd4 did, so a quoted terminator ending in a backslash again glues to a plain `git push` on the next line. Cycle 2 refused these; f564cd4 and origin/main did not.
  (c) `_hd_unquote` reads `<<"X'\\"`, `<<$'X\\'`, and `<<$"X\\"` differently from bash, so the push after their terminator stays hidden. /security's real run sent the commit.
  (d) Heredoc-like text such as `<<'git \'` can hide a push only when a later continued line equals it exactly, so it is reachable only on purpose.
  (e) A comment line ending in a backslash hides a prefixed push, in every version (security).
  Evidence: /security's cycle 3 fuzz, two seeds, 5,804 unique commands: of the pushes cycle 3 allows, the 143 that cycle 2 refused are all past a bound, and the 57 that f564cd4 refused are all the long-word cutoff. Confidence: high on each mechanism, low on frequency.
  Suggested fix: Read a long word's quote state in one awk pass, and model double quotes and `$'` in `_hd_unquote`. Or record these in the "Remaining limitation" comment.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:466-540, 235-266 — Over-refusals in the safe direction: `git push "$REMOTE" main`, `--force-with-lease=main:$SHA`, the unquoted `git push -u origin $(git rev-parse --abbrev-ref HEAD)`, `"$(git branch --show-current)"`, `-o "ci skip"`, a remote path with a space, a remote URL with `?` or `[` (`ssh://[::1]/repo`), and `echo $(date) git push`, which reads as a push. `NAME="O'Brien" git push` and `GIT_SSH_COMMAND="ssh -i key" git push` are refused with "run this push as its own command", which is misleading for them (re-checked this run for `"$REMOTE"` and `O'Brien`).
  Suggested fix: Name the deploy-key workaround in the push-first refusal. A quote-aware tokenizer would remove most of these.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:58-62 — (also claude-code, also security) The quoted-text false positive. f564cd4 updates BACKLOG push-gate-quoted-text-false-positive to four occurrences and narrows its revisit criterion to sessions that do not work on the gate. This run hit it once more, also in gate work (a probe setup whose heredoc held a push line). The recovery ("move that text to a file") assumes a Write tool, which a read-only agent may not have.
  Suggested fix: None beyond the BACKLOG entry.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:51-56, 179-233, 253-321 — (also claude-code, also security) Detection misses that predate this run, in the accepted "detection is heuristic" class (8e8dee7, cycle 3, and HEAD all miss them): `timeout 1.5m git push` (the numeric regex rejects decimals), `` `git push` ``, `coproc git push`, `env "FOO=1" git push`, the quoted and escaped spellings `"git" push`, `'git' push`, `\git push`, `git "push"`, `git pu\sh`, and `git $'push'` (claude-code, security), `git -c alias.p=push p`, `git submodule foreach git push`, `git {push,origin,main}`, a -C value with text after its substitution (`git -C "$(pwd)x" push`, `git -C "$(pwd)-wt" push`), a substitution in the middle of a `-c` value (`git -c "x=a$(echo hi)b" push`), escaped operators inside a word (`A=x\;y git push`, sent by /security), nested quotes in a substitution (`A="$(echo "a b")" git push`), a continued line whose quoted value holds ` #` (`git -c 'a #b' \` then `push`, claude-code; the join regex at line 82 does not know quotes, and 8e8dee7 joined no continuations), and `git --attr-source <tree> push` on git 2.40 and later, where `--attr-source` takes a separate value the walk does not list (unverified here, git 2.34.1). A statement can also run before the push inside a value the hook steps past: `` A=`./commit.sh` git push `` (claude-code), `git -c a.b=$(git commit ...) push`, and `git >"$(git commit ...; echo /dev/null)" push`. f564cd4 closed `>/dev/null git push`, `git 2>&1 push`, and `A="x it's y" git push`, which this run re-checked.
  Suggested fix: Allow a decimal at line 211, add `--attr-source` to the option list, refuse a backtick or `$(` in a prefix assignment or between git and push, keep `\;`, `\|`, `\&` inside their word with a placeholder as lines 98-102 do for `\<` and `\>`, and list the rest in the "Remaining limitation" comment.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:408-446 — (security) What remains of the target-repo gap: a target whose `core.worktree` points outside it is judged against the enclosing repo, and `git -C - push` makes `cd -P -- -` go to $OLDPWD while git enters `./-` (this run: the hook exits 0 there; git fails unless `./-` exists). f564cd4 closed `git -C "p q" push` (now refused) and stopped following a `-C` inside a quoted `-c` value. It also dropped BACKLOG push-gate-pushed-repo as closed, so these two items and the `-C` pre-approval WARN have no deferral entry.
  Suggested fix: Compare the target's `--absolute-git-dir` with the same call run from its toplevel, use `./-` for a `-` value, and record what remains in BACKLOG.md.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:78-107, 253, 341-344, 408-412, 466-471, 587-595 — (also claude-code, security) Apart from the scanner WARN above, tokenizing time grows with the square of the command length, and each check re-runs `_normalize_ops` and `_push_invocations` (about eight passes per push). /security's thresholds for short words still hold (near 400 KB, or 220 KB when operator-dense). The built-in notes that the separate copies are also why the `&>` handling in `_push_invocations` never reached the argument walks.
  /security's cycle 3 re-check adds two shapes. A line ending in a long run of backslashes costs the run's length times the line's in `slashes="${line##*[!\\]}"`, which has been there since the prior run's cycle 1: 32 KB of trailing backslashes took 26.9 s, and the shape passes 30 s near 34 KB. And the bounded heredoc tracking adds linear cost: 240 KB of quoted-marker lines with a continuation took 28.0 s, against 20.6 s at f564cd4.
  Suggested fix: Normalize once in main and pass the tokens to every function, with one shared argument walker. Count trailing backslashes with `[[ "${line}" =~ (\\+)$ ]]`, which took under 0.01 s on the same input. Add 65,600-byte and 500 KB test cases.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:751-755 — (claude-code, also security) The skip marker is resolved after the `cd` into the `-C` target, so `codereview-skip` in repo A followed by `git -C B push` is blocked and leaves A's marker armed; the next unreviewed push in A was then allowed and consumed it. A leftover skip marker at any age also passes a push of another ref, because the skip check runs before `push_sends_commits_outside_head`.
  Suggested fix: Deferred with BACKLOG skip-marker-bound-to-diff; tell the agent in the refusal that a bypass applies per repo.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:47-49, 59, 576 — (claude-code) Comments still say a false positive only costs a needless review; since the push-first rule it is a refusal. Line 59 still says the tokenizer ignores quoting, which `_word_end` now partly reads.
  Suggested fix: Update the comments.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:601 — (claude-code) The multi-push loop in `is_tag_only_push` can no longer run more than once, because `push_is_alone_and_first` runs first. Its comment still describes compounds.
  Suggested fix: Optional. Remove the loop in a later cleanup.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:185, 222, 354, 386, 488, 613 — (also claude-code) The operator list appears in six places and the copies diverge (`)` and `}` differ, and only `_push_invocations` reads `&>`); the `&&` and `||` arms cannot match after `_normalize_ops`, which pads each character.
  Suggested fix: Optional. Single-source it in a helper.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:562, 638 — (claude-code) A failing `rev-list` reads as tag-only, while `_has_commits_outside_head` fails closed on the same call.
  Suggested fix: Treat a non-zero exit as "not tag-only".

[NOTE] (carried forward) hooks/pre-push-codereview.sh:382 — (claude-code, also security) `/usr/bin/gh repo create --push` is not detected, though the walker accepts `*/git`.
  Suggested fix: Also accept `*/gh`.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:757-770, 794-844 — (claude-code) The outside-ref and uncommitted refusals do not name the `-C` target repo, unlike the no-marker refusal at line 871.
  Suggested fix: Add the same target note.

[NOTE] (carried forward) zat.env-install.sh:336-345 — (claude-code) With no `if` filter, the gate's bash and jq processes start on every Bash and PowerShell call, which costs most on Windows, where process start is slow. Not measured.
  Suggested fix: Exit at once when the command has no `push` substring, before tokenizing. Every detection the hook makes needs a `push` or `--push` token, so nothing it catches today is lost, and the hook still decides for itself.

[NOTE] (carried forward) gitconfig/ignore-global:24 — The fix covers one of two paths Claude Code 2.1.296 appends to `core.excludesfile`, and that setting points at this tracked file, so the next append again dirties the tree and the pre-push `uncommitted` check refuses every push from zat.env (also claude-code)
  Evidence: the binary's append routine has a second caller, which passes `.claude/.cc-writes/` once per session when a staging directory is set up in a repo that does not already ignore `.claude/.cc-writes/sample-file.txt`; it would append `**/.claude/.cc-writes/`. Whether that feature runs on this machine is unverified. The failure is fail-safe (the hook names the file). Confidence: high on the code path, low on when it fires.
  Suggested fix: Add `**/.claude/.cc-writes/` now, in that exact form so both of Claude Code's checks pass. The structural fix (point `core.excludesfile` at a user-owned file the installer seeds from the repo copy) changes install behavior for every adopter and requires a user decision.

[NOTE] (carried forward) gitconfig/ignore-global:24 — Nothing records why the line is there: unlike the other blocks it has no comment, and no lint check pins it. It looks redundant in this repo, whose .gitignore already ignores `.claude/`, so a later tidy-up could remove it and bring back the push refusal (claude-code)
  Evidence: gitconfig/ignore-global:23-24; .gitignore:18. Confidence: low that it matters.
  Suggested fix: Optional. A one-line comment naming Claude Code as the writer, or a sentence in CLAUDE.md's gitconfig bullet saying Claude Code appends to this file.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:4-7 — The header describes the missing `if` filter but still says the hook is installed "on Bash"; it is also registered for the PowerShell tool.
  Suggested fix: Mention the PowerShell entry.

[NOTE] (carried forward) hooks/README.md:121-127 — The manual test recipe says `echo '{}' | bash .../pre-push-codereview.sh` "should block (no marker)", but `{}` has no command, which reads as "not a push" and exits 0. Pre-existing.
  Suggested fix: Use a payload with `{"tool_input":{"command":"git push"}}`.

[NOTE] (carried forward) tests/test-pre-push-hook.sh:1304 — PATH_SANITIZED keeps jq's directory, so where jq lives in ~/bin next to codereview-marker the "codereview-marker missing" test fails falsely (loud, not silent) (also claude-code)
  Suggested fix: Build a temp directory that links only `git` and `jq`.

[NOTE] (carried forward) zat.env-install.sh:12 — `CYGWIN*` maps to windows, but Cygwin reads `CYGWIN=winsymlinks:...`, not `MSYS`, and Cygwin's own symlinks pass the `[[ -L ]]` probe while native programs such as Claude Code may not follow them (also claude-code)
  Suggested fix: Drop `CYGWIN*` from the case (Claude Code requires Git Bash), or set `CYGWIN=winsymlinks:nativestrict` as well.

[NOTE] (carried forward) zat.env-install.sh:105 — Skill directories copied by a pre-nativestrict Windows install are not symlinks, so every re-run prints "exists and is not a symlink — skipping" and leaves the frozen copies; ~/.claude/CLAUDE.md and ~/bin entries are replaced (claude-code)
  Suggested fix: On Windows, tell the user to delete the copies, or replace a directory whose contents match the repo skill.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:666 — The CR fix is repeated per consumer (hook, installer `tr -d '\r'`, windows.md advice); `jq -b` stops CRLF at the source (claude-code)
  Suggested fix: Optional. Verify the oldest supported jq accepts `-b` first (Ubuntu 22.04 ships jq 1.6; `--binary` may be newer, confidence low).

[NOTE] (carried forward) zat.env-install.sh:397 — The shadow warning compares path strings, so an earlier PATH entry that is another spelling of ~/bin (a symlinked HOME) warns about a copy that does not exist (claude-code)
  Suggested fix: Compare with `[[ "${FOUND_MARKER}" -ef "${BIN_DIR}/codereview-marker" ]]`.

[NOTE] (carried forward) bin/review-external.sh:276-278 — (security) Without `bc`, the cost expression is pasted into the awk program text, where `system()` would run; `_count` and the price literals are the only guard, and the hostile-value test covers only OpenAI `input_tokens`. The awk branch runs only on hosts without bc, so on Linux only the lint pin covers it.
  Suggested fix: Pass the operands with `-v` and keep the expression fixed, or add hostile-value tests for every token count; add a test that shadows `bc` so the awk branch runs everywhere.

[NOTE] (carried forward) hooks/pre-push-codereview.sh:260 — (security) `git.exe push`, `"/c/Program Files/Git/cmd/git.exe" push`, and `GIT push` (case-insensitive filesystems) are not gated: the walker recognizes only a bare `git` token or a path ending in /git. The Windows form of the absolute-path case in the accepted "detection is heuristic" risk (also claude-code)
  Suggested fix: Requires a user decision: accept it under the existing risk, or compare the token's basename with `git` or `git.exe`.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:238, 471 — (security) A `.gitattributes` `-diff` or `binary` attribute on a text file shows it as "Binary files differ" to the inline and external reviewers; the marker hash still covers its content, so the gate holds
  Suggested fix: Add `--text` (or `-a`) to the review diffs.

[NOTE] (carried forward) bin/codereview-marker:131 — `in_surface` keeps agent-instruction markdown only by filename or a `.claude/` path, so a skill's `references/*.md` and `claude/references/*.md` (read through global-claude.md) count as plain docs (claude-code, also security)
  Suggested fix: Also keep `*/references/*.md` and markdown under zat.env's `claude/` tree, or invert the rule and drop only known prose paths (README*, docs/, CHANGELOG*).

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:274 — The prose lists of agent-instruction markdown in Step 2 and Step 5 (line 395), and README, omit CLAUDE.local.md, which `in_surface` keeps (claude-code)
  Suggested fix: Add CLAUDE.local.md to both prose lists and README.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:597 — `git stash create` and `codereview-marker surface <PRE_FIX>` ignore untracked files, so a codefix edit to a new untracked file gets no post-fix /security pass (claude-code)
  Suggested fix: Soften the sentence to tracked changes, or list untracked files changed since PRE_FIX as well.


[NOTE] (carried forward) claude/skills/codereview/SKILL.md:460 — (security) The secret-in-diff guard depends on a step that reports secrets, and in a full-tier review no step looks in plain markdown, so a key added to a README beside a code change still goes to OpenAI and Google
  Suggested fix: Grep the exact Step 5.5 diff for key patterns before sending.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:405 — (security) The model pastes SECURITY_META's commit value into `codereview-marker surface <meta-commit>`, so a planted `$(...)` would run before the script's leading-dash check
  Suggested fix: Extract the commit inside the command with a hex-only `grep -oP`, and update the lint pin.

[NOTE] (carried forward) claude/skills/pr/SKILL.md:152 — (security) The PR template passes commit-derived text in double-quoted `--title`/`--body` arguments, where backticks or `$(...)` run as commands
  Suggested fix: Write the body with a quoted heredoc and pass `--body-file`.

[NOTE] (carried forward) claude/skills/spec/SKILL.md:8 — (security) /spec is inline and model-invocable, and its `allowed-tools` grants unprompted Bash(*), Write, and Edit for the rest of the invoking turn. Confidence: medium.
  Suggested fix: Narrow /spec's grant and let Write and Edit fall to the session's rules.

[NOTE] (carried forward, security) hooks/pre-push-codereview.sh, bin/codereview-marker — BACKLOG-deferred gate gaps: the skip marker never expires and is not tied to a diff (skip-marker-bound-to-diff); marker_dir ignores mkdir/chmod failure and checks no owner or symlink, and `chmod` does nothing on Windows (marker-dir-ownership-check); a secret committed then deleted in the pushed range is never reviewed (push-gate-net-diff-secret).
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

[NOTE] (carried forward, security) zat.env-install.sh:200, 213 — Each settings.json rewrite moves a new .tmp file into place, so a 0600 settings.json returns at the default umask (same at every later rewrite). Not reachable on this host (home 0750, no other group members)
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

[NOTE] (carried forward) zat.env-install.sh:227 — Deny entries accumulate across installs; deliberate, since deny entries only narrow.
  Suggested fix: None needed.

Resolved by this push:
- [WARN] README.md:582 — "forked skills never wait on background work" now reads "`/security` and `/codefix` never wait on background work" (this run's /codefix, uncommitted).
- [NOTE] claude/skills/codereview/SKILL.md:339 (carried from 2026-11-03) — /security's verification runs overlapping the project's test suite: 9787b0b stops /security from running the project's suites, which was the overlap that could collide. Short single-fact commands remain and are not expected to collide.
- [NOTE] b8746a8 bundling two review follow-ups (2026-11-07): the commit is now on origin/main, so there is nothing left to split.

### Fixes Applied

- [WARN] README.md:582 — Replaced "forked skills never wait on background work" with "`/security` and `/codefix` never wait on background work", matching CLAUDE.md:60. Uncommitted.

### Accepted Risks

- **`/pr merge` cannot tell reviewed commits from later ones** (claude/skills/pr/SKILL.md, review gate conditions 3 and 4): a commit pulled from the PR after the review, or pushed with `codereview-skip`, passes the gate. The skill and README state the gap and name a read for pulled changes. Deferred 2026-11-07 to BACKLOG `pr-merge-reviewed-changes-hash`.
- **Review files decide review depth** (claude/skills/codereview/SKILL.md, Steps 1, 2, 5, and 6): CODEREVIEW.md and SECURITY.md edits inside the reviewed commits can anchor a refresh, mark findings accepted, or skip a security scan, and the review diff excludes those files. Needs a hostile committer in the reviewed range. Deferred 2026-11-07 to BACKLOG `review-files-set-review-depth`.
- **Gate follows `git -C <path>` before approval** (hooks/pre-push-codereview.sh, `enter_push_target`): the hook runs `git diff` in the repo a `-C` names before the command is approved, so that repo's config (`core.fsmonitor`, `diff.external`) chooses what runs. Accepted 2026-11-07, following the 2026-11-03 decision to stop patching the tokenizer: the next gate change is the heredoc-aware rewrite (BACKLOG `push-gate-quoted-text-false-positive`). If revisited, pinning `-c core.fsmonitor= -c diff.external=` on the hook's git calls is the small mitigation.
- **Gate judges only refs spelled on the command line** (hooks/pre-push-codereview.sh): fetched refs, refs chosen by config (`remote.<name>.push`, `push.default=matching`), git's abbreviated options, `--repo -d`, `--mirror`, and `--recurse-submodules=on-demand` can still send unreviewed commits. Accepted 2026-11-07 under the advisory-gate threat model of the detection entry below; a git-native pre-push hook, which receives the exact refs, is the structural fix.
- **No `onFailure: block` on the gate entries** (zat.env-install.sh): a hook that times out, crashes, or cannot start lets the command through. Accepted 2026-11-07: the hook runs on every shell command, so `block` would refuse every shell command while the script is missing, including the ones needed to fix it.
- **Submodule `ignore = all` hides pointer changes** (bin/codereview-marker): the marker hash, the uncommitted check, the security surface, and the review diff all miss a pointer change in such a submodule. Accepted 2026-11-07: zat.env has no submodules, and the setting has to be chosen in the repo's own config.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-11-07, commit 1d1b5da): Refresh review of b8746a8 (External-Only Mode range after `--end-of-options`, hooks/README Monitor matcher) and 1d1b5da (two BACKLOG deferrals moved to Accepted Risks). No /codefix cycle; it left 0 BLOCK / 1 WARN (global-claude.md:108, held for a user decision) / 92 NOTE.*

<!-- REVIEW_META: {"date":"2026-11-12","commit":"721b632","reviewed_up_to":"721b63214433918519a515129456221b51294e86","base":"origin/main","tier":"refresh","block":0,"warn":1,"note":98} -->
