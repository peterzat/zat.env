## Review — 2026-10-02 (commit: c03a14c)

**Review scope:** Refresh review. Focus: 18 file(s) changed since prior review (commit 2f556b0), which is every file in the unpushed range origin/main..c03a14c (11 commits). 0 already-reviewed file(s).

**Summary:** Reviewed the 11 unpushed commits: control-character stripping in review-external.sh, the `codereview-marker surface` security surface and light-tier rule, carrying open /security findings past a scoped run, launching /security at the end of Step 2, the post-fix /security re-check, quoted argument-hint frontmatter with /spec inline, the uncommitted-changes push check, the secret-in-diff skip for external reviewers, and BACKLOG/README updates. Four WARNs in the new code were auto-fixed (a SIGPIPE fail-open in the new hook branch, the "nothing to review" exit still passing commits reverted only in the working tree, cwd-relative review-file excludes, and the post-fix condition when Step 5 skipped). Seven pre-existing gate and policy WARNs from /security remain open for a user decision. tests/run-all.sh 786/786 before fixes, 790/790 after. /security (paths, 15 files) found 0 BLOCK / 5 WARN / 12 NOTE; its post-fix re-check of the 6 files codefix changed confirmed the fixes and added 2 pre-existing WARNs (0 BLOCK / 7 WARN / 12 NOTE). The fixes are uncommitted: the push gate will refuse the push until they are committed.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 6 findings, 6 kept after Step 6 (3 WARN, all auto-fixed, one also found inline; 3 NOTE).

### Findings

[WARN] hooks/pre-push-codereview.sh:248-311 — (security) The gate hashes the checked-out branch and allows on a match or on "nothing to review", whatever refs the push names; `git push origin <other>`, `<other>:main`, and `--all` pushed unreviewed refs in a scratch repo
  Evidence: SECURITY.md 2026-10-02, reproduced with synthetic hook input and re-confirmed against the fixed hook. Pre-existing hook logic, the same-repo sibling of BACKLOG push-gate-pushed-repo.
  Suggested fix: Requires a user decision (changes the gate for every project). Gate pushes whose refspec sources are not the current branch, HEAD, or a tag, or move to a git-native pre-push hook, which receives the exact refs.

[WARN] hooks/pre-push-codereview.sh:248-311 — (security) The hook judges the repo as it is before the command runs, so `git merge feat && git push`, `git cherry-pick feat && git push`, or edit, commit, and push in one Bash call on a clean branch are allowed
  Evidence: SECURITY.md 2026-10-02 (post-fix re-check), reproduced in scratch repos. Pre-existing; the new uncommitted check cannot see commits that do not exist yet.
  Suggested fix: Requires a user decision. Block a command where another statement precedes `git push`, or move to a git-native pre-push hook.

[WARN] bin/codereview-marker:162-178 — (security) A submodule with `ignore = all` hides its pointer changes from `git diff`, so the marker hash, the uncommitted check, the security surface, and the review diff all miss them; a diff that adds `ignore = all` next to a pointer change shows reviewers one line
  Evidence: SECURITY.md 2026-10-02 (post-fix re-check), reproduced in scratch repos. No project under ~/src uses submodules today.
  Suggested fix: Requires a user decision. Add `--ignore-submodules=dirty` to the script's diffs and the codereview skill's review diffs (hash unchanged for repos without submodules).

[WARN] claude/skills/pr/SKILL.md:184-191 — (security) /pr merge accepts a review of any ancestor of local HEAD and never compares the remote PR head with local HEAD, so a commit added after the review merges with the gate passing
  Evidence: SECURITY.md 2026-10-02, reproduced with the skill's own commands. Pre-existing; this diff changed only the file's argument-hint.
  Suggested fix: Requires a user decision. Require no non-review-file change since `reviewed_up_to` and a remote head equal to local HEAD.

