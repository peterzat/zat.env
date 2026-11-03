## Security Review — 2026-11-03 (scope: paths)

**Summary:** Path-scoped scan, at HEAD f564cd4 on the Linux box, of the four security-surface files
f564cd4 changed since the 8e8dee7 scan (CLAUDE.md, hooks/pre-push-codereview.sh,
tests/lint-skills.sh, and tests/test-pre-push-hook.sh), then post-fix re-checks of the hook and its
tests after each of /codefix's three uncommitted cycles. 0 BLOCK / 9 WARN / 18 NOTE, and no secrets.
At f564cd4 the new character scanner held a 72 KB heredoc, commit, and push past the 30 s hook
timeout (WARN, resolved by cycle 1). Cycle 2 resolved the three detection regressions cycle 1 added,
the partly quoted backslash delimiters, and the clustered `-fo -d`, and added two regressions of its
own. Cycle 3 resolves both as reported: the heredoc tracking is bounded (1.5 s where cycle 2 took
32.1 s on the same 28.9 KB command), and the join drops a quoted terminator's trailing backslash, so
`A="x it's y" git push` on the next line is refused again. Its bounds fall back to f564cd4's reading:
after 16 open quoted markers, 16 markers on one line, or a delimiter word over 256 characters, a
terminator that ends in a backslash hides a plain `git push` on the next line again, as at f564cd4
(regression NOTE). Still open: a long word holding both quote kinds or a backslash stops the
fallback, three delimiter spellings that `_hd_unquote` reads differently from bash hide a push, a
comment line ending in a backslash hides a prefixed push in every version, and, also in every
version, `git push --repo -d origin feature:main` sends the branch (refspec WARN). Nineteen findings
in out-of-scope files are carried.

### Findings

