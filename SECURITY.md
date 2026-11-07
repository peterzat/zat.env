## Security Review — 2026-11-07 (scope: paths)

**Summary:** Path-scoped scan, at HEAD 03aacf2, of the six files `codereview-marker surface
895c3d3` lists: bin/spec-backlog-apply.sh, the codereview, pr, and spec skills, tests/lint-skills.sh,
and tests/test-spec-backlog-apply.sh. 03aacf2 commits the /codefix pass that the prior post-fix
re-check covered, plus a rewording of /pr merge's condition 4 that no scan had seen. The rewording
admits the pull case and advises running /codereview after pulling, which does not help: the pulled
commit is already upstream, so the review finds nothing to review and REVIEW_META stays as it was
(the /pr merge WARN, re-reported). Two new NOTEs: External-Only Mode hands a range that begins with
`-` to `git diff` ahead of the script's guard, which writes the diff to a file, and /pr status and
inspect read other people's PR text under a pre-approved `Bash(*)`. No prior finding is resolved,
and there are no secrets. Still pending from the prior entry: this host's live settings.json has the
`Bash` gate matcher on CLI 2.1.311, so re-run zat.env-install.sh and restart open sessions. A
post-fix re-check of the four files /codefix then changed found the /pr merge advice corrected (it
now names a read that shows pulled commits) but the gate unchanged, so that WARN stays, narrowed. A
new NOTE shows the pulled commits can empty that read. The mawk regex fix and the /spec date change
alter no security behavior, and no finding is resolved. Totals: 0 BLOCK / 3 WARN / 24 NOTE.

### Findings

```
[WARN] claude/skills/pr/SKILL.md:183-211 — /pr merge still merges a commit that reached the PR
branch some other way once the operator has pulled it, or one pushed with `codereview-skip`. After
/codefix, condition 4 (lines 194-204), its failure report (lines 206-210), README.md:466-472, and
README.md:838 say that /codereview does not review pulled changes and give a read that shows them,
which replaces the 03aacf2 advice to "run `/codereview` after pulling" (that run found nothing to
review). Nothing in the merge flow runs the read or notices a pull, so the gate is unchanged. What
remains of the 2026-10-02 WARN; re-checked in the post-fix working tree on 03aacf2.
  Attack vector: a collaborator, a bot that pushes to PR branches, or a suggestion applied on
    GitHub adds commit X to the PR branch after the last /codereview. The operator pulls, as a
    routine sync or as the new condition 4 failure report directs, and runs /pr merge without the
    read. Local HEAD and the PR head are both X, REVIEWED_UP_TO is an ancestor of X, and
    REVIEW_BLOCKS is 0, so all four conditions hold, and the forked skill, which cannot tell that a
    pull happened, merges X. A commit pushed with `codereview-skip` passes the same way. Where the
    read is done, the pulled commits can still empty it (the first NOTE below).
  Evidence: /codefix changed only prose. The commands at lines 184-187 and conditions 3 and 4
    (lines 193-194) are as they were at 03aacf2, so that scan's reproduction stands: in a scratch
    repo, after `git pull --ff-only` of a commit authored by bot@example.invalid, the skill's own
    commands gave REVIEW_BLOCKS=0, `merge-base --is-ancestor` true, and a PR head equal to HEAD,
    while `git diff --stat <reviewed_up_to> HEAD` showed the unreviewed line. Confidence: high on
    the mechanism, medium on frequency (it needs someone else's commit on the PR branch).
  Remediation: bind the review to content rather than ancestry. At Step 9, have /codereview record
    a hash of `git diff <reviewed_up_to>` (working tree, review files excluded, computed by a
    codereview-marker subcommand so both sides agree), and have /pr merge require `git diff
    <reviewed_up_to> HEAD` over the same paths to hash the same. That passes the /codefix flow,
    whose committed fixes are the reviewed working-tree change, and refuses a pulled or skipped
    commit. Simpler: have /pr merge list `git log --format='%h %an <%ae> / %cn %s'
    <reviewed_up_to>..HEAD` (a commit made in GitHub's web UI has the committer GitHub) whenever
    it is not empty, and stop for the user to confirm the commits. Needs a user decision.

[WARN] claude/skills/codereview/SKILL.md:203-209, 290-316, 413-436, 574-578, 686-688 — review state
that the reviewed commits can change decides how deeply those commits are reviewed, and the changes
never appear in the reviewed diff (same trust in claude/skills/security/SKILL.md:43-46 and
claude/skills/pr/SKILL.md:183-193). Found in the 2026-10-02 scan. Re-checked at 03aacf2: still
present. The cited lines are unchanged, and 03aacf2's Step 7 rule reads only the hold marks this
run writes.
  Attack vector: commits the operator did not author (a contributor branch merged or checked out
    locally, a cherry-picked patch) edit CODEREVIEW.md and SECURITY.md beside the code. A
    REVIEW_META with block 0, the right base, `"tier":"full"`, and reviewed_up_to at the code
    commit makes the run a refresh with an empty focus set; a SECURITY.md META footer naming that
    commit with scope full makes Step 5 skip /security; an Accepted Risks line describing the code
    downgrades matching findings to NOTE (lines 206-207, 578). The review diff, the security
    surface, and the push hash all exclude these files (line 238, bin/codereview-marker:68), so no
    reviewer sees the edit, and /pr merge accepts the same REVIEW_META with no review at all.
  Evidence: the cited lines read at 03aacf2, and EXCLUDES at bin/codereview-marker:68 still lists
    both files. The 2026-10-02 scan reproduced the deterministic part with the skill's Step 2 and
    Step 5 commands in a scratch repo; the model-executed downgrades were not run end to end.
    Confidence: high on the mechanism, medium on how the model weighs planted entries.
  Remediation: at Step 2, list `git log --format='%h %ae %s' "$(codereview-marker
    base)"..HEAD -- CODEREVIEW.md SECURITY.md`. When a commit not authored by the operator (`git
    config user.email`) touched them, take the full tier, run /security, read prior META and
    Accepted Risks from `git show "$(codereview-marker base):<file>"`, and do not honor Accepted
    Risks added in the range until the user confirms them. Needs a user decision.

[WARN] claude/global-claude.md:108 — the convention loaded into every session binds every service
to 0.0.0.0. That is safe only behind a host firewall that sees the service's traffic, which
Docker-published ports bypass and which the documented setup path never enables (carried from the
2026-10-02 scan, not re-checked).
  Attack vector: an agent follows this line and claude/references/networking.md:14 to start a
    container for a dev UI or model server (Jupyter, Gradio, an OpenAI-compatible server). Docker
    publishes the port through its own NAT and FORWARD rules ahead of UFW, so the service answers
    on the box's public address, and many such services have no authentication. hw-bootstrap.sh
    installs Docker and never enables UFW. Since 6c9741a the rule also reaches Windows sessions, and
    claude/references/windows.md tells them that networking.md, the only place the firewall premise
    is written down, describes the Linux GPU box.
  Evidence: as recorded on 2026-10-02 (a public /32 on the Linux box with ufw and docker active and
    no `"iptables": false`; its rules are root-only and were not read).
  Remediation: bind to the Tailscale address rather than all interfaces (`--host "$(tailscale ip
    -4)"`, `-p "$(tailscale ip -4):PORT:PORT"`), or 127.0.0.1 plus `tailscale serve`. If 0.0.0.0
    stays, add DOCKER-USER rules that drop forwarded traffic not arriving on tailscale0, have
    hw-bootstrap.sh enable UFW, and give Windows its own binding guidance.