[WARN] claude/skills/codereview/SKILL.md:269-277 — (security) The light tier still treats `.txt` and `.gitconfig` as plain documentation, so a diff limited to `gitconfig/aliases.gitconfig` (live in ~/.gitconfig via include; it can set core.fsmonitor or `!` aliases) or a downstream `requirements*.txt` or `CMakeLists.txt` skips /security, tests, and external reviewers
  Evidence: SECURITY.md 2026-10-02 (a core.fsmonitor set through an include ran on `git status`). The rule dates from a262d48; fe3cb3d restated it. The inline review reached the same conclusion for `.gitconfig`.
  Suggested fix: Requires a user decision (tiering policy for every project). Drop `.txt` and `.gitconfig` from the light tier, and update README and the lint pin at tests/lint-skills.sh:420.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425 — (security) CODEREVIEW.md and SECURITY.md edits inside the reviewed commits decide how deeply those commits are reviewed (refresh tier with an empty focus set, a skipped /security, planted Accepted Risks), and the review diff excludes those files
  Evidence: SECURITY.md 2026-10-02; the deterministic part reproduced in a scratch repo, the model-executed downgrades not run end to end. Pre-existing design.
  Suggested fix: Requires a user decision. Take the full tier and read prior META from the base when a commit not authored by the operator touched the review files.

[WARN] claude/global-claude.md:104 — (security) The global convention binds every service to 0.0.0.0, which is safe only behind a host firewall; Docker-published ports bypass UFW and hw-bootstrap.sh never enables UFW
  Evidence: SECURITY.md 2026-10-02; this host has a public address, exposure at a given time unconfirmed (rules are root-only). Pre-existing; not changed by this diff.
  Suggested fix: Requires a user decision (machine-wide networking convention). Bind to the Tailscale address, or add DOCKER-USER rules and enable UFW in hw-bootstrap.sh.

[NOTE] bin/codereview-marker:131 — `in_surface` keeps agent-instruction markdown only by filename or a `.claude/` path, so a skill's `references/*.md` (the layout CLAUDE.md recommends) and `claude/references/*.md` (read through global-claude.md) count as plain docs: a diff limited to them takes the light tier and never reaches /security (claude-code, also security)
  Suggested fix: Also keep `*/references/*.md` and markdown under zat.env's `claude/` tree, or invert the rule and drop only known prose paths (README*, docs/, CHANGELOG*).

[NOTE] claude/skills/codereview/SKILL.md:274 — The prose lists of agent-instruction markdown in Step 2 and Step 5 (line 395), and README, omit CLAUDE.local.md, which `in_surface` keeps (claude-code)
  Evidence: The light-tier rule tells the model to apply the script's output, so the tier is still right; the lists describing one contract have drifted.
  Suggested fix: Add CLAUDE.local.md to both prose lists and README.

[NOTE] claude/skills/codereview/SKILL.md:597 — `git stash create` and `codereview-marker surface <PRE_FIX>` ignore untracked files, so a codefix edit to a new untracked file gets no post-fix /security pass, despite "No codefix change reaches the push without a security pass" (claude-code)
  Evidence: Untracked files are neither hashed nor pushed; adding the file changes the hash and forces a new review, so this is a coverage gap, not a gate bypass. Codefix has no Write tool but has Bash.
  Suggested fix: Soften the sentence to tracked changes, or list untracked files changed since PRE_FIX as well.

[NOTE] claude/skills/codereview/SKILL.md:339 — /security now starts before Step 3, so its at-max-effort verification runs (scratch repos, test runs) can overlap the project's test suite; the built-in review was deliberately launched after Step 3 to avoid test collisions on ports, databases, or temp files
  Evidence: Speculative. This run's /security experiments used the scratchpad and did not collide. Confidence: low.
  Suggested fix: None now; revisit if a downstream test run collides with a /security reproduction.