```
[WARN] hooks/pre-push-codereview.sh:487-525, 785, 799, 882 — following `git -C <path>` makes the
hook run `git diff` in a directory named by the command, before the command is approved, and that
repo's own config names what `git diff` executes. New with 49ecf37. Re-checked at f564cd4 and after
each fix cycle: still present. f564cd4 narrows it only in that a `-C` inside a quoted or substituted
`-c` value no longer moves the hook; none of the three fix cycles touches this code.
  Attack vector: a hostile repo is cloned. Git refuses to track a `.git` directory but tracks a
    bare-repo layout under any other name, so vendor/inner/{HEAD,config,objects,refs} arrive as
    ordinary files, with `core.worktree = .` and `core.fsmonitor` or `diff.external` in
    vendor/inner/config. An extracted archive carrying a real .git/config works the same way. Text
    in the repo steers the agent to `git -C vendor/inner push`, the form the hook's own refusals
    recommend (lines 785, 799). The configured command then runs as the user, whether or not the
    hook goes on to refuse the push.
  Evidence: at f564cd4 and after each fix cycle, a plain repo target whose .git/config sets both
    keys, with a working-tree change: the hook exited 2 and the payload ran 3 times, as at 8e8dee7
    and on the cycle-3 tree. The clone-delivered layout above, tracked files only and a plain `git
    clone`: the hook exited 0, because the layout holds no commit, and the payload ran twice. `git -C
    vendor/inner diff` or `status` run directly ran it once each. The no-working-tree refusal (lines
    820-829) still stops a layout without `core.worktree` before any `git diff`. `codereview-marker
    hash` (line 882) runs `git diff --quiet` and then `git diff` in the target. Why this is not a
    BLOCK, as at 8e8dee7: an approved `git -C vendor/inner diff` or `status` runs the same payload,
    and `Bash(git *)` skips approval outside auto mode (accepted risk), so what is lost is the
    approval step for this one command, in auto mode, the mode the installer sets. Confidence: high
    on the mechanism, low on how often an agent is steered to that command.
  Remediation: refuse a `-C` target whose toplevel is not the session's, and say to run /codereview
    and the push from inside it. To close the cwd route too, have bin/codereview-marker pass
    `--no-ext-diff --no-textconv` to each diff and export GIT_CONFIG_COUNT overrides for
    `core.fsmonitor=false` and `diff.external=`, refuse a repo whose local config defines
    `filter.*`, and add a clone-delivered layout case to tests/test-pre-push-hook.sh that asserts
    the sentinel is absent.

[WARN] hooks/pre-push-codereview.sh:530-536, 545-630 — a recognized push can still send commits the
review did not cover. The hook judges only refs spelled plainly after the push and counts any
remote-tracking ref as already gated. Re-checked at f564cd4, where the redirection-target group was
closed, and after each fix cycle: cycle 1 closes the `&>` and `-o -d` items and cycle 2 the
clustered `-o`, cycle 3 changes nothing here, and everything below predates every fix cycle
(8e8=0 c3=0 head=0 f1=0 f2=0 f3=0).
  Attack vector: no adversary is needed. From a clean main with an unreviewed `feature`, or in the
    state named, the hook exited 0 at f564cd4 and after each fix cycle for each of these. (ran)
    marks a real push to a bare remote in the scratchpad; the earlier scans' real runs were not
    repeated.
    - Fetched, never reviewed: `git push origin origin/contrib:main`, `git push origin
      fork/evil:refs/heads/main`, and a tag on such a commit, `git push origin v7`.
    - A local upstream: on a branch made with `--track main`, where main holds an unreviewed
      commit, `git push origin topic:main`.
    - Implicit refspecs: `git -c push.default=matching push`, `git -c
      remote.origin.push=feature:main push`, `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.push
      GIT_CONFIG_VALUE_0=feature:main git push`, and `GIT_CONFIG_PARAMETERS=...`. The same keys set
      in config, and `remote.origin.mirror`, were not re-run.
    - Abbreviated options and `--repo=`: `git push --al`, `--mir`, `--ta` (ran: a tag on the
      unreviewed commit reached the remote), and `git push --repo=origin feature`.
    - An option that takes the next word, new in this scan and open in every version: git reads
      `--repo -d` as the repository `-d`, which the positional `origin` then overrides, so `git
      push --repo -d origin feature:main` sends feature to main (ran), and `--rep -d` does the
      same (ran). The walk steps over `--repo` as a flag (line 591) and then returns at the `-d`
      as for a delete (line 587).
    - /pr's spelling in another repo: `git -C <other> push origin "$(git rev-parse --abbrev-ref
      HEAD)"`, where the substitution names a branch of the shell's repo, not <other>'s.
    - An ancestor under a valid marker: `git push origin HEAD~1:main` sends the unfixed commit.
    - A non-tag ref on a tree: with refs/foo/bar on a new tree, `git push --mirror`.
    - A submodule: `--recurse-submodules=on-demand` is skipped as an option (line 591); its payload
      exits 0, but no submodule push was run.
  Evidence: the exits above, six-way against 8e8dee7, the cycle-3 tree, f564cd4, and the three fix
    cycles. Closed by f564cd4: an operator in a quoted redirection target, `> "a;b" feature`,
    `2>"x;y" feature`, `> "a|b" feature`, `> "x (1).log" feature`, and `> 'a&b' feature`,
    refused at line 577. Closed by cycle 1: `git push origin main &>log feature`, `git push
    origin &>/dev/null feature:main`, `&>>log`, `git push -o -d origin feature`, and
    `--push-option -d` or `--delete`, now refused as commits the review cannot cover (line 852).
    Closed by cycle 2: `git push -fo -d origin feature:main`, `-uo -d`, and `-qo -d` (lines
    580-584). Cycle 1 also refuses `GIT_CONFIG_PARAMETERS="'remote.origin.push'='feature:main'"
    git push`, as a side effect of its mixed-quote prefix rule (line 442), though with the "run
    this push as its own command" message; the `GIT_CONFIG_COUNT` form still passes. The controls
    stay refused (`feature`, `feature:main`, `"feature"`, `--all`, `--mirror`,
    `refs/heads/*:refs/heads/*`, `:`, `+:`) and allowed (`>/dev/null 2>&1`, `> push.log 2>&1`,
    `&>/dev/null`, `2>&1 | tail -1`, /pr's spelling, `# don't`, `-o ci.skip`).
    tests/test-pre-push-hook.sh has none of the open cases.
    Confidence: high on the mechanism, medium on frequency for the fetched-branch cases, low for
    the rest.
  Remediation: (1) In the argument walk, treat `--al`, `--b*`, `--m*`, and `--ta*` as the options
    they abbreviate, and `--repo` and its unique abbreviations (and `--receive-pack` and `--exec`)
    as taking the next word as their value. (2) With no refspec, refuse when `push.default` is
    `matching` or `remote.<r>.push` or `remote.<r>.mirror` is set, including through `-c`, and
    refuse `GIT_CONFIG*=` in a prefix and `--recurse-submodules=on-demand`. (3) Count a commit as gated
    only when the pushed remote's tracking ref for the destination has it. A git-native pre-push
    hook (core.hooksPath) receives the exact local and remote refs and would close this WARN with
    most other gate findings. It overrides per-repo hooks and fires on terminal pushes, so it
    needs a user decision.

[WARN] zat.env-install.sh:213, 336-345 — seeding `autoUpdatesChannel` to stable rolled this host
back from Claude Code 2.1.317 to 2.1.311, which predates the fix that makes hooks matching Bash run
on Monitor commands, and the installer registers no Monitor entry. New with 4132078 (carried from
the 2026-11-03 scan at 8e8dee7, not re-checked).
  Attack vector: Monitor is a model-callable tool that takes a shell command and follows the Bash
    permission rules. The 2.1.314 changelog says "Fixed hooks matching Bash not running on shell
    commands started by the Monitor tool". On an earlier build, an agent that runs `git push`
    through Monitor skips the gate for any ref. With the channel set and no `minimumVersion`, the
    updater moves a newer install back.
  Evidence: as recorded at 8e8dee7: ~/.local/bin/claude moved from 2.1.317 to 2.1.311 at 06:18,
    40 minutes after the install wrote the setting. On 2.1.317 a Monitor probe was refused with
    `PreToolUse:Monitor`. The bypass on 2.1.311 was not reproduced: the headless probes stopped at
    the spend limit before any model call. Confidence: high on the rollback, medium on the bypass.
  Remediation: seed `minimumVersion` to 2.1.314 or later beside the channel, which also stops the
    rollback, or add a `"matcher": "Monitor"` gate entry pinned in lint, after checking that two
    matching entries do not run the hook twice and burn a skip marker. Say in README's settings
    bullet that the setting can downgrade. This affects every install, so it needs a user decision.

[WARN] zat.env-install.sh:331-346 — the two pre-push gate entries set no `onFailure`, and by
default Claude Code runs the tool call when a command hook cannot start, exits with a code other
than 0 or 2, or times out (carried from the 2026-11-03 scan at 8e8dee7; the installer was not
re-checked, the hook-side crash was, after cycle 3 too). The crash point is now
hooks/pre-push-codereview.sh:915 (line numbers updated after cycle 3), and the tokenizing NOTE below
names the long-command triggers.
  Attack vector: no adversary is needed. A moved or renamed checkout leaves the stored command
    pointing at a missing script (exit 127) until the installer is re-run. An unreadable marker
    makes `cat` at hooks/pre-push-codereview.sh:915 fail under `set -e` (exit 1). A long command,
    including a long quoted word in a call of about 150 KB or more, keeps the hook past the 30 s
    timeout. The hook recognizes each of these pushes, so the accepted "detection is heuristic"
    risk does not cover them.
  Evidence: as recorded at 8e8dee7, plus this scan: with the marker at mode 000, the f564cd4 hook
    exited 1, and so did the cycle-3 hook (exit 0 with the marker readable). The hooks docs, re-read
    this scan: any other exit code is a "Non-blocking error ...
    The action goes ahead", and with `"onFailure": "block"` a failure does what exit 2 does
    (Claude Code 2.1.295 or later). The live ~/.claude/settings.json sets no `onFailure`.
    Confidence: high on the mechanism and the default, low on how often each trigger occurs.
  Remediation: an EXIT trap, set once a push is recognized, that turns any status other than 0 or
    2 into 2 closes the crash case. A missing script and a timeout need `"onFailure": "block"`.
    Since 1a85d54 the hook runs on every shell command, so `block` would refuse every shell command
    while the script is missing or slow, including the ones needed to fix it. That cost needs a
    user decision.

[WARN] claude/skills/codereview/SKILL.md:269-277 — the light tier treats `.txt` and `.gitconfig`
files as plain documentation, so a diff limited to them skips /security, the tests, the external
reviewers, and the built-in review, and still gets a marker (carried from the 2026-10-02 scan, not
re-checked).
  Attack vector: gitconfig/aliases.gitconfig is live configuration. zat.env-install.sh adds it to
    ~/.gitconfig through include.path, and it can set `core.fsmonitor`, `core.pager`,
    `core.sshCommand`, or a `!` alias, each of which runs a command during ordinary git use.
    Downstream, `requirements*.txt` (pip accepts `--index-url` and direct URL requirements) and
    `CMakeLists.txt` share the extension. Such a change is reviewed only for "broken
    links/references, accidental secret leaks in prose, and factual accuracy" (lines 283-284),
    while `.json`, `.yaml`, and `.toml` get the full tier because they are operationally live
    (lines 271-272).
  Evidence: as recorded on 2026-10-13: lines 269-277 unchanged, and `codereview-marker surface`
    lists both extensions (bin/codereview-marker:133-135), so the gap is in the tier rule. The
    2026-10-02 scan ran a `core.fsmonitor` set through an included file on `git status`.
    Confidence: high on the mechanism.
  Remediation: drop `.txt` and `.gitconfig` from the light tier (or keep only `.gitignore` and
    prose `.txt` that is neither a dependency manifest nor a build file), and update the lint pin
    for that text in tests/lint-skills.sh.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 555-561 — review state that
the reviewed commits can change decides how deeply those commits are reviewed, and the changes
never appear in the reviewed diff (same trust in claude/skills/security/SKILL.md:43-46 and
claude/skills/pr/SKILL.md:184-191) (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: commits the operator did not author (a contributor branch merged or checked out
    locally, a cherry-picked patch) edit CODEREVIEW.md and SECURITY.md beside the code. A
    REVIEW_META with block 0, the right base, and reviewed_up_to at the code commit makes the run
    a refresh with an empty focus set; a SECURITY.md META footer naming that commit with scope
    full makes Step 5 skip /security; an Accepted Risks line describing the code downgrades
    matching findings to NOTE (lines 206-207, 559). The review diff, the security surface, and the
    push hash all exclude these files (line 238, bin/codereview-marker:68), so no reviewer sees the
    edit, and /pr merge accepts the same REVIEW_META with no review at all.
  Evidence: the 2026-10-02 scan reproduced the deterministic part with the skill's Step 2 and Step
    5 commands in a scratch repo. The model-executed downgrades were not run end to end.
    Confidence: high on the mechanism, medium on how the model weighs planted entries.
  Remediation: at Step 2, list `git log --format='%h %ae %s' "$(codereview-marker
    base)"..HEAD -- CODEREVIEW.md SECURITY.md`. When a commit not authored by the operator (`git
    config user.email`) touched them, take the full tier, run /security, read prior META and
    Accepted Risks from `git show "$(codereview-marker base):<file>"`, and do not honor Accepted
    Risks added in the range until the user confirms them.

[WARN] bin/codereview-marker:156, 167, 173, 177 — `list_surface`, `list_uncommitted`, and
`compute_hash` call `git diff` without `--ignore-submodules`, so when a submodule has `ignore =
all` (in .gitmodules, or `diff.ignoreSubmodules=all` in any git config), its pointer changes are
left out of the marker hash, the uncommitted check, the security surface, and the review diff
(claude/skills/codereview/SKILL.md:238, 471) (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: in a project with a submodule, a commit moves the pointer to an older, vulnerable
    release or an unreviewed upstream commit. With `ignore = all` already in .gitmodules, `hash`
    exits 2 and the hook prints "nothing to review. Allowed."; without it, the same commit can add
    `ignore = all`, and every reviewer sees only that line while `codereview-marker write` produces
    a marker the hook accepts.
  Evidence: as recorded on 2026-10-02 (both cases reproduced in scratch repos, git 2.34.1).
  Remediation: pass `--ignore-submodules=dirty` to every `git diff` in the script (the hash of a
    repo without submodules is unchanged), add it to the review diffs in SKILL.md Steps 2, 5.5,
    E.3, and E.4 (or add a `codereview-marker diff` subcommand), update the lint pins that match
    those commands, and add an `ignore = all` test.

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

[WARN] claude/skills/pr/SKILL.md:184-191, 217 — /pr merge's review gate passes when the review
covers any ancestor of local HEAD, and the merge acts on the remote PR head, which the gate never
compares with local HEAD (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: a commit lands on the PR branch after the last /codereview (a GitHub suggestion, a
    bot, a collaborator, a terminal push, or a "push now" skip). `git merge-base --is-ancestor
    "${REVIEWED_UP_TO}" HEAD` stays true, and `gh pr merge --squash` merges the remote head, so the
    unreviewed commit reaches main with the gate reporting a passing review.
  Evidence: as recorded on 2026-10-02 (reproduced with the skill's own commands).
  Remediation: require no non-review-file change since the reviewed commit (`git diff --quiet
    "${REVIEWED_UP_TO}" HEAD -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md'`), stop
    unless the remote PR head equals local HEAD, and pass `--match-head-commit` where gh supports
    it.

