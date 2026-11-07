## Review — 2026-11-07 (commit: 895c3d3)

**Summary:** Refresh review of the seven commits on main not on origin/main (5cd6836 through 895c3d3). The focus set equals the full set (12 files), so every file got full-depth review. The changes route the /spec turn-close capture through `spec-backlog-apply.sh`, make `clear` refuse to run beside other ops, gate the Monitor tool, narrow the light review tier, tighten refresh detection, add a PR-head check to `/pr merge`, send findings outside the diff to /codefix, and record v1.6 in README. One /codefix cycle fixed four WARNs, uncommitted in the working tree; three WARNs remain, each needing a user decision.
- **Security.** /security scanned the 11 surface files changed since its last scan (431af78): 0 BLOCK, 3 WARN, 20 NOTE, no secrets. Its post-fix re-check of the six files /codefix changed added one NOTE (21 total). SECURITY.md is updated and uncommitted.
- **Tests.** tests/run-all.sh: 1201/1201 before the fixes, 1204/1204 after (three new checks for the stray `end-append` refusal).
- **Act now (operational, not a code finding).** The Monitor gate takes effect only after re-running `zat.env-install.sh` and restarting open sessions. /security found the live `~/.claude/settings.json` still has `"matcher": "Bash"` and the CLI at 2.1.311, and a dry-run push through Monitor in this session exited 0. A headless 2.1.311 run with the new `Bash|Monitor` matcher did fire the hook.
- **Uncommitted.** The four fixes, CODEREVIEW.md, and SECURITY.md are uncommitted. The push gate refuses a push while tracked files other than the review files have uncommitted changes, so commit the fixes before pushing.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 9 findings, 9 kept after Step 6. Three merged with this review's own findings, one merged with /security's /pr merge WARN, five new (one WARN, four NOTEs).

### Findings

No BLOCK findings. Four WARNs found this run were fixed by /codefix (see Fixes Applied).

Open this run:

[WARN] claude/skills/pr/SKILL.md:183-201, README.md:466-468, 834 — (also claude-code, also security; carried and narrowed) Requires a user decision; not for /codefix. 13b67ba's condition 4 refuses a PR whose GitHub head differs from local HEAD, but the gate still merges commits no review covered in two cases, and README and the skill's rationale overstate it ("a commit added on GitHub after the review cannot merge with it", "Local commits reach the PR through the pre-push gate"):
  - A commit added on GitHub (a suggestion, a bot, a collaborator) that the user then pulls: PR_HEAD equals HEAD, and REVIEWED_UP_TO is still an ancestor. A fresh /codereview does not help, because the commit is already upstream and the review diff is empty (security reproduced this with the skill's own commands).
  - A commit pushed through `codereview-skip` after the last review (claude-code).
  Evidence: condition 3 accepts any ancestor of HEAD; condition 4 compares only the remote and local heads. Confidence: high.
  The choice: requiring REVIEWED_UP_TO to equal HEAD breaks the normal flow, where /codefix's fixes and the review files are committed after the review. Recording a hash of the reviewed changes in REVIEW_META and comparing it at merge time (security's suggestion) closes both cases but adds a REVIEW_META field and a /pr contract. Narrowing the README and skill wording to what condition 4 catches is the third option.

