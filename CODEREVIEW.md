## Review — 2026-11-03 (commit: f564cd4)

**Summary:** Refresh review of f564cd4, which commits the prior run's three uncommitted fix cycles plus a fourth round no review had seen: `_quote_scan`, `_word_end`, `_word_is_open`, a fallback command-position reading, and `-C` values taken from the walk.
- **Scope.** Focus set: BACKLOG.md, CLAUDE.md, hooks/README.md, hooks/pre-push-codereview.sh, tests/lint-skills.sh, tests/test-pre-push-hook.sh. README.md, docs/hardware-setup.md, hw-bootstrap.sh, and zat.env-install.sh were checked for interactions only. To isolate the new round, this run rebuilt the prior run's cycle-3 hook (its postfix3 copy minus the candidate patch, which reproduced the prior WARN's results) and compared it with HEAD, 8e8dee7, and origin/main.
- **What f564cd4 did.** It closes the prior run's first WARN: all seven spellings are gated again. It also added three WARNs:
  - a rare detection regression (`\$'`, `$$'`);
  - a quadratic scanner that held a 60 KB push past the hook's 30 s timeout;
  - argument walks that end at `&>`, and a `-d` that is `-o`'s value.
- **Fix loop.** Three /codefix cycles fixed all three. Cycles 1 and 2 each added regressions, which the next cycle fixed. The cycle 3 tree gates every probe this run and /security wrote, and each reported timing shape now finishes in under 1.5 s.
- **What is left.** The nine WARNs that need a user decision, and the "Fix-loop limits" NOTE.
- **Tests.** tests/run-all.sh went from 1063/1063 to 1096/1096 across 6 suites. Shellcheck is clean on the hook.
- **Commit before pushing.** The fixes are uncommitted, so the push gate refuses a push until hooks/pre-push-codereview.sh and tests/test-pre-push-hook.sh are committed. CODEREVIEW.md and SECURITY.md are uncommitted too.
- **Delete before staging.** Cycle 3 left two untracked copies of the hook in the repo root, head-hook.sh and new-hook.sh. Delete them before any `git add -A`.
- **Line numbers.** Hook line numbers in the carried findings are at f564cd4. The uncommitted fixes shift them by up to about 75 lines.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 9 findings, all kept after Step 6. Two formed a new WARN, the `&>` and `-o` argument walks, which was also in /security's refspec WARN; this run confirmed the tag-only form with a real push, and cycles 1 and 2 fixed it. Six merged into existing WARNs and NOTEs, and one became a new NOTE.

### Findings

No BLOCK findings.

All five WARNs this run sent to /codefix are resolved: its three original WARNs, and the two regressions cycle 2 added. The same holds for each regression cycle 1 added. This run re-ran each of its probes against the cycle 3 tree and /security re-ran its own; each is gated.
- **The `$'` misread** (`git -c x.y=\$'a\' push`, `$$'`, and the `--namespace` and gh forms), with a test.
- **A `#` after an escaped operator in a prefix word** (`A=x\;#y ...`, `A="x\"; #y" ...`).
- **A heredoc delimiter ending in a backslash.** Covered in its fully quoted, part-quoted, and backslash-quoted forms, and when a second heredoc shares the line.
- **The quadratic scanner.**
  - A push-first 60 KB minified-JSON heredoc: 0.44 s, was 30.35 s.
  - /security's 64 KB commit-and-push: 3.5 s, was 26.1 s.
- **The `&>` and `-o` argument walks**, including `& >` before a `-d` and `-fo -d`.
- **Cycle 1's heredoc tracking**, which had turned joining off.
- **Cycle 1's 1,024-character cutoff**, for words with one quote kind.
- **Cycle 2's slow heredoc parsing.**
  - A 64 KB quoted delimiter after a push: 0.47 s.
  - /security's 1,200 unclosed markers: 1.5 s, was 32.1 s.
- **Cycle 2's delimiter line that kept its backslash.**