[NOTE] hooks/pre-push-codereview.sh:80-137, 255-258, 272-273 — spellings that f564cd4 refused and
the cycle-3 tree lets through, and some that only an earlier version refused. Cycle 3 resolves the
two regressions cycle 2 added, as this NOTE listed them: the heredoc tracking's run time (the open
list, the markers read per line, and the tracked delimiter length are now bounded) and the trailing
backslash of a quoted terminator, which the join now drops. Past its bounds the join reads as
f564cd4 did, so one f564cd4 miss returns there. What remains needs a spelling agents rarely write.
  Attack vector: no adversary is needed, only an unusual spelling. (ran) marks a real push to a bare
    remote in the scratchpad that sent the unreviewed commit.
    - New with cycle 3, past a bound the join reads as f564cd4 did (lines 117-128). Once 16 quoted
      markers are open, after 16 markers on one line, or for a quoted delimiter word over 256
      characters, a marker is not tracked, so a quoted terminator that ends in a backslash joins the
      next line again and hides a push there. After 16 lines of `# see <<'M<n>'`, or one `echo`
      string holding 16 such markers, `cat <<'X\' >/dev/null`, `X\`, and `git push origin main`
      exit 0; after 15 they are refused. The same holds after `echo "a<<b ..."` with 16 `<<` before
      the real marker on its line, and for a 257-character delimiter word (256 is tracked). Bash
      runs the push in each. Cycle 2 refused all of them and f564cd4 none. `A="x it's y" git push`
      there is refused, as at f564cd4.
    - The cutoff, unchanged: a token over 1,024 characters that holds both quote kinds, a
      backslash, or `$'` still ends the fallback reading for the rest of the command (line 257).
      After a heredoc line of 1,106 characters with `it's` inside double quotes, `>/dev/null git
      push origin main` (ran, cycle 2) and `A="x it's y" git push` exit 0. f564cd4 refused them;
      8e8dee7 and the cycle-3 tree missed them. A long line of prose in a heredoc often holds both
      kinds.
    - Unchanged: three delimiter spellings that `_hd_unquote` reads differently from bash. Bash ends
      each heredoc at a line that ends in a backslash, so the hook joins that line to the next and
      hides the push there, as f564cd4 did. `cat <<"X'\\"` (bash wants `X'\`, the hook `X\\"`,
      because a single quote inside double quotes is literal), then `X'\`, then `git push` (ran,
      cycle 2); the same with `<<$'X\\'` and `<<$"X\\"`, which bash reads as `X\`. 8e8dee7 refused
      all three; cycle 1 refused the first only because it stopped joining at any quoted marker.
    - Unchanged: a marker in a comment or a string still decides how one later line joins. After
      `# see <<'git \'`, the lines `git \` and `push` read as no push. The marker must equal the
      continued line exactly, so this is reachable only on purpose. f564cd4 refused it.
    - In every version: a comment line that ends in a backslash. The join keeps the backslash, and
      the fallback reading (lines 272-273) takes it as escaping the `;` the newline becomes, so
      after `# note \`, `A="x it's y" git push origin main` and `>/dev/null git push origin main`
      exit 0. A plain `git push` there is refused.
  Evidence: six-way runs against 8e8dee7, the cycle-3 tree, f564cd4, and the three fix cycles.
    Closed by cycle 3 (f2=0 f3=2): `cat <<'X\' >/dev/null`, `X\`, then `A="x it's y" git push
    origin main` (head=2; bash runs the push, ran) or `>/dev/null git push origin main` (head=0),
    and the same after `<<'X\\\'`, `<<-'X\'` with a tab before the terminator, `<<"X\\"`,
    `<<\X\\`, `<<'\'`, and `<<'A' <<'B\'`. tests/test-pre-push-hook.sh covers the first. The
    run-time item, cycle 2 against cycle 3 under LANG=en_US.UTF-8: a push, 1,200 lines that each
    open a quoted marker, and a continued line (28.9 KB), 32.1 s and 1.5 s; 2,000 such lines
    before `git \` and `push`, 34.5 s and 1.2 s; a 24 KB word after `<<`, 22.9 s and 0.27 s (2.1 s
    at 256 KB). The new tests time a 64 KB delimiter word and 1,200 unclosed markers. What the
    bounded tracking still costs at a few hundred kilobytes is in the tokenizing NOTE. A
    differential fuzz with a fake git as ground truth, given atoms at and under each bound (16 and
    15 markers in comments, in a string, and before the real marker; 300- and 250-character
    delimiters) and terminators with one or three backslashes, ran 5,804 unique commands over two
    seeds. Of the 1,110 pushes cycle 3 allowed, cycle 2 refused 143, every one past a bound (42
    after a 300-character delimiter, 44 after 16 markers in a string, 31 after 16 `<<` on the line,
    26 after 16 in comments), and f564cd4 refused 57, every one the cutoff (28 after a long line
    with a backslash, 29 with both kinds). The rest are known gaps: 335 the walker NOTE's `A=x\;y`
    prefix (every miss after an atom under a bound is one of these), 220 the `_hd_unquote`
    misreads (cycle 1 refused 51), 110 the comment line, and a `>/dev/null` spelling past a bound,
    which no version refuses. Confidence: high on the mechanisms, low on frequency.
  Remediation: for the bounds, refuse a recognized push once a bound is reached and the command
    holds a quoted terminator that ends in a backslash, or say in the hook's "Remaining limitation"
    comment that past a bound the join reads as f564cd4 did. For the comment line, drop its
    trailing backslashes from the joined text, as cycle 3 does for a terminator. For the cutoff,
    read a long word that holds both kinds but no backslash or `$'` by running `_quote_scan` on its
    quote characters alone (`${w//[^\"\']/}` under the C locale), since without escapes their order
    alone sets the state. In `_hd_unquote`, keep a single quote inside double quotes, let a
    backslash there escape only `$`, `` ` ``, `"`, and `\`, and drop a `$` before a quote. Add each
    spelling to tests/test-pre-push-hook.sh.