[NOTE] claude/skills/codereview/SKILL.md:460 — (security) The secret-in-diff guard depends on a step that reports secrets, and in a full-tier review no step looks in plain markdown (/security's surface omits it), so a key added to a README beside a code change still goes to OpenAI and Google
  Suggested fix: Grep the exact Step 5.5 diff for key patterns (`sk-`, `sk-ant-`, `AIza`, `ghp_`, `github_pat_`, `AKIA`, `xox[bp]-`, `hf_`, private-key headers) before sending.

[NOTE] claude/skills/codereview/SKILL.md:405 — (security) The model pastes SECURITY_META's commit value into `codereview-marker surface <meta-commit>`, so a planted `$(...)` would run before the script's leading-dash check; Step 2 already extracts `reviewed_up_to` with a hex-only `grep -oP` inside the command
  Suggested fix: Extract the commit the same way, inside the command, and update the lint pin at tests/lint-skills.sh:401.

[NOTE] claude/skills/pr/SKILL.md:152 — (security) The PR template passes commit-derived text in double-quoted `--title`/`--body` arguments, where backticks or `$(...)` run as commands
  Suggested fix: Write the body with a quoted heredoc and pass `--body-file`.

[NOTE] claude/skills/spec/SKILL.md:8 — (security) Since 6f43afe made the frontmatter parse, /spec is inline and model-invocable, and its `allowed-tools` grants unprompted Bash(*), Write, and Edit for the rest of the invoking turn; before, the frontmatter was ignored and /spec ran under the session's rules. The commit message describes the change as matching how /spec already ran
  Evidence: Documented grant semantics; added exposure small where the accepted `Bash(python3 *)`-class rules already apply. Auto-mode treatment undocumented. Confidence: medium.
  Suggested fix: Narrow /spec's grant (git read commands, spec-backlog-apply.sh, Read, Grep, Glob) and let Write and Edit fall to the session's rules.

[NOTE] (carried forward, security) hooks/pre-push-codereview.sh — BACKLOG-deferred gate gaps, re-confirmed 2026-10-02: the skip marker never expires and is not tied to a diff (skip-marker-bound-to-diff); marker_dir ignores mkdir/chmod failure and checks no owner or symlink (marker-dir-ownership-check); without jq the hook exits 0 (push-gate-jq-fail-open); the hook evaluates the cwd repo, not the pushed one, now including a run from inside `.git` (push-gate-pushed-repo); a secret committed then deleted in the pushed range is never reviewed (push-gate-net-diff-secret)
  Suggested fix: As recorded in each BACKLOG.md entry.

[NOTE] (carried forward, security) bin/review-external.sh:357 — The `-gt 272000` comparison is an arithmetic context that would run a command substitution in an array subscript; `_count` makes it safe, but no test covers this sink (Gemini comparison at 463 the same)
  Suggested fix: Use a `PATH[$(: > ${TEST_DIR}/ran)]` payload in the hostile-token test, assert no file, add a Gemini case, and name the comparison in `_count`'s comment.

[NOTE] (carried forward, security) tests/test-review-external.sh:112 — The invalid-key tests call the real OpenAI and Google APIs from the repo root, sending unpushed commit subjects without opt-in (same at 287-294)
  Suggested fix: Run them against the suite's fake curl with FAKE_CODE=401.

[NOTE] (carried forward) bin/review-external.sh:318 — `-H @<(...)` needs curl 7.55 or later; older curl misreports the failure (also claude-code)
  Suggested fix: Optionally note the curl 7.55 requirement in README's platform section.

[NOTE] (carried forward) tests/lint-skills.sh — The negative pin on API keys in curl arguments matches only the old `-H "Authorization: Bearer ${` and `-H "x-goog-api-key: ${` forms (also claude-code)
  Suggested fix: Optionally flag any curl argument line containing `api_key}` or `$api_key` outside a `printf` in `<(...)`.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:467 — The 360000 ms timeout in Steps 5.5 and E.4 covers only the script's default REVIEW_TIMEOUT; a larger value in the reviewer .env brings the cut-off back, and the "300 seconds" prose is not lint-checked (also claude-code)
  Suggested fix: Say to raise the Bash timeout for a larger REVIEW_TIMEOUT, up to 600000 ms; have lint match the prose's seconds value.

[NOTE] (carried forward) tests/lint-skills.sh — The timeout pin sets a lower bound but no upper bound, so a script default past 570 s would demand a Bash timeout above the tool's 600000 ms maximum (claude-code)
  Suggested fix: Also fail when the ms value exceeds 600000.

[NOTE] (carried forward) tests/test-review-external.sh:838 — The price tests miss the 272000 and 200000 tier boundaries (claude-code)
  Suggested fix: Optional: add 272000 (short) and 272001 (long) fixtures, and the Gemini equivalent.

[NOTE] (carried forward) bin/review-external.sh:359 — Each GPT-6 price row repeats an inline long-tier if/else (claude-code)
  Suggested fix: None recommended; explicit rows match the provider pricing pages.

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
  Suggested fix: Drop the quoted phrase from claude/skills/tester/SKILL.md ("A reason that would fit every entry is boilerplate, not a reason.").

[NOTE] (carried forward) bin/review-external.sh:144 — gemini_thinking chooses thinkingLevel or thinkingBudget from the shape of GEMINI_EFFORT, not the model, and the 32768 default budget exceeds gemini-2.5-flash's cap (claude-code)
  Suggested fix: For gemini-2.5 models map a level to a budget, and cap the flash default at 24576.

[NOTE] (carried forward) tests/test-review-external.sh:883 — The hostile-token test detects a regression by elapsed time with no bound on the run, so a regression would hang the suite (claude-code)
  Suggested fix: Bound the run with the script's TIMEOUT_CMD pattern.

[NOTE] (carried forward) bin/review-external.sh:168 — `--check` prints an invalid GEMINI_EFFORT but still counts Google as configured and exits 0 (claude-code)
  Suggested fix: Do not count Google as configured when its thinking setting is invalid.

[NOTE] (carried forward) bin/review-external.sh:285 — `_redact` has no word boundary, so "task-" or "risk-" in error text is partly redacted (also claude-code)
  Suggested fix: Anchor the match on a non-alphanumeric character or line start.

[NOTE] (carried forward) bin/review-external.sh:465 — The Gemini price table has no gemini-2.5-flash rate and no fallback, so those models log cost "?" (claude-code)
  Suggested fix: None, or add verified rates for models in actual use.

[NOTE] (carried forward) tests/lint-skills.sh — 28 failure branches update FAILS and TOTAL inline, duplicating fail() (claude-code)
  Suggested fix: Replace those branches with `fail "..."`.

[NOTE] (carried forward) bin/review-external.sh:151 — gemini_thinking accepts `minimal`, which the header, install template, and validation message do not list (claude-code)
  Suggested fix: Document `minimal`, or drop it.

[NOTE] (carried forward, security) zat.env-install.sh:170 — Each settings.json rewrite moves a new .tmp file into place, so a 0600 settings.json returns at the default umask (same at 224, 233, 249, 271, 288, 306)
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

[NOTE] (carried forward) claude/skills/codereview/SKILL.md — The skill is 742 lines against the CLAUDE.md guideline of about 500 (683 at the prior review). Deferred to BACKLOG.md (skill-size-references-split) (claude-code)
  Suggested fix: Move Step 5.6's mechanics or other long sections to claude/skills/codereview/references/ (and add references/*.md to the security surface first; see the in_surface NOTE).

[NOTE] (carried forward, security) hooks/allow-venv-source.sh:12 — The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Suggested fix: Approve only for an explicit list of modes and make no decision otherwise.

[NOTE] (carried forward) zat.env-install.sh:114 — The reviewer .env exists at the process umask for an instant on first creation; it holds only template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:184 — Deny entries accumulate across installs; deliberate, since deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward, security) hw-bootstrap.sh:197 — Docker group membership lets anything running as the user obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

