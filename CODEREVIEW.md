## Review — 2026-11-03 (commit: 8e8dee7)

**Summary:** Refresh review of the 7 unpushed commits (78c6fa1 through 8e8dee7): pre-push gate hardening (push first and alone, `-C` targets, refs outside HEAD, tag pushes, `gh repo create --push`, prefixes before git), removal of the gate's `if` filter, opt-in docker group, the stable update channel seed, and docs. The focus set equalled the full set, so every changed file got full depth. Three /codefix cycles then changed hooks/pre-push-codereview.sh, its tests, hooks/README.md, tests/lint-skills.sh, and CLAUDE.md; those changes are uncommitted and are covered by this review and the marker. tests/run-all.sh went from 933/933 to 1041/1041 across 6 suites, and shellcheck is clean on the hook. No BLOCK. The fixes close many more bypasses than they open, but seven unusual spellings the committed hook refused now pass (first WARN). Seeding the stable channel rolled this host's CLI back past a hook fix (second WARN).

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 16 findings (10, plus 6 named below its cap), all kept after Step 6: 8 merged with inline or /security findings, 1 WARN of its own (a comment before a push read as a statement, fixed in cycle 1), 7 NOTEs. One claim was refuted: that large heredocs used to skip the hook (1a85d54 records that live settings had no `if` filter). Its execution was denied, so it traced by hand; this run reproduced each kept claim by running the hook.

### Findings

No BLOCK findings.

[WARN] hooks/pre-push-codereview.sh:77-106, 138-153, 177-212, 353-397 — (also security) Requires manual intervention: the fix loop reached its 3-cycle limit. Seven spellings that the committed hook sends to review now pass with an unreviewed commit (head=2, now=0, each re-run on the final tree). From cycle 1's `<`/`>` padding: `A=x>y git push`, `git -c a.b=c>d push`, and `git -C .>log push`, where a glued, unquoted redirection splits the word so git reads as an argument. From cycle 1's redirection arm with cycle 2's `#` break: `git push origin main > "log #1" feature`, where the walk steps over the redirection target and then reads `#1"` as a comment, so `feature` is never checked. From cycle 3's span skip, which counts quotes per word rather than by kind: `git -c "user.name=O'Brien -x" push`, `git -c "x.y=it's -c z.w=1" push`, and `A="x -y'z -w" git push`. /security sent commits to scratch remotes with these spellings. Confidence: high on the mechanism, low on how often an agent writes them.
  Evidence: three-way runs against the committed hook, each cycle's stash, and the working tree.
  Suggested fix: Before committing, either fix these or accept them under the "detection is heuristic" risk. The cycle 3 /security re-check left an unreviewed five-hunk patch at `/tmp/claude-1000/-home-peter-src-zat-env/d4b2404e-6c86-42de-80b2-9933212c5bb1/scratchpad/postfix3/candidate.diff` (scratchpad, session-scoped). It covers the glued redirections and the redirection-target `#`, and its suite run passed 296/296. Review it the way this run reviewed the cycle 2 candidate, whose argument-walk hunks added a bypass. The mixed-quote spans need quote tracking character by character, which is the quote-aware tokenizer of BACKLOG push-gate-quoted-text-false-positive.

[WARN] zat.env-install.sh:213, 336-345 — (security) Requires a user decision. Seeding `autoUpdatesChannel` to stable rolled this host's CLI back from 2.1.317 to 2.1.311, which predates a hook fix, and the installer registers no Monitor entry. New with 4132078. The 2.1.314 changelog reads "Fixed hooks matching Bash not running on shell commands started by the Monitor tool", so a new session on 2.1.311 likely runs a push through Monitor ungated, with no unusual spelling.
  Evidence: verified this run: `~/.local/bin/claude` links to versions/2.1.311 with mtime 06:18 on 2026-11-03, settings.json (mtime 05:38) has `autoUpdatesChannel: "stable"` and no `minimumVersion`, and the changelog line sits under 2.1.314. NOT reproduced on 2.1.311: /security's three probes stopped at the spend limit before any model call. On this session's 2.1.317 the gate refused a Monitor probe. This answers the question 4132078's message left open. Confidence: high on the rollback, medium on the bypass.
  Suggested fix: Choose one or both: seed `minimumVersion` to 2.1.314 or later beside the channel, which also stops the rollback; or add a `"matcher": "Monitor"` gate entry and pin it in lint, after checking that two matching entries do not run the hook twice and burn a skip marker. Say in README's settings bullet that the setting can downgrade an install. To finish the probe: `bash /tmp/claude-1000/-home-peter-src-zat-env/d4b2404e-6c86-42de-80b2-9933212c5bb1/scratchpad/t15-monitor-probe.sh 2.1.311 v311`.