[NOTE] claude/skills/pr/SKILL.md:185, 200-210 — the read that condition 4 now gives for pulled PR
changes, `git log -p "${REVIEWED_UP_TO}..HEAD"` or `/codereview external "${REVIEWED_UP_TO}"`, can
be emptied by the pulled commits themselves (same text at README.md:470-472 and 838). It is the
interim step this entry's /pr merge WARN suggested, which /codefix applied. New in the post-fix
re-check.
  Attack vector: someone with push access to the PR branch, as in the /pr merge WARN, writes the
    pulled commits. (1) A commit that adds `<file> -diff` to .gitattributes beside a change to that file
    makes `git log -p` print "Binary files a/<file> and b/<file> differ" in place of the change,
    and /codereview external's diff does the same (the .gitattributes NOTE). (2) REVIEWED_UP_TO is
    read from the working tree's CODEREVIEW.md (line 185), which the pull updates. A code commit X1
    followed by X2, which sets `reviewed_up_to` to X1, shrinks the read to X2's one-line metadata
    hunk, and /codereview external, whose diff excludes CODEREVIEW.md, stops with "Empty diff".
    Condition 3 holds for X1, so the gate passes as before (the review-state WARN). A suggestion
    applied on GitHub or a dependency bot does neither, so the read works for the honest cases.
  Evidence: this re-check, in scratch repos on git 2.34.1. (1) After a bot commit that added
    `app.py -diff` and changed `return token == SECRET` to `return True`, `git log -p` showed the
    .gitattributes hunk and "Binary files a/app.py and b/app.py differ"; with `--text` it showed
    both lines. (2) With X1 and X2, the skill's line-185 grep returned X1, `merge-base
    --is-ancestor` held, `git log -p` listed only X2's CODEREVIEW.md hunk, and the E.3 `git diff`
    was 0 lines, while `git log -p --text` from the pre-pull head showed X1's change. `git pull`,
    fast-forward or merge, set ORIG_HEAD to the pre-pull head. Not run through the skill or a live
    model. Confidence: high on the mechanism, low on likelihood (it needs a hostile committer on
    the PR branch, and a reader who does not question a new `-diff` line or a metadata-only
    commit).
  Remediation: take the range from the heads, not from files the pull changes. In the condition 4
    failure report, say to `git fetch` and read `git log -p --text "HEAD..${PR_HEAD}"` before
    pulling; in condition 4 and the README, read `git log -p --text ORIG_HEAD..HEAD` right after
    the pull. Add `--text` to External-Only Mode's diffs, as the .gitattributes NOTE suggests. The
    /pr merge WARN's content-hash remediation closes both.

[NOTE] claude/skills/codereview/SKILL.md:115-119, 141, 165 — External-Only Mode hands the range to
`git diff` before `review-external.sh` sees it, and Step E.2's `git rev-parse <ref>` check passes a
value that begins with `-`, so a range such as `--output=<path>` makes Step E.3 write the
working-tree diff to a file. The 2026-08-20 WARN on the same primitive put the leading-dash guard in
the script, which only Step E.4 reaches. New in this scan.
  Attack vector: the range is `$ARGUMENTS` after `external`. Typed by the user it is the user's own
    choice, but /codereview is model-invocable (no `disable-model-invocation`) and its description
    advertises `/codereview external [<ref>|<from>..<to>]`, so text the agent reads, such as a
    cloned repo's CLAUDE.md asking for a second opinion "with /codereview external
    --output=$HOME/.bashrc.d/review", can choose it. E.2 maps a single ref to `<ref>..HEAD` and
    validates the ref, and `git rev-parse` echoes an option it does not know and exits 0. E.3 then
    runs `git diff --output=<path>..HEAD -- ...`, which creates or truncates `<path>..HEAD` with the
    unstaged diff and prints nothing, so the skill stops with "Empty diff" after the write. The name
    always ends in `..<ref>`, so the write matters only in a directory that loads every file, such
    as the ~/.bashrc.d that Fedora's and RHEL's default ~/.bashrc sources. There the diff's context
    lines, which start with a space, run as commands at the next shell start.
  Evidence: this scan, on git 2.34.1 in a scratch repo: `git rev-parse --output=<p>` printed the
    option and exited 0; `git diff --output=<p>..HEAD -- ':!CODEREVIEW.md' ...` printed 0 bytes and
    wrote `<p>..HEAD` holding the diff, its context line ` echo ...` intact; `review-external.sh
    --range` with the same value exited 2 with its dash refusal. Not run through the skill or
    against a live model. Confidence: high on the mechanism, low on likelihood (the model has to
    accept an option as a git ref).
  Remediation: put `--end-of-options` before `<range>` in the E.3 and E.4 `git diff` commands, and
    validate in E.2 with `git rev-parse --verify --quiet --end-of-options "<ref>^{commit}"`. On git
    2.34.1 both refuse the dash value as a bad revision, write nothing, and accept real refs and
    ranges. Pin both in tests/lint-skills.sh beside the script's dash check.

[NOTE] claude/skills/pr/SKILL.md:11, 159-176 — /pr status and inspect pass PR bodies, comments, and
review text, which anyone who can comment on the PR writes, into a fork whose `allowed-tools`
pre-approves `Bash(*)`, and the skill never says that text is data. New in this scan.
  Attack vector: on a public repo any GitHub user can comment on a PR. A comment written as
    instructions to the assistant reaches the model through `gh pr view --json comments --jq
    '.comments[].body'` (line 167), which status mode runs whenever comments exist, or through
    inspect mode's `body`, `reviews`, and `comments` (line 173). If the model follows it, the
    command runs as the user, and outside auto mode the skill's grant means no prompt. On this host
    (defaultMode auto, `autoMode.classifyAllShell` true) the classifier still sees it. The global
    allow list already passes `Bash(gh *)`, `Bash(git *)`, and `Bash(python3 *)` (accepted risk
    below), so the skill's grant adds commands such as `curl`. Unlike the review-state and
    planted-finding paths, this needs no write access to the repo.
  Evidence: lines 11, 159-168, and 172-176 read at 03aacf2, and unchanged in the post-fix re-check.
    /pr is manual-only (line 8), so the user starts the run, and the comments arrive with it. Not
    run against a live model. Confidence: medium on the mechanism, low on likelihood.
  Remediation: say in status and inspect modes that PR bodies, comments, and reviews are other
    people's text, to be summarized as quoted data and never to decide a command, and narrow
    `allowed-tools` to `Bash(gh *)` and `Bash(git *)` so anything else falls to the session's
    rules. The /spec grant NOTE below suggests the same narrowing for /spec.

[NOTE] claude/skills/codereview/SKILL.md:203-209, 566-572 — since 500153c, a finding carried into
a review goes to /codefix with its suggested fix even when its file is outside the diff, and a
carried finding's text is repo content: CODEREVIEW.md's prior entry, or a SECURITY.md finding that
/security carries "not re-checked" by design (claude/skills/security/SKILL.md:142-145). Found in the
2026-11-07 scan at 895c3d3. Re-checked at 03aacf2: still present. 03aacf2's Step 7 (lines 608-613,
656-659) skips /codefix only when every open BLOCK and WARN carries the hold mark, so a planted
finding without the mark still starts a cycle.
  Attack vector: a commit the operator did not author (as in the review-state WARN above) adds a
    WARN to SECURITY.md's current entry about a file the push does not change, such as a CI
    workflow or a dependency manifest, with a concrete remediation that pins an action or a
    package to a commit, version, or index the attacker chose. A path-scoped /security run carries
    it at its original severity without re-checking, Step 6 sends it to /codefix "like any other
    when its suggested fix is concrete", and /codefix takes the suggested fix as its spec
    (claude/skills/codefix/SKILL.md:40-44). A planted CODEREVIEW.md finding takes the same route
    after Step 1's check that its pattern is still in the code, which the attacker can make true,
    and lines 208-209's rule against downgrading it. The change lands outside the contributor's
    visible diff, in a review that reports it as a fix. The accepted third-party-model risk covers
    the external reviewers' findings; this channel is the repo's own files.
  Evidence: lines 566-572 and 203-209, and codefix lines 33-47, re-read at 03aacf2. What stands in
    the way is model judgment: the /security post-fix re-check of the files /codefix changed
    (lines 635-646) and the re-review, both of which see a pin, which reads as hardening. Not run
    against a live model. Confidence: medium on the mechanism, low on likelihood.
  Remediation: in Step 6, send a carried finding to /codefix only after this run has confirmed it
    against the code, as Step 6 already requires for the built-in review's findings, and with a
    fix this run derives from the code instead of one copied from the carried text. Mark a finding
    that /security carried as not re-checked `Requires a user decision; not for /codefix.` The
    review-state WARN's remediation, which distrusts review files that others' commits changed,
    closes the planted-text half. Since Step 7 runs /codefix only for findings without that mark,
    the mark alone keeps such a finding out of the fix loop. Needs a user decision, since 500153c
    chose the current rule.

[NOTE] claude/skills/pr/SKILL.md:232-240 — the `--match-head-commit` guard ahead of the merge
applies only when `gh pr merge --help` lists the flag, and this host's gh 2.4.0 (Ubuntu 22.04's
package) does not. There, a commit that reaches the PR branch between condition 4's check (lines
187, 194) and `gh pr merge` merges unreviewed. Found in the 2026-11-07 post-fix re-check at
895c3d3. Re-checked at 03aacf2 and in the post-fix re-check: still present (gh still 2.4.0, and the
lines moved only because condition 4's text grew).
  Attack vector: a collaborator, or a bot that pushes to PR branches, pushes commit X while /pr
    merge runs. After `gh api` returns a PR head equal to local HEAD, the skill still runs the
    readiness `gh pr view` and `gh pr merge --help` before it merges, a window of seconds, and `gh
    pr merge --squash` then squashes the PR's current head, X included. hw-bootstrap.sh installs gh
    from GitHub's APT repo only when no gh is present, so a host that already had Ubuntu's 2.4.0
    keeps it, as this one has.
  Evidence: this scan: `gh --version` prints 2.4.0+dfsg1 and `gh pr merge --help` lists no
    `--match-head-commit`. As recorded at 895c3d3, `expectedHeadOid` appears once in the binary, as
    a struct tag, with no flag that sets it (not traced in gh's source). No merge or API call was
    made. Confidence: high that the guard is absent here, low on likelihood (it needs a push inside
    that window).
  Remediation: when the flag is missing, merge through the REST endpoint, which takes the expected
    head on every gh version: `gh api -X PUT "repos/{owner}/{repo}/pulls/${PR_NUMBER}/merge" -f
    merge_method=squash -f sha="$(git rev-parse HEAD)"` (GitHub refuses with 409 when the head
    moved), then delete the branch as `--delete-branch` does. Or stop and ask the user to upgrade
    gh.

[NOTE] bin/spec-backlog-apply.sh:64, 158-162 — the symlink guard checks only the last path
component, and the script resolves BACKLOG.md against the caller's working directory, so a run from
inside a tracked directory link still creates and fills a BACKLOG.md outside the repo. Found in the
2026-11-07 post-fix re-check at d12ce05. Re-checked at 03aacf2: still present; the stray
end-append refusal 03aacf2 commits (lines 102-105, 169-172) runs before any write and adds no path
check. Re-checked in the post-fix re-check: still present; /codefix changed only four awk regexes
(lines 234, 264, 323, 358). Since 5cd6836 the /spec turn-close capture also writes through the
script, so this is the remaining gap in every skill-driven BACKLOG.md write.
  Attack vector: a cloned repo tracks `app -> ../../.bashrc.d`, and text in it steers the agent to
    run the backlog step from app/ (a CLAUDE.md that names app/ as the project root, say), so the
    command is `cd app && spec-backlog-apply.sh <<'MANIFEST'` with an `append:` block. The script
    creates ~/.bashrc.d/BACKLOG.md holding the entry. Fedora's and RHEL's default ~/.bashrc source
    every file in ~/.bashrc.d, so the entry's code spans run at each interactive shell start. The
    Claude Code 2.1.311 binary names `~/.claude/rules/` and `.claude/rules/*.md`, so a link to
    that directory would likely load the entry into every session as instructions. Every skill
    invocation of the script (/spec Steps 3c, 3f, 3g, and 4, and /tester design D.6) says to run
    it from the project root, directly or by pointing at /spec backlog, so the agent has to be
    steered past that, and the target directory must already exist (the script creates none). On
    this host neither directory exists, and ~/.bashrc sources no directory.
  Evidence: this scan, at 03aacf2, in a scratch repo tracking `app -> ../outside` (mode 120000):
    from inside app/, an `append:` manifest exited 0 and created outside/BACKLOG.md holding the
    entry, the repo's status stayed clean, and `git rev-parse --show-prefix` failed (exit 128)
    inside the link. The post-fix re-check re-ran the probe against /codefix's version of the
    script with the same result. The Fedora and RHEL behavior is from their default ~/.bashrc and
    the rules loading from strings in the binary; neither was run. Confidence: high on the
    mechanism, low on likelihood.
  Remediation: refuse unless `git rev-parse --show-prefix` succeeds and prints nothing, which holds
    only when the working directory is the repo's toplevel by its physical path (comparing `pwd -P`
    with `--show-toplevel` would likely fail on Git Bash, where git.exe spells the drive as `C:/`).
    This also stops a stray BACKLOG.md in a subdirectory. It would refuse /spec outside a git
    repo, which needs a decision. Add a test that runs the script from a directory link.

[NOTE] hooks/pre-push-codereview.sh:80-137, 255-258, 272-273 — past the bounds 82379d2 put on its
heredoc tracking, and in a few unusual spellings, a push that bash runs reads as no push. Some of
these f564cd4 refused (regressions of the fix cycles); others no version refused. Last re-checked on
2026-11-07 at d12ce05: still present (carried from the 2026-11-03 scan, not re-checked).
  Attack vector: no adversary is needed, only an unusual spelling. (ran) marks a real push to a bare
    remote by an earlier scan that sent the unreviewed commit.
    - Past a bound, the join reads as f564cd4 did (lines 117-128). Once 16 quoted markers are open,
      after 16 markers on one line, or for a quoted delimiter word over 256 characters, a marker is
      not tracked, so a quoted terminator that ends in a backslash joins the next line again and
      hides a push there. After 16 lines of `# see <<'M<n>'`, `cat <<'X\' >/dev/null`, `X\`, and
      `git push origin main` exit 0; after 15 they are refused. The same holds after `echo "a<<b
      ..."` with 16 `<<` before the real marker on its line, and for a 257-character delimiter word.
    - The cutoff: a token over 1,024 characters that holds both quote kinds, a backslash, or `$'`
      ends the fallback reading for the rest of the command (line 257). After a heredoc line of
      1,106 characters with `it's` inside double quotes, `>/dev/null git push origin main` (ran)
      and `A="x it's y" git push` exit 0. f564cd4 refused them. A long line of prose in a heredoc
      often holds both kinds.
    - Three delimiter spellings that `_hd_unquote` reads differently from bash. Bash ends each
      heredoc at a line that ends in a backslash, so the hook joins that line to the next and hides
      the push there: `cat <<"X'\\"` (bash wants `X'\`, the hook `X\\"`, because a single quote
      inside double quotes is literal), then `X'\`, then `git push` (ran); the same with `<<$'X\\'`
      and `<<$"X\\"`, which bash reads as `X\`.
    - A marker in a comment or a string still decides how one later line joins. After `# see
      <<'git \'`, the lines `git \` and `push` read as no push. The marker must equal the continued
      line exactly, so this is reachable only on purpose. f564cd4 refused it.
    - In every version: a comment line that ends in a backslash. The join keeps the backslash, and
      the fallback reading (lines 272-273) takes it as escaping the `;` the newline becomes, so
      after `# note \`, `A="x it's y" git push origin main` and `>/dev/null git push origin main`
      exit 0. A plain `git push` there is refused.
  Evidence: the 2026-11-07 scan at d12ce05, in a scratch repo with an unreviewed commit: the 16-marker command exited 0
    and the 15-marker one 2, `# note \` then `>/dev/null git push origin main` exited 0, and the
    plain push exited 2. The other items as recorded on 2026-11-03, whose differential fuzz (5,804
    unique commands, a fake git as ground truth) found no miss under the bounds that an older hook
    refused. Confidence: high on the mechanisms, low on frequency.
  Remediation: for the bounds, refuse a recognized push once a bound is reached and the command
    holds a quoted terminator that ends in a backslash, or say in the hook's "Remaining limitation"
    comment that past a bound the join reads as f564cd4 did. For the comment line, drop its
    trailing backslashes from the joined text, as the terminator join does. For the cutoff, read a
    long word that holds both kinds but no backslash or `$'` by running `_quote_scan` on its quote
    characters alone (`${w//[^\"\']/}` under the C locale), since without escapes their order alone
    sets the state. In `_hd_unquote`, keep a single quote inside double quotes, let a backslash
    there escape only `$`, `` ` ``, `"`, and `\`, and drop a `$` before a quote. Add each spelling
    to tests/test-pre-push-hook.sh.

[NOTE] hooks/pre-push-codereview.sh:218-240, 247-277, 282-310, 330-398 — the walker still misses a
push in some spellings that are not wrappers, and a statement can still run before the push inside
a value the hook steps past. Last re-checked on 2026-11-07 at d12ce05: still present (carried from
the 2026-11-03 scan, not re-checked).
  Attack vector: an agent reaches for none of these often, which is why this is a NOTE. (ran) marks
    a real push to a bare remote by an earlier scan.
    - Not read as a push, with an unreviewed commit: `` `git push` ``, `coproc git push`, `timeout
      1.5m git push`, `env "FOO=1" git push`, the quoted spellings `"git" push`, `'git' push`,
      `\git push`, `g""it push`, `git "push"`, `git 'push'`, `git pu\sh`, `git "-C" . push`, and
      `git $'push'`, and the subcommands and aliases `git -c alias.p=push p`, `git submodule
      foreach git push`, and `git subtree push --prefix=sub origin split` (not re-run).
    - A -C value with text after its substitution: `git -C $(pwd)$(echo /) push`, `git -C
      "$(pwd)/$(echo .)" push`, `git -C $(pwd)x push`, and `git -C "$(pwd)x" push`, where the walk
      stops at the text after the substitution.
    - A statement in a value, from a clean tree, where the hook looks before the commit exists:
      `git -c a.b=$(git commit --allow-empty -qm y) push`, its quoted and backtick forms, `git
      --namespace=$(git commit ...) push`, `git push origin main >$(git commit ...; echo
      /dev/null)` and its backtick form, `` A=`./x.sh`; git push ``, ``A=`git commit
      --allow-empty -qm unreviewed` git push``, and `git >"$(git commit --allow-empty -qm y; echo
      /dev/null)" push` (ran).
    - Brace expansion or a glob that spells the command: `git {push,origin,main}`, `{git,push}`,
      and `git pus? origin main` or `git pu[s]h` with a file named push (not re-run).
    - An escaped operator inside a word. `_normalize_ops` pads `\;`, `\|`, and `\&` apart from their
      word, so the rest reads as a new word: `A=x\;y git push` (ran), `A=x\|y git push`, `A=x\&y
      git push`, `git -c a.b=c\;d push`, and `git -c a.b=c\|x push`.
    - Nested double quotes in a substitution inside double quotes, which neither reading models:
      `A="$(echo "a b")" git push`, and `gh repo create me/x --description "$(echo "it's")"
      --source . --push`.
  Evidence: the 2026-11-07 scan at d12ce05, with an unreviewed commit: `A=x\;y git push`, `timeout 1.5m git push`, and
    `git "push"` exited 0 where `git push origin main` exited 2. The rest as recorded on
    2026-11-03, whose differential fuzz found the `A=x\;y` prefix the largest group of misses. The
    ordinary statement-first forms stay refused. Confidence: high on the mechanism, low on
    frequency.
  Remediation: between git and push, refuse a `(` or a word holding a backtick, and refuse a
    redirection target holding a backtick or `$(`; allow a decimal in the numeric regex at line
    288. For the escaped operators, keep `\;`, `\|`, `\&`, `\(`, and `\)` inside their word with a
    placeholder, as lines 143-147 do for `\<` and `\>`. The nested quotes need the scan to track
    `$(` depth inside double quotes. A quote-aware tokenizer (BACKLOG
    push-gate-quoted-text-false-positive) would fix most of these together.

[NOTE] hooks/pre-push-codereview.sh:487-525 — what remains of the target-repo gap: two spellings
still judge a repo other than the one git pushes from. Last re-checked on 2026-11-07 at d12ce05:
still present (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: each needs an unusual target, so this is a NOTE.
    - core.worktree. codereview-marker changes to the toplevel before it diffs, and `worktree = ..`
      in a layout's config makes that toplevel a directory of the enclosing repo. With a layout at
      vendor/inner2 holding an unreviewed commit and its own remote, `git -C vendor/inner2 push
      origin main` exited 0 from a clean enclosing repo, and the toplevel read as the enclosing
      repo's vendor/ directory (2026-11-03; not re-run).
    - `git -C - push`. `cd -P -- -` at line 522 goes to $OLDPWD, because bash special-cases `-` even
      after `--`, while git enters ./-.
  Evidence: the 2026-11-07 scan at d12ce05: with a repo at ./- holding an unreviewed commit and OLDPWD=/, `git -C -
    push` exited 0. Not run for real. Confidence: high on the mechanism, low on frequency.
  Remediation: after entering the target, compare `git rev-parse --absolute-git-dir` with the same
    call run from `--show-toplevel`, and refuse when they differ (on a throwaway copy this kept a
    normal repo, a separate-git-dir checkout, a linked worktree, and a submodule working). For
    `-`, use `./-` at line 522 (not tried). These two items have no BACKLOG deferral entry; the
    pre-approval `git diff` that the old WARN beside them described is now an accepted risk.

[NOTE] hooks/pre-push-codereview.sh:94-152, 188-240, 295-310 — the hook's run time grows with the
square of the command's length in a few shapes, and it tokenizes about ten times per recognized
push and twice for any other command. A long command passes the 30 s timeout, and without
`onFailure` (accepted risk below) the command then runs, including any statement before the push
that the hook would have refused. Last re-checked on 2026-11-07 at d12ce05: still present (carried
from the 2026-10-13 scan, not re-checked).
  Attack vector: no adversary. One Bash call that holds a very long quoted word where the hook
    steps over whole words (an option value, a push argument), a line that ends in tens of
    kilobytes of backslashes, or a few hundred kilobytes of text holding quoted heredoc markers and
    a line continuation. Rare.
  Evidence: the 2026-11-07 scan at d12ce05, a push, a continued line, and a line ending in 4, 8, and 16 KB of
    backslashes: 0.5, 1.8, and 6.8 s (exit 2 each), the quadratic shape the 2026-11-03 scan
    measured (26.9 s at 32 KB, past 30 s near 34 KB). The join counts the run with
    `${line##*[!\\]}` (line 129), which matches ever shorter prefixes. As recorded then, under
    LANG=en_US.UTF-8: `git -c x.y='<64 KB JSON>' push` 26.8 s and `git push origin main -o '<64 KB
    JSON>'` 8.9 s, through `_word_end` and `_word_is_open`; a push, 10,000 lines that each open a
    quoted marker, and a continued line (240 KB) 28.0 s, and past 200 s at 960 KB; the
    minified-JSON heredoc shape 0.41 s at 64 KB. Confidence: high on the mechanism and the
    timings, low on reachability.
  Remediation: count a line's trailing backslashes with `[[ "${line}" =~ (\\+)$ ]]` and
    `${#BASH_REMATCH[1]}` at line 129, and strip them the same way at line 113. Bound `_word_end`
    and `_word_is_open` the way the fallback is, reading a long word with no backslash and one kind
    of quote by its parity. Normalize once in main and pass the tokens to every function, which
    also runs the heredoc tracking once rather than about ten times, and pad the operators in one
    linear pass after joining continuations. Or refuse a command over a fixed size that contains a
    push. Add timed cases for a 64 KB `git -c x.y='<JSON>' push` and a 32 KB run of backslashes to
    tests/test-pre-push-hook.sh.

[NOTE] hooks/pre-push-codereview.sh:337, 461 — the walker treats only a token named `git`, or a path
ending in /git, as git, so `git.exe push`, which runs git in Git Bash, passes the gate, and `gh` has
the same gap without even the /git allowance. This is the Windows counterpart of the absolute-path
spelling that 600d074 closed; it is listed for a decision, not re-flagged. Last re-checked on
2026-11-07 at d12ce05: still present (carried from the 2026-10-13 scan, not re-checked).
  Attack vector: an agent on Windows writes `git.exe push`, the native program's file name, and the
    hook exits 0. `GIT push` runs git on a case-insensitive filesystem (Windows, default macOS).
    `/usr/bin/gh repo create me/x --source . --push` runs git itself, as the plain `gh` form the
    hook refuses does.
  Evidence: the 2026-11-07 scan at d12ce05, on Linux with an unreviewed commit, `git.exe push` exited 0. As recorded on
    2026-11-03: `"/c/Program Files/Git/cmd/git.exe" push`, `GIT push`, and the absolute-path `gh`
    form exited 0, and `gh repo create me/x --source . --push` 2. The git spellings run only on
    the other platforms and were not run there. Confidence: high on the mechanism, low on
    frequency.
  Remediation: compare the token's basename with `git` or `git.exe` at line 337 and with `gh` or
    `gh.exe` at line 461, and add tests. Or add `git.exe` to the accepted risk.

[NOTE] hooks/pre-push-codereview.sh:845-848 — the skip marker is honored at any age and for any
diff, and its check runs before push_sends_commits_outside_head, on purpose for "push now", so a
marker left by a tag-only or terminal push lets a later unreviewed agent push through, including a
push of another ref. Deferred to BACKLOG.md (skip-marker-bound-to-diff). Last re-checked on
2026-11-07 at d12ce05: unchanged (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: a leftover marker plus a later agent push.
  Evidence: the 2026-11-07 scan at d12ce05, a skip marker backdated 30 days let `git push` with an unreviewed commit
    through (exit 0) and was consumed. As recorded on 2026-11-03: a fresh one let `git push origin
    feature:main` through from a clean main, and because the marker is resolved after the hook
    enters a -C target, `codereview-skip` in repo A followed by `git -C B push` was refused and
    left A's marker armed for A's next unreviewed push. Confidence: high on the mechanism, low on
    frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match, or add an
    age limit, and say in the refusal that a bypass applies per repo.

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is an
inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for the rest
of the turn that invokes it. Found in the 2026-10-02 scan. Re-checked at 03aacf2 and in the post-fix
re-check: lines 8-9 unchanged, and neither adds a grant.
  Attack vector: the post-ExitPlanMode hook tells the model to run `/spec plan`, so a turn that
    leaves plan mode can carry unprompted Bash, Write, and Edit into implementation, where content
    the model reads can steer a command.
  Evidence: frontmatter lines 8-9 (`context: inline`, `allowed-tools: Bash(*), Read, Write, Edit,
    Grep, Glob`), and hooks/post-tool-exit-plan-mode.sh:33 still points at `/spec plan`.
    Documented grant semantics; not tested.
  Remediation: narrow /spec's grant to what it runs (git read commands, spec-backlog-apply.sh, Read,
    Grep, Glob) and let Write and Edit fall to the session's rules; consider the same for
    /codereview and /architect.

[NOTE] zat.env-install.sh:200, 213 — every settings.json write creates a new file at the process
umask and moves it into place (also lines 267, 276, 285, 307, 353, 370, 388), so a settings.json
the user restricted to 0600 comes back 0644 or 0664 on each run. Last re-checked at 895c3d3: still
present (carried from the 2026-11-03 scan, not re-checked).
  Attack vector: settings.json can hold secrets in its `env` block, and its hooks run as the user.
    Where another account can traverse the home directory (macOS creates /Users/<name> as 0755),
    that account can read the file after a re-run; with umask 0002 and a primary group shared with
    other accounts, it can also edit the hooks. Not reachable on this host: the home directory is
    0750, and group peter has no other members. The installer itself writes no secret there.
  Evidence: as recorded at 895c3d3: no `umask` in the script, ~/.claude/settings.json at 0664 under
    umask 0002, the home directory at 0750. As recorded on 2026-10-13: a 0600 file rewritten with
    the installer's `jq ... > tmp && mv` pattern came back 0664. Confidence: high on the
    mechanism, low on reachability.
  Remediation: `umask 077` at the top of the installer (which also closes the reviewer .env's brief
    creation window), or restore the file's previous mode after each rewrite.

[NOTE] claude/skills/codereview/SKILL.md:238, 482 — the review diffs honor the repository's own
.gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as "Binary
files a/<f> and b/<f> differ", while the marker hash still binds its content (same in the
external-mode diffs at lines 141 and 165). Found in the 2026-10-13 scan. Re-checked at 03aacf2:
still present; none of the four diff commands passes `--text`.
  Attack vector: a commit the operator did not write adds `<file> -diff` to .gitattributes beside a
    change to that file; or, more commonly, a downstream repo marks a lockfile `-diff` to quiet
    noise, and a dependency swap in it reaches review as that one line. The external reviewers see
    only the diff, so they get nothing of the change, and a refresh review reads only diff hunks for
    already-reviewed files (lines 344-348). A full-tier inline review and /security still read the
    whole file (it stays in `codereview-marker surface`), but nothing marks what changed.
  Evidence: as recorded on 2026-10-13 (git 2.34.1). One commit added `app.py -diff` and changed
    `return token == SECRET` to `return True`. The Step 2 diff showed the .gitattributes hunk and
    "Binary files a/app.py and b/app.py differ", `surface` listed both files, and `git diff
    --numstat` printed `-` counts for app.py. Confidence: high on the mechanism, low on likelihood.
  Remediation: in Step 2, list the changed files git renders as binary (`git diff --numstat` prints
    `-` counts for them), review any that are text with `git diff --text -- <file>`, and send those
    hunks to the external reviewers too; report an added `-diff` or `binary` attribute on a text
    path as a finding.

[NOTE] claude/skills/codereview/SKILL.md:471-475 — the secret-in-diff guard relies on a step that
reports secrets, and in a full-tier review no step looks for them in plain markdown. Found in the
2026-10-02 scan. Re-checked at 03aacf2: still present.
  Attack vector: no adversary. A diff touches code and also adds a key to a markdown file, so it
    takes the full tier. Step 4's full-tier dimensions (lines 376-391) include no secret check
    (only the light tier's reduced scope does, line 286), and /security receives only
    `codereview-marker surface` files, which omit plain markdown (bin/codereview-marker:131-144).
    Neither reports the key, and Step 5.5 sends the diff, key included, to OpenAI and Google. The
    symlinked BACKLOG.md WARN, resolved in 897b1a7, was one way a key file's content could reach
    such a diff.
  Evidence: traced through the skill text and the surface code; not run end to end. Confidence: high
    on the mechanism.
  Remediation: before Step 5.5, grep the exact diff it will send for key patterns (`sk-`, `sk-ant-`,
    `AIza`, `ghp_`, `github_pat_`, `AKIA`, `xox[bp]-`, `hf_`, private-key headers) and skip the
    providers on a match, or add a whole-diff secret check to Step 4.

[NOTE] claude/skills/codereview/SKILL.md:416-420, 448-452 — the model extracts the commit field of
SECURITY.md's META footer and pastes it into a shell command, so codereview-marker's leading-dash
check (bin/codereview-marker:152) runs only after the shell has expanded it. Found in the
2026-10-02 scan. Re-checked at 03aacf2: still present.
  Attack vector: a commit that edits SECURITY.md puts a `$(...)` or backtick span in the footer's
    commit value. If the model substitutes it unquoted or in double quotes into `codereview-marker
    surface <meta-commit>`, the substitution runs under the skill's `Bash(*)` grant. Step 2 already
    avoids this for reviewed_up_to with a hex-only `grep -oP` inside the command substitution
    (lines 298, 323).
  Evidence: traced through the skill text; not tested against a live model, which may refuse such a
    value. Confidence: medium on the mechanism, low on likelihood.
  Remediation: extract the commit inside the command with a hex-only `grep -oP` (7 to 40 hex
    characters), or add a codereview-marker subcommand that reads the footer, and update the lint
    pin that matches that text. b47852a closed the same class in /spec with a format rule and
    single quotes, which would also fit here.

[NOTE] bin/review-external.sh:276-278 — without bc, `_calc` splices the cost expression into awk
program text, and awk's `system()` runs commands, so a non-integer operand would execute as the
user; `_count` is the only guard (carried from the 2026-10-13 scan, not re-checked).
  Attack vector: none at HEAD. Lines 357-359 and 464-466 pass all six token counts through `_count`
    before `_calc` sees them (lines 375, 478). If a later edit hands `_calc` a raw value, a provider
    response with `"input_tokens":"system(\"cmd\")"` runs cmd on every host without bc, which
    includes every Git Bash install. Only the provider, or someone who can tamper with its TLS
    connection, controls that field.
  Evidence: as recorded at 6c9741a (`_calc` run in a scratchpad executed a `system()` operand;
    `_count` maps it to 0; the hostile-value test covers only OpenAI input_tokens).
  Remediation: keep the awk program fixed and pass the numbers with `-v`, or have `_calc` print "?"
    for any expression that is not digits, dots, spaces, parentheses, and `*/+`. Extend the
    hostile-value test to every count, once with bc removed from PATH.

[NOTE] bin/codereview-marker:131-144 — the security surface keeps agent-instruction markdown only by
a fixed name list, so markdown that agents read as instructions under other names counts as plain
documentation (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: global-claude.md:96, :100, and :108 point sessions at claude/references/windows.md,
    ml-gpu.md, and networking.md, which agents follow as conventions; CLAUDE.md tells skill authors
    to move details into a skill's references/ directory; a CLAUDE.md can `@`-import any markdown
    file. in_surface drops all of these, so a diff limited to them takes the light tier, and in a
    full-tier run they never reach /security's file list.
  Evidence: as recorded on 2026-10-02 and at 6c9741a, where `codereview-marker surface c03a14c`
    omitted the new windows.md.
  Remediation: also keep `*/references/*.md` and markdown under zat.env's `claude/` tree, and files a
    CLAUDE.md `@`-imports; or invert the rule and drop only known prose paths (README*, docs/,
    CHANGELOG*).

[NOTE] bin/review-external.sh:365 — the long-context price comparison is a bash arithmetic context,
which expands a command substitution hidden in an array subscript. `_count` (lines 284-286) makes it
safe, but no test covers this sink; the Gemini comparison at line 471 is the same (carried from the
2026-10-01 scan, not re-checked).
  Attack vector: none at HEAD. If a later edit compares the raw jq output instead of the `_count`
    value, a provider response carrying "input_tokens":"PATH[$(cmd)]" runs cmd as the user.
  Evidence: as recorded on 2026-10-01 (a mutant run executed the payload while the suite still
    passed).
  Remediation: name the comparisons and the awk branch in the `_count` comment, change the
    hostile-value test to a payload such as "PATH[$(: > ${TEST_DIR}/ran)]" and assert the file does
    not exist, and add the same case for promptTokenCount.

[NOTE] bin/codereview-marker:104-109, 188 — marker_dir ignores mkdir and chmod failures and checks
neither the directory's owner nor whether it is a symlink, and `write` follows a symlinked marker
path. Deferred to BACKLOG.md (marker-dir-ownership-check) (carried from the 2026-10-02 scan, not
re-checked).
  Attack vector: needs XDG_CACHE_HOME in a directory another account can write, where that account
    pre-creates the directory or plants a symlink at the marker path. On Windows `chmod 700` changes
    nothing, so the directory's privacy rests on the ACL it inherits.
  Evidence: as recorded on 2026-10-02 and at 6c9741a (the Windows ACL grants only SYSTEM,
    Administrators, and the user).
  Remediation: verify a real directory owned by the current user and private to it (mode 0700, or an
    ACL check on Windows) and fail otherwise, then write the marker to a temp file in that directory
    and rename it into place.

[NOTE] bin/codereview-marker:170-178 — the marker hashes only the net diff against the base, so a
secret committed and then deleted inside the pushed range ships in history without review. Deferred
to BACKLOG.md (push-gate-net-diff-secret) (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: no adversary needed; an agent commits a key, removes it in a later commit, and the
    review sees only the net diff.
  Evidence: as recorded on 2026-10-02 (compute_hash diffs the base against the working tree, and
    /codereview reviews the same net diff).
  Remediation: scan the per-commit diffs of `<base>..HEAD` for key patterns before writing the
    marker.

[NOTE] claude/skills/pr/SKILL.md:152 — the PR template puts free text derived from commit messages
inside double-quoted shell arguments, where backticks or `$(...)` run as commands under the skill's
`Bash(*)` grant. Found in the 2026-10-02 scan. Re-checked at 03aacf2 and in the post-fix re-check:
line 152 unchanged.
  Attack vector: `gh pr create --title "<title>" --body "<body>"` with a commit subject or body
    carrying a code span or `$(...)`; even "adds `codereview-marker write`" would run that command
    and write the push marker.
  Evidence: traced through the template; not run.
  Remediation: write the body with a quoted heredoc and pass `--body-file`; build the title the same
    way.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294) send the
caller's unpushed commit subjects to api.openai.com and generativelanguage.googleapis.com (carried
from the 2026-10-01 scan, not re-checked).
  Attack vector: no adversary; the data leaves the machine without the user's opt-in.
  Evidence: as recorded on 2026-10-02 (a recording curl stub saw "=== COMMITS ===" with the unpushed
    subjects in three of four real-curl requests).
  Remediation: run these tests against the suite's fake curl with FAKE_CODE=401, or from
    ${TEST_DIR}.
```

No prior finding is resolved: 03aacf2 changes none of the mechanisms the in-scope findings cite.
The post-fix re-check resolves none either: /codefix's /pr merge change corrects the advice the WARN
called wrong but leaves the gate as it was.

### Coverage

All eight dimensions were reviewed for the six files at HEAD 03aacf2; the working tree matched HEAD
throughout.

- Read in full: bin/spec-backlog-apply.sh (372 lines) and the codereview (764), pr (252), and spec
  (726) skills. tests/test-spec-backlog-apply.sh through its setup, teardown, symlink cases, the
  case 03aacf2 adds, and a grep of every file-system operation; every case runs inside its
  `mktemp -d` directory, which an EXIT trap removes. tests/lint-skills.sh through its helpers, the
  two pins 03aacf2 changes, the shellcheck and frontmatter sections, and a grep for `eval`,
  `source`, `rm`, `curl`, `mktemp`, `chmod`, `python3`, and writes; it is a static checker that
  writes nothing and parses frontmatter with `yaml.safe_load`.
- Suites on Linux (bash 5.1.16, git 2.34.1), run from a scratch working directory with TMPDIR and
  XDG_CACHE_HOME in the scratchpad: test-spec-backlog-apply.sh 127/127 and lint-skills.sh 562/562,
  with no temp files left. Shellcheck 0.8.0 is clean on the backlog script at style level and on
  both test files at warning level. tests/run-all.sh was not run, because test-review-external.sh
  calls the real provider APIs (NOTE above).
- Probes, each in a new scratchpad directory: the /pr merge pull case, the directory link, and the
  External-Only range (Evidence above). Fetches into a bare repo stood in for every push. The live
  gate refused this scan's first probe, which held a scratch `git push` among other statements,
  before any of it ran.
- Checked and not findings:
  - 03aacf2's other changes. The Step 7 skip applies only when every open BLOCK and WARN carries
    the hold mark this run writes in Step 6.5, and Step 8 still writes no marker while a BLOCK
    remains (lines 668, 678). The `--since` date stays inside single quotes behind the format rule
    (claude/skills/spec/SKILL.md:96-98, 258-260), and both lint pins match only the quoted form.
    The stray end-append refusal runs before any write. A body line reading `append: <heading>`
    after an early `end-append` still runs the lines between as ops (in CODEREVIEW.md); it touches
    single entries, is recoverable through git, and needs the model to write such a body.
  - The /pr merge greps each return one value against the current review files (one REVIEW_META
    and one security metadata footer).
  - The Step 5.6 child keeps Bash; as recorded on 2026-10-02 it starts in auto mode on this host, so
    its Bash calls reach the classifier (settings re-read: defaultMode auto, classifyAllShell true).
  - The backlog script's adopt date is not format-checked before `awk -v`, so `\n` in it becomes a
    line break in BACKLOG.md; an `append:` already writes any text, so this grants nothing. Its
    mktemp and mv path leaves BACKLOG.md at mode 0600 (as in this checkout), which is stricter.
- Not verified: Windows and macOS at this HEAD, and the model-mediated paths (the review-state
  downgrades, planted findings, and the two new NOTEs) against a live model.

Git history checked for secrets: `git log -p --follow -3` for each of the six files (commits
03aacf2, 500153c, 72dee81, 13b67ba, b47852a, 5cd6836, 5c774f1, and 6f43afe) and the 895c3d3..HEAD
diff, pattern-scanned for OpenAI, Anthropic, Google, GitHub, GitLab, AWS, Slack, Hugging Face, npm,
and Tailscale keys, private-key headers, and generic key, token, secret, and password assignments,
and for email addresses. No hits. None of the six files handles credentials. PII: none added.

Nothing left the machine, and no marker was written. zat.env's tree was not changed apart from this
file.

Post-fix re-check (same day, the working tree on 03aacf2 after /codefix), all eight dimensions, for
the four files /codefix changed: bin/spec-backlog-apply.sh, the pr and spec skills, and
tests/lint-skills.sh. README.md's matching change was read for the /pr merge WARN; it is plain
markdown and outside the listed scope.

- Read: the full working-tree diff of the five files, the backlog script and the pr skill in full,
  /spec Steps 2 and 3d, and External-Only Mode Steps E.2 to E.4 (for the advice that points there).
- Suites, run as above: test-spec-backlog-apply.sh 127/127 under gawk 5.1.0 and 127/127 under mawk
  1.3.4 20200120 (a PATH shim); the HEAD script under the same shim failed 13 of 127, which confirms
  the shim took effect. lint-skills.sh 562/562 under both. Shellcheck 0.8.0 is clean on the backlog
  script at style level and on lint at warning level. No temp files were left.
- Probes, each in a new scratchpad directory: the directory link (against /codefix's script), the
  `-diff` and moved-`reviewed_up_to` cases for the new NOTE, and `git pull` setting ORIG_HEAD
  (fast-forward and merge, from a local clone). `gh pr merge --help` on gh 2.4.0 still lists no
  `--match-head-commit`. No probe command named a push.
- Checked and not findings:
  - The four awk regexes now spell out their intervals: the same matches under gawk, and correct
    under mawk, which ignored the ACTIVE annotation before. No path, input, or write handling
    changed. No awk interval expression remains in the script or in lint (the `sed -E` at line 70
    keeps its intervals, which GNU and BSD sed support).
  - The /spec stale-proposal date keeps its format rule and single quotes; only the literal time
    changed, and the lint pin still matches only the quoted form.
  - The new advice and failure report take values only from the line-185 grep (hex only, so
    `/codereview external "${REVIEWED_UP_TO}"` cannot carry the leading dash of the External-Only
    NOTE) and from GitHub's `.head.sha`. Every branch of the failure report stops; a push it
    advises goes through the gate. With an empty PR_HEAD (no PR) it names the wrong cause but
    still stops.
  - The lint D.7 boundary change (`/^###? /`) extracts the same 23 lines under gawk and mawk.
- Not verified: the new NOTE's paths through the skill or a live model, and the regex fix under
  macOS's BSD awk or Git Bash (the spelled-out form needs no interval support, but it was not run
  there).
- Git history: HEAD is unchanged since the scan above, so its history check stands. The added lines
  of the five-file diff were pattern-scanned for the same key families and for email addresses: no
  hits.

### Accepted Risks

- **`/pr merge` cannot tell reviewed commits from later ones** (claude/skills/pr/SKILL.md, review
  gate conditions 3 and 4): a commit pulled from the PR after the review, or pushed with
  `codereview-skip`, passes the gate. The skill and README state the gap and name a read for pulled
  changes. Deferred 2026-11-07 to BACKLOG `pr-merge-reviewed-changes-hash`.
- **Review files decide review depth** (claude/skills/codereview/SKILL.md, Steps 1, 2, 5, and 6):
  CODEREVIEW.md and SECURITY.md edits inside the reviewed commits can anchor a refresh, mark
  findings accepted, or skip a security scan, and the review diff excludes those files. Needs a
  hostile committer in the reviewed range. Deferred 2026-11-07 to BACKLOG
  `review-files-set-review-depth`.
- **Gate follows `git -C <path>` before approval** (hooks/pre-push-codereview.sh,
  `enter_push_target`): the hook runs `git diff` in the repo a `-C` names before the command is
  approved, so that repo's config (`core.fsmonitor`, `diff.external`) chooses what runs. Accepted
  2026-11-07, following the 2026-11-03 decision to stop patching the tokenizer: the next gate change
  is the heredoc-aware rewrite (BACKLOG `push-gate-quoted-text-false-positive`). If revisited,
  pinning `-c core.fsmonitor= -c diff.external=` on the hook's git calls is the small mitigation.
- **Gate judges only refs spelled on the command line** (hooks/pre-push-codereview.sh): fetched
  refs, refs chosen by config (`remote.<name>.push`, `push.default=matching`), git's abbreviated
  options, `--repo -d`, `--mirror`, and `--recurse-submodules=on-demand` can still send unreviewed
  commits. Accepted 2026-11-07 under the advisory-gate threat model of the detection entry below; a
  git-native pre-push hook, which receives the exact refs, is the structural fix.
- **No `onFailure: block` on the gate entries** (zat.env-install.sh): a hook that times out,
  crashes, or cannot start lets the command through. Accepted 2026-11-07: the hook runs on every
  shell command, so `block` would refuse every shell command while the script is missing, including
  the ones needed to fix it.
- **Submodule `ignore = all` hides pointer changes** (bin/codereview-marker): the marker hash, the
  uncommitted check, the security surface, and the review diff all miss a pointer change in such a
  submodule. Accepted 2026-11-07: zat.env has no submodules, and the setting has to be chosen in the
  repo's own config.
- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:226-267`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)` each reach
  arbitrary execution. The deny entries are prefix matches and cannot enumerate every spelling.
  Accepted 2026-08-20 because README.md:224 and the script comment (lines 221-225) state plainly that
  the deny list is a speed bump. `autoMode.classifyAllShell` sends these commands through the
  classifier in auto mode, so the risk as accepted applies to the other permission modes. The Linux
  host has the setting (verified 2026-10-01, 2026-10-13, and 2026-11-03), and so did the Windows host
  (verified 2026-10-13). The hook's `git diff` before approval (its own entry above) is not covered
  by this, because it runs ahead of the classifier.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in
  default, acceptEdits, plan, and dontAsk modes, the hook returns allow for `. .venv/bin/activate &&
  <anything>`, including pipes, `$(...)`, and further commands. The user kept this behavior on
  2026-10-01 when approving the auto-mode fix, as recorded in CODEREVIEW.md Accepted Risks. The hook
  exists to avoid the eval-like-builtin prompt, and its reach matches the accepted interpreter grants
  in those modes.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh` tagging loops
  at lines 380-386, 483-489, and 544-550): a model steered by attacker-authored code under review can
  emit a correctly tagged finding line that /codefix consumes as a spec. The own-tag demux added in
  379af38 closes the status channel only. It does not limit what a model writes on its own stdout.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to
  `peterzat`): inherent to a personal dotfiles repo. Reviewed and accepted.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 86, Tailscale line 209, Claude
  Code line 217): remote code execution by design over HTTPS to first-party vendor domains, which is
  the documented purpose of a bootstrap script. Not checksum-pinned, consistent with first-party
  supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:184-189): `curl -o` to a predictable
  path, then `sudo dpkg -i`. A TOCTOU vector only on a multi-user host; immaterial on the documented
  single-user target. The three service accounts on the Linux host run with PrivateTmp=yes and cannot
  reach it (verified 2026-10-01).
- **Pre-push gate detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): the
  walker misses a push inside an interpreter (`bash -c`, `eval`), behind a wrapper that takes a
  non-numeric argument (`sudo -u bob`, `env -u X`, `xargs -a f`, `flock`), or behind a prefix whose
  quoted value holds whitespace (`GIT_SSH_COMMAND="ssh -i key" git push`). Each lets a push bypass the
  advisory codereview gate. Accepted under the advisory-gate threat model. The hook is intentionally
  simple and biased toward over-detection. Since 600d074 the plain `env`, `command`, `xargs`,
  absolute-path, and env-var-prefix spellings this entry used to list are detected, and since 49ecf37
  a `v[0-9]` branch no longer reads as a tag. Re-checked at f564cd4: the interpreter and wrapper
  examples still pass, and a prefix whose quoted value holds whitespace, mixed quotes included, is
  now detected (a prefix holding a substitution with nested quotes is still missed, walker NOTE; and
  after 82379d2, one after a token over 1,024 characters that holds both quote kinds or a
  backslash, or after a comment line that ends in a backslash, regression NOTE). This does not
  cover a recognized push checked against the wrong ref or the wrong repo (the command-line refs
  entry above and the target-repo NOTE), a spelling that is not a wrapper (the walker and regression
  NOTEs), or a recognized push whose hook times out or fails (the tokenizing NOTE and the
  `onFailure` entry above). Whether the Windows spelling `git.exe push` belongs here is open (NOTE
  above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when configured, the full
  git diff goes to OpenAI and Google, so any secrets in the diff would be exposed. Sending the diff is
  the script's explicit purpose, and the user opts in by configuring keys. Since 253ad52, /codereview
  Step 5.5 skips the providers when the review reports a secret in the diff (see the markdown gap NOTE
  above); /codereview external has no such check.

---
*Prior review (2026-11-07, scope: paths, at 895c3d3): the eleven files `codereview-marker surface
431af78` listed, then a post-fix re-check of the six files /codefix changed; 0 BLOCK / 3 WARN / 21
NOTE, no secrets. It resolved the Monitor gate gap and the light-tier WARN, closed the /spec date and
turn-close NOTEs, narrowed the /pr merge WARN to the pull case, added NOTEs on carried findings
reaching /codefix and on gh 2.4.0 lacking `--match-head-commit`, and found that this host's live
settings.json still had the old `Bash` gate matcher.*

<!-- SECURITY_META: {"date":"2026-11-07","commit":"03aacf214ecad2498a02671958d9cba5592930e3","scope":"paths","scanned_files":["bin/spec-backlog-apply.sh","claude/skills/codereview/SKILL.md","claude/skills/pr/SKILL.md","claude/skills/spec/SKILL.md","tests/lint-skills.sh","tests/test-spec-backlog-apply.sh"],"block":0,"warn":3,"note":24} -->