Resolved since the prior review: control characters in provider output (97ab0f0), and the open question of whether a forked /codereview can wait on background children without polling (6f43afe's probes; this run waited on /security, the built-in, and /codefix by ending its turn).

### Fixes Applied

- [WARN] hooks/pre-push-codereview.sh:297 — The uncommitted-file list prints with `sed -n '1,20s/^/  /p'` instead of `head -20 | sed`, so more than 64 KB of names no longer kills the hook with SIGPIPE (exit 141, which Claude Code treats as non-blocking). New test: 2,500 uncommitted names still block with exit 2.
- [WARN] hooks/pre-push-codereview.sh:250 — The "nothing to review" branch runs `codereview-marker uncommitted` (fails closed) and blocks when the commits differ from the working tree, so commits reverted only in the working tree are no longer pushed unreviewed. New test covers the revert case. (also claude-code)
- [WARN] bin/codereview-marker:91 — `require_git` changes to the top level, so the review-file excludes apply from any subdirectory; `uncommitted` no longer lists a root CODEREVIEW.md and `hash` matches the root value. Root hashes are unchanged. /security noted this also closes a fail-open with `diff.relative=true` from a clean subdirectory. New tests cover both subcommands from a subdirectory. (claude-code)
- [WARN] claude/skills/codereview/SKILL.md:618 — Step 7 uses `/security post-fix` whenever this review has already written a SECURITY.md entry (Step 5 or an earlier cycle's re-check), not only when Step 5 scanned; CLAUDE.md:55 updated to match. (claude-code)

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit 2f556b0): Refresh review of passing API keys to curl through a file descriptor and the v1.5 documentation fold-in; 0 BLOCK / 0 WARN / 36 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-02","commit":"c03a14c","reviewed_up_to":"c03a14c50ce9a163d891e47a30dd0c170126a694","base":"origin/main","tier":"refresh","block":0,"warn":7,"note":41} -->