[WARN] hooks/pre-push-codereview.sh:297-333, 577, 674 — (also security) Requires a user decision. Following `git -C <path>` makes the hook run `git diff` in a directory named by the command before the command is approved, and that repo's config names what `git diff` executes. New with 49ecf37. Cycle 1's no-working-tree refusal stops a bare layout before `git diff` runs, but a layout with `core.worktree = .` still runs the payload.
  Evidence: a scratch repo's `diff.external` and `core.fsmonitor` each created a sentinel while the hook exited 2. /security reproduced it through a plain `git clone` of a bare-repo layout tracked as ordinary files, and with `filter.<x>.clean` and `diff.<x>.textconv`. An approved `git -C <dir> diff` runs the same payload, so what is lost is the approval step for this one command in auto mode; that the hook runs before the classifier comes from the docs and was not observed. Confidence: high on the mechanism, low on how often an agent is steered there.
  Suggested fix: Refuse a `-C` target whose toplevel is not the session's, so a person decides to work there, which gives up part of 49ecf37. To also close the cwd route, pass `--no-ext-diff --no-textconv` and config overrides in bin/codereview-marker and refuse a repo whose local config defines `filter.*`.

[WARN] hooks/pre-push-codereview.sh:338-344, 353-425 — (also claude-code, security) Requires a user decision. The gate judges only refs spelled on the command line and counts any remote-tracking ref as already gated, so these still send unreviewed commits: fetched refs (`git push origin origin/contrib:main`, `fork/evil:refs/heads/main`), a branch tracking a local upstream, config-chosen refs (`remote.origin.push` or `push.default=matching`, in config or through `-c`), `git push origin HEAD~1:main` under a valid marker, and git's abbreviated options and `--repo=` (`git push --al`, `--mir`, `--repo=origin feature`). Narrowed by 49ecf37 and the fix cycles, which close `git push origin <other>`, `<other>:main`, `:`, shell-expanded names, braces and globs, quoted values, continuations, and tags on trees or blobs.
  Evidence: real pushes by /security to scratch remotes; `remote.origin.push`, `--al`, and `--repo=` confirmed this run (exit 0). Confidence: high on the mechanism, medium on frequency for fetched branches.
  Suggested fix: Count a commit as gated only when the pushed remote's tracking ref for the destination has it, or move to a git-native pre-push hook (core.hooksPath). That hook receives the exact refs and would close most gate findings together, but it also fires on terminal pushes and overrides per-repo hooks.

[WARN] zat.env-install.sh:331-346 — (security) Requires a user decision. A hook that times out, crashes, or cannot start does not block the tool call, and neither gate entry sets `"onFailure": "block"`. On Linux at the final tree: a moved checkout exits 127, an unreadable marker makes `cat` at hooks/pre-push-codereview.sh:707 exit 1, and a long command outlasts the 30 s timeout. Since 1a85d54 the hook runs on every shell command, so `block` would refuse every shell command while the script is missing, including the ones needed to fix it.
  Evidence: SECURITY.md 2026-11-03; the hooks docs say a timed-out PreToolUse hook does not block.
  Suggested fix: An EXIT trap, set once a push is recognized, can turn a crash into a refusal without that cost. Add `"onFailure": "block"` only if the every-command cost is acceptable.

[WARN] bin/codereview-marker:156, 167, 173, 177 — (security) Requires a user decision. A submodule with `ignore = all` hides its pointer changes from `git diff`, so the marker hash, the uncommitted check, the security surface, and the review diff all miss them (carried, not re-checked).
  Suggested fix: Add `--ignore-submodules=dirty` to the script's diffs and the codereview skill's review diffs.

[WARN] claude/skills/pr/SKILL.md:184-191, 217 — (security) Requires a user decision. /pr merge accepts a review of any ancestor of local HEAD and never compares the remote PR head with local HEAD (carried, not re-checked).
  Suggested fix: Require no non-review-file change since `reviewed_up_to` and a remote head equal to local HEAD.