/security's last fuzz found no other regression against f564cd4 except past the cycle 3 bounds; see the "Fix-loop limits" NOTE.

[WARN] zat.env-install.sh:213, 336-345 — (security) Requires a user decision; not for /codefix. Seeding `autoUpdatesChannel` to stable rolled this host's CLI back from 2.1.317 to 2.1.311, which predates a hook fix, and the installer registers no Monitor entry. New with 4132078. The 2.1.314 changelog reads "Fixed hooks matching Bash not running on shell commands started by the Monitor tool", so a new session on 2.1.311 likely runs a push through Monitor ungated, with no unusual spelling.
  Evidence: re-checked this run: `~/.local/bin/claude` still resolves to versions/2.1.311, and settings.json has `autoUpdatesChannel: "stable"` and `minimumVersion: null`. Not reproduced on 2.1.311 (the prior run's probes stopped at the spend limit). Confidence: high on the rollback, medium on the bypass.
  Suggested fix: Seed `minimumVersion` to 2.1.314 or later beside the channel, or add a `"matcher": "Monitor"` gate entry and pin it in lint after checking that two matching entries do not run the hook twice and burn a skip marker. Say in README's settings bullet that the setting can downgrade an install.

[WARN] hooks/pre-push-codereview.sh:408-446, 692, 706, 789 — (also security) Requires a user decision; not for /codefix. Following `git -C <path>` makes the hook run `git diff` in a directory named by the command before the command is approved, and that repo's config names what `git diff` executes. New with 49ecf37. f564cd4 narrows it only in that a `-C` inside a quoted or substituted `-c` value no longer moves the hook.
  Evidence: /security at f564cd4: a target whose .git/config sets `core.fsmonitor` and `diff.external` ran the payload 3 times while the hook exited 2, and a clone-delivered bare-repo layout with `core.worktree = .` ran it twice. An approved `git -C <dir> diff` runs the same payload, so what is lost is the approval step for this one command in auto mode. Confidence: high on the mechanism, low on how often an agent is steered there.
  Suggested fix: Refuse a `-C` target whose toplevel is not the session's. To also close the cwd route, pass `--no-ext-diff --no-textconv` and config overrides in bin/codereview-marker and refuse a repo whose local config defines `filter.*`.

[WARN] hooks/pre-push-codereview.sh:451-457, 466-540 — (also claude-code, security) Requires a user decision; not for /codefix. The gate judges only refs spelled on the command line and counts any remote-tracking ref as already gated, so these still send unreviewed commits: fetched refs (`git push origin origin/contrib:main`, `fork/evil:refs/heads/main`, and a tag on such a commit), a branch tracking a local upstream, config-chosen refs (`remote.origin.push`, `push.default=matching`, through config, `-c`, or `GIT_CONFIG_COUNT`), `git push origin HEAD~1:main` under a valid marker, git's abbreviated options (`--al`, `--mir`, `--ta`, which /security's real run used to send a tag on an unreviewed commit) and `--repo=`, `git push --repo -d origin feature:main` and `--rep -d`, where git takes `-d` as `--repo`'s value but the hook reads a delete (security, real run; open in every version), `--mirror` with a non-tag ref on a tree, and `--recurse-submodules=on-demand`. The `&>` and `-o` cases are in the WARN above.
  Evidence: real pushes by /security to scratch remotes; the built-in reproduced `git -c remote.origin.push=refs/heads/feature:refs/heads/main push`, `git -c push.default=matching push`, and `git push origin fork/pr1:main`. Confidence: high on the mechanism, medium on frequency for fetched branches.
  Suggested fix: Count a commit as gated only when the pushed remote's tracking ref for the destination has it, and refuse a push with no refspec when config chooses the refs; or move to a git-native pre-push hook (core.hooksPath), which receives the exact refs and would close most gate findings together, but also fires on terminal pushes and overrides per-repo hooks.

