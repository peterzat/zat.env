## Review — 2026-11-07 (commit: 431af78)

**Summary:** Refresh review of 431af78, the one commit not on origin/main. It changes only documentation and a script header comment: they now name every `spec-backlog-apply.sh` caller and the one BACKLOG.md write that skips the script, as two NOTEs from the 897b1a7 review asked. No behavior changes.
- **Scope.** The push diff against origin/main is CLAUDE.md, README.md, and bin/spec-backlog-apply.sh (comment lines only). 5c774f1, which committed the 897b1a7 review's fixes, is already on origin/main. Its files (claude/skills/spec/SKILL.md, tests/test-spec-backlog-apply.sh) were read only to check the new text's claims.
- **Verified.** Every caller the new text names exists: Step 3f append and clear (spec SKILL.md:379, 403), Step 3g (437), Step 4 adoption (553), and /tester design D.6 (tester SKILL.md:551). The Step 3c turn-close template (spec SKILL.md:177-195) is the only BACKLOG.md write a skill directs outside the script. The four-field template sits in Step 3c, the Step 3f append manifest, and the Format section, which matches the lint pin at tests/lint-skills.sh:792-799.
- **Security.** /security scanned the four files changed since its last scan (SECURITY_META at 897b1a7). It found no BLOCK or WARN, one new NOTE (merged into the turn-close NOTE below), and no secrets. SECURITY.md is updated and uncommitted.
- **Tests.** tests/run-all.sh: 1168/1168 across 6 suites. There was no fix loop, so the suite was not re-run.
- **Uncommitted review files.** SECURITY.md and CODEREVIEW.md are uncommitted. The push gate excludes them, so they do not block the push.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 5 findings, 5 kept after Step 6. One merged into the carried turn-close NOTE; the other four merged into the two new NOTEs.

### Findings

No BLOCK findings. No new WARN findings.

New this run:

[NOTE] claude/skills/spec/SKILL.md:658, bin/spec-backlog-apply.sh:4, tests/lint-skills.sh:883-887 — (also claude-code for the script and lint lines) Three caller or op descriptions the cleanup missed:
  - The skill's own Manifest format paragraph says the manifest is piped "by Step 3f, Step 3g Step 2, and `/tester design`". It leaves out Step 4's `adopt:` call (SKILL.md:553).
  - The script header's first line still says "Apply a BACKLOG sweep manifest", above the new list of callers that are not the sweep. README:696 now says "Apply a BACKLOG.md manifest".
  - The lint section comment says the script "parses ops (`delete:` / `adopt:`)" and leaves out `clear`, `purge-origin:`, and `append:`.
  These are comments and prose only; every op has its own lint pins and tests. Confidence: high.
  Suggested fix: Add Step 4 to SKILL.md:658, say "BACKLOG.md manifest" on the script's line 4, and list all five ops in the lint comment.

[NOTE] README.md:855, CLAUDE.md:62 — (claude-code) README's Done (v1.4) bullet still says "Both `/spec` and `/tester design` mutate BACKLOG.md exclusively via this script". That contradicts the exception now named at README:323 and CLAUDE.md:59, 62. The bullet is release history, so it can stay as a record of v1.4.
  Separately, CLAUDE.md:62 opens with an unscoped "All BACKLOG.md mutations flow through the script", although user hand-edits are also allowed (README:35, spec SKILL.md:357, 572). The clause that follows scopes the rule to "from inside the skills", so a misreading is unlikely.
  Confidence: high on the text, low that either one misleads.
  Suggested fix: Optional. Leave the release bullet as history or add "(except the turn-close capture)", and start CLAUDE.md:62's sentence with "All skill-driven BACKLOG.md mutations".