[NOTE] bin/spec-backlog-apply.sh:81-147 — (security post-fix re-check, also this run's re-review) Requires a user decision. Residue of this run's `end-append` WARN after the fix. The new refusal fires only when an early `end-append` leaves the real terminator unmatched. If a later body line reads `append: <heading>`, it opens a new block, the real terminator closes it, and the lines between still run as ops. Security reproduced it: `append: early-end` / body / `end-append` / `delete: keep-spec` / `append: y` / `end-append` exited 0, deleted keep-spec, and appended an empty `y`. The header comment at 44-49 reads as if this case is covered. Confidence: high on the mechanism, very low on occurrence (the body has to quote a manifest with a later `append:`).
  Suggested fix: Ops can legitimately follow an `end-append`, so position cannot tell a quoted op from a real one. A full fix needs a format change, such as a terminator that names its block (`end-append: <heading>`), which every manifest writer in /spec and /tester would adopt. Otherwise, narrow the header comment to the case the refusal covers.

[NOTE] claude/skills/pr/SKILL.md:222-230 — (security post-fix re-check) This host has gh 2.4.0 (Ubuntu 22.04's package), which has no `--match-head-commit`, so the skill skips the flag and the race between the head check and `gh pr merge` stays open here. hw-bootstrap.sh installs gh from GitHub's repo only when none is present.
  Suggested fix: When the flag is missing, merge through the REST API, which checks the head on any gh version: `gh api -X PUT "repos/{owner}/{repo}/pulls/${PR_NUMBER}/merge" -f merge_method=squash -f sha="$(git rev-parse HEAD)"`. Or stop and ask the user to upgrade gh.

[NOTE] claude/skills/spec/SKILL.md:707-712, tests/lint-skills.sh:984-987 — (re-review of the fix) The Format rules list the missing-`end-append` and empty-heading errors but not the new stray-`end-append` refusal, and lint pins the other two refusal messages but not this one. The behavioral test covers it, and a skill that sees the error stops and reports it.
  Suggested fix: Optional. Add the refusal to the Format rules and a `has` pin on `end-append outside an append block`.

[NOTE] bin/spec-backlog-apply.sh:148, 157-160 — (claude-code) The clear-only guard counts only ops that parsed. A malformed op the parser drops (`adopt: foo|2026-05-01` without spaces around `|`, an empty `delete:`, a typo such as `delet: x`) does not count, so a stray `clear` beside only such lines still empties the register. It needs two mistakes in one manifest. Confidence: high on the mechanism, low on occurrence.
  Suggested fix: Refuse clear when any non-blank line other than `clear` sits outside an append block. The Format rules say unknown lines are ignored, so this narrows that rule for clear manifests only.

[NOTE] claude/skills/codereview/SKILL.md:566-572 — (claude-code, also security) Requires a user decision. Sending findings outside the diff to /codefix (500153c, a deliberate choice) has two costs. A fix in a file the push does not touch bundles an unrelated change, against global-claude.md's "change only what is necessary" and Step 4's mixed-concern check (claude-code). And a carried finding's suggested fix is repo content (the prior CODEREVIEW.md entry, or a SECURITY.md finding carried without re-check), so a commit by someone else could plant a fix that lands outside its visible diff, with only the post-fix /security re-check and the re-review as filters (security).
  Suggested fix: Send a carried finding to /codefix only after this run confirms it against the code, with a fix the run derives itself.

[NOTE] claude/skills/spec/SKILL.md:258-260 — (claude-code) Step 3d's fallback for an invalid SPEC_META date, "the commits since SPEC.md last changed", usually starts after the turn's work, because evolve mode commits criterion check-offs to SPEC.md, so the proposal sees little or no history. It applies only when the date fails the format check.
  Suggested fix: Fall back to the commits since the SPEC.md commit that introduced the current entry, or skip the history and say so.

[NOTE] claude/skills/pr/SKILL.md:186-187 — (claude-code) PR_HEAD takes two gh calls; `gh pr view --json headRefOid --jq .headRefOid` returns the same SHA in one. When `gh pr view` fails, PR_NUMBER is empty and the second call reports a jq error rather than "no PR". The check still fails closed. The lint pin at tests/lint-skills.sh:101 fixes the longer form.
  Suggested fix: Optional. Use `headRefOid` and update the pin.

[NOTE] bin/spec-backlog-apply.sh:11-20, claude/skills/spec/SKILL.md:672-680 — The script's "Invocation:" example and the skill's Manifest format block list `clear` together with every other op, a manifest the script now refuses. The rules under each say clear runs alone.
  Suggested fix: Optional. Show `clear` as its own one-line manifest in both.

[NOTE] README.md:808, 826 — README says "v1.6 is the most recent tag" and adds a Done (v1.6) section, but no v1.6 tag exists locally or on origin. It is correct once the tag is cut. Confidence: low that it matters.
  Suggested fix: None if the tag follows this push.

[NOTE] bin/spec-backlog-apply.sh:254, 354 — (security, carried from the 897b1a7 review) On a CRLF BACKLOG.md, `adopt:` rewrites the heading with an LF ending and `append:` adds LF-only lines, leaving mixed endings. Matching is unaffected, and b47852a's CRLF tests now cover delete, adopt, and the append check. Cosmetic.
  Suggested fix: Optional. Detect a CR on the first line and write CRLF to match.

Resolved by this push:
- The Monitor WARN (zat.env-install.sh): 1608332 registers the gate as `Bash|Monitor`, and README says the stable channel can downgrade an install. Pending the reinstall in the Summary.
- The light-tier WARN: 13b67ba limits the light tier to plain `.md` and `.gitignore`.
- The /pr merge WARN: narrowed by 13b67ba to the WARN above.
- The 431af78 review's three NOTEs: caller lists (b47852a), CLAUDE.md:62's scope, and the turn-close capture, which now appends through the script (5cd6836).
- The 897b1a7 review's NOTEs on the unchecked `mktemp`, SPEC.md dates in `git log`, the stray `clear` and the empty `append:` heading (the residue is the `end-append` and clear-guard NOTEs above), the tester role and D.2's bound, `propose` routing, `/spec new` in the escape hatch, the TESTER_D7 range, and the CRLF test gap.
- The four gate WARNs 1608332 moved to Accepted Risks. They are listed there and not re-reported.

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

Carried forward from the 2026-11-03 review, verbatim. zat.env-install.sh and claude/skills/codereview/SKILL.md changed in this push, so line numbers there have shifted. /security re-checked the review-files WARN and four NOTEs (the /spec tool grant, the installer's settings.json mode, three codereview prompt NOTEs, /pr create quoting) this run; the rest were not re-checked.

[WARN] (carried forward) claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — (security) Requires a user decision; not for /codefix. CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed, and the review diff excludes those files (carried, not re-checked).
  Suggested fix: Take the full tier and read prior META from the base when a commit not authored by the operator touched the review files.

[WARN] (carried forward) claude/global-claude.md:108 — (security) Requires a user decision; not for /codefix. The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW. The rule also loads on Windows, where windows.md says networking.md (the only place the firewall assumption is written) does not apply (carried, not re-checked).
  Suggested fix: Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW; scope the rule to the Linux box.

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

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:339 — /security starts before Step 3, so its verification runs can overlap the project's test suite. Confidence: low.
  Suggested fix: None now; revisit if a downstream test run collides with a /security reproduction.

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

### Fixes Applied

One /codefix cycle, uncommitted in the working tree:
- [WARN] claude/skills/spec/SKILL.md:96, 258, tests/lint-skills.sh:899, 904 — (claude-code) `git log --since='YYYY-MM-DD'` read the date at the current time of day, so commits made earlier that day were left out (reproduced: 0 commits against 13 at midnight). Both sites now use `--since='YYYY-MM-DD 00:00'`, and both lint pins match.
- [WARN] claude/skills/codereview/SKILL.md:608-612, 656-659 — (also claude-code) Step 7 now invokes /codefix, and starts another cycle, only when a BLOCK or WARN not marked `Requires a user decision; not for /codefix.` is open, so held findings no longer run up to three no-op cycles.
- [WARN] claude/skills/pr/SKILL.md:222-230 — (also claude-code) The `--match-head-commit` instruction now comes before the merge block and says to add the flag to the `gh pr merge` line before `git checkout main`.
- [WARN] bin/spec-backlog-apply.sh:43-49, 81, 102-105, 169-172, tests/test-spec-backlog-apply.sh:547-570 — (also claude-code, also security) A manifest with an `end-append` line outside an append block is refused (exit 1, nothing changed), which catches a body line that ended its block early when the real terminator follows. Three new checks cover it. The case where a later body line opens a new `append:` block is the residual NOTE above.

### Accepted Risks

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
*Prior review (2026-11-07, commit 431af78): Refresh review of 431af78, which changed only documentation and a script comment. No fix loop ran. It left 0 BLOCK / 9 WARN / 81 NOTE, all needing a user decision or informational; its three new NOTEs are resolved by this push.*

<!-- REVIEW_META: {"date":"2026-11-07","commit":"895c3d3","reviewed_up_to":"895c3d3964d2ebe4d26bd2ccad67e75013eb3873","base":"origin/main","tier":"refresh","block":0,"warn":3,"note":80} -->
