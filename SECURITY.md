## Security Review — 2026-10-13 (scope: paths)

**Summary:** Path-scoped scan, at HEAD 0ccfae7 on the Linux box, of the five security-surface
files changed since the 6c9741a scan: b065794 (the /codefix changes that scan's post-fix
re-check reviewed before they were committed) and 0ccfae7 (a global gitignore rule for Claude
Code's `.claude/settings.local.json`). 0 BLOCK / 8 WARN / 16 NOTE, and no secrets. Neither
commit adds a finding. b065794 matches what the re-check reviewed and passes the hook, marker,
and lint suites on Linux. The ignore rule touches only untracked files, which the gate neither
hashes nor pushes. Every in-scope finding is still present, and the push-gate findings were
reproduced again on Linux. Two entries changed. The tokenizer NOTE is restated: on Linux the
cost is `_normalize_ops` (quadratic in bash 5.1, and run three times per hook call), not the
read form, and the hook passes its 30 s timeout at about 400 to 720 KB. A pre-existing NOTE is
listed here for the first time: the installer rewrites settings.json at the process umask.
Eleven findings in out-of-scope files are carried.

### Findings

```
[WARN] zat.env-install.sh:320-337 — the two pre-push gate entries set no `onFailure`, and by
default Claude Code runs the tool call when a command hook cannot start, exits with a code
other than 0 or 2, or times out. Re-checked at 0ccfae7 on Linux: still present.
  Attack vector: no adversary is needed. The hook refuses with exit 2, and a refusal holds
    only while the hook runs to completion. On Linux three things skip it. A moved or renamed
    zat.env checkout leaves the stored command pointing at a missing script (exit 127) until
    the installer is re-run. An unreadable marker file makes `cat` at
    hooks/pre-push-codereview.sh:297 fail under `set -e` (exit 1). A command of about 400 to
    720 KB keeps the tokenizer past the 30 s timeout (NOTE below). On Windows the 6c9741a scan
    measured a 125 MB first push at 29.8 s and the tokenizer passing 30 s at 400 to 500 KB. A
    `$` or backtick in the checkout path also breaks the stored command. The hook recognizes
    each of these pushes, so the accepted "detection is heuristic" risk does not cover them.
  Evidence: the Claude Code 2.1.296 binary on this host defines the field for a hook that
    "could not start ..., timed out, exited with a code other than 0 or 2": "'continue'
    (default): the failure is reported and the action goes ahead. 'block': the failure counts
    as exit code 2". The live ~/.claude/settings.json here carries b065794's quoted commands
    and no `onFailure`. Against a scratch repo with an unreviewed commit, the hook exited 2
    with no marker and with a stale readable marker, and exited 1 with the stale marker at mode
    000 ("cat: ... Permission denied"). Invoking a missing hook path exited 127. Lint does not
    pin `onFailure`. The cancellation itself was not observed live. Confidence: high on the
    mechanism and the default, low on how often each trigger occurs.
  Remediation: add `"onFailure": "block"` to both entries (Claude Code 2.1.295 or later) and
    pin it in lint, so a missing, crashed, or timed-out gate refuses the push. Then raise the
    timeout (for example to 120 s) so a slow but healthy run is not refused.

[WARN] hooks/pre-push-codereview.sh:263-327 — the gate hashes the checked-out branch against
its upstream and allows the push on a match, or on "nothing to review", whatever refs the push
command names. Re-checked at 0ccfae7 on Linux: still present.
  Attack vector: an agent pushes a ref other than the checked-out branch, such as
    `git push origin <other>`, `git push origin <other>:main`, or `git push --all origin`.
    With a valid marker on the current branch, or a current branch equal to its upstream,
    the hook exits 0 and the unreviewed ref reaches the remote, remote main included. The
    hook recognizes the push and checks the wrong content, so the accepted "detection is
    heuristic" risk does not cover this. It is the same-repo sibling of BACKLOG.md
    push-gate-pushed-repo.
  Evidence: in a scratch repo (scratch XDG_CACHE_HOME, synthetic hook input), with
    `codereview-marker write` run on main and an unreviewed commit on `evil`,
    `git push origin evil`, `git push origin evil:main`, and `git push --all origin` each
    exited 0. tests/test-pre-push-hook.sh has no case whose refspec names another branch.
    Confidence: high on the mechanism, medium on how often agents push a non-current ref.
  Remediation: gate any push whose refspec sources are not the current branch, HEAD, or a
    tag; the per-push positional walk in is_tag_only_push (lines 152-168) already isolates
    them. Block `--all`, `--mirror`, and `--branches` the same way. A git-native pre-push hook
    (core.hooksPath), which receives the exact local and remote refs on stdin, would close
    this, the compound-command WARN below, and push-gate-pushed-repo.

[WARN] hooks/pre-push-codereview.sh:263-327 — the hook judges the repository as it is before
the command runs, so commits that the same command creates or imports ahead of its push are
sent on the strength of the earlier state. Re-checked at 0ccfae7 on Linux: still present.
  Attack vector: on a branch equal to its upstream with a clean tree, or one whose committed
    state carries a valid marker, an agent runs `git merge <branch> && git push`,
    `git cherry-pick <sha> && git push`, or an edit, commit, and push in one call. The hook
    finds nothing to review, or a matching marker and nothing uncommitted, and exits 0; the
    commits the command then makes are pushed unreviewed. The hook recognizes the push, so
    the accepted risk does not cover this.
  Evidence: in a scratch repo on main equal to origin/main, with an unreviewed commit on
    `feat`, `git merge --no-edit feat && git push` exited 0 ("Pre-push gate: nothing to
    review. Allowed."). No test puts a history-changing command before the push.
    Confidence: high on the mechanism, medium on frequency.
  Remediation: block any command in which another statement comes before a `git push`
    (ignoring a leading `(`, `{`, or `!`), and tell the agent to run the other statements
    first and `git push` as its own Bash call; the token indices from
    _push_subcommand_indices (lines 86-118) show what comes first. This also stops
    `cd <other> && git push`. A git-native pre-push hook would close it outright.

[WARN] claude/skills/codereview/SKILL.md:269-277 — the light tier treats `.txt` and
`.gitconfig` files as plain documentation, so a diff limited to them skips /security, the
tests, the external reviewers, and the built-in review, and still gets a marker. Re-checked at
0ccfae7: text unchanged.
  Attack vector: gitconfig/aliases.gitconfig is live configuration. zat.env-install.sh:78-82
    adds it to ~/.gitconfig through include.path, and it can set `core.fsmonitor`,
    `core.pager`, `core.sshCommand`, or a `!` alias, each of which runs a command during
    ordinary git use. Downstream, `requirements*.txt` (pip accepts `--index-url` and direct
    URL requirements) and `CMakeLists.txt` share the extension. Such a change is reviewed
    only for "broken links/references, accidental secret leaks in prose, and factual
    accuracy" (lines 283-284), while `.json`, `.yaml`, and `.toml` get the full tier because
    they are operationally live (lines 271-272).
  Evidence: lines 269-277 are unchanged, and `codereview-marker surface` lists both
    extensions (bin/codereview-marker:133-135), so the gap is in the tier rule. This run's
    own diff (gitconfig/ignore-global, a gitignore file that cannot run anything) took the
    full tier only because it has no extension. The 2026-10-02 scan ran a `core.fsmonitor`
    set through an included file on `git status`. Confidence: high on the mechanism.
  Remediation: drop `.txt` and `.gitconfig` from the light tier (or keep only `.gitignore`
    and prose `.txt` that is neither a dependency manifest nor a build file), and update the
    lint pin at tests/lint-skills.sh:420.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — review state
that the reviewed commits can change decides how deeply those commits are reviewed, and the
changes never appear in the reviewed diff (same trust in claude/skills/security/SKILL.md:43-46
and claude/skills/pr/SKILL.md:184-191, not re-checked). Re-checked at 0ccfae7: unchanged.
  Attack vector: commits the operator did not author (a contributor branch merged or
    checked out locally, a cherry-picked patch) edit CODEREVIEW.md and SECURITY.md beside
    the code. A REVIEW_META with block 0, the right base, and reviewed_up_to at the code
    commit makes the run a refresh with an empty focus set; a SECURITY.md META footer
    naming that commit with scope full makes Step 5 skip /security; an Accepted Risks line
    describing the code downgrades matching findings to NOTE (lines 206-207, 559). The
    review diff, the security surface, and the push hash all exclude these files (line
    238, bin/codereview-marker:68), so no reviewer sees the edit, and /pr merge accepts
    the same REVIEW_META with no review at all.
  Evidence: the 2026-10-02 scan reproduced the deterministic part with the skill's Step 2
    and Step 5 commands in a scratch repo; the cited text is unchanged. The model-executed
    downgrades were not run end to end. Confidence: high on the mechanism, medium on how
    the model weighs planted entries.
  Remediation: at Step 2, list `git log --format='%h %ae %s' "$(codereview-marker
    base)"..HEAD -- CODEREVIEW.md SECURITY.md`. When a commit not authored by the operator
    (`git config user.email`) touched them, take the full tier, run /security, read prior
    META and Accepted Risks from `git show "$(codereview-marker base):<file>"`, and do not
    honor Accepted Risks added in the range until the user confirms them.

[WARN] bin/codereview-marker:156, 167, 173, 177 — `list_surface`, `list_uncommitted`, and
`compute_hash` call `git diff` without `--ignore-submodules`, so when a submodule has
`ignore = all` (in .gitmodules, or `diff.ignoreSubmodules=all` in any git config), its pointer
changes are left out of the marker hash, the uncommitted check, the security surface, and the
review diff (claude/skills/codereview/SKILL.md:238, 471) (carried from the 2026-10-02 scan,
not re-checked).
  Attack vector: in a project with a submodule, a commit moves the pointer to an older,
    vulnerable release or an unreviewed upstream commit. With `ignore = all` already in
    .gitmodules, `hash` exits 2 and the hook prints "nothing to review. Allowed."; without
    it, the same commit can add `ignore = all`, and every reviewer sees only that line
    while `codereview-marker write` produces a marker the hook accepts.
  Evidence: as recorded on 2026-10-02 (both cases reproduced in scratch repos, git 2.34.1)
    and re-read at 6c9741a. bin/codereview-marker is unchanged since 6c9741a.
  Remediation: pass `--ignore-submodules=dirty` to every `git diff` in the script (the
    hash of a repo without submodules is unchanged), add it to the review diffs in
    SKILL.md Steps 2, 5.5, E.3, and E.4 (or add a `codereview-marker diff` subcommand),
    update the lint pins that match those commands, and add an `ignore = all` test.

[WARN] claude/global-claude.md:108 — the convention loaded into every session binds every
service to 0.0.0.0. That is safe only behind a host firewall that sees the service's traffic,
which Docker-published ports bypass and which the documented setup path never enables
(carried from the 2026-10-02 scan, not re-checked).
  Attack vector: an agent follows this line and claude/references/networking.md:14 to
    start a container for a dev UI or model server (Jupyter, Gradio, an OpenAI-compatible
    server). Docker publishes the port through its own NAT and FORWARD rules ahead of UFW,
    so the service answers on the box's public address, and many such services have no
    authentication. hw-bootstrap.sh installs Docker and never enables UFW. Since 6c9741a
    the rule also reaches Windows sessions, and claude/references/windows.md tells them
    that networking.md, the only place the firewall premise is written down, describes
    the Linux GPU box.
  Evidence: as recorded on 2026-10-02 (a public /32 on the Linux box with ufw and docker
    active and no `"iptables": false`; its rules are root-only and were not read) and
    re-read at 6c9741a. global-claude.md is unchanged since 6c9741a.
  Remediation: bind to the Tailscale address rather than all interfaces (`--host
    "$(tailscale ip -4)"`, `-p "$(tailscale ip -4):PORT:PORT"`), or 127.0.0.1 plus
    `tailscale serve`. If 0.0.0.0 stays, add DOCKER-USER rules that drop forwarded traffic
    not arriving on tailscale0, have hw-bootstrap.sh enable UFW, and give Windows its own
    binding guidance.

[WARN] claude/skills/pr/SKILL.md:184-191, 217 — /pr merge's review gate passes when the
review covers any ancestor of local HEAD, and the merge acts on the remote PR head, which the
gate never compares with local HEAD (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: a commit lands on the PR branch after the last /codereview (a GitHub
    suggestion, a bot, a collaborator, a terminal push, or a "push now" skip). `git
    merge-base --is-ancestor "${REVIEWED_UP_TO}" HEAD` stays true, and `gh pr merge
    --squash` merges the remote head, so the unreviewed commit reaches main with the gate
    reporting a passing review.
  Evidence: as recorded on 2026-10-02 (reproduced with the skill's own commands). The
    file is unchanged since c03a14c.
  Remediation: require no non-review-file change since the reviewed commit (`git diff
    --quiet "${REVIEWED_UP_TO}" HEAD -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md'
    ':!SPEC.md'`), stop unless the remote PR head equals local HEAD, and pass
    `--match-head-commit` where gh supports it.

[NOTE] hooks/pre-push-codereview.sh:63-73, 89, 142 — the hook's tokenizing time grows with
the square of the command's length, so a long command passes the 30 s timeout, and without
`onFailure` (WARN above) the push then runs. Re-checked at 0ccfae7 on Linux, which corrects
the cause the 6c9741a entry gave: the process-substitution read from b065794 is not the
Linux cost. `_normalize_ops` pads operators with six bash pattern substitutions, each
quadratic in bash 5.1, and the hook runs it three times (once in is_git_push, twice in
is_tag_only_push).
  Attack vector: no adversary. One Bash call that writes a large file with a heredoc and
    then commits and pushes. A command that size is well over 100k tokens in one tool call,
    so it is rare.
  Evidence: end to end against a scratch repo with an unreviewed commit, using shell-like
    text with one operator character per ~13 bytes: 65.6 KB took 0.45 s, 250 KB 4.2 s,
    500 KB 14.7 s, 650 KB 24.6 s, 750 KB 32.0 s, 1 MB 62.3 s, and 4 MB was still running at
    a 120 s cap. Every run that finished exited 2. 6c9741a's here-string and the in-process
    split the 6c9741a entry proposed took 15.6 and 14.4 s at 500 KB and 57.2 and 55.6 s at
    1 MB, the same as HEAD. Profiled: one `_normalize_ops` call took 0.29, 1.12, and 4.4 s
    at 125, 250, and 500 KB, and the read took 30 to 139 ms. Denser text is slower: with
    one operator per ~4.5 bytes, one call took 14.3 s at 500 KB, so the hook passes 30 s
    near 400 KB. On Git Bash the 6c9741a re-check measured the same code at 34.5 s for
    500 KB. No hook test uses a long command. Confidence: high on the mechanism, low on
    reachability.
  Remediation: normalize once in main and pass the tokens to both functions, and pad the
    operators in one linear pass, for example `tr '\n' ';' | sed 's/[;|&()]/ & /g'`, which
    produced identical tokens in 19 ms at 500 KB. Or refuse (exit 2) any recognized push
    whose command exceeds a fixed size, telling the agent to push in its own Bash call. Add
    65,600-byte and 500 KB cases to tests/test-pre-push-hook.sh.

[NOTE] zat.env-install.sh:200, 208 — every settings.json write creates a new file at the
process umask and moves it into place (also lines 262, 271, 280, 302, 337, 354, 372), so a
settings.json the user restricted to 0600 comes back 0644 or 0664 on each run. (Pre-existing;
carried in CODEREVIEW.md since 2026-10-01 and listed here for the first time.)
  Attack vector: settings.json can hold secrets in its `env` block, and its hooks run as the
    user. Where another account can traverse the home directory (macOS creates
    /Users/<name> as 0755), that account can read the file after a re-run; with umask 0002
    and a primary group shared with other accounts, it can also edit the hooks. Not
    reachable on this host: the home directory is 0750, and group peter has no other
    members. The installer itself writes no secret there.
  Evidence: ~/.claude/settings.json here is 0664 (umask 0002) after today's install. In the
    scratchpad, a 0600 file rewritten with the installer's `jq ... > tmp && mv` pattern
    came back 0664. Whether Claude Code's own settings writes keep the mode was not
    checked. Confidence: high on the mechanism, low on reachability.
  Remediation: `umask 077` at the top of the installer (which also closes the reviewer
    .env's brief creation window), or restore the file's previous mode after each rewrite.

[NOTE] hooks/pre-push-codereview.sh:92 — the walker treats only the token `git` as git, so
`git.exe push`, which runs git in Git Bash, passes the gate. This is the Windows counterpart
of the absolute-path spelling in the accepted "detection is heuristic" risk; it is listed for
a decision, not re-flagged. Re-checked at 0ccfae7: line 92 unchanged.
  Attack vector: an agent on Windows writes `git.exe push`, the native program's file
    name. The hook exits 0 for it, so whether Claude Code's `if` filter passes the command
    to the hook does not matter.
  Evidence: run directly on Linux against a scratch repo with an unreviewed commit, the hook
    exited 2 for `git push` and 0 for `git.exe push` (and for `/usr/bin/git push`, the
    accepted spelling). The spelling runs git only on Windows, where the 6c9741a scan pushed
    a scratch commit this way through the live gate. Confidence: high on the mechanism, low
    on frequency.
  Remediation: in _push_subcommand_indices, treat a token whose basename is `git` or
    `git.exe` as git (which also closes the accepted absolute-path case), add tests, and
    confirm with a live push that the `if` filter reaches the hook for `git.exe push`. Or
    add `git.exe` to the accepted risk.

[NOTE] claude/skills/codereview/SKILL.md:238, 471 — the review diffs honor the repository's
own .gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as
"Binary files a/<f> and b/<f> differ", while the marker hash still binds its content (same in
the external-mode diffs at lines 141 and 165). Re-checked at 0ccfae7: still present.
  Attack vector: a commit the operator did not write adds `<file> -diff` to .gitattributes
    beside a change to that file; or, more commonly, a downstream repo marks a lockfile
    `-diff` to quiet noise, and a dependency swap in it reaches review as that one line.
    The external reviewers see only the diff, so they get nothing of the change, and a
    refresh review reads only diff hunks for already-reviewed files (lines 333-335). A
    full-tier inline review and /security still read the whole file (it stays in
    `codereview-marker surface`), but nothing marks what changed.
  Evidence: re-run on Linux (git 2.34.1). One commit added `app.py -diff` and changed
    `return token == SECRET` to `return True`. The Step 2 diff showed the .gitattributes
    hunk and "Binary files a/app.py and b/app.py differ", `surface` listed both files, and
    `git diff --numstat` printed `-` counts for app.py. Confidence: high on the mechanism,
    low on likelihood.
  Remediation: in Step 2, list the changed files git renders as binary (`git diff
    --numstat` prints `-` counts for them), review any that are text with `git diff --text
    -- <file>`, and send those hunks to the external reviewers too; report an added
    `-diff` or `binary` attribute on a text path as a finding.

[NOTE] claude/skills/codereview/SKILL.md:460-464 — the secret-in-diff guard relies on a step
that reports secrets, and in a full-tier review no step looks for them in plain markdown.
Re-checked at 0ccfae7: unchanged.
  Attack vector: no adversary. A diff touches code and also adds a key to a markdown file,
    so it takes the full tier. Step 4's full-tier dimensions (lines 363-380) include no
    secret check (only the light tier's reduced scope does, line 283), and /security
    receives only `codereview-marker surface` files, which omit plain markdown
    (bin/codereview-marker:133-143). Neither reports the key, and Step 5.5 sends the diff,
    key included, to OpenAI and Google.
  Evidence: traced through the skill text and the surface code; not run end to end.
    Confidence: high on the mechanism.
  Remediation: before Step 5.5, grep the exact diff it will send for key patterns (`sk-`,
    `sk-ant-`, `AIza`, `ghp_`, `github_pat_`, `AKIA`, `xox[bp]-`, `hf_`, private-key
    headers) and skip the providers on a match, or add a whole-diff secret check to Step 4.

[NOTE] claude/skills/codereview/SKILL.md:405-410, 437-441 — the model extracts the commit
field of SECURITY.md's META footer and pastes it into a shell command, so codereview-marker's
leading-dash check (bin/codereview-marker:146-155) runs only after the shell has expanded it.
Re-checked at 0ccfae7: unchanged.
  Attack vector: a commit that edits SECURITY.md puts a `$(...)` or backtick span in the
    footer's commit value. If the model substitutes it unquoted or in double quotes into
    `codereview-marker surface <meta-commit>`, the substitution runs under the skill's
    `Bash(*)` grant. Step 2 already avoids this for reviewed_up_to with a hex-only
    `grep -oP` inside the command substitution (lines 295, 316).
  Evidence: traced through the skill text; not tested against a live model, which may
    refuse such a value. Confidence: medium on the mechanism, low on likelihood.
  Remediation: extract the commit inside the command with a hex-only `grep -oP` (7 to 40
    hex characters), or add a codereview-marker subcommand that reads the footer, and
    update the lint pin at tests/lint-skills.sh:401.

[NOTE] hooks/pre-push-codereview.sh:241-245 — the skip marker is honored at any age and for
any diff, so a marker left by a tag-only push or a terminal push lets a later, unreviewed
agent push through. Deferred to BACKLOG.md (skip-marker-bound-to-diff). Re-checked at 0ccfae7:
unchanged.
  Attack vector: a leftover marker plus a later agent push.
  Evidence: on Linux, a skip marker backdated 30 days let `git push` from a scratch repo with
    an unreviewed commit through (exit 0), and the hook removed it. Confidence: high on the
    mechanism, low on frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match,
    or add an age limit.

[NOTE] hooks/pre-push-codereview.sh:226-327 — the hook evaluates the repository at its own
working directory, not the repository being pushed. Deferred to BACKLOG.md
(push-gate-pushed-repo). Re-checked at 0ccfae7: still present.
  Attack vector: `git -C <other> push`, or `cd <other> && git push`, run from a clean
    repository or a non-git directory pushes <other> without review. The .git-directory
    variant (line 226 treats a failed `--show-toplevel` inside .git as "not in a git
    repo") is unchanged.
  Evidence: on Linux, from a scratch repo equal to its upstream, `git -C <other> push` and
    `cd <other> && git push` exited 0, while `git push` run inside <other>, which held an
    unreviewed commit, exited 2. Confidence: high on the mechanism, low on reachability of
    the .git variant.
  Remediation: resolve the target repo from the command (`-C`, `--git-dir`, a leading
    `cd <dir> &&`) and evaluate the marker there, failing closed when it cannot be
    resolved, or move to a git-native pre-push hook. For the .git variant, pass through
    only when `git rev-parse --git-dir` fails.

[NOTE] bin/review-external.sh:276-278 — without bc, `_calc` splices the cost expression into
awk program text, and awk's `system()` runs commands, so a non-integer operand would execute
as the user; `_count` is the only guard (carried from the 2026-10-13 scan, not re-checked).
  Attack vector: none at HEAD. Lines 357-359 and 464-466 pass all six token counts through
    `_count` before `_calc` sees them (lines 375, 478). If a later edit hands `_calc` a raw
    value, a provider response with `"input_tokens":"system(\"cmd\")"` runs cmd on every
    host without bc, which includes every Git Bash install. Only the provider, or someone
    who can tamper with its TLS connection, controls that field.
  Evidence: as recorded at 6c9741a (`_calc` run in a scratchpad executed a `system()`
    operand; `_count` maps it to 0; the hostile-value test covers only OpenAI
    input_tokens). bin/review-external.sh is unchanged since 6c9741a.
  Remediation: keep the awk program fixed and pass the numbers with `-v`, or have `_calc`
    print "?" for any expression that is not digits, dots, spaces, parentheses, and
    `*/+`. Extend the hostile-value test to every count, once with bc removed from PATH.

[NOTE] bin/codereview-marker:131-144 — the security surface keeps agent-instruction markdown
only by a fixed name list, so markdown that agents read as instructions under other names
counts as plain documentation (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: global-claude.md:96, :100, and :108 point sessions at
    claude/references/windows.md, ml-gpu.md, and networking.md, which agents follow as
    conventions; CLAUDE.md tells skill authors to move details into a skill's references/
    directory; a CLAUDE.md can `@`-import any markdown file. in_surface drops all of
    these, so a diff limited to them takes the light tier, and in a full-tier run they
    never reach /security's file list.
  Evidence: as recorded on 2026-10-02 and at 6c9741a, where `codereview-marker surface
    c03a14c` omitted the new windows.md. bin/codereview-marker is unchanged since 6c9741a.
  Remediation: also keep `*/references/*.md` and markdown under zat.env's `claude/` tree,
    and files a CLAUDE.md `@`-imports; or invert the rule and drop only known prose paths
    (README*, docs/, CHANGELOG*).

[NOTE] bin/review-external.sh:365 — the long-context price comparison is a bash arithmetic
context, which expands a command substitution hidden in an array subscript. `_count` (lines
284-286) makes it safe, but no test covers this sink; the Gemini comparison at line 471 is the
same (carried from the 2026-10-01 scan, not re-checked).
  Attack vector: none at HEAD. If a later edit compares the raw jq output instead of the
    `_count` value, a provider response carrying "input_tokens":"PATH[$(cmd)]" runs cmd
    as the user.
  Evidence: as recorded on 2026-10-01 (a mutant run executed the payload while the suite
    still passed) and re-read at 6c9741a. bin/review-external.sh is unchanged since 6c9741a.
  Remediation: name the comparisons and the awk branch in the `_count` comment, change the
    hostile-value test to a payload such as "PATH[$(: > ${TEST_DIR}/ran)]" and assert the
    file does not exist, and add the same case for promptTokenCount.

[NOTE] bin/codereview-marker:104-109, 188 — marker_dir ignores mkdir and chmod failures and
checks neither the directory's owner nor whether it is a symlink, and `write` follows a
symlinked marker path. Deferred to BACKLOG.md (marker-dir-ownership-check) (carried from the
2026-10-02 scan, not re-checked).
  Attack vector: needs XDG_CACHE_HOME in a directory another account can write, where that
    account pre-creates the directory or plants a symlink at the marker path. On Windows
    `chmod 700` changes nothing, so the directory's privacy rests on the ACL it inherits.
  Evidence: as recorded on 2026-10-02 and at 6c9741a (the Windows ACL grants only SYSTEM,
    Administrators, and the user). test-codereview-marker.sh's mode check passes on this
    Linux host.
  Remediation: verify a real directory owned by the current user and private to it (mode
    0700, or an ACL check on Windows) and fail otherwise, then write the marker to a temp
    file in that directory and rename it into place.

[NOTE] bin/codereview-marker:170-178 — the marker hashes only the net diff against the base,
so a secret committed and then deleted inside the pushed range ships in history without
review. Deferred to BACKLOG.md (push-gate-net-diff-secret) (carried from the 2026-10-02 scan,
not re-checked).
  Attack vector: no adversary needed; an agent commits a key, removes it in a later
    commit, and the review sees only the net diff.
  Evidence: as recorded on 2026-10-02 (compute_hash diffs the base against the working
    tree, and /codereview reviews the same net diff).
  Remediation: scan the per-commit diffs of `<base>..HEAD` for key patterns before
    writing the marker.

[NOTE] claude/skills/pr/SKILL.md:152 — the PR template puts free text derived from commit
messages inside double-quoted shell arguments, where backticks or `$(...)` run as commands
under the skill's `Bash(*)` grant (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: `gh pr create --title "<title>" --body "<body>"` with a commit subject or
    body carrying a code span or `$(...)`; even "adds `codereview-marker write`" would run
    that command and write the push marker.
  Evidence: as recorded on 2026-10-02 (traced through the template; not run).
  Remediation: write the body with a quoted heredoc and pass `--body-file`; build the
    title the same way.

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is
an inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for
the rest of the turn that invokes it (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: the post-ExitPlanMode hook tells the model to run `/spec plan`, so a turn
    that leaves plan mode can carry unprompted Bash, Write, and Edit into implementation,
    where content the model reads can steer a command.
  Evidence: as recorded on 2026-10-02 (documented grant semantics; not tested).
  Remediation: narrow /spec's grant to what it runs (git read commands,
    spec-backlog-apply.sh, Read, Grep, Glob) and let Write and Edit fall to the session's
    rules; consider the same for /codereview and /architect.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294)
send the caller's unpushed commit subjects to api.openai.com and
generativelanguage.googleapis.com (carried from the 2026-10-01 scan, not re-checked).
  Attack vector: no adversary; the data leaves the machine without the user's opt-in.
  Evidence: as recorded on 2026-10-02 (a recording curl stub saw "=== COMMITS ===" with the
    unpushed subjects in three of four real-curl requests). This scan did not run the
    suite for that reason.
  Remediation: run these tests against the suite's fake curl with FAKE_CODE=401, or from
    ${TEST_DIR}.
```

### Coverage

All eight dimensions were reviewed for the five files at HEAD 0ccfae7.

- Read in full: hooks/pre-push-codereview.sh (344 lines), zat.env-install.sh (425),
  claude/skills/codereview/SKILL.md (742), and gitconfig/ignore-global (24).
- tests/lint-skills.sh (1,916) was read in part: its helpers, the b065794 hunks, the pins
  findings cite (lines 380-440), and the frontmatter and Windows sections (lines 1800-1916).
  The rest was searched for eval, source, `bash -c`, interpreter calls, temp files, network
  calls, and file writes, which found only grep pins and a fixed `python3 -c` program. It was
  not read line by line; earlier scans covered it through its diffs.
- Every commit since 6c9741a was read. b065794 and 0ccfae7 change code; 916d070, 35a2fbf, and
  bfed238 change only CODEREVIEW.md, SECURITY.md, and README.md.
- Runs on Linux (bash 5.1.16, git 2.34.1, jq 1.6, shellcheck 0.8.0, Claude Code 2.1.296),
  with XDG_CACHE_HOME in the scratchpad: test-pre-push-hook.sh 79/79,
  test-codereview-marker.sh 69/69 (the marker-directory mode check runs here),
  lint-skills.sh 502/502 (with shellcheck and PyYAML). This is the first Linux run of these
  suites since the Windows port. tests/test-review-external.sh was not run, because its
  invalid-key tests reach the real providers (NOTE above).
- The gate checks ran the hook directly, with synthetic payloads, against scratch repos in
  the scratchpad. No command in a payload was executed, nothing was pushed, and zat.env's
  working tree was not changed.
- Out of scope but used as context: bin/codereview-marker (read in full), CODEREVIEW.md,
  SPEC.md, the BACKLOG.md origins of the deferred findings, and the hook schema text in the
  Claude Code 2.1.296 binary.
- Checked and not findings:
  - 0ccfae7: ignore rules apply only to untracked files. `codereview-marker` builds the
    hash, the uncommitted list, and the security surface from `git diff`
    (bin/codereview-marker:156, 167, 173, 177), which sees only tracked files, so the gate
    and the review are unchanged. A repo that tracks `.claude/settings.local.json` still
    shows its changes. Claude Code appends the same rule itself when it creates the file
    (the reason for the commit), so hiding an untracked copy from `git status` matches its
    stock behavior. The rule also keeps per-project permission rules, and any `env` secrets
    in them, out of commits. zat.env's own .gitignore:18 already ignores `.claude/`.
  - b065794 on Linux: the process-substitution read yields the same tokens (79/79, and every
    long-command run that finished exited 2). ~/.claude/settings.json here carries the
    quoted hook commands from today's install. `MSYS_NO_PATHCONV=1` does nothing off
    Windows.
  - If the process substitution at lines 89 and 142 could not be opened, `|| true` would
    leave no tokens, which reads as "not a push". Bash opens it through /dev/fd, which
    exists wherever /proc is mounted, and the here-string it replaced failed the same way
    when bash could not create its temp file.
  - The stale-hook prune (zat.env-install.sh:289-306) reads whole lines and passes the
    script's basename to jq as a regex string. It acts only on entries whose zat.env script
    is missing. REPO_DIR in the double-quoted hook commands is the operator's own path.
  - lint-skills.sh:1835-1838 runs `python3 -c 'import yaml'`, which imports from the
    current directory first. Lint runs from the zat.env checkout, and anyone able to plant
    yaml.py there can edit lint itself.
- Not verified: Claude Code cancelling a hook at 30 s and running the command (taken from
  the binary's field description, not observed); whether Claude Code's own settings.json
  writes keep a restricted mode; Windows timings at this HEAD (the 6c9741a re-check
  measured the same hook code there before it was committed).

Git history checked for secrets: `git log -p --follow -3` for each of the five files, and
every diff in 6c9741a..HEAD. zat.env-install.sh is the credential-handling file in scope (it
creates the reviewer key file). Both were pattern-scanned for OpenAI, Anthropic, Google,
GitHub, AWS, Slack, Hugging Face, and Tailscale keys, private-key headers, and generic key,
token, secret, and password assignments. The only hit was a removed SECURITY.md line naming
the documented fake test keys. The earlier history of these files was covered by the
2026-10-02 scan and the 2026-10-13 scan of 6c9741a. PII: none in the five files.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:221-262`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution. The deny entries are prefix matches and cannot
  enumerate every spelling. Accepted 2026-08-20 because README.md:222 and the script
  comment (lines 216-220) state plainly that the deny list is a speed bump.
  `autoMode.classifyAllShell` sends these commands through the classifier in auto mode,
  so the risk as accepted applies to the other permission modes. The Linux host has the
  setting (verified 2026-10-01 and again 2026-10-13), and so did the Windows host
  (verified 2026-10-13).
- **Venv-activation chains auto-approved outside auto mode**
  (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes,
  the hook returns allow for `. .venv/bin/activate && <anything>`, including pipes,
  `$(...)`, and further commands. The user kept this behavior on 2026-10-01 when
  approving the auto-mode fix, as recorded in CODEREVIEW.md Accepted Risks. The hook
  exists to avoid the eval-like-builtin prompt, and its reach matches the accepted
  interpreter grants in those modes.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  tagging loops at lines 380-386, 483-489, and 544-550): a model steered by
  attacker-authored code under review can emit a correctly tagged finding line that
  /codefix consumes as a spec. The own-tag demux added in 379af38 closes the status
  channel only. It does not limit what a model writes on its own stdout.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 86, Tailscale
  line 201, Claude Code line 209): remote code execution by design over HTTPS to
  first-party vendor domains, which is the documented purpose of a bootstrap script. Not
  checksum-pinned, consistent with first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:184-189): `curl -o` to a
  predictable path, then `sudo dpkg -i`. A TOCTOU vector only on a multi-user host;
  immaterial on the documented single-user target. The three service accounts on the
  Linux host run with PrivateTmp=yes and cannot reach it (verified 2026-10-01).
- **Pre-push gate detection is heuristic, not a shell parser**
  (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper and prefix invocations
  (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and
  `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass
  the advisory codereview gate. Accepted under the advisory-gate threat model. The hook
  is intentionally simple and biased toward over-detection. This does not cover a
  recognized push checked against the wrong ref or the wrong state (the refspec and
  compound-command WARNs), or a recognized push whose hook times out or fails (the
  `onFailure` WARN). Whether the Windows spelling `git.exe push` belongs here is open
  (NOTE above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when
  configured, the full git diff goes to OpenAI and Google, so any secrets in the diff
  would be exposed. Sending the diff is the script's explicit purpose, and the user opts
  in by configuring keys. Since 253ad52, /codereview Step 5.5 skips the providers when
  the review reports a secret in the diff (see the markdown gap NOTE above);
  /codereview external has no such check.

---
*Prior review (2026-10-13, scope: paths, at 6c9741a, with a post-fix re-check of the four
files /codefix changed): 11 files, 0 BLOCK / 8 WARN / 15 NOTE, no secrets. New then: the
`onFailure` WARN (a gate hook that times out, crashes, or cannot start lets the push run), and
NOTEs for the awk cost sink, `git.exe push`, and `-diff` attributes; it resolved the jq
fail-open NOTE. The re-check confirmed the /codefix fixes, since committed as b065794, and
added the tokenizer timing NOTE, restated above.*

<!-- SECURITY_META: {"date":"2026-10-13","commit":"0ccfae7caabed5316aeb8a2849f1203c340c6fc8","scope":"paths","scanned_files":["claude/skills/codereview/SKILL.md","gitconfig/ignore-global","hooks/pre-push-codereview.sh","tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":8,"note":16} -->