[NOTE] claude/skills/spec/SKILL.md:177-195, CLAUDE.md:59, 62 — (also claude-code, also security; carried and extended) The Step 3c turn-close capture still tells the conversation "I'll create BACKLOG.md with a `# Backlog` header if it doesn't exist" and never mentions the script. 431af78 documents this write as the one exception rather than routing it through `append:`. The write therefore skips two things the script does:
  - The same-name check. A duplicate `### <name>` heading can land, and a later `delete:` or `adopt:` then acts on the first copy (claude-code).
  - The symlink refusal. /security extended this case on Claude Code 2.1.311. Write refuses a symlinked BACKLOG.md, but its error tells the agent to write to the target instead. Write follows a directory link: `repo/app/BACKLOG.md`, with `app` linking outside the repo, created the file outside. A shell append follows either kind of link. Step 3f forbids that fallback; the turn-close text does not.
  Confidence: high on the tool behavior, low on occurrence, since it needs a hostile repo and a poor choice after a refusal.
  Suggested fix: Have the capture append each entry with an `append:` manifest, then drop the exception from CLAUDE.md:59, 62 and README:323. The directory-link check suggested for the script (`git rev-parse --show-prefix` must succeed and print nothing) would then cover every BACKLOG.md write.

Resolved by 431af78:
- The 897b1a7 review's stale-lists NOTE. The script header, README:696, and CLAUDE.md's Tester/spec contract (1) now name every caller and all three template sites.
- The CLAUDE.md half of the turn-close NOTE. CLAUDE.md:59 and 62 now name the exception, so CLAUDE.md and README:323 agree.

Dropped:
- The bundled-commit WARN on 33cea03. The commit is on origin/main, so splitting it would take a force-push, and pushing it settled the decision the WARN asked for.

Carried forward from the 2026-11-07 review of 897b1a7, verbatim, so "this run" in them means that review. Since then, bin/spec-backlog-apply.sh has changed only in its header comment, and claude/skills/spec/SKILL.md and tests/test-spec-backlog-apply.sh only by the fixes that review recorded.