[WARN] claude/skills/codereview/SKILL.md:269-277 — (security) Requires a user decision. The light tier still treats `.txt` and `.gitconfig` as plain documentation, so a diff limited to `gitconfig/aliases.gitconfig` or a downstream `requirements*.txt` or `CMakeLists.txt` skips /security, tests, and external reviewers (carried, not re-checked).
  Suggested fix: Drop `.txt` and `.gitconfig` from the light tier, and update README and the lint pin.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — (security) Requires a user decision. CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed, and the review diff excludes those files (carried, not re-checked).
  Suggested fix: Take the full tier and read prior META from the base when a commit not authored by the operator touched the review files.

[WARN] claude/global-claude.md:108 — (security) Requires a user decision. The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW. The rule also loads on Windows, where windows.md says networking.md (the only place the firewall assumption is written) does not apply (carried, not re-checked).
  Suggested fix: Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW; scope the rule to the Linux box.

[NOTE] hooks/pre-push-codereview.sh:353-425, 235-266 — Over-refusals the fix cycles added, all in the safe direction: `git push "$REMOTE" main`, `--force-with-lease=main:$SHA`, the unquoted `git push -u origin $(git rev-parse --abbrev-ref HEAD)`, `"$(git branch --show-current)"`, `-o "ci skip"`, a remote path with a space, a remote URL with `?` or `[` (`ssh://[::1]/repo`), and `echo $(date) git push`, which now reads as a push. `NAME="O'Brien" git push` and `GIT_SSH_COMMAND="ssh -i key" git push` are refused with "run this push as its own command", which is misleading for them; `git -c core.sshCommand="ssh -i k" push` is gated normally.
  Suggested fix: Name the deploy-key workaround in the push-first refusal. A quote-aware tokenizer would remove most of these.

[NOTE] hooks/pre-push-codereview.sh:58-61 — (also claude-code, also security) The quoted-text false positive recurred three times in this run: this review's read-only grep with a quoted alternation, the built-in's heredoc probe script, and a /security setup heredoc whose body held a push line. BACKLOG push-gate-quoted-text-false-positive records "one occurrence so far", and its revisit criterion ("more than occasionally") looks met. The recovery ("move that text to a file") also assumes a Write tool, which a read-only agent may not have.
  Suggested fix: Requires a user decision: pick up the BACKLOG item. It would also fix the mixed-quote regressions in the first WARN and the over-refusals above.

[NOTE] hooks/pre-push-codereview.sh:51-56, 125-136 — (also claude-code, also security) Detection misses that predate this run, in the accepted "detection is heuristic" class (head=0, now=0): `timeout 1.5m git push` (the numeric regex rejects decimals), `>/dev/null git push`, `` `git push` ``, `coproc git push`, `git -c alias.p=push p`, `git submodule foreach git push`, `"git" push`, `git {push,origin,main}`, a span holding the other kind of quote (`A="x it's y" git push`), and `` A=`git commit ...` git push ``, which pushes the commit its own substitution makes. `git -C "$(pwd)x" push` is missed too, and `git -C "$(pwd)-wt" push`, which cycles 1 and 2 caught by accident, is missed again since cycle 3. A heredoc delimiter that ends in a backslash also hides a push (security). The "Remaining limitation" comment names few of these.
  Suggested fix: Allow `^[0-9]+(\.[0-9]+)?[smhd]?$` at line 135 and list the rest in the comment.

[NOTE] hooks/pre-push-codereview.sh:297-333, 612, 674 — (security) What remains of the target-repo gap: `git -C "p q" push` is now detected but judged against `p`; a target whose `core.worktree` points outside it is judged against the enclosing repo; `git -C - push` judges the wrong directory; a `-C` inside a quoted `-c` value is followed.
  Suggested fix: Refuse a `-C` value with an unmatched quote, and compare the target's `--absolute-git-dir` with its toplevel's.

