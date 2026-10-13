## Security Review — 2026-10-13 (scope: paths)

**Summary:** Path-scoped scan of the 11 security-surface files changed since c03a14c, at HEAD
6c9741a (the Windows 11 port, plus the a631978 fixes the prior post-fix re-check covered),
with a post-fix re-check of the four files /codefix then changed (uncommitted): 0 BLOCK /
8 WARN / 15 NOTE, and no secrets. New findings: one WARN, because the gate's hook entries
keep Claude Code's default of running the push when the hook times out or crashes. On
Windows, a 128-byte band of command lengths (a here-string deadlock) reached that path at
HEAD, and so does a ~125 MB first push. There are also three new NOTEs: an awk command sink
in the no-bc cost path, `git.exe push` passing the gate on Windows, and `-diff` attributes
hiding hunks from the reviewed diff. 6c9741a resolves the jq fail-open NOTE. The other prior
findings in these files are still present, and four in out-of-scope files are carried.
Post-fix: the fix resolves the here-string hang (the hook now blocks across the band in
about 5 s), and a repo path with spaces no longer stops the gate from starting. No finding
is fully resolved: the `onFailure` WARN stays open, and the fix adds one NOTE, because its
pipe read makes a command of 400 to 500 KB outlast the 30 s timeout.

### Findings