[NOTE] hooks/pre-push-codereview.sh:218-240, 247-277, 282-310, 330-398 — the walker still misses a
push in some spellings that are not wrappers, and a statement can still run before the push inside
a value the hook steps past. f564cd4 closes part of the first and third groups and all of the
-C-inside-a-value group. This scan's fuzzing adds three pre-existing groups. Everything listed
predates every fix cycle (8e8=0 c3=0 head=0 f1=0 f2=0 f3=0). Re-checked after each fix cycle:
unchanged, except `git -C "$(pwd)-wt" push`, which cycle 1's `_word_end` backstop (lines 226-228)
now reads as a push and refuses for the `$` in its -C value.
  Attack vector: an agent reaches for none of these often, which is why this is a NOTE. (ran) marks
    a real push to a bare remote in the scratchpad this scan.
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
      /dev/null)` and its backtick form, `` A=`./x.sh`; git push ``, and ``A=`git commit
      --allow-empty -qm unreviewed` git push``. New in this scan, the same before the push: `git
      >"$(git commit --allow-empty -qm y; echo /dev/null)" push` (ran). f564cd4 reads it as a push
      now, but the commit its target makes does not exist when the hook looks.
    - Brace expansion or a glob that spells the command: `git {push,origin,main}`, `{git,push}`,
      and `git pus? origin main` or `git pu[s]h` with a file named push (not re-run).
    - New in this scan: an escaped operator inside a word. `_normalize_ops` pads `\;`, `\|`, and
      `\&` apart from their word, so the rest reads as a new word: `A=x\;y git push` (ran), `A=x\|y
      git push`, `A=x\&y git push`, `git -c a.b=c\;d push`, and `git -c a.b=c\|x push`.
    - New in this scan: nested double quotes in a substitution inside double quotes, which neither
      reading models: `A="$(echo "a b")" git push`, and `gh repo create me/x --description
      "$(echo "it's")" --source . --push`.
  Evidence: the runs above, three-way at f564cd4, five-way after cycle 2, and six-way after cycle
    3. Closed by f564cd4:
    `>/dev/null git push`, `git >/dev/null push`, `git 2>&1 push`, the quoted redirection target
    after the push (`git push origin main >"$(git commit ...; echo /dev/null)"`, now refused), and
    every -C inside a value (`git -c a.b=$(true -C <dir>) push`, `git -c "x.y=a -C <dir>" push`,
    and `git -c 'alias.st=status -C <dir>' push`, now judged in the session's repo). After a token
    over 1,024 characters that holds both quote kinds or a backslash, the fix cycles lose
    `>/dev/null git push` again (regression NOTE). The differential fuzz found these groups and no
    other; after cycle 3, the `A=x\;y` prefix is still its largest group of misses. The ordinary
    statement-first forms stay refused. Confidence: high on the mechanism, low on frequency.
  Remediation: between git and push, refuse a `(` or a word holding a backtick, and refuse a
    redirection target holding a backtick or `$(`; allow a decimal in the numeric regex at line
    288. For the escaped operators, keep `\;`, `\|`, `\&`, `\(`, and `\)` inside their word with a
    placeholder, as lines 143-147 do for `\<` and `\>`. The nested quotes need the scan to track
    `$(` depth inside double quotes. A quote-aware tokenizer (BACKLOG
    push-gate-quoted-text-false-positive) would fix most of these together.

[NOTE] hooks/pre-push-codereview.sh:487-525 — what remains of the target-repo gap: two spellings
still judge a repo other than the one git pushes from. f564cd4 closes the third, a quoted -C path
with a space, which is now refused. Re-checked after each fix cycle: unchanged.
  Attack vector: each needs an unusual target, so this is a NOTE.
    - core.worktree. codereview-marker changes to the toplevel before it diffs, and `worktree = ..`
      in a layout's config makes that toplevel a directory of the enclosing repo. With a layout at
      vendor/inner2 holding an unreviewed commit and its own remote, `git -C vendor/inner2 push
      origin main` exited 0 at HEAD from a clean enclosing repo, and the toplevel read as the
      enclosing repo's vendor/ directory.
    - `git -C - push`. `cd -P -- -` at line 522 goes to $OLDPWD, because bash special-cases `-` even
      after `--`, while git enters ./-. With a repo at ./- holding an unreviewed commit and $OLDPWD
      outside any repo, the hook exited 0. Not run for real.
  Evidence: both still exit 0 on 8e8dee7, the cycle-3 tree, f564cd4, and the three fix cycles.
    `git -C "p q" push`, `git -C 'p q' push`, and `git -C p\ q push`, with a directory `p` beside
    `p q`, gave 8e8=0 c3=0 head=2 f1=2 f2=2 f3=2, because enter_push_target refuses a -C value that
    spans several tokens (line 511). Confidence: high on the mechanism, low on frequency.
  Remediation: after entering the target, compare `git rev-parse --absolute-git-dir` with the same
    call run from `--show-toplevel`, and refuse when they differ (on cycle 1's throwaway copy this
    kept a normal repo, a separate-git-dir checkout, a linked worktree, and a submodule working).
    For `-`, use `./-` at line 522 (not tried). f564cd4 dropped BACKLOG push-gate-pushed-repo as
    closed, so these two items and the pre-approval WARN have no deferral entry.

[NOTE] hooks/pre-push-codereview.sh:94-152, 188-240, 295-310 — the hook's run time grows with the
square of the command's length, and it tokenizes about ten times per recognized push and twice for
any other command. A long command passes the 30 s timeout, and without `onFailure` (WARN above) the
command then runs, including any statement before the push that the hook would have refused.
Re-checked after cycle 3, which bounds the heredoc tracking that cycle 2 made quadratic. What
remains is a long word in an option value, a line that ends in a long run of backslashes (present
since f564cd4, found in this re-check), and the bounded tracking's own linear cost.
  Attack vector: no adversary. One Bash call that holds a very long quoted word where the hook
    steps over whole words (an option value, a push argument), a line that ends in tens of
    kilobytes of backslashes, or a few hundred kilobytes of text holding quoted heredoc markers and
    a line continuation. Rare.
  Evidence: end to end against a scratch repo with an unreviewed commit, under LANG=en_US.UTF-8.
    - The long-word WARN's shape (a minified JSON heredoc, then `git add data.json && git commit -qm
      "update git data" && git push`): 0.41 s at 64 KB after cycle 3, and after cycle 2 3.2 s at
      192 KB and 5.5 s at 256 KB (cycle 1: 3.5, 30.95, and 54.9 s); with apostrophes in the JSON,
      1.8 s at 192 KB. A push first, the heredoc, then `echo "updated git config"`: 0.71 s at 64 KB
      and 5.3 s at 192 KB after cycle 2 (5.4 and 47.2 s). These hold no continuation, so cycle 3's
      code does not run for them. Cycle 2 reads a long word with one kind of quote by its parity
      (`_quote_parity`, lines 165-174) and runs `_has_open_quote` under the C locale.
    - A long quoted word in an option value or a push argument still reaches the quadratic
      `_quote_scan` through `_word_end` and `_word_is_open`: `git -c x.y='<64 KB JSON>' push` took
      26.8 s after cycle 3 (26.2 s after cycles 1 and 2, 64.7 s at f564cd4), `git push origin main
      -o '<64 KB JSON>'` 8.9 s (12.3 s after cycle 1), and a push followed by a comment holding the
      word 4.5 s after cycle 2 (6.2 s after cycle 1). No agent is likely to write any of them.
    - New in this re-check, present since f564cd4: a line that ends in a long run of backslashes.
      The join counts the run with `${line##*[!\\]}` (line 129), which matches ever shorter prefixes
      until one ends in another character, so its cost is the run's length times the line's. A
      push, a continued line, and a line that ends in 32 KB of backslashes took 26.9 s
      at f564cd4 and after cycle 3 (6.7 s at 16 KB). That shape passes 30 s near 34 KB. `[[
      "${line}" =~ (\\+)$ ]]` reads the same run in under 0.01 s. 8e8dee7 joined no continuations.
    - Cycle 3's bounded tracking compares each later line with up to 16 open markers, so it is
      linear but adds to the general cost when the command holds a continuation. A push, 10,000
      lines that each open a quoted marker, and a continued line (240 KB) took 28.0 s, against
      20.6 s at f564cd4 and 19.5 s for the same lines with no continuation; at 960 KB cycle 3 ran
      past 200 s (f564cd4 was not timed there). 1,000 open and close pairs at the 256-character
      bound (518 KB) took 22.4 s, against 9.8 s at f564cd4.
    - The general numbers, cycle 1 / cycle 2: one operator per 4 bytes, push first, 125 KB 11.1 /
      11.1 s; about one per 13 bytes, push last, 250 KB 6.6 / 6.6 s; a heredoc of quoted lines
      that mention git, push last, 64 KB 2.5 / 2.8 s and 250 KB 10.6 / 11.8 s. The 8e8dee7 scan's
      thresholds, near 400 KB or 220 KB depending on operator density, still hold for short words.
    Confidence: high on the mechanism and the timings, low on reachability.
  Remediation: count a line's trailing backslashes with `[[ "${line}" =~ (\\+)$ ]]` and
    `${#BASH_REMATCH[1]}` at line 129, and strip them the same way at line 113. Bound `_word_end`
    and `_word_is_open` the way the fallback now is, reading a long word with no backslash and one
    kind of quote by its parity. Normalize once in main and pass the tokens to every function,
    which also runs the heredoc tracking once rather than about ten times, and pad the operators in
    one linear pass after joining continuations. Or refuse a command over a fixed size that
    contains a push. Add timed cases for a 64 KB `git -c x.y='<JSON>' push` and a 32 KB run of
    backslashes to tests/test-pre-push-hook.sh.

[NOTE] hooks/pre-push-codereview.sh:337, 461 — the walker treats only a token named `git`, or a path
ending in /git, as git, so `git.exe push`, which runs git in Git Bash, passes the gate, and `gh` has
the same gap without even the /git allowance. This is the Windows counterpart of the absolute-path
spelling that 600d074 closed; it is listed for a decision, not re-flagged. Re-checked at f564cd4
and after each fix cycle: still present.
  Attack vector: an agent on Windows writes `git.exe push`, the native program's file name, and the
    hook exits 0. `GIT push` runs git on a case-insensitive filesystem (Windows, default macOS).
    `/usr/bin/gh repo create me/x --source . --push` runs git itself, as the plain `gh` form the
    hook refuses does.
  Evidence: on Linux with an unreviewed commit, the hook exited 0 at f564cd4 and after each fix
    cycle for `git.exe push`, `"/c/Program Files/Git/cmd/git.exe" push`, `GIT push`, and the
    absolute-path `gh` form, and 2 for `gh repo create me/x --source . --push`. The git spellings
    run only on the other platforms and were not run there. Confidence: high on the mechanism, low
    on frequency.
  Remediation: compare the token's basename with `git` or `git.exe` at line 337 and with `gh` or
    `gh.exe` at line 461, and add tests. Or add `git.exe` to the accepted risk.

[NOTE] hooks/pre-push-codereview.sh:845-848 — the skip marker is honored at any age and for any
diff, and its check runs before push_sends_commits_outside_head, on purpose for "push now", so a
marker left by a tag-only or terminal push lets a later unreviewed agent push through, including a
push of another ref. Deferred to BACKLOG.md (skip-marker-bound-to-diff). Re-checked at f564cd4 and
after each fix cycle: unchanged.
  Attack vector: a leftover marker plus a later agent push.
  Evidence: at f564cd4 and after each fix cycle, a skip marker backdated 30 days let `git push` with an
    unreviewed commit through and was consumed, and a fresh one let `git push origin feature:main`
    through from a clean main. The marker is resolved after the hook enters a -C target, so
    `codereview-skip` in repo A followed by `git -C B push` was refused and left A's marker armed;
    the next unreviewed push in A then passed and consumed it. Confidence: high on the mechanism,
    low on frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match, or add an
    age limit, and say in the refusal that a bypass applies per repo.

[NOTE] zat.env-install.sh:200, 213 — every settings.json write creates a new file at the process
umask and moves it into place (also lines 267, 276, 285, 307, 346, 363, 381), so a settings.json
the user restricted to 0600 comes back 0644 or 0664 on each run (carried from the 2026-11-03 scan at
8e8dee7, not re-checked).
  Attack vector: settings.json can hold secrets in its `env` block, and its hooks run as the user.
    Where another account can traverse the home directory (macOS creates /Users/<name> as 0755),
    that account can read the file after a re-run; with umask 0002 and a primary group shared with
    other accounts, it can also edit the hooks. Not reachable on this host: the home directory is
    0750, and group peter has no other members. The installer itself writes no secret there.
  Evidence: as recorded at 8e8dee7 (~/.claude/settings.json here is 0664 under umask 0002; the
    2026-10-13 scan rewrote a 0600 file with the installer's `jq ... > tmp && mv` pattern and it
    came back 0664). Confidence: high on the mechanism, low on reachability.
  Remediation: `umask 077` at the top of the installer (which also closes the reviewer .env's brief
    creation window), or restore the file's previous mode after each rewrite.

[NOTE] claude/skills/codereview/SKILL.md:238, 471 — the review diffs honor the repository's own
.gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as "Binary
files a/<f> and b/<f> differ", while the marker hash still binds its content (same in the
external-mode diffs at lines 141 and 165) (carried from the 2026-10-13 scan, not re-checked).
  Attack vector: a commit the operator did not write adds `<file> -diff` to .gitattributes beside a
    change to that file; or, more commonly, a downstream repo marks a lockfile `-diff` to quiet
    noise, and a dependency swap in it reaches review as that one line. The external reviewers see
    only the diff, so they get nothing of the change, and a refresh review reads only diff hunks for
    already-reviewed files (lines 333-335). A full-tier inline review and /security still read the
    whole file (it stays in `codereview-marker surface`), but nothing marks what changed.
  Evidence: as recorded on 2026-10-13 (git 2.34.1). One commit added `app.py -diff` and changed
    `return token == SECRET` to `return True`. The Step 2 diff showed the .gitattributes hunk and
    "Binary files a/app.py and b/app.py differ", `surface` listed both files, and `git diff
    --numstat` printed `-` counts for app.py. Confidence: high on the mechanism, low on likelihood.
  Remediation: in Step 2, list the changed files git renders as binary (`git diff --numstat` prints
    `-` counts for them), review any that are text with `git diff --text -- <file>`, and send those
    hunks to the external reviewers too; report an added `-diff` or `binary` attribute on a text
    path as a finding.

[NOTE] claude/skills/codereview/SKILL.md:460-464 — the secret-in-diff guard relies on a step that
reports secrets, and in a full-tier review no step looks for them in plain markdown (carried from
the 2026-10-02 scan, not re-checked).
  Attack vector: no adversary. A diff touches code and also adds a key to a markdown file, so it
    takes the full tier. Step 4's full-tier dimensions (lines 363-380) include no secret check (only
    the light tier's reduced scope does, line 283), and /security receives only `codereview-marker
    surface` files, which omit plain markdown (bin/codereview-marker:133-143). Neither reports the
    key, and Step 5.5 sends the diff, key included, to OpenAI and Google.
  Evidence: traced through the skill text and the surface code; not run end to end. Confidence: high
    on the mechanism.
  Remediation: before Step 5.5, grep the exact diff it will send for key patterns (`sk-`, `sk-ant-`,
    `AIza`, `ghp_`, `github_pat_`, `AKIA`, `xox[bp]-`, `hf_`, private-key headers) and skip the
    providers on a match, or add a whole-diff secret check to Step 4.

[NOTE] claude/skills/codereview/SKILL.md:405-410, 437-441 — the model extracts the commit field of
SECURITY.md's META footer and pastes it into a shell command, so codereview-marker's leading-dash
check (bin/codereview-marker:146-155) runs only after the shell has expanded it (carried from the
2026-10-02 scan, not re-checked).
  Attack vector: a commit that edits SECURITY.md puts a `$(...)` or backtick span in the footer's
    commit value. If the model substitutes it unquoted or in double quotes into `codereview-marker
    surface <meta-commit>`, the substitution runs under the skill's `Bash(*)` grant. Step 2 already
    avoids this for reviewed_up_to with a hex-only `grep -oP` inside the command substitution (lines
    295, 316).
  Evidence: traced through the skill text; not tested against a live model, which may refuse such a
    value. Confidence: medium on the mechanism, low on likelihood.
  Remediation: extract the commit inside the command with a hex-only `grep -oP` (7 to 40 hex
    characters), or add a codereview-marker subcommand that reads the footer, and update the lint pin
    that matches that text.

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
`Bash(*)` grant (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: `gh pr create --title "<title>" --body "<body>"` with a commit subject or body
    carrying a code span or `$(...)`; even "adds `codereview-marker write`" would run that command
    and write the push marker.
  Evidence: as recorded on 2026-10-02 (traced through the template; not run).
  Remediation: write the body with a quoted heredoc and pass `--body-file`; build the title the same
    way.

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is an
inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for the rest
of the turn that invokes it (carried from the 2026-10-02 scan, not re-checked).
  Attack vector: the post-ExitPlanMode hook tells the model to run `/spec plan`, so a turn that
    leaves plan mode can carry unprompted Bash, Write, and Edit into implementation, where content
    the model reads can steer a command.
  Evidence: as recorded on 2026-10-02 (documented grant semantics; not tested).
  Remediation: narrow /spec's grant to what it runs (git read commands, spec-backlog-apply.sh, Read,
    Grep, Glob) and let Write and Edit fall to the session's rules; consider the same for /codereview
    and /architect.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294) send the
caller's unpushed commit subjects to api.openai.com and generativelanguage.googleapis.com (carried
from the 2026-10-01 scan, not re-checked).
  Attack vector: no adversary; the data leaves the machine without the user's opt-in.
  Evidence: as recorded on 2026-10-02 (a recording curl stub saw "=== COMMITS ===" with the unpushed
    subjects in three of four real-curl requests).
  Remediation: run these tests against the suite's fake curl with FAKE_CODE=401, or from
    ${TEST_DIR}.
```

### Coverage

All eight dimensions were reviewed for the four files at HEAD f564cd4.

- Read in full: hooks/pre-push-codereview.sh (874 lines) and CLAUDE.md (82). Also read: the whole
  8e8dee7..f564cd4 diff of the four files, and the diff from the cycle-3 tree (the cycle-3
  re-check's copy, scratchpad postfix3/hook-now.sh) to f564cd4, which no earlier re-check covered.
- tests/test-pre-push-hook.sh (1,402 lines): its helpers and setup (lines 1-140) and the 378 added
  lines. It passes each command to the hook as JSON and never runs it, its new `rm -rf` targets come
  from mktemp, and it has no finding of its own; its gaps are named in the findings.
- tests/lint-skills.sh (1,964 lines): the 4-line diff (two pins) and a scan for eval, network,
  file-write, and rm constructs, which found nothing beyond the known `python3 -c 'import yaml'`.
- Suites on Linux (bash 5.1.16, git 2.34.1, jq 1.6, shellcheck 0.8.0), with XDG_CACHE_HOME in the
  scratchpad: test-pre-push-hook.sh 318/318, test-codereview-marker.sh 69/69, lint-skills.sh
  519/519. Shellcheck is clean on the hook and reports only info-level SC2016, SC2030, and SC2031 in
  the test file.
- The gate checks ran the hook with synthetic payloads against scratch repos, three-way against
  8e8dee7, the cycle-3 tree, and f564cd4, and against origin/main's hook for a few. Entries marked
  (ran) were real pushes to bare repos in the scratchpad. Nothing left the machine, no marker was
  written outside the scratchpad, and zat.env's tree was not changed apart from this file.
- Fuzzing: 1,500 random commands found no hook exit other than 0 or 2. A differential fuzz ran
  5,698 unique commands under a fake git and gh that only log their subcommand, with PATH limited to
  them plus /usr/bin and /bin, in an empty scratch directory, and compared each push the shell ran
  with the hook's decision.
- Checked and not findings:
  - CLAUDE.md's new text matches the code: `enter_push_target` follows only the -C values the walk
    reports, and the fallback reading can only add a detection. Its claim that `_quote_scan` reads
    quotes "as the shell does" is too strong (regression and walker NOTEs). It holds no secret.
  - No new route from command text to a git option: refspec words still reach git only through
    `rev-parse --verify` with a fixed suffix or a `refs/` prefix, and the new -C handling cds only
    into a single literal token.
  - The fallback reading and the new redirection, `&`, and file-descriptor arms only add
    detections; the only regression the fuzz found is the ANSI-C misread.
  - Over-refusals, the safe direction: `NAME="O'Brien" git push` and `GIT_SSH_COMMAND="ssh -o
    'IdentitiesOnly yes' -i key" git push` on a clean tree are told to run the push as its own
    command.
  - The test `git -C /tmp push` makes the hook run git in /tmp. git 2.34.1-1ubuntu1.18 carries the
    CVE-2022-24765 ownership check and no `safe.directory` entry is set, so a /tmp/.git planted by
    another account is refused.
- Not verified: Claude Code cancelling the hook at 30 s and running the command (from the docs,
  re-read this scan, not observed); Windows and macOS at this HEAD; the `filter` and `textconv`
  payloads; the submodule and config-set refspec cases, whose code f564cd4 did not change; the
  Monitor bypass.

Post-fix re-check, cycle 1 (same day, `/security post-fix`), of hooks/pre-push-codereview.sh and
tests/test-pre-push-hook.sh with /codefix's uncommitted fix on f564cd4. All eight dimensions were
reviewed for both files. Findings in other files were left as they were, apart from the hook line
numbers in the `onFailure` WARN and the Accepted Risks cross-reference.

- Read in full: the fixed hook (906 lines) and the uncommitted diff of both files. The 43 added test
  lines use mktemp repos, run no command they send, and have no finding of their own.
- Suites on Linux, with XDG_CACHE_HOME in the scratchpad: test-pre-push-hook.sh 333/333 in 17 s,
  test-codereview-marker.sh 69/69, lint-skills.sh 519/519. Shellcheck is clean on the hook and
  reports only info-level SC2016, SC2030, and SC2031 in the test file.
- Four-way runs against 8e8dee7, the cycle-3 tree, f564cd4, and the fix. Entries marked (ran) were
  real pushes to bare repos in the scratchpad. Nothing left the machine, no marker was written
  outside the scratchpad, and zat.env's tree was not changed apart from this file.
- Differential fuzz: two seeds, 7,496 unique commands, under the fake git and gh, with new atoms
  for the fix's code: here-strings and heredoc text before a continued push, `& >` with `-d`,
  1,100-character tokens, and `\$'`, `$$'`, and `$$$'`.
- Checked and not findings:
  - `local LC_ALL=C` is restored when `_quote_scan` returns, and the function starts no child
    process. A child would see C only where LC_ALL was already exported.
  - The byte-level scan reads UTF-8 values as before, since no multibyte UTF-8 sequence holds an
    ASCII byte (`git -c user.name="José O'Brien -x" push` and four more are refused).
  - The dollar-run count matches bash for `\$'`, `$$'`, `$$$'`, `$\$'`, and a `$` inside double
    quotes.
  - The `_word_end` backstop only adds detections. The one place it widens what the hook follows,
    an open-at-end -C value in `enter_push_target`, belongs to a push that f564cd4 did not detect
    at all.
  - `_quote_is_unclear` on prefixes and the `&>` arm in `is_tag_only_push` only add refusals. A
    tag push with `&>/dev/null` is now gated, as one with `>/dev/null 2>&1` already was.
- Not verified: Windows, where the new long-word test hands a 77 KB argument to the native jq. That
  is past the 32,767-character command-line limit, so the test would likely fail there, loudly.
  Also not verified: the 30 s cancellation itself.

Post-fix re-check, cycle 2 (same day, `/security post-fix`), of the same two files with /codefix's
second uncommitted cycle on f564cd4. All eight dimensions were reviewed for both files. Findings in
other files were left as they were, apart from the hook line number in the `onFailure` WARN and the
Accepted Risks cross-reference.

- Read in full: the cycle-2 hook (953 lines), its diff from cycle 1 (the heredoc tracking and
  `_hd_unquote`, `_quote_parity`, `_has_open_quote` under the C locale, and the `& >` and `-o`
  cluster arms), and the test diff. The added tests pass each command to the hook as a payload,
  never run it, and build their repos with mktemp; they have no finding of their own.
  `invoke_in_test_repo` now hands the command to jq on stdin, which removes the Windows
  command-line limit noted under cycle 1 (not run on Windows).
- Suites on Linux, with XDG_CACHE_HOME in the scratchpad: test-pre-push-hook.sh 346/346 in 33.5 s,
  test-codereview-marker.sh 69/69, lint-skills.sh 519/519. Shellcheck is clean on the hook and
  reports only info-level SC2016, SC2030, and SC2031 in the test file.
- Five-way runs against 8e8dee7, the cycle-3 tree, f564cd4, cycle 1, and cycle 2, from copies
  taken before the first probe (the working files' hashes were unchanged at the end). Entries
  marked (ran) were real pushes to bare repos in the scratchpad. Nothing left the machine, no
  marker was written outside the scratchpad, and zat.env's tree was not changed apart from this
  file.
- Every finding in the two files was re-run: the `-C` pre-approval WARN (payload counts), the
  refspec WARN and its controls, and the walker, target-repo, `git.exe`, and skip-marker NOTEs.
- Differential fuzz: two seeds, 5,748 unique commands, under the fake git and gh, with atoms for
  cycle 2's code: delimiters in each quoting form with their terminators, heredoc text in comments
  and strings, here-strings, long lines with one quote kind, both, or a backslash, `& >` with `-d`,
  `-fo -d`, and `--repo -d`. A crash fuzz of 1,500 random commands built from heredoc, quote, and
  operator atoms found no exit other than 0 or 2 and no run over 20 s.
- Checked and not findings:
  - The new code opens no route from command text to a command or a git option. `_hd_unquote`,
    `_quote_parity`, and the new arms are plain bash; the delimiter comparison is a quoted, literal
    `==`, and the strip after each marker match quotes its pattern.
  - `_quote_parity` leaves the same quote state as `_quote_scan` for every word it accepts (no
    backslash, no `$'`, at most one kind of quote), so it is exact where it replaces the cutoff.
  - The `& >` and `-o` cluster arms only make the walk stricter. A `break` at `-d` keeps the refs
    already collected, and a `-d` skipped after a cluster such as `-ofo`, where git reads it as a
    delete, only refuses a push that sends nothing (a real `git push -ofo -d origin feature`
    deleted the remote branch, and cycle 2 refuses it).
  - The heredoc regex skips here-strings (`<<<`) and strips tabs only after `<<-`, as bash does.
- Not verified: Windows and macOS; the 30 s cancellation itself.

Post-fix re-check, cycle 3 (same day, `/security post-fix`), of the same two files with /codefix's
third uncommitted cycle on f564cd4. All eight dimensions were reviewed for both files. Findings in
other files were left as they were, apart from the hook line number and a cross-reference in the
`onFailure` WARN and the Accepted Risks cross-reference.

- Read in full: the cycle-3 hook (967 lines) and its diff from cycle 2 (`_hd_unquote` under the C
  locale, the three bounds on the heredoc tracking, the regex's new rest-of-line group, and the
  dropped trailing backslashes on a terminator), and the test diff (one spelling and two timed
  cases). The added tests pass each command to the hook as a payload, never run it, and build
  their repos with mktemp; they have no finding of their own.
- Suites on Linux, with XDG_CACHE_HOME in the scratchpad: test-pre-push-hook.sh 351/351 in 34.9 s,
  test-codereview-marker.sh 69/69, lint-skills.sh 519/519. Shellcheck is clean on the hook and
  reports only info-level SC2016, SC2030, and SC2031 in the test file.
- Six-way runs against 8e8dee7, the cycle-3 tree, f564cd4, and the three fix cycles, from copies
  taken before the first probe (the working files' hashes were unchanged at the end). Entries
  marked (ran) were real pushes to bare repos in the scratchpad. Nothing left the machine, no
  marker was written outside the scratchpad, and zat.env's tree was not changed apart from this
  file. The untracked head-hook.sh and new-hook.sh in the repo root, copies of the f564cd4 and
  cycle-3 hooks, predate this re-check.
- Every finding in the two files was re-run, all unchanged: the `-C` pre-approval WARN (payload
  counts), the refspec WARN and its controls, the unreadable-marker crash, and the walker,
  target-repo, `git.exe`, and skip-marker NOTEs.
- Differential fuzz: two seeds, 5,804 unique commands, under the fake git and gh, with atoms at and
  under each of cycle 3's bounds, terminators with one or three backslashes, `<<-` with tabs,
  `<<'\'`, and a comment line ending in a backslash. A crash fuzz of 1,500 random commands, with
  markers at and past each bound and a 64-backslash run among its atoms, found no exit other than
  0 or 2 and no run over 20 s.
- Checked and not findings:
  - The regex's new `(.*)$` group fails to match, and so skips a marker, on a byte the locale
    rejects (a raw 0xFF or an encoded surrogate under en_US.UTF-8), but no payload can supply one:
    jq turns an invalid byte and a lone `\udcff` into U+FFFD, so the command it hands the hook is
    valid UTF-8.
  - `local LC_ALL=C` in `_hd_unquote` changes only the indexing. Every byte it compares is ASCII,
    and the delimiter it builds holds the same bytes as before.
  - The dropped backslashes apply only to a line the tracking reads as a terminator. A real
    continued line is affected only when a misread marker equals it, the comment-marker item that
    cycle 2 already had (f2=0 f3=0).
  - The bounds only reduce what is tracked. Past them the join reads as at f564cd4 (regression
    NOTE), and under them the fuzz found no miss that an older hook refused.
  - The new code opens no route from command text to a command or a git option; it is plain bash
    with quoted, literal comparisons.
- Not verified: Windows and macOS, where the new tests' 10 s bounds were not run; the 30 s
  cancellation itself.

Git history checked for secrets: `git log -p --follow -3` for each of the four files, and their
8e8dee7..f564cd4 diff, pattern-scanned for OpenAI, Anthropic, Google, GitHub, AWS, Slack, Hugging
Face, and Tailscale keys, private-key headers, and generic key, token, secret, and password
assignments. No hits. Post-fix, after each cycle: the uncommitted diff of the hook and its tests,
and `git log -p --follow -3` for both, scanned the same way, with no hits. None of the four files
handles credentials. PII: only the fixture address `test@test.invalid`; cycles 2 and 3 add no
address.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:226-267`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)` each reach
  arbitrary execution. The deny entries are prefix matches and cannot enumerate every spelling.
  Accepted 2026-08-20 because README.md:224 and the script comment (lines 221-225) state plainly that
  the deny list is a speed bump. `autoMode.classifyAllShell` sends these commands through the
  classifier in auto mode, so the risk as accepted applies to the other permission modes. The Linux
  host has the setting (verified 2026-10-01, 2026-10-13, and 2026-11-03), and so did the Windows host
  (verified 2026-10-13). The hook's `git diff` before approval (WARN above) is not covered by this,
  because it runs ahead of the classifier.
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
  after cycle 3, one after a token over 1,024 characters that holds both quote kinds or a
  backslash, or after a comment line that ends in a backslash, regression NOTE). This does not
  cover a recognized push checked against the wrong ref or the wrong repo (the refspec WARN and
  target-repo NOTE), a spelling that is not a wrapper (the walker and regression NOTEs), or a
  recognized push whose hook times out or fails (the tokenizing NOTE and the `onFailure` WARN). Whether the Windows
  spelling `git.exe push` belongs here is open (NOTE above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when configured, the full
  git diff goes to OpenAI and Google, so any secrets in the diff would be exposed. Sending the diff is
  the script's explicit purpose, and the user opts in by configuring keys. Since 253ad52, /codereview
  Step 5.5 skips the providers when the review reports a secret in the diff (see the markdown gap NOTE
  above); /codereview external has no such check.

---
*Prior review (2026-11-03, scope: paths, at 8e8dee7, with three post-fix re-checks of the then
uncommitted fixes): six files, 0 BLOCK / 9 WARN / 18 NOTE at the last re-check, no secrets. It
found the `git diff` a `-C` target runs before approval and the stable-channel rollback past the
Monitor hook fix, and tracked the regressions each fix cycle added; f564cd4 committed those fixes
with a further round of changes that no re-check covered.*

<!-- SECURITY_META: {"date":"2026-11-03","commit":"f564cd4d401e48c6fa1df956840dc43f6a33b986","scope":"paths","scanned_files":["CLAUDE.md","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/test-pre-push-hook.sh"],"block":0,"warn":9,"note":18} -->