[NOTE] tests/test-spec-backlog-apply.sh:165-184, bin/spec-backlog-apply.sh:239 — (security) The CRLF test covers only `purge-origin:`; with the `\r` strip removed from delete, adopt, or the append check, every test still passes. A regression there shows as a MISS or a duplicate heading, not a silent loss. Separately, `adopt:` on a CRLF file rewrites its heading with an LF ending, leaving one line that differs from the rest (cosmetic; git's autocrlf normalizes it on commit).
  Suggested fix: Optional. Add one CRLF case each for delete, adopt, and the append collision.

[NOTE] tests/test-spec-backlog-apply.sh:28 — (security, pre-existing since ba621cf) `TEST_DIR=$(mktemp -d)` is unchecked and the suite does not run with `set -e`. If `mktemp` fails, `pushd ""` succeeds without moving, and every case runs against the caller's BACKLOG.md, which under tests/run-all.sh is usually zat.env's own. /security's probe with TMPDIR pointing at a missing directory added six fixture entries to a tracked copy and failed 78 of 105 checks with no summary line.
  Suggested fix: `TEST_DIR=$(mktemp -d) || exit 1`.

[NOTE] claude/skills/spec/SKILL.md:95-96, 250 — (security, new this run; already-reviewed file) The skill has the model read a date from SPEC.md and paste it into a `git log` command. Nothing checks the date's format or says how to quote it, so a cloned repo's SPEC.md with `$(...)` in its proposal date could run a command under /spec's `Bash(*)`. Confidence: medium on the mechanism, low that a model would paste such a value.
  Suggested fix: Extract the date inside the command with a strict `[0-9]{4}-[0-9]{2}-[0-9]{2}` pattern; SECURITY.md has a tested version.

[NOTE] bin/spec-backlog-apply.sh:93-96, 121-130 — (claude-code, also security; carried and extended) A bare `clear` line is a destructive op in every manifest, and it runs first, while the Format rules say other lines are ignored. A stray `clear` in a Step 3g or `/tester design` manifest would remove every entry, ACTIVE ones included. Two ways it can arrive from inside an entry body: a body line reading exactly `end-append` ends the block early (security), and an `append:` with an empty heading never enters the block, so its body lines, a `clear` among them, are parsed as ops and its `end-append` is silently ignored (claude-code, new this run). Recoverable through git when BACKLOG.md is committed. Confidence: low on occurrence.
  Suggested fix: Refuse a manifest that combines `clear` with any other op, since only `/spec backlog clear` sends it, and make an `append:` with an empty heading an error.

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

[NOTE] claude/skills/tester/SKILL.md:18, 313 — (claude-code) The role statement says the tester's job is "not to write, run, or review individual tests", while D.2 (33cea03) says to confirm each "What fails today" item "by running or reproducing it", with no stated limit on what may be run. A literal reading either skips the confirmation or runs suites and live checks under Bash(*). Confidence: low that it changes behavior.
  Suggested fix: Scope the role sentence to audit mode, or bound D.2's confirmation (one run of the named command, no live services).

[NOTE] claude/skills/spec/SKILL.md:83-84, 89, 245-246 — (claude-code, carried) `propose` with no SPEC.md "falls through to interview mode", but the interview branch now requires empty arguments, so a literal reading continues to the direct-mode branch with "propose" as the brief. Confidence: low.
  Suggested fix: Name the step: "route to interview mode (Step 3a)".

[NOTE] claude/skills/spec/SKILL.md:91-93, 138-151 — (claude-code, carried) A vague brief in a project's first `/spec` used to get the interview's questions and now stops at the escape hatch, which points only to plan mode.
  Suggested fix: Mention `/spec new` in the escape-hatch message as the alternative to plan mode.

[NOTE] tests/lint-skills.sh:1779 — (claude-code, carried) `TESTER_D7` runs from `### Step D.7:` to the end of the file. D.7 is the last section today, so the pins are exact. A section added after it would let the D.7 phrases pass from elsewhere.
  Suggested fix: Optional. End the range at the next `^#{2,3} ` heading.

Carried forward from the 2026-11-03 review. The files they cite are unchanged since 82379d2, which committed that review's fixes, so neither this run nor the 2026-11-07 d12ce05 review re-checked them beyond the probes /security re-ran. Hook line numbers are as that review recorded them (f564cd4 numbering, shifted by up to about 75 lines in 82379d2).

[WARN] (carried forward) zat.env-install.sh:213, 336-345 — (security) Requires a user decision; not for /codefix. Seeding `autoUpdatesChannel` to stable rolled this host's CLI back from 2.1.317 to 2.1.311, which predates a hook fix, and the installer registers no Monitor entry. New with 4132078. The 2.1.314 changelog reads "Fixed hooks matching Bash not running on shell commands started by the Monitor tool", so a new session on 2.1.311 likely runs a push through Monitor ungated, with no unusual spelling.
  Evidence: re-checked this run: `~/.local/bin/claude` still resolves to versions/2.1.311, and settings.json has `autoUpdatesChannel: "stable"` and `minimumVersion: null`. Not reproduced on 2.1.311 (the prior run's probes stopped at the spend limit). Confidence: high on the rollback, medium on the bypass.
  Suggested fix: Seed `minimumVersion` to 2.1.314 or later beside the channel, or add a `"matcher": "Monitor"` gate entry and pin it in lint after checking that two matching entries do not run the hook twice and burn a skip marker. Say in README's settings bullet that the setting can downgrade an install.

[WARN] (carried forward) hooks/pre-push-codereview.sh:408-446, 692, 706, 789 — (also security) Requires a user decision; not for /codefix. Following `git -C <path>` makes the hook run `git diff` in a directory named by the command before the command is approved, and that repo's config names what `git diff` executes. New with 49ecf37. f564cd4 narrows it only in that a `-C` inside a quoted or substituted `-c` value no longer moves the hook.
  Evidence: /security at f564cd4: a target whose .git/config sets `core.fsmonitor` and `diff.external` ran the payload 3 times while the hook exited 2, and a clone-delivered bare-repo layout with `core.worktree = .` ran it twice. An approved `git -C <dir> diff` runs the same payload, so what is lost is the approval step for this one command in auto mode. Confidence: high on the mechanism, low on how often an agent is steered there.
  Suggested fix: Refuse a `-C` target whose toplevel is not the session's. To also close the cwd route, pass `--no-ext-diff --no-textconv` and config overrides in bin/codereview-marker and refuse a repo whose local config defines `filter.*`.

[WARN] (carried forward) hooks/pre-push-codereview.sh:451-457, 466-540 — (also claude-code, security) Requires a user decision; not for /codefix. The gate judges only refs spelled on the command line and counts any remote-tracking ref as already gated, so these still send unreviewed commits: fetched refs (`git push origin origin/contrib:main`, `fork/evil:refs/heads/main`, and a tag on such a commit), a branch tracking a local upstream, config-chosen refs (`remote.origin.push`, `push.default=matching`, through config, `-c`, or `GIT_CONFIG_COUNT`), `git push origin HEAD~1:main` under a valid marker, git's abbreviated options (`--al`, `--mir`, `--ta`, which /security's real run used to send a tag on an unreviewed commit) and `--repo=`, `git push --repo -d origin feature:main` and `--rep -d`, where git takes `-d` as `--repo`'s value but the hook reads a delete (security, real run; open in every version), `--mirror` with a non-tag ref on a tree, and `--recurse-submodules=on-demand`. The `&>` and `-o` cases are in the WARN above.
  Evidence: real pushes by /security to scratch remotes; the built-in reproduced `git -c remote.origin.push=refs/heads/feature:refs/heads/main push`, `git -c push.default=matching push`, and `git push origin fork/pr1:main`. Confidence: high on the mechanism, medium on frequency for fetched branches.
  Suggested fix: Count a commit as gated only when the pushed remote's tracking ref for the destination has it, and refuse a push with no refspec when config chooses the refs; or move to a git-native pre-push hook (core.hooksPath), which receives the exact refs and would close most gate findings together, but also fires on terminal pushes and overrides per-repo hooks.

[WARN] (carried forward) zat.env-install.sh:331-346 — (security) Requires a user decision; not for /codefix. A hook that times out, crashes, or cannot start does not block the tool call, and neither gate entry sets `"onFailure": "block"`. An unreadable marker makes `cat` at hooks/pre-push-codereview.sh:822 exit 1, and a long command outlasts the 30 s timeout (the scanner WARN above makes that far easier). Since 1a85d54 the hook runs on every shell command, so `block` would refuse every shell command while the script is missing, including the ones needed to fix it.
  Suggested fix: An EXIT trap, set once a push is recognized, can turn a crash into a refusal without that cost. Add `"onFailure": "block"` only if the every-command cost is acceptable.

[WARN] (carried forward) bin/codereview-marker:156, 167, 173, 177 — (security) Requires a user decision; not for /codefix. A submodule with `ignore = all` hides its pointer changes from `git diff`, so the marker hash, the uncommitted check, the security surface, and the review diff all miss them (carried, not re-checked).
  Suggested fix: Add `--ignore-submodules=dirty` to the script's diffs and the codereview skill's review diffs.

[WARN] (carried forward) claude/skills/pr/SKILL.md:184-191, 217 — (security) Requires a user decision; not for /codefix. /pr merge accepts a review of any ancestor of local HEAD and never compares the remote PR head with local HEAD (carried, not re-checked).
  Suggested fix: Require no non-review-file change since `reviewed_up_to` and a remote head equal to local HEAD.

[WARN] (carried forward) claude/skills/codereview/SKILL.md:269-277 — (security) Requires a user decision; not for /codefix. The light tier still treats `.txt` and `.gitconfig` as plain documentation, so a diff limited to `gitconfig/aliases.gitconfig` or a downstream `requirements*.txt` or `CMakeLists.txt` skips /security, tests, and external reviewers (carried, not re-checked).
  Suggested fix: Drop `.txt` and `.gitconfig` from the light tier, and update README and the lint pin.

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

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.


---
*Prior review (2026-11-07, commit 897b1a7): Refresh review of 897b1a7. Two /codefix cycles fixed two WARNs (Step 3f had no stop rule for a script error; CRLF headings defeated the ACTIVE carve-out) and made the CRLF test portable to macOS, committed in 5c774f1. It left 0 BLOCK / 10 WARN / 80 NOTE, all needing a user decision or informational.*

<!-- REVIEW_META: {"date":"2026-11-07","commit":"431af78","reviewed_up_to":"431af789e1e19721f12798f02f980105fa33232f","base":"origin/main","tier":"refresh","block":0,"warn":9,"note":81} -->