[WARN] zat.env-install.sh:331-346 — (security) Requires a user decision; not for /codefix. A hook that times out, crashes, or cannot start does not block the tool call, and neither gate entry sets `"onFailure": "block"`. An unreadable marker makes `cat` at hooks/pre-push-codereview.sh:822 exit 1, and a long command outlasts the 30 s timeout (the scanner WARN above makes that far easier). Since 1a85d54 the hook runs on every shell command, so `block` would refuse every shell command while the script is missing, including the ones needed to fix it.
  Suggested fix: An EXIT trap, set once a push is recognized, can turn a crash into a refusal without that cost. Add `"onFailure": "block"` only if the every-command cost is acceptable.

[WARN] bin/codereview-marker:156, 167, 173, 177 — (security) Requires a user decision; not for /codefix. A submodule with `ignore = all` hides its pointer changes from `git diff`, so the marker hash, the uncommitted check, the security surface, and the review diff all miss them (carried, not re-checked).
  Suggested fix: Add `--ignore-submodules=dirty` to the script's diffs and the codereview skill's review diffs.

[WARN] claude/skills/pr/SKILL.md:184-191, 217 — (security) Requires a user decision; not for /codefix. /pr merge accepts a review of any ancestor of local HEAD and never compares the remote PR head with local HEAD (carried, not re-checked).
  Suggested fix: Require no non-review-file change since `reviewed_up_to` and a remote head equal to local HEAD.

[WARN] claude/skills/codereview/SKILL.md:269-277 — (security) Requires a user decision; not for /codefix. The light tier still treats `.txt` and `.gitconfig` as plain documentation, so a diff limited to `gitconfig/aliases.gitconfig` or a downstream `requirements*.txt` or `CMakeLists.txt` skips /security, tests, and external reviewers (carried, not re-checked).
  Suggested fix: Drop `.txt` and `.gitconfig` from the light tier, and update README and the lint pin.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — (security) Requires a user decision; not for /codefix. CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed, and the review diff excludes those files (carried, not re-checked).
  Suggested fix: Take the full tier and read prior META from the base when a commit not authored by the operator touched the review files.

[WARN] claude/global-claude.md:108 — (security) Requires a user decision; not for /codefix. The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW. The rule also loads on Windows, where windows.md says networking.md (the only place the firewall assumption is written) does not apply (carried, not re-checked).
  Suggested fix: Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW; scope the rule to the Linux box.