[NOTE] hooks/pre-push-codereview.sh:77-106, 166-232, 353-425, 472-520 — (also claude-code, security) The hook's tokenizing time grows with the square of the command length, and it tokenizes about ten times per recognized push and twice for any other command, up from three at 0ccfae7. A long push passes the 30 s timeout near 400 KB, or 220 KB when operator-dense. The cycles add costs: padding `<` and `>` slowed a 500 KB HTML heredoc from 0.8 s to 26.5 s (cycle 1), a push with many words that do not resolve costs two `rev-parse` calls each (about 50 s at 48 KB, per /security; wide run-to-run variance), and quote-heavy commands run 30 to 50% slower since cycle 3. A non-push only waits: 20 ms for `ls -la`, 134 ms at 89 KB. The built-in's claim that heredocs "used to skip the hook" is refuted by 1a85d54.
  Suggested fix: Normalize once in main and pass the tokens to every function, padding operators in one linear pass. Add 65,600-byte and 500 KB test cases.

[NOTE] hooks/pre-push-codereview.sh:605, 637 — (claude-code, also security) The skip marker is resolved after the `cd` into the `-C` target, so `codereview-skip` in repo A followed by `git -C B push` is blocked and leaves A's marker armed; the next unreviewed push in A was then allowed and consumed it. A leftover skip marker also passes a push of another ref, because the skip check runs before `push_sends_commits_outside_head`.
  Suggested fix: Deferred with BACKLOG skip-marker-bound-to-diff; tell the agent in the refusal that a bypass applies per repo.

[NOTE] hooks/pre-push-codereview.sh:47-49, 462 — (claude-code) Two comments still say a false positive only costs a needless review; since the push-first rule, it is a refusal (lines 58-61 say so).
  Suggested fix: Update both comments.

[NOTE] hooks/pre-push-codereview.sh:504 — (claude-code) The multi-push loop in `is_tag_only_push` can no longer run more than once, because `push_is_alone_and_first` runs first. Its comment still describes compounds.
  Suggested fix: Optional. Remove the loop in a later cleanup.

[NOTE] hooks/pre-push-codereview.sh:140, 245, 279, 380, 498 — (claude-code) The operator list appears in five places, and its `&&` and `||` arms cannot match after `_normalize_ops`, which pads each character.
  Suggested fix: Optional. Single-source it in a helper.

[NOTE] hooks/pre-push-codereview.sh:445, 527 — (claude-code) A failing `rev-list` reads as tag-only, while `_has_commits_outside_head` fails closed on the same call.
  Suggested fix: Treat a non-zero exit as "not tag-only".

[NOTE] hooks/pre-push-codereview.sh:275 — (claude-code) `/usr/bin/gh repo create --push` is not detected, though the walker accepts `*/git`.
  Suggested fix: Also accept `*/gh`.

[NOTE] hooks/pre-push-codereview.sh:643-656, 673-700 — (claude-code) The outside-ref and uncommitted refusals do not name the `-C` target repo, unlike the no-marker refusal at line 754.
  Suggested fix: Add the same target note.

[NOTE] BACKLOG.md:55 — (also security) push-gate-pushed-repo still describes `git -C <other> push` and `cd <other> && git push`, which 49ecf37 and 78c6fa1 closed. Its revisit criterion ("the tokenizer is reworked anyway") was met, as 1a85d54's message says of the sibling entry.
  Suggested fix: Rewrite it around what remains.

[NOTE] gitconfig/ignore-global:24 — The fix covers one of two paths Claude Code 2.1.296 appends to `core.excludesfile`, and that setting points at this tracked file, so the next append again dirties the tree and the pre-push `uncommitted` check refuses every push from zat.env (also claude-code)
  Evidence: the binary's append routine has a second caller, which passes `.claude/.cc-writes/` once per session when a staging directory is set up in a repo that does not already ignore `.claude/.cc-writes/sample-file.txt`; it would append `**/.claude/.cc-writes/`. Whether that feature runs on this machine is unverified. The failure is fail-safe (the hook names the file). Confidence: high on the code path, low on when it fires.
  Suggested fix: Add `**/.claude/.cc-writes/` now, in that exact form so both of Claude Code's checks pass. The structural fix (point `core.excludesfile` at a user-owned file the installer seeds from the repo copy) changes install behavior for every adopter and requires a user decision.