```
[WARN] zat.env-install.sh:320-337 — the two pre-push gate entries set no `onFailure`, and by
default Claude Code runs the tool call when a command hook times out, crashes, or cannot
start. On Windows the hook nears its 30 s timeout on a large first push and, with the
uncommitted /codefix change, on a command of 400 to 500 KB, so a push the gate recognizes
goes out unreviewed. (New. The default predates 6c9741a; the Windows triggers arrive with
it. Re-checked after /codefix: the here-string hang this WARN cited is fixed, and
`onFailure` is still unset.)
  Attack vector: no adversary is needed. The hook's fail-closed paths (exit 2 when
    codereview-marker breaks, and since 6c9741a when jq cannot read the payload) hold only
    while the script runs to completion. Three things skip them. (1) A long command, such
    as a heredoc that writes a file followed by a commit and a push in one Bash call. At
    HEAD, a length after _normalize_ops of 65,536 to 65,663 bytes hangs the `read -ra`
    here-string (hooks/pre-push-codereview.sh:89, 142) on Git Bash. The fix closes that
    band, but its pipe read now passes 30 s between 400 and 500 KB (NOTE below).
    (2) On Windows, a first push (empty-tree base), or a branch that adds about 125 MB of
    text, keeps `codereview-marker hash` running up to the timeout. (3) On any platform, a
    moved or renamed zat.env checkout or a hook that cannot start exits with a code other
    than 0 or 2, which is non-blocking. The fix quotes the script path in the stored
    commands (lines 320, 341, 359), which closes the space-in-path case. A `$` or
    backtick in the path still breaks the command, as before. The hooks reference ("Block
    the action when a hook fails") says a timed-out command hook "doesn't block the tool
    call ... so don't count on a stalled hook to act as a gate", and "a policy hook with a
    wrong path or a crashing script lets everything through". The accepted "detection is
    heuristic" risk covers pushes the hook does not recognize; it recognizes these.
  Evidence: on this host (Git Bash 5.3.15, Claude Code 2.1.296), the hook was run directly
    with a scratch XDG_CACHE_HOME against a scratch repo holding an unreviewed commit. At
    HEAD, normalized commands of 65,535 or 65,664 bytes exited 2 in 3 to 5 s, and 65,536,
    65,600, and 65,663 bytes were still running at a 40 s cap (exit 124). With the fix the
    same three exited 2 in 4.9 to 5.0 s. A 125 MB first push took 29.8 s through the hook
    (26.4 s in `codereview-marker hash`), and 50 MB took 14.0 s. From a zat.env copy at a
    path with spaces, with HOME in the scratchpad, HEAD's installer stored a command that
    exited 127 under `bash -c` and `sh -c`. The fixed installer replaced both gate entries
    (no duplicates) with a command that exited 2. The live ~/.claude/settings.json keeps
    the unquoted commands until the installer is re-run. The docs quotes are from
    code.claude.com/docs/en/hooks.md, fetched 2026-10-13; the cancellation itself was not
    observed live. tests/test-pre-push-hook.sh has no long command, and lint pins neither
    the read form nor `onFailure`. Confidence: high on the mechanisms and the documented
    behavior, low on how often a command or a diff is that large.
  Remediation: add `"onFailure": "block"` to both entries (Claude Code 2.1.295 or later)
    and pin it in lint, so a cancelled or crashed gate refuses the push. Raise the timeout
    (for example to 120 s) so a large first push is not refused once failure blocks.
    Tokenize in-process (NOTE below) and add a 65,600-byte test.
    bin/spec-backlog-apply.sh:109 uses the same here-string form (out of scope; a hang
    there is functional only).

[NOTE] hooks/pre-push-codereview.sh:89, 142 — the uncommitted /codefix change reads the
normalized command from a process substitution, and bash's `read` takes a pipe one byte per
read() call. On Git Bash the hook therefore takes nearly twice as long on a long command and
passes the 30 s timeout between 400 and 500 KB, where HEAD stayed under it to at least
700 KB. With no `onFailure` (WARN above), that push runs unreviewed. (New in the fix.)
  Attack vector: no adversary. One Bash call above that size that writes a file with a
    heredoc and then commits and pushes. At HEAD the same command blocks in time,
    consistent with bash reading a here-string too large for a pipe from a temp file in
    buffered chunks. The fix trades the 128-byte hang band for this open-ended range.
    A command that size is over 100k tokens in one tool call, so it is rare.
  Evidence: run end to end as in the WARN with heredoc commands of 120, 250, 400, 500, and
    700 KB. HEAD took 6.0, 9.8, 14.8, 19.3, and 25.6 s; the fix took 9.1, 18.3, 26.8,
    34.5, and 47.0 s. Every run exited 2. A single read of a 1 MB line took 15.7 to 16.4 s
    through the pipe and 5.6 to 5.7 s through HEAD's here-string. Not measured on Linux,
    where a read() costs far less. Confidence: high on the mechanism, low on reachability.
  Remediation: split in-process with globbing off, `set -f; t=( $(_normalize_ops "$1") );
    set +f`, and the same for `toks` at line 142. Command substitution reads its pipe in
    chunks, and the writer is a separate process, so it cannot deadlock. In this
    re-check, that variant produced the same arrays and blocked the band in 2.7 to 2.9 s,
    500 KB in 10.1 s, and 1 MB in 22.8 s. It also passed tests/test-pre-push-hook.sh 79/79.
    Add 65,600-byte and 500 KB cases to the hook tests.

[WARN] hooks/pre-push-codereview.sh:263-327 — the gate hashes the checked-out branch against
its upstream and allows the push on a match, or on "nothing to review", whatever refs the push
command names. Re-checked at 6c9741a: still present.
  Attack vector: an agent pushes a ref other than the checked-out branch, such as
    `git push origin <other>`, `git push origin <other>:main`, or `git push --all origin`.
    With a valid marker on the current branch, or a current branch equal to its upstream,
    the hook exits 0 and the unreviewed ref reaches the remote, remote main included. The
    hook recognizes the push and checks the wrong content, so the accepted "detection is
    heuristic" risk does not cover this. It is the same-repo sibling of BACKLOG.md
    push-gate-pushed-repo.
  Evidence: re-run at 6c9741a in a scratch repo (isolated XDG_CACHE_HOME, synthetic hook
    input): with `codereview-marker write` run on main and an unreviewed commit on `evil`,
    `git push origin evil` and `git push origin evil:main` both exited 0. The 2026-10-02
    scan also reproduced `--all` and the equal-to-upstream case. tests/test-pre-push-hook.sh
    has no case whose refspec names another branch. Confidence: high on the mechanism,
    medium on how often agents push a non-current ref.
  Remediation: gate any push whose refspec sources are not the current branch, HEAD, or a
    tag; the per-push positional walk in is_tag_only_push (lines 152-168) already
    isolates them. Block `--all`, `--mirror`, and `--branches` the same way. A git-native
    pre-push hook (core.hooksPath), which receives the exact local and remote refs on
    stdin, would close this, the compound-command WARN below, and push-gate-pushed-repo.

[WARN] hooks/pre-push-codereview.sh:263-327 — the hook judges the repository as it is before
the command runs, so commits that the same command creates or imports ahead of its push are
sent on the strength of the earlier state. Re-checked at 6c9741a: still present.
  Attack vector: on a branch equal to its upstream with a clean tree, or one whose
    committed state carries a valid marker, an agent runs `git merge <branch> && git push`,
    `git cherry-pick <sha> && git push`, or an edit, commit, and push in one call. The hook
    finds nothing to review, or a matching marker and nothing uncommitted, and exits 0;
    the commits the command then makes are pushed unreviewed. The hook recognizes the
    push, so the accepted risk does not cover this.
  Evidence: re-run at 6c9741a in a scratch repo: on main equal to origin/main, with an
    unreviewed commit on `feat`, `git merge --no-edit feat && git push` exited 0 ("no
    reviewable changes vs origin/main"). No test puts a history-changing command before
    the push. Confidence: high on the mechanism, medium on frequency.
  Remediation: block any command in which another statement comes before a `git push`
    (ignoring a leading `(`, `{`, or `!`), and tell the agent to run the other statements
    first and `git push` as its own Bash call; the token indices from
    _push_subcommand_indices (lines 86-118) show what comes first. This also stops
    `cd <other> && git push`. A git-native pre-push hook would close it outright.

[WARN] bin/codereview-marker:156, 167, 173, 177 — `list_surface`, `list_uncommitted`, and
`compute_hash` call `git diff` without `--ignore-submodules`, so when a submodule has
`ignore = all` (in .gitmodules, or `diff.ignoreSubmodules=all` in any git config), its pointer
changes are left out of the marker hash, the uncommitted check, the security surface, and the
review diff (claude/skills/codereview/SKILL.md:238, 471). Re-checked at 6c9741a: still present.
  Attack vector: in a project with a submodule, a commit moves the pointer to an older,
    vulnerable release or an unreviewed upstream commit. With `ignore = all` already in
    .gitmodules, `hash` exits 2 and the hook prints "nothing to review. Allowed."; without
    it, the same commit can add `ignore = all`, and every reviewer sees only that line
    while `codereview-marker write` produces a marker the hook accepts.
  Evidence: the four calls are unchanged since the a631978 fixes, against which the
    2026-10-02 post-fix re-check reproduced both cases (git 2.34.1, scratch repos). Not
    re-run here. Confidence: high on the mechanism, low on how often it is reached.
  Remediation: pass `--ignore-submodules=dirty` to every `git diff` in the script (the
    hash of a repo without submodules is unchanged), add it to the review diffs in
    SKILL.md Steps 2, 5.5, E.3, and E.4 (or add a `codereview-marker diff` subcommand),
    update the lint pins that match those commands, and add an `ignore = all` test.

[WARN] claude/skills/codereview/SKILL.md:269-277 — the light tier treats `.txt` and
`.gitconfig` files as plain documentation, so a diff limited to them skips /security, the
tests, the external reviewers, and the built-in review, and still gets a marker. Re-checked
at 6c9741a: text unchanged.
  Attack vector: gitconfig/aliases.gitconfig is live configuration. zat.env-install.sh:78-82
    adds it to ~/.gitconfig through include.path, and it can set `core.fsmonitor`,
    `core.pager`, `core.sshCommand`, or a `!` alias, each of which runs a command during
    ordinary git use. Downstream, `requirements*.txt` (pip accepts `--index-url` and
    direct URL requirements) and `CMakeLists.txt` share the extension. Such a change is
    reviewed only for "broken links/references, accidental secret leaks in prose, and
    factual accuracy" (lines 283-284), while `.json`, `.yaml`, and `.toml` get the full
    tier because they are operationally live (lines 271-272).
  Evidence: lines 269-277 are unchanged, and `codereview-marker surface` lists both
    extensions (bin/codereview-marker:133-135), so the gap is in the tier rule. The
    2026-10-02 scan ran a `core.fsmonitor` set through an included file on `git status`.
    Confidence: high on the mechanism.
  Remediation: drop `.txt` and `.gitconfig` from the light tier (or keep only `.gitignore`
    and prose `.txt` that is neither a dependency manifest nor a build file), and update
    the lint pin at tests/lint-skills.sh:420.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — review state
that the reviewed commits can change decides how deeply those commits are reviewed, and the
changes never appear in the reviewed diff (same trust in claude/skills/security/SKILL.md:43-46
and claude/skills/pr/SKILL.md:184-191, not re-checked). Re-checked at 6c9741a: unchanged.
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

[WARN] claude/global-claude.md:108 — the convention loaded into every session binds every
service to 0.0.0.0. That is safe only behind a host firewall that sees the service's traffic,
which Docker-published ports bypass and which the documented setup path never enables.
Re-checked at 6c9741a: still present (moved from line 104), and it now loads on Windows too.
  Attack vector: an agent follows this line and claude/references/networking.md:14 to
    start a container for a dev UI or model server (Jupyter, Gradio, an OpenAI-compatible
    server). Docker publishes the port through its own NAT and FORWARD rules ahead of UFW,
    so the service answers on the box's public address, and many such services have no
    authentication. hw-bootstrap.sh installs Docker and never enables UFW. Since 6c9741a
    the rule also reaches Windows sessions, and claude/references/windows.md tells them
    that networking.md, the only place the firewall premise is written down, describes
    the Linux GPU box.
  Evidence: the rule is unchanged. The 2026-10-02 scan found a public /32 on the Linux box
    with ufw and docker active and no `"iptables": false`; its rules are root-only and
    were not read. Windows Defender Firewall rules on this host were not inspected.
    Confidence: high on the Docker and UFW mechanism, medium on exposure at a given time.
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

[NOTE] bin/review-external.sh:276-278 — without bc, `_calc` splices the cost expression into
awk program text, and awk's `system()` runs commands, so a non-integer operand would execute
as the user; `_count` is the only guard. (New in 6c9741a.)
  Attack vector: none at HEAD. Lines 357-359 and 464-466 pass all six token counts through
    `_count` before `_calc` sees them (lines 375, 478). If a later edit hands `_calc` a raw
    value, a provider response with `"input_tokens":"system(\"cmd\")"` runs cmd on every
    host without bc, which includes every Git Bash install. Before 6c9741a such a host
    printed "?" and evaluated nothing, and bc's worst case is a loop. Only the provider,
    or someone who can tamper with its TLS connection, controls that field.
  Evidence: `_calc` and `_count` extracted from HEAD and run in the scratchpad: an operand
    of `system("echo SINK-RAN > ran.txt")` wrote the file, and `_count` maps the same
    string to 0. bc is absent on this host, so the awk branch is the one that runs. The
    hostile-value test (tests/test-review-external.sh:883-892) puts a non-integer only in
    OpenAI input_tokens, so dropping `_count` from any of the other five counts would pass
    the suite. The `_count` comment (line 282) still names only bc. Confidence: high on
    the mechanism.
  Remediation: keep the awk program fixed and pass the numbers with `-v`, or have `_calc`
    print "?" for any expression that is not digits, dots, spaces, parentheses, and
    `*/+`. Extend the hostile-value test to every count, once with bc removed from PATH.

[NOTE] hooks/pre-push-codereview.sh:92 — the walker treats only the token `git` as git, so
`git.exe push`, which runs git in Git Bash, passes the gate. This is the Windows counterpart
of the absolute-path spelling in the accepted "detection is heuristic" risk; it is listed for
a decision, not re-flagged. (New with Windows support.)
  Attack vector: an agent on Windows writes `git.exe push`, the native program's file
    name. The hook exits 0 for it, so whether Claude Code's `if` filter passes the command
    to the hook does not matter.
  Evidence: in this session, with zat.env unreviewed and no marker or skip marker,
    `cd <scratch repo> && git.exe push` pushed a scratch commit to a scratch bare repo,
    while `git -C <scratch repo> push` and `cd <scratch repo> && git -c
    push.default=current push` were blocked. Run directly against a repo with an
    unreviewed commit, the hook exited 2 for `git push` and 0 for `git.exe push` and
    `/clangarm64/bin/git.exe push`. Confidence: high on the mechanism, low on frequency.
  Remediation: in _push_subcommand_indices, treat a token whose basename is `git` or
    `git.exe` as git (which also closes the accepted absolute-path case), add tests, and
    confirm with a live push that the `if` filter reaches the hook for `git.exe push`. Or
    add `git.exe` to the accepted risk.

[NOTE] claude/skills/codereview/SKILL.md:238, 471 — the review diffs honor the repository's
own .gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as
"Binary files a/<f> and b/<f> differ", while the marker hash still binds its content (same in
the external-mode diffs at lines 141 and 165). (New.)
  Attack vector: a commit the operator did not write adds `<file> -diff` to .gitattributes
    beside a change to that file; or, more commonly, a downstream repo marks a lockfile
    `-diff` to quiet noise, and a dependency swap in it reaches review as that one line.
    The external reviewers see only the diff, so they get nothing of the change, and a
    refresh review reads only diff hunks for already-reviewed files (lines 333-335). A
    full-tier inline review and /security still read the whole file (it stays in
    `codereview-marker surface`), but nothing marks what changed.
  Evidence: in a scratch repo, one commit added `app.py -diff` and changed `return token
    == SECRET` to `return True`. The Step 2 diff showed the .gitattributes hunk and
    "Binary files a/app.py and b/app.py differ"; `surface` listed both files; the hash
    changed when app.py changed again, so the gate binds the content; `git diff --text`
    showed the edit. Confidence: high on the mechanism, low on likelihood.
  Remediation: in Step 2, list the changed files git renders as binary (`git diff
    --numstat` prints `-` counts for them), review any that are text with `git diff --text
    -- <file>`, and send those hunks to the external reviewers too; report an added
    `-diff` or `binary` attribute on a text path as a finding.

[NOTE] bin/codereview-marker:131-144 — the security surface keeps agent-instruction markdown
only by a fixed name list, so markdown that agents read as instructions under other names
counts as plain documentation. Re-checked at 6c9741a: still present, with a new instance.
  Attack vector: global-claude.md:96, :100, and :108 point sessions at
    claude/references/windows.md, ml-gpu.md, and networking.md, which agents follow as
    conventions; CLAUDE.md tells skill authors to move details into a skill's references/
    directory; a CLAUDE.md can `@`-import any markdown file. in_surface drops all of
    these, so a diff limited to them takes the light tier, and in a full-tier run they
    never reach /security's file list. 6c9741a added windows.md, which tells every Windows
    session how to set up Python and how to run PowerShell from bash, and
    `codereview-marker surface c03a14c` omitted it, so it was not in this scan's list.
  Evidence: in_surface returns 1 for any `.md` whose basename is not in the list and whose
    path has no `.claude/` component (lines 133-143); tests/test-codereview-marker.sh:372
    and 393-395 pin docs/guide.md as omitted. windows.md was read here as context, and its
    guidance is benign. Confidence: high on the mechanism, low on likelihood.
  Remediation: also keep `*/references/*.md` and markdown under zat.env's `claude/` tree,
    and files a CLAUDE.md `@`-imports; or invert the rule and drop only known prose paths
    (README*, docs/, CHANGELOG*).

[NOTE] claude/skills/codereview/SKILL.md:460-464 — the secret-in-diff guard relies on a step
that reports secrets, and in a full-tier review no step looks for them in plain markdown.
Re-checked at 6c9741a: unchanged.
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
Re-checked at 6c9741a: unchanged.
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

[NOTE] bin/review-external.sh:365 — the long-context price comparison is a bash arithmetic
context, which expands a command substitution hidden in an array subscript. `_count` (lines
284-286) makes it safe, but no test covers this sink; the Gemini comparison at line 471 is the
same. Re-checked at 6c9741a: code unchanged (moved from lines 357 and 463). The awk sink above
is the same class.
  Attack vector: none at HEAD. If a later edit compares the raw jq output instead of the
    `_count` value, a provider response carrying "input_tokens":"PATH[$(cmd)]" runs cmd
    as the user.
  Evidence: the token-count lines (357-359, 464-466) and the comparisons are unchanged
    since the 2f556b0 scan, whose mutant run executed the payload while the suite still
    passed. The hostile-value test sends "1; while (1) { }", and no test sends a hostile
    Gemini count. Confidence: high on the mechanism.
  Remediation: name the comparisons and the awk branch in the `_count` comment, change the
    hostile-value test to a payload such as "PATH[$(: > ${TEST_DIR}/ran)]" and assert the
    file does not exist, and add the same case for promptTokenCount.

[NOTE] hooks/pre-push-codereview.sh:241-245 — the skip marker is honored at any age and for
any diff, so a marker left by a tag-only push or a terminal push lets a later, unreviewed
agent push through. Deferred to BACKLOG.md (skip-marker-bound-to-diff). Re-checked at
6c9741a: unchanged (moved from lines 226-230).
  Attack vector: a leftover marker plus a later agent push.
  Evidence: same code; the 2026-10-01 scan reproduced a 30-day-old marker being honored.
    Confidence: high on the mechanism, low on frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match,
    or add an age limit.

[NOTE] bin/codereview-marker:104-109, 188 — marker_dir ignores mkdir and chmod failures and
checks neither the directory's owner nor whether it is a symlink, and `write` follows a
symlinked marker path. Deferred to BACKLOG.md (marker-dir-ownership-check). Re-checked at
6c9741a: unchanged.
  Attack vector: needs XDG_CACHE_HOME in a directory another account can write, where that
    account pre-creates the directory or plants a symlink at the marker path. On Windows
    `chmod 700` changes nothing, so the directory's privacy rests on the ACL it inherits.
  Evidence: on this Windows host Git Bash reads ~/.cache/claude-codereview back as 755
    after the chmod, and its ACL (inherited from the profile) grants only SYSTEM,
    Administrators, and the user; tests/test-codereview-marker.sh now skips the mode check
    there. The 2026-10-02 scan confirmed the errexit behavior. Confidence: high on the
    mechanism, low on reachability.
  Remediation: verify a real directory owned by the current user and private to it (mode
    0700, or an ACL check on Windows) and fail otherwise, then write the marker to a temp
    file in that directory and rename it into place.

[NOTE] hooks/pre-push-codereview.sh:226-327 — the hook evaluates the repository at its own
working directory, not the repository being pushed. Deferred to BACKLOG.md
(push-gate-pushed-repo). Re-checked at 6c9741a: still present.
  Attack vector: `git -C <other> push`, or `cd <other> && git push`, run from a clean
    repository or a non-git directory pushes <other> without review. The .git-directory
    variant from the 2026-10-02 re-check (line 226 treats a failed `--show-toplevel`
    inside .git as "not in a git repo") is unchanged.
  Evidence: this session showed the mechanism live. The gate blocked `git -C <scratch
    repo> push` and `cd <scratch repo> && git -c push.default=current push` because
    zat.env, the session's directory, had no marker. The scratch repo's own state was
    never consulted, so with zat.env reviewed both would have been allowed. Confidence:
    high on the mechanism, low on reachability of the .git variant.
  Remediation: resolve the target repo from the command (`-C`, `--git-dir`, a leading
    `cd <dir> &&`) and evaluate the marker there, failing closed when it cannot be
    resolved, or move to a git-native pre-push hook. For the .git variant, pass through
    only when `git rev-parse --git-dir` fails.

[NOTE] bin/codereview-marker:170-178 — the marker hashes only the net diff against the base,
so a secret committed and then deleted inside the pushed range ships in history without
review. Deferred to BACKLOG.md (push-gate-net-diff-secret). Re-checked at 6c9741a: unchanged.
  Attack vector: no adversary needed; an agent commits a key, removes it in a later
    commit, and the review sees only the net diff.
  Evidence: compute_hash diffs the base against the working tree, and /codereview reviews
    the same net diff. Confidence: high on the mechanism, low on frequency.
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

All eight dimensions were reviewed for the 11 files at HEAD 6c9741a.

- Read in full: hooks/pre-push-codereview.sh (344 lines), bin/codereview-marker (217),
  bin/review-external.sh (615), zat.env-install.sh (422), claude/skills/codereview/SKILL.md
  (742), claude/global-claude.md (112), CLAUDE.md (81), and .gitattributes (6).
- Read through their diffs since c03a14c with the surrounding code: tests/lint-skills.sh
  (1,914; the new Windows and curl-key pins, and the pins at lines 398-422 that findings
  cite), tests/test-codereview-marker.sh (469), and tests/test-pre-push-hook.sh (664, plus
  its setup helpers). The a631978 hunks were read line by line by the 2026-10-02 post-fix
  re-check.
- Runs on Windows 11 ARM64 (Git Bash 5.3.15, git 2.55.0.windows.3, jq 1.8.2, gawk 5.4.0, no
  bc, Claude Code 2.1.296), with XDG_CACHE_HOME in the scratchpad: test-pre-push-hook.sh
  79/79, test-codereview-marker.sh 68/68 plus one skip (NTFS mode), lint-skills.sh 477/477.
  tests/test-review-external.sh was not run, because its invalid-key tests reach the real
  providers (NOTE above); review-external.sh ran once against a recording curl stub instead.
- Live checks through this session's own gate, with zat.env unreviewed and no marker or skip
  marker present: the gate blocked a scratch setup command that contained a push,
  `git -C <scratch repo> push`, and `cd <scratch repo> && git -c push.default=current push`;
  `cd <scratch repo> && git.exe push` went through. Every push targeted a scratch bare repo
  in the scratchpad. Nothing else was pushed, and zat.env's working tree was unchanged.
- Checked and not findings:
  - CR stripping (hooks/pre-push-codereview.sh:208): Git Bash itself removes a bare CR and
    joins the words around it (`echo<CR>WORD` runs `echoWORD`), and Linux bash keeps the CR
    inside the word, so the stripped string tokenizes the way the command runs.
  - The jq path: with jq off PATH, or an unparseable payload, the hook exits 2. An empty
    payload or one without `tool_input.command` reads as "not a push"; the hooks docs give
    the PowerShell tool's command in `tool_input.command`, the same field as Bash.
  - API keys reach curl only on stdin: with a recording stub, curl's arguments held `-H @-`
    and neither key, and stdin held both headers. printf is a builtin, so no process
    carries a key in its argv.
  - The `if` filter reaches the hook for git-level options: `git -C <dir> push` and
    `git -c k=v push` were both gated live.
  - The PowerShell entry is idle here: this session has no PowerShell tool, and settings.json
    sets `env.CLAUDE_CODE_USE_POWERSHELL_TOOL` to "0". How an `if` rule matches compound
    PowerShell commands is undocumented and was not tested.
  - Windows file modes: `chmod 700` and `chmod 600` read back as 755 and 644, but the ACLs on
    ~/.cache/claude-codereview and ~/.config/claude-reviewers/.env grant only SYSTEM,
    Administrators, and the user.
  - Developer Mode, which the installer now requires, lets standard accounts create file
    symlinks. Junctions and object-manager links were already open to them, so it was not
    reported.
  - `* text=auto eol=lf` normalizes the hashed diff and the committed blobs the same way, so
    it cannot open a gap between them. `winpath`, the symlink probe (`mktemp -d`), the
    codereview-marker shadow warning, and the `winget install jqlang.jq` hint touch nothing
    outside the user's own directories.
- Not verified: the end-to-end timeout (Claude Code cancelling the gate at 30 s and running
  the command) is from the hooks reference, not observed; the here-string band on Linux,
  where bash can check the pipe's capacity before using it, and on macOS; whether the `if`
  filter passes `git.exe push` to the hook; Windows Defender Firewall rules for the 0.0.0.0
  WARN.
- Out of scope but used as context: claude/references/windows.md (see the in_surface NOTE),
  claude/references/networking.md, README.md, BACKLOG.md, hooks/README.md, and the Claude
  Code hooks reference.
- Post-fix re-check (/codereview Step 7) of the four files /codefix changed, uncommitted on
  6c9741a: hooks/pre-push-codereview.sh (lines 89 and 142), zat.env-install.sh (the
  stale-hook prune and the quoted hook commands), claude/skills/codereview/SKILL.md (line
  511), and tests/lint-skills.sh (two pins). All eight dimensions were reviewed on the
  changed hunks, and the prior findings in these files were re-checked. Their cited lines
  are unchanged except the `onFailure` WARN's (317-334 is now 320-337). With the fix:
  test-pre-push-hook.sh 79/79, lint-skills.sh 478/478. Checked and not findings:
  - `MSYS_NO_PATHCONV=1` (SKILL.md:511) reaches the Step 5.6 child and everything it
    spawns, the gate hook included. Scratch repos were tested with an upstream, with none
    (empty-tree base), and with a valid marker. With and without the variable,
    `codereview-marker base` and `hash` printed the same values, and the hook returned the
    same exit codes. The gate hands native git no POSIX path except /dev/null, which Git
    for Windows maps itself. test-pre-push-hook.sh fails 32 of 79 with the variable
    exported. That is because the harness passes /tmp paths to native `git -C`, so its
    test repos are never created; the gate itself is unaffected.
  - The prune loop reads whole lines from a process substitution, and nothing in its body
    reads stdin. A quoted command for a missing script was pruned, and the live entries
    stayed. Double quotes leave `$`, backticks, and `"` in REPO_DIR live, as the unquoted
    form did. REPO_DIR is the operator's own checkout path.
  - The `|| true` after each `read` changes no outcome. Both functions run inside `$(...)`
    or an `if`, where errexit is already off, and token counts matched HEAD's at every
    size tested.

Git history checked for secrets: the full history of all 11 files through c03a14c was
checked by the 2026-10-02 scan. This scan pattern-scanned a631978, d6b9410, and 6c9741a
(`git show`) and the current tree of the 11 files for OpenAI, Anthropic, Google, GitHub, AWS,
Slack, Hugging Face, and Tailscale keys, private-key headers, and generic key, token, secret,
and password assignments. The only hits were the documented fake key names in SECURITY.md
prose. The post-fix re-check scanned the uncommitted diff of its four files the same way,
with no hits. PII: nothing new; windows.md uses the placeholder `C:\Users\me`.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:221-262`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution. The deny entries are prefix matches and cannot
  enumerate every spelling. Accepted 2026-08-20 because README.md:222 and the script
  comment (lines 216-220) state plainly that the deny list is a speed bump.
  `autoMode.classifyAllShell` sends these commands through the classifier in auto mode,
  so the risk as accepted applies to the other permission modes. The Linux host had the
  setting on 2026-10-01, and this Windows host has it (verified 2026-10-13).
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
  compound-command WARNs), or a recognized push whose hook times out (the `onFailure`
  WARN). Whether the Windows spelling `git.exe push` belongs here is open (NOTE above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when
  configured, the full git diff goes to OpenAI and Google, so any secrets in the diff
  would be exposed. Sending the diff is the script's explicit purpose, and the user opts
  in by configuring keys. Since 253ad52, /codereview Step 5.5 skips the providers when
  the review reports a secret in the diff (see the markdown gap NOTE above);
  /codereview external has no such check.

---
*Prior review (2026-10-02, scope: paths, at c03a14c, with a post-fix re-check of the six
files /codefix changed): 15 files, 0 BLOCK / 7 WARN / 12 NOTE. The WARNs were push-gate and
review-gate gaps (refspec, compound commands, submodule `ignore = all`, /pr merge ancestry,
the light tier's `.txt` and `.gitconfig`, review state inside the reviewed commits) and the
0.0.0.0 convention. The re-check confirmed the four codefix fixes, since committed as
a631978. All of its findings except the jq fail-open NOTE are still open above.*

<!-- SECURITY_META: {"date":"2026-10-13","commit":"6c9741a108253962cd237c71d0bb035eeafbeb4b","scope":"paths","scanned_files":[".gitattributes","CLAUDE.md","bin/codereview-marker","bin/review-external.sh","claude/global-claude.md","claude/skills/codereview/SKILL.md","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/test-codereview-marker.sh","tests/test-pre-push-hook.sh","zat.env-install.sh"],"block":0,"warn":8,"note":15} -->