[NOTE] hooks/pre-push-codereview.sh (working tree) 78-130, 233-260 — (also security) Fix-loop limits: trade-offs the fix cycles made, which the cycle limit leaves for a later change. Hook line numbers here are in the working tree.
  (a) A word over 1,024 characters that holds both quote kinds or a backslash still stops the fallback reading for the rest of the command. Spellings only that reading catches (`>/dev/null git push`, `A="x it's y" git push`) are missed after it, as they were at origin/main and 8e8dee7. /security's real run sent a commit this way.
  (b) The heredoc tracking stops at its bounds: 16 open quoted heredocs, 16 markers on a line, and a delimiter word over 256 characters. Past them it reads the command as f564cd4 did, so a quoted terminator ending in a backslash again glues to a plain `git push` on the next line. Cycle 2 refused these; f564cd4 and origin/main did not.
  (c) `_hd_unquote` reads `<<"X'\\"`, `<<$'X\\'`, and `<<$"X\\"` differently from bash, so the push after their terminator stays hidden. /security's real run sent the commit.
  (d) Heredoc-like text such as `<<'git \'` can hide a push only when a later continued line equals it exactly, so it is reachable only on purpose.
  (e) A comment line ending in a backslash hides a prefixed push, in every version (security).
  Evidence: /security's cycle 3 fuzz, two seeds, 5,804 unique commands: of the pushes cycle 3 allows, the 143 that cycle 2 refused are all past a bound, and the 57 that f564cd4 refused are all the long-word cutoff. Confidence: high on each mechanism, low on frequency.
  Suggested fix: Read a long word's quote state in one awk pass, and model double quotes and `$'` in `_hd_unquote`. Or record these in the "Remaining limitation" comment.

[NOTE] hooks/pre-push-codereview.sh:466-540, 235-266 — Over-refusals in the safe direction: `git push "$REMOTE" main`, `--force-with-lease=main:$SHA`, the unquoted `git push -u origin $(git rev-parse --abbrev-ref HEAD)`, `"$(git branch --show-current)"`, `-o "ci skip"`, a remote path with a space, a remote URL with `?` or `[` (`ssh://[::1]/repo`), and `echo $(date) git push`, which reads as a push. `NAME="O'Brien" git push` and `GIT_SSH_COMMAND="ssh -i key" git push` are refused with "run this push as its own command", which is misleading for them (re-checked this run for `"$REMOTE"` and `O'Brien`).
  Suggested fix: Name the deploy-key workaround in the push-first refusal. A quote-aware tokenizer would remove most of these.

[NOTE] hooks/pre-push-codereview.sh:58-62 — (also claude-code, also security) The quoted-text false positive. f564cd4 updates BACKLOG push-gate-quoted-text-false-positive to four occurrences and narrows its revisit criterion to sessions that do not work on the gate. This run hit it once more, also in gate work (a probe setup whose heredoc held a push line). The recovery ("move that text to a file") assumes a Write tool, which a read-only agent may not have.
  Suggested fix: None beyond the BACKLOG entry.

[NOTE] hooks/pre-push-codereview.sh:51-56, 179-233, 253-321 — (also claude-code, also security) Detection misses that predate this run, in the accepted "detection is heuristic" class (8e8dee7, cycle 3, and HEAD all miss them): `timeout 1.5m git push` (the numeric regex rejects decimals), `` `git push` ``, `coproc git push`, `env "FOO=1" git push`, the quoted and escaped spellings `"git" push`, `'git' push`, `\git push`, `git "push"`, `git pu\sh`, and `git $'push'` (claude-code, security), `git -c alias.p=push p`, `git submodule foreach git push`, `git {push,origin,main}`, a -C value with text after its substitution (`git -C "$(pwd)x" push`, `git -C "$(pwd)-wt" push`), a substitution in the middle of a `-c` value (`git -c "x=a$(echo hi)b" push`), escaped operators inside a word (`A=x\;y git push`, sent by /security), nested quotes in a substitution (`A="$(echo "a b")" git push`), a continued line whose quoted value holds ` #` (`git -c 'a #b' \` then `push`, claude-code; the join regex at line 82 does not know quotes, and 8e8dee7 joined no continuations), and `git --attr-source <tree> push` on git 2.40 and later, where `--attr-source` takes a separate value the walk does not list (unverified here, git 2.34.1). A statement can also run before the push inside a value the hook steps past: `` A=`./commit.sh` git push `` (claude-code), `git -c a.b=$(git commit ...) push`, and `git >"$(git commit ...; echo /dev/null)" push`. f564cd4 closed `>/dev/null git push`, `git 2>&1 push`, and `A="x it's y" git push`, which this run re-checked.
  Suggested fix: Allow a decimal at line 211, add `--attr-source` to the option list, refuse a backtick or `$(` in a prefix assignment or between git and push, keep `\;`, `\|`, `\&` inside their word with a placeholder as lines 98-102 do for `\<` and `\>`, and list the rest in the "Remaining limitation" comment.

[NOTE] hooks/pre-push-codereview.sh:408-446 — (security) What remains of the target-repo gap: a target whose `core.worktree` points outside it is judged against the enclosing repo, and `git -C - push` makes `cd -P -- -` go to $OLDPWD while git enters `./-` (this run: the hook exits 0 there; git fails unless `./-` exists). f564cd4 closed `git -C "p q" push` (now refused) and stopped following a `-C` inside a quoted `-c` value. It also dropped BACKLOG push-gate-pushed-repo as closed, so these two items and the `-C` pre-approval WARN have no deferral entry.
  Suggested fix: Compare the target's `--absolute-git-dir` with the same call run from its toplevel, use `./-` for a `-` value, and record what remains in BACKLOG.md.

[NOTE] hooks/pre-push-codereview.sh:78-107, 253, 341-344, 408-412, 466-471, 587-595 — (also claude-code, security) Apart from the scanner WARN above, tokenizing time grows with the square of the command length, and each check re-runs `_normalize_ops` and `_push_invocations` (about eight passes per push). /security's thresholds for short words still hold (near 400 KB, or 220 KB when operator-dense). The built-in notes that the separate copies are also why the `&>` handling in `_push_invocations` never reached the argument walks.
  /security's cycle 3 re-check adds two shapes. A line ending in a long run of backslashes costs the run's length times the line's in `slashes="${line##*[!\\]}"`, which has been there since the prior run's cycle 1: 32 KB of trailing backslashes took 26.9 s, and the shape passes 30 s near 34 KB. And the bounded heredoc tracking adds linear cost: 240 KB of quoted-marker lines with a continuation took 28.0 s, against 20.6 s at f564cd4.
  Suggested fix: Normalize once in main and pass the tokens to every function, with one shared argument walker. Count trailing backslashes with `[[ "${line}" =~ (\\+)$ ]]`, which took under 0.01 s on the same input. Add 65,600-byte and 500 KB test cases.

[NOTE] hooks/pre-push-codereview.sh:751-755 — (claude-code, also security) The skip marker is resolved after the `cd` into the `-C` target, so `codereview-skip` in repo A followed by `git -C B push` is blocked and leaves A's marker armed; the next unreviewed push in A was then allowed and consumed it. A leftover skip marker at any age also passes a push of another ref, because the skip check runs before `push_sends_commits_outside_head`.
  Suggested fix: Deferred with BACKLOG skip-marker-bound-to-diff; tell the agent in the refusal that a bypass applies per repo.

[NOTE] hooks/pre-push-codereview.sh:47-49, 59, 576 — (claude-code) Comments still say a false positive only costs a needless review; since the push-first rule it is a refusal. Line 59 still says the tokenizer ignores quoting, which `_word_end` now partly reads.
  Suggested fix: Update the comments.

[NOTE] hooks/pre-push-codereview.sh:601 — (claude-code) The multi-push loop in `is_tag_only_push` can no longer run more than once, because `push_is_alone_and_first` runs first. Its comment still describes compounds.
  Suggested fix: Optional. Remove the loop in a later cleanup.

[NOTE] hooks/pre-push-codereview.sh:185, 222, 354, 386, 488, 613 — (also claude-code) The operator list appears in six places and the copies diverge (`)` and `}` differ, and only `_push_invocations` reads `&>`); the `&&` and `||` arms cannot match after `_normalize_ops`, which pads each character.
  Suggested fix: Optional. Single-source it in a helper.

[NOTE] hooks/pre-push-codereview.sh:562, 638 — (claude-code) A failing `rev-list` reads as tag-only, while `_has_commits_outside_head` fails closed on the same call.
  Suggested fix: Treat a non-zero exit as "not tag-only".

[NOTE] hooks/pre-push-codereview.sh:382 — (claude-code, also security) `/usr/bin/gh repo create --push` is not detected, though the walker accepts `*/git`.
  Suggested fix: Also accept `*/gh`.

[NOTE] hooks/pre-push-codereview.sh:757-770, 794-844 — (claude-code) The outside-ref and uncommitted refusals do not name the `-C` target repo, unlike the no-marker refusal at line 871.
  Suggested fix: Add the same target note.

[NOTE] zat.env-install.sh:336-345 — (claude-code) With no `if` filter, the gate's bash and jq processes start on every Bash and PowerShell call, which costs most on Windows, where process start is slow. Not measured.
  Suggested fix: Exit at once when the command has no `push` substring, before tokenizing. Every detection the hook makes needs a `push` or `--push` token, so nothing it catches today is lost, and the hook still decides for itself.

[NOTE] gitconfig/ignore-global:24 — The fix covers one of two paths Claude Code 2.1.296 appends to `core.excludesfile`, and that setting points at this tracked file, so the next append again dirties the tree and the pre-push `uncommitted` check refuses every push from zat.env (also claude-code)
  Evidence: the binary's append routine has a second caller, which passes `.claude/.cc-writes/` once per session when a staging directory is set up in a repo that does not already ignore `.claude/.cc-writes/sample-file.txt`; it would append `**/.claude/.cc-writes/`. Whether that feature runs on this machine is unverified. The failure is fail-safe (the hook names the file). Confidence: high on the code path, low on when it fires.
  Suggested fix: Add `**/.claude/.cc-writes/` now, in that exact form so both of Claude Code's checks pass. The structural fix (point `core.excludesfile` at a user-owned file the installer seeds from the repo copy) changes install behavior for every adopter and requires a user decision.

[NOTE] gitconfig/ignore-global:24 — Nothing records why the line is there: unlike the other blocks it has no comment, and no lint check pins it. It looks redundant in this repo, whose .gitignore already ignores `.claude/`, so a later tidy-up could remove it and bring back the push refusal (claude-code)
  Evidence: gitconfig/ignore-global:23-24; .gitignore:18. Confidence: low that it matters.
  Suggested fix: Optional. A one-line comment naming Claude Code as the writer, or a sentence in CLAUDE.md's gitconfig bullet saying Claude Code appends to this file.

[NOTE] hooks/pre-push-codereview.sh:4-7 — The header describes the missing `if` filter but still says the hook is installed "on Bash"; it is also registered for the PowerShell tool.
  Suggested fix: Mention the PowerShell entry.

[NOTE] hooks/README.md:121-127 — The manual test recipe says `echo '{}' | bash .../pre-push-codereview.sh` "should block (no marker)", but `{}` has no command, which reads as "not a push" and exits 0. Pre-existing.
  Suggested fix: Use a payload with `{"tool_input":{"command":"git push"}}`.

[NOTE] tests/test-pre-push-hook.sh:1304 — PATH_SANITIZED keeps jq's directory, so where jq lives in ~/bin next to codereview-marker the "codereview-marker missing" test fails falsely (loud, not silent) (also claude-code)
  Suggested fix: Build a temp directory that links only `git` and `jq`.

[NOTE] zat.env-install.sh:12 — `CYGWIN*` maps to windows, but Cygwin reads `CYGWIN=winsymlinks:...`, not `MSYS`, and Cygwin's own symlinks pass the `[[ -L ]]` probe while native programs such as Claude Code may not follow them (also claude-code)
  Suggested fix: Drop `CYGWIN*` from the case (Claude Code requires Git Bash), or set `CYGWIN=winsymlinks:nativestrict` as well.

[NOTE] zat.env-install.sh:105 — Skill directories copied by a pre-nativestrict Windows install are not symlinks, so every re-run prints "exists and is not a symlink — skipping" and leaves the frozen copies; ~/.claude/CLAUDE.md and ~/bin entries are replaced (claude-code)
  Suggested fix: On Windows, tell the user to delete the copies, or replace a directory whose contents match the repo skill.

[NOTE] hooks/pre-push-codereview.sh:666 — The CR fix is repeated per consumer (hook, installer `tr -d '\r'`, windows.md advice); `jq -b` stops CRLF at the source (claude-code)
  Suggested fix: Optional. Verify the oldest supported jq accepts `-b` first (Ubuntu 22.04 ships jq 1.6; `--binary` may be newer, confidence low).

[NOTE] zat.env-install.sh:397 — The shadow warning compares path strings, so an earlier PATH entry that is another spelling of ~/bin (a symlinked HOME) warns about a copy that does not exist (claude-code)
  Suggested fix: Compare with `[[ "${FOUND_MARKER}" -ef "${BIN_DIR}/codereview-marker" ]]`.

[NOTE] bin/review-external.sh:276-278 — (security) Without `bc`, the cost expression is pasted into the awk program text, where `system()` would run; `_count` and the price literals are the only guard, and the hostile-value test covers only OpenAI `input_tokens`. The awk branch runs only on hosts without bc, so on Linux only the lint pin covers it.
  Suggested fix: Pass the operands with `-v` and keep the expression fixed, or add hostile-value tests for every token count; add a test that shadows `bc` so the awk branch runs everywhere.

[NOTE] hooks/pre-push-codereview.sh:260 — (security) `git.exe push`, `"/c/Program Files/Git/cmd/git.exe" push`, and `GIT push` (case-insensitive filesystems) are not gated: the walker recognizes only a bare `git` token or a path ending in /git. The Windows form of the absolute-path case in the accepted "detection is heuristic" risk (also claude-code)
  Suggested fix: Requires a user decision: accept it under the existing risk, or compare the token's basename with `git` or `git.exe`.

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

Resolved since the prior review: the WARN on seven spellings that the fix cycles let through (f564cd4; this run gated all seven at HEAD); the NOTE that BACKLOG push-gate-pushed-repo was stale (f564cd4 dropped it; what remains is in the target-repo NOTE); and, within the NOTEs, `>/dev/null git push`, `A="x it's y" git push`, and `git -C "p q" push`.

### Fixes Applied

Cycle 1, applied by /codefix to hooks/pre-push-codereview.sh with tests in tests/test-pre-push-hook.sh, uncommitted:
- [WARN] `_quote_scan` opens `$'...'` only after an odd run of unescaped `$`, so `\$'` and `$$'` read as plain single quotes. `_word_end` steps over only the first token when a quote is still open at the end of the command. push_is_alone_and_first also refuses a prefix word that `_quote_is_unclear` matches. The continuation join skips the body and terminator of a quoted heredoc. That join change added the cycle 2 WARN above.
- [WARN] `_exact_command_positions` stops at the first token over 1,024 characters, and `_quote_scan` runs under a local C locale. The cutoff added the cycle 2 WARN above.
- [WARN] Both argument walks read `&>` as a redirection, and push_sends_commits_outside_head steps over a `-d` or `--delete` that is the value of `-o` or `--push-option`. The `&>` arm added the cycle 2 WARN above.

Cycle 2, by /codefix, uncommitted:
- [WARN] Heredoc tracking no longer suspends the join: every line joins as at f564cd4 except the exact delimiter line. `<<<` is not a heredoc, tabs are stripped only after `<<-`, part-quoted and backslash delimiters are recognized through a new `_hd_unquote`, and several heredocs on a line are tracked. This added the two cycle 3 WARNs above.
- [WARN] A long word with no backslash, no `$'`, and one quote kind is read by quote parity (`_quote_parity`) instead of stopping the fallback; `_has_open_quote` runs under a local C locale; the long-word test passes its command to jq on stdin.
- [WARN] A `-d` after an `&` and `>` pair ends the walk instead of reading as a delete, and a short-option cluster ending in `o` is treated like `-o`.

Cycle 3, by /codefix, uncommitted:
- [WARN] The heredoc regex captures the rest of the line itself, removing a quadratic prefix strip that a trace showed was the main cost. A delimiter word over 256 characters is not tracked. At most 16 open heredocs, and 16 markers per line, are read. `_hd_unquote` runs under a local C locale. Tests time a 64 KB quoted delimiter and 1,200 unclosed heredocs after a push.
- [WARN] A line that ends a quoted heredoc drops its trailing backslashes before it is added. The three-line case is a test.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-11-03, commit 8e8dee7): Refresh review of seven unpushed gate-hardening commits; three /codefix cycles left 0 BLOCK / 10 WARN / 65 NOTE, with uncommitted fixes that f564cd4 now commits.*

<!-- REVIEW_META: {"date":"2026-11-03","commit":"f564cd4","reviewed_up_to":"f564cd4d401e48c6fa1df956840dc43f6a33b986","base":"origin/main","tier":"refresh","block":0,"warn":9,"note":66} -->