[NOTE] gitconfig/ignore-global:24 — Nothing records why the line is there: unlike the other blocks it has no comment, and no lint check pins it. It looks redundant in this repo, whose .gitignore already ignores `.claude/`, so a later tidy-up could remove it and bring back the push refusal (claude-code)
  Evidence: gitconfig/ignore-global:23-24; .gitignore:18. Confidence: low that it matters.
  Suggested fix: Optional. A one-line comment naming Claude Code as the writer, or a sentence in CLAUDE.md's gitconfig bullet saying Claude Code appends to this file.

[NOTE] hooks/pre-push-codereview.sh:4-7 — The header now describes the missing `if` filter but still says the hook is installed "on Bash"; it is also registered for the PowerShell tool.
  Suggested fix: Mention the PowerShell entry.

[NOTE] hooks/README.md:121-127 — The manual test recipe says `echo '{}' | bash .../pre-push-codereview.sh` "should block (no marker)", but `{}` has no command, which reads as "not a push" and exits 0. Pre-existing.
  Suggested fix: Use a payload with `{"tool_input":{"command":"git push"}}`.

[NOTE] tests/test-pre-push-hook.sh:1249 — PATH_SANITIZED keeps jq's directory, so where jq lives in ~/bin next to codereview-marker the "codereview-marker missing" test fails falsely (loud, not silent) (also claude-code)
  Suggested fix: Build a temp directory that links only `git` and `jq`.

[NOTE] zat.env-install.sh:12 — `CYGWIN*` maps to windows, but Cygwin reads `CYGWIN=winsymlinks:...`, not `MSYS`, and Cygwin's own symlinks pass the `[[ -L ]]` probe while native programs such as Claude Code may not follow them (also claude-code)
  Suggested fix: Drop `CYGWIN*` from the case (Claude Code requires Git Bash), or set `CYGWIN=winsymlinks:nativestrict` as well.

[NOTE] zat.env-install.sh:105 — Skill directories copied by a pre-nativestrict Windows install are not symlinks, so every re-run prints "exists and is not a symlink — skipping" and leaves the frozen copies; ~/.claude/CLAUDE.md and ~/bin entries are replaced (claude-code)
  Suggested fix: On Windows, tell the user to delete the copies, or replace a directory whose contents match the repo skill.

[NOTE] hooks/pre-push-codereview.sh:571 — The CR fix is repeated per consumer (hook, installer `tr -d '\r'`, windows.md advice); `jq -b` stops CRLF at the source (claude-code)
  Suggested fix: Optional. Verify the oldest supported jq accepts `-b` first (Ubuntu 22.04 ships jq 1.6; `--binary` may be newer, confidence low).

[NOTE] zat.env-install.sh:397 — The shadow warning compares path strings, so an earlier PATH entry that is another spelling of ~/bin (a symlinked HOME) warns about a copy that does not exist (claude-code)
  Suggested fix: Compare with `[[ "${FOUND_MARKER}" -ef "${BIN_DIR}/codereview-marker" ]]`.

[NOTE] bin/review-external.sh:276-278 — (security) Without `bc`, the cost expression is pasted into the awk program text, where `system()` would run; `_count` and the price literals are the only guard, and the hostile-value test covers only OpenAI `input_tokens`. The awk branch runs only on hosts without bc, so on Linux only the lint pin covers it.
  Suggested fix: Pass the operands with `-v` and keep the expression fixed, or add hostile-value tests for every token count; add a test that shadows `bc` so the awk branch runs everywhere.

[NOTE] hooks/pre-push-codereview.sh:172, 275 — (security) `git.exe push` is not gated on Windows: the walker recognizes only a bare `git` token or a path ending in /git; /security pushed a scratch repo this way. The Windows form of the absolute-path case in the accepted "detection is heuristic" risk (also claude-code)
  Suggested fix: Requires a user decision: accept it under the existing risk, or treat `git.exe` as `git` in the walker.

[NOTE] claude/skills/codereview/SKILL.md:238, 471 — (security) A `.gitattributes` `-diff` or `binary` attribute on a text file shows it as "Binary files differ" to the inline and external reviewers; the marker hash still covers its content, so the gate holds
  Suggested fix: Add `--text` (or `-a`) to the review diffs.

[NOTE] bin/codereview-marker:131 — `in_surface` keeps agent-instruction markdown only by filename or a `.claude/` path, so a skill's `references/*.md` and `claude/references/*.md` (read through global-claude.md) count as plain docs (claude-code, also security)
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

Resolved since the prior review: the WARN on a statement before a push (78c6fa1); the docker group NOTE (14ddf06 makes membership opt-in); the `git -C <other> push` and `cd <other> && git push` part of the pushed-repo gap (49ecf37, 78c6fa1); the WARN on refs other than the checked-out branch, narrowed to the user-decision WARN above (49ecf37); and the empty-payload NOTE, whose premise (the hook runs only on matched pushes) ended with 1a85d54. The "detection is heuristic" accepted risk is narrower: 600d074 detects `env`, `command`, absolute paths, `xargs`, and env-var prefixes, and 49ecf37 no longer treats a `v<digit>` branch as a tag. Interpreter wrappers and the spellings in the NOTEs above remain.

### Fixes Applied

All uncommitted, applied by /codefix to hooks/pre-push-codereview.sh with tests in tests/test-pre-push-hook.sh unless noted. Each fix was re-reviewed and re-checked by /security after its cycle.

Cycle 1:
- [WARN] `git -C .git push`, a bare repo through `-C`, and `core.bare=true` read as "not a repo" (the regression 49ecf37 introduced). A target with no working tree is now refused; hooks/README.md updated. (also security)
- [WARN] `GIT_DIR=`, `GIT_WORK_TREE=`, `GIT_COMMON_DIR=`, `env --chdir`, and `sudo -D` before git were judged against the wrong repo; they are refused, and `cd` is now `CDPATH='' cd -P`. (also claude-code, also security)
- [WARN] The tag-only exit passed `--tags` beside a refspec, `refs/tags/*`, and a tag on a tree or blob. (also claude-code, also security)
- [WARN] Shell-expanded refspecs and `:` were skipped as unresolved; they are refused, and /pr's exact substitution reads as HEAD. (also claude-code, also security)
- [WARN] Line continuations, `)`, and glued redirections hid a push. (also security)
- [WARN] A substitution in a `-C` value was undetected.
- [WARN] A comment line before a push counted as an earlier statement, which refused /pr's own block. (claude-code)

Cycle 2:
- [WARN] A `#` inside a quoted value read as a comment, which hid the statement before a push and the ref after one (cycle 1 regression). (security)
- [WARN] Any line ending in a backslash was joined to the next, though an even run ends the statement (cycle 1 regression); comments after `;`, `&`, `|`, `(`, `)` are now recognized. (also security)
- [WARN] `_normalize_ops` read through a here-string, the form b065794 removed after a Git Bash hang at 65,536 bytes (cycle 1 regression); now process substitution, pinned in tests/lint-skills.sh and recorded as CLAUDE.md Windows point (9).
- [WARN] Brace expansion and globs (`{main,feature}`, `refs/tags/{v1.0,v2.0}`, `?`, `[`) passed the check for shell-expanded words. (also security)
- [WARN] The no-working-tree refusal had no lint pin; pinned in tests/lint-skills.sh, and named in CLAUDE.md's "What the gate can vouch for".

Cycle 3:
- [WARN] A quoted value split by the tokenizer broke both argument walks: `-o "merge_request.title=Fix login (SSO)"`, `-o "a;b"`, `--push-option="Fix A & B"`, `-o "x -d y"`, and `v1.0 --push-option="a;b" feature` sent an unchecked branch. A split quoted value after the push is now refused, and cycle 2's never-cleared `open_quote` flag is gone. (also security) The cycle 2 re-check's candidate argument-walk hunks were rejected because they let `git push -o "x y" origin feature && ls -d .` through.
- [WARN] Padding `<` and `>` split quoted and escaped values, so `A="x>y" git push`, `git -c "a.b=c>d" push`, and `A=x\>y git push` went undetected (cycle 1 regression), as did the pre-existing `A="x;y"`, `TOKEN="$(echo x)"`, and `GIT_SSH_COMMAND="ssh -i key"` forms.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-13, commit 0ccfae7): Refresh review of a one-line global gitignore rule for Claude Code's `.claude/settings.local.json`; two new NOTEs, and 0 BLOCK / 8 WARN / 55 NOTE in all, carried from the Windows port review.*

<!-- REVIEW_META: {"date":"2026-11-03","commit":"8e8dee7","reviewed_up_to":"8e8dee737d8f19792795092d8df8c45ee66a874b","base":"origin/main","tier":"refresh","block":0,"warn":10,"note":65} -->
