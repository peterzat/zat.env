## Security Review — 2026-11-07 (scope: paths)

**Summary:** Path-scoped scan, at HEAD d12ce05, of the eight security-surface files changed since
the f564cd4 scan: 82379d2 (the commit of the hook fixes that scan re-checked), and 33cea03 and
d12ce05, which route /spec backlog mode and /spec's new BACKLOG adoption through
spec-backlog-apply.sh, add its `clear` op, and add /tester design's defect report. The scan found
one new WARN: the script followed a BACKLOG.md symlink, so a cloned repo that tracks one turned
`/spec backlog`'s append into a write outside the repo (a shell startup file then runs the entry's
code spans), and turned `/tester design` or `/spec backlog clear` into a copy of the link's target
into the working tree. All nine in-scope prior findings were still present, eighteen findings in
out-of-scope files are carried, and no secrets were found. The post-fix re-check of /codefix's
uncommitted changes to CLAUDE.md, bin/spec-backlog-apply.sh, tests/lint-skills.sh, and
tests/test-spec-backlog-apply.sh resolves that WARN: the script now refuses a symlinked (live or
dangling) or non-regular BACKLOG.md before any read or write, and tests and a lint pin cover the
check. It adds one NOTE for what remains, a run from inside a tracked directory link. A second
post-fix re-check, of fix cycle 2's changes to the script, its tests, and lint, finds nothing new:
fences are now tracked only above the first entry, which closes the stray-fence regression the first
re-check passed to the code review, and the directory-link NOTE is still present. Totals: 0 BLOCK /
9 WARN / 19 NOTE.

### Findings

```
[WARN] hooks/pre-push-codereview.sh:487-525, 785, 799, 882 — following `git -C <path>` makes the
hook run `git diff` in a directory named by the command, before the command is approved, and that
repo's own config names what `git diff` executes. New with 49ecf37. Re-checked at d12ce05, whose
hook is 82379d2's commit of the cycle-3 tree the 2026-11-03 re-check read: still present.
  Attack vector: a hostile repo is cloned. Git refuses to track a `.git` directory but tracks a
    bare-repo layout under any other name, so vendor/inner/{HEAD,config,objects,refs} arrive as
    ordinary files, with `core.worktree = .` and `core.fsmonitor` or `diff.external` in
    vendor/inner/config. An extracted archive carrying a real .git/config works the same way. Text
    in the repo steers the agent to `git -C vendor/inner push`, the form the hook's own refusals
    recommend (lines 785, 799). The configured command then runs as the user, whether or not the
    hook goes on to refuse the push.
  Evidence: this scan, from a clean session repo, `git -C <target> push` where the target's
    .git/config sets `core.fsmonitor` to a sentinel script and its working tree has a change: the
    hook exited 2 and the sentinel ran 4 times. As recorded on 2026-11-03: the clone-delivered
    layout, tracked files only and a plain `git clone`, exited 0 and ran the payload twice; `git
    -C vendor/inner diff` or `status` run directly ran it once each; the no-working-tree refusal
    (lines 820-829) stops a layout without `core.worktree` before any `git diff`; `codereview-marker
    hash` (line 882) runs `git diff --quiet` and then `git diff` in the target. Why this is not a
    BLOCK: an approved `git -C vendor/inner diff` or `status` runs the same payload, and `Bash(git
    *)` skips approval outside auto mode (accepted risk), so what is lost is the approval step for
    this one command, in auto mode, the mode the installer sets. Confidence: high on the mechanism,
    low on how often an agent is steered to that command.
  Remediation: refuse a `-C` target whose toplevel is not the session's, and say to run /codereview
    and the push from inside it. To close the cwd route too, have bin/codereview-marker pass
    `--no-ext-diff --no-textconv` to each diff and export GIT_CONFIG_COUNT overrides for
    `core.fsmonitor=false` and `diff.external=`, refuse a repo whose local config defines
    `filter.*`, and add a clone-delivered layout case to tests/test-pre-push-hook.sh that asserts
    the sentinel is absent.

[WARN] hooks/pre-push-codereview.sh:530-536, 545-630 — a recognized push can still send commits the
review did not cover. The hook judges only refs spelled plainly after the push and counts any
remote-tracking ref as already gated. Re-checked at d12ce05: still present.
  Attack vector: no adversary is needed. From a clean main with an unreviewed `feature`, or in the
    state named, the hook exits 0 for each of these. (ran) marks a real push to a bare remote by
    an earlier scan.
    - Fetched, never reviewed: `git push origin origin/contrib:main`, `git push origin
      fork/evil:refs/heads/main`, and a tag on such a commit, `git push origin v7`.
    - A local upstream: on a branch made with `--track main`, where main holds an unreviewed
      commit, `git push origin topic:main`.
    - Implicit refspecs: `git -c push.default=matching push`, `git -c
      remote.origin.push=feature:main push`, `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.push
      GIT_CONFIG_VALUE_0=feature:main git push`, and the same keys or `remote.origin.mirror` set in
      config (not re-run).
    - Abbreviated options and `--repo=`: `git push --al`, `--mir`, `--ta` (ran: a tag on the
      unreviewed commit reached the remote), and `git push --repo=origin feature`.
    - An option that takes the next word: git reads `--repo -d` as the repository `-d`, which the
      positional `origin` then overrides, so `git push --repo -d origin feature:main` sends
      feature to main (ran), and `--rep -d` does the same (ran). The walk steps over `--repo` as a
      flag (line 591) and then returns at the `-d` as for a delete (line 587).
    - /pr's spelling in another repo: `git -C <other> push origin "$(git rev-parse --abbrev-ref
      HEAD)"`, where the substitution names a branch of the shell's repo, not <other>'s.
    - An ancestor under a valid marker: `git push origin HEAD~1:main` sends the unfixed commit.
    - A non-tag ref on a tree: with refs/foo/bar on a new tree, `git push --mirror`.
    - A submodule: `--recurse-submodules=on-demand` is skipped as an option (line 591); its payload
      exits 0, but no submodule push was run.
  Evidence: this scan, in a scratch repo with origin/main at main and one unreviewed commit on
    `feature`: the controls `git push origin feature:main` and `git push origin feature` exited 2;
    `git push --repo -d origin feature:main`, `--rep -d origin feature:main`, `--repo=origin
    feature`, `git -c push.default=matching push`, and `git push --ta` exited 0; and with
    refs/remotes/contrib/x at feature, `git push origin contrib/x:main` and `git push origin
    feature:main` exited 0. The rest as recorded on 2026-11-03, where the `GIT_CONFIG_PARAMETERS`
    form was refused as a side effect of the mixed-quote prefix rule (line 442) and the
    `GIT_CONFIG_COUNT` form passed. tests/test-pre-push-hook.sh has none of the open cases.
    Confidence: high on the mechanism, medium on frequency for the fetched-branch cases, low for
    the rest.
  Remediation: (1) In the argument walk, treat `--al`, `--b*`, `--m*`, and `--ta*` as the options
    they abbreviate, and `--repo` and its unique abbreviations (and `--receive-pack` and `--exec`)
    as taking the next word as their value. (2) With no refspec, refuse when `push.default` is
    `matching` or `remote.<r>.push` or `remote.<r>.mirror` is set, including through `-c`, and
    refuse `GIT_CONFIG*=` in a prefix and `--recurse-submodules=on-demand`. (3) Count a commit as
    gated only when the pushed remote's tracking ref for the destination has it. A git-native
    pre-push hook (core.hooksPath) receives the exact local and remote refs and would close this
    WARN with most other gate findings. It overrides per-repo hooks and fires on terminal pushes,
    so it needs a user decision.

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
than 0 or 2, or times out (carried from the 2026-11-03 scan at 8e8dee7, not re-checked; this scan
re-ran only the hook-side crash). The crash point is hooks/pre-push-codereview.sh:915, and the
tokenizing NOTE below names the long-command triggers.
  Attack vector: no adversary is needed. A moved or renamed checkout leaves the stored command
    pointing at a missing script (exit 127) until the installer is re-run. An unreadable marker
    makes `cat` at hooks/pre-push-codereview.sh:915 fail under `set -e` (exit 1). A long command,
    including a long quoted word in a call of about 150 KB or more, keeps the hook past the 30 s
    timeout. The hook recognizes each of these pushes, so the accepted "detection is heuristic"
    risk does not cover them.
  Evidence: as recorded at 8e8dee7. This scan: with the marker at mode 000, the d12ce05 hook
    exited 1 on `git push`. The hooks docs, as read on 2026-11-03: any other exit code is a
    "Non-blocking error ... The action goes ahead", and with `"onFailure": "block"` a failure does
    what exit 2 does (Claude Code 2.1.295 or later). Confidence: high on the mechanism and the
    default, low on how often each trigger occurs.
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

[NOTE] bin/spec-backlog-apply.sh:56, 143-147 — the post-fix guard checks only the last path
component, and the script resolves BACKLOG.md against the caller's working directory, so a run from
inside a tracked directory link still creates and fills a BACKLOG.md outside the repo. This is what
remains of the symlinked-BACKLOG.md WARN that the post-fix re-check resolved. Re-checked after fix
cycle 2: still present.
  Attack vector: a cloned repo tracks `app -> ../../.bashrc.d`, and text in it steers the agent to
    run the backlog step from app/ (a CLAUDE.md that names app/ as the project root, say), so the
    command is `cd app && spec-backlog-apply.sh <<'MANIFEST'` with an `append:` block. The script
    creates ~/.bashrc.d/BACKLOG.md holding the entry. Fedora's and RHEL's default ~/.bashrc source
    every file in ~/.bashrc.d, so the entry's code spans run at each interactive shell start, as in
    the resolved WARN. The Claude Code 2.1.311 binary names `~/.claude/rules/` and
    `.claude/rules/*.md`, so a link to that directory would likely load the entry into every
    session as instructions. Every skill invocation of the script says to run it from the project
    root, so the agent has to be steered past that, and the target directory must already exist
    (the script creates none). On this host neither directory exists, and ~/.bashrc sources no
    directory.
  Evidence: the first post-fix re-check, repeated in the second with the same result, in a scratch
    clone with `app` tracked as mode 120000 pointing at a scratch home's .bashrc.d: run from app/,
    `append:` exited 0 and created BACKLOG.md there with the entry. In that directory `pwd -P` named the outside directory and `git rev-parse
    --show-toplevel` failed. The Fedora and RHEL behavior is from their default ~/.bashrc and the
    rules loading from strings in the binary; neither was run. Confidence: high on the mechanism,
    low on likelihood.
  Remediation: refuse unless `git rev-parse --show-prefix` succeeds and prints nothing, which holds
    only when the working directory is the repo's toplevel by its physical path (comparing `pwd -P`
    with `--show-toplevel` would likely fail on Git Bash, where git.exe spells the drive as `C:/`).
    This also stops a stray BACKLOG.md in a subdirectory. It would refuse /spec outside a git
    repo, which needs a decision. Add a test that runs the script from a directory link.

[NOTE] hooks/pre-push-codereview.sh:80-137, 255-258, 272-273 — past the bounds 82379d2 put on its
heredoc tracking, and in a few unusual spellings, a push that bash runs reads as no push. Some of
these f564cd4 refused (regressions of the fix cycles); others no version refused. Re-checked at
d12ce05: still present.
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
  Evidence: this scan, in a scratch repo with an unreviewed commit: the 16-marker command exited 0
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
a value the hook steps past. Re-checked at d12ce05: still present.
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
  Evidence: this scan, with an unreviewed commit: `A=x\;y git push`, `timeout 1.5m git push`, and
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
still judge a repo other than the one git pushes from. Re-checked at d12ce05: still present.
  Attack vector: each needs an unusual target, so this is a NOTE.
    - core.worktree. codereview-marker changes to the toplevel before it diffs, and `worktree = ..`
      in a layout's config makes that toplevel a directory of the enclosing repo. With a layout at
      vendor/inner2 holding an unreviewed commit and its own remote, `git -C vendor/inner2 push
      origin main` exited 0 from a clean enclosing repo, and the toplevel read as the enclosing
      repo's vendor/ directory (2026-11-03; not re-run).
    - `git -C - push`. `cd -P -- -` at line 522 goes to $OLDPWD, because bash special-cases `-` even
      after `--`, while git enters ./-.
  Evidence: this scan: with a repo at ./- holding an unreviewed commit and OLDPWD=/, `git -C -
    push` exited 0. Not run for real. Confidence: high on the mechanism, low on frequency.
  Remediation: after entering the target, compare `git rev-parse --absolute-git-dir` with the same
    call run from `--show-toplevel`, and refuse when they differ (on a throwaway copy this kept a
    normal repo, a separate-git-dir checkout, a linked worktree, and a submodule working). For
    `-`, use `./-` at line 522 (not tried). These two items and the pre-approval WARN have no
    BACKLOG deferral entry.

[NOTE] hooks/pre-push-codereview.sh:94-152, 188-240, 295-310 — the hook's run time grows with the
square of the command's length in a few shapes, and it tokenizes about ten times per recognized
push and twice for any other command. A long command passes the 30 s timeout, and without
`onFailure` (WARN above) the command then runs, including any statement before the push that the
hook would have refused. Re-checked at d12ce05: still present.
  Attack vector: no adversary. One Bash call that holds a very long quoted word where the hook
    steps over whole words (an option value, a push argument), a line that ends in tens of
    kilobytes of backslashes, or a few hundred kilobytes of text holding quoted heredoc markers and
    a line continuation. Rare.
  Evidence: this scan, a push, a continued line, and a line ending in 4, 8, and 16 KB of
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
spelling that 600d074 closed; it is listed for a decision, not re-flagged. Re-checked at d12ce05:
still present.
  Attack vector: an agent on Windows writes `git.exe push`, the native program's file name, and the
    hook exits 0. `GIT push` runs git on a case-insensitive filesystem (Windows, default macOS).
    `/usr/bin/gh repo create me/x --source . --push` runs git itself, as the plain `gh` form the
    hook refuses does.
  Evidence: this scan, on Linux with an unreviewed commit, `git.exe push` exited 0. As recorded on
    2026-11-03: `"/c/Program Files/Git/cmd/git.exe" push`, `GIT push`, and the absolute-path `gh`
    form exited 0, and `gh repo create me/x --source . --push` 2. The git spellings run only on
    the other platforms and were not run there. Confidence: high on the mechanism, low on
    frequency.
  Remediation: compare the token's basename with `git` or `git.exe` at line 337 and with `gh` or
    `gh.exe` at line 461, and add tests. Or add `git.exe` to the accepted risk.

[NOTE] hooks/pre-push-codereview.sh:845-848 — the skip marker is honored at any age and for any
diff, and its check runs before push_sends_commits_outside_head, on purpose for "push now", so a
marker left by a tag-only or terminal push lets a later unreviewed agent push through, including a
push of another ref. Deferred to BACKLOG.md (skip-marker-bound-to-diff). Re-checked at d12ce05:
unchanged.
  Attack vector: a leftover marker plus a later agent push.
  Evidence: this scan, a skip marker backdated 30 days let `git push` with an unreviewed commit
    through (exit 0) and was consumed. As recorded on 2026-11-03: a fresh one let `git push origin
    feature:main` through from a clean main, and because the marker is resolved after the hook
    enters a -C target, `codereview-skip` in repo A followed by `git -C B push` was refused and
    left A's marker armed for A's next unreviewed push. Confidence: high on the mechanism, low on
    frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match, or add an
    age limit, and say in the refusal that a bypass applies per repo.

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is an
inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for the rest
of the turn that invokes it. Found on 2026-10-02. Re-checked at d12ce05: lines 8-9 unchanged.
33cea03 adds spec-backlog-apply.sh calls (Step 4's adoption for Steps 3a, 3b, and 3e, and Step 3f's
append and clear) but no new grant.
  Attack vector: the post-ExitPlanMode hook tells the model to run `/spec plan`, so a turn that
    leaves plan mode can carry unprompted Bash, Write, and Edit into implementation, where content
    the model reads can steer a command.
  Evidence: frontmatter lines 8-9 (`context: inline`, `allowed-tools: Bash(*), Read, Write, Edit,
    Grep, Glob`), and hooks/post-tool-exit-plan-mode.sh still points at `/spec plan`. Documented
    grant semantics; not tested.
  Remediation: narrow /spec's grant to what it runs (git read commands, spec-backlog-apply.sh, Read,
    Grep, Glob) and let Write and Edit fall to the session's rules; consider the same for
    /codereview and /architect.

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
    key, and Step 5.5 sends the diff, key included, to OpenAI and Google. The symlinked BACKLOG.md
    WARN, resolved in the post-fix re-check, was one way a key file's content could reach such a
    diff.
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

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294) send the
caller's unpushed commit subjects to api.openai.com and generativelanguage.googleapis.com (carried
from the 2026-10-01 scan, not re-checked).
  Attack vector: no adversary; the data leaves the machine without the user's opt-in.
  Evidence: as recorded on 2026-10-02 (a recording curl stub saw "=== COMMITS ===" with the unpushed
    subjects in three of four real-curl requests).
  Remediation: run these tests against the suite's fake curl with FAKE_CODE=401, or from
    ${TEST_DIR}.
```

Resolved since the prior entry: none. Every finding in the eight files was re-checked and is still
present.

Resolved in the post-fix re-check: the bin/spec-backlog-apply.sh WARN for a symlinked BACKLOG.md.
Lines 143-147 of the working tree (140-144 before fix cycle 2) refuse a symlink (live or dangling)
or any other non-regular file before the script reads or writes BACKLOG.md. The second re-check
found the guard unchanged and every op still refused through a live link.

### Coverage

All eight dimensions were reviewed for the eight files at HEAD d12ce05.

- Read in full: bin/spec-backlog-apply.sh (319 lines), claude/skills/spec/SKILL.md (709 lines),
  and the f564cd4..d12ce05 diff of all eight files. Also read: claude/skills/tester/SKILL.md's
  frontmatter and Design Mode Steps D.1 to D.7 (the 33cea03 hunks fall there), CLAUDE.md's two
  changed bullets, tests/test-spec-backlog-apply.sh's setup and its 84 added lines, and
  tests/lint-skills.sh's 81 added lines.
- hooks/pre-push-codereview.sh: 82379d2 committed the cycle-3 tree that the 2026-11-03 re-check
  read in full. Its length (967 lines) and every line the prior findings cite match, so it was not
  re-read line by line; the main flow and the target and ref walks (lines 480-967) were. Each
  in-scope finding was re-run with at least one probe. tests/test-pre-push-hook.sh holds the cycle
  1 to 3 additions those re-checks covered; it passes each command to the hook as a payload and
  never runs it.
- Suites on Linux (bash 5.1.16, git 2.34.1, jq 1.6), with XDG_CACHE_HOME in the scratchpad:
  test-spec-backlog-apply.sh 80/80, lint-skills.sh 540/540, test-pre-push-hook.sh 351/351 in 31 s.
  Shellcheck 0.8.0 is clean on the hook and the backlog script, and at warning level on its test.
- Probes ran in scratchpad repos with XDG_CACHE_HOME in the scratchpad. The hook only decided; no
  push was run. Nothing left the machine, no marker was written outside the scratchpad, and
  zat.env's tree was not changed apart from this file.
- Checked and not findings:
  - The new `clear` op is recognized only outside an `append:` block, and its awk reads BACKLOG.md
    and writes a mktemp file (created exclusively, mode 0600). No manifest text reaches a command:
    headings reach awk through `-v`, which processes escapes but cannot run code.
  - The `mv` from mktemp leaves BACKLOG.md 0600 after clear, delete, adopt, or purge (zat.env's
    own BACKLOG.md is 0600 now). That is the restrictive direction, and git tracks only the
    executable bit.
  - The skills' heredocs are quoted (`<<'MANIFEST'`). A body line equal to `MANIFEST` would end one
    early, but the text after it is part of the command the classifier sees, so it is not a hidden
    route.
  - /tester design Step D.2's "Confirm each by running or reproducing it" widens what a design run
    executes, from the framework's listing and a sample run to a check the project configures.
    /tester is manual-invocation only (`disable-model-invocation: true`) and already runs the
    project's suite, so this adds no trust boundary. A check against a live system could have side
    effects; that is operational, not a security finding.
  - The D.7 defect report reaches the calling session as text it may act on ("Fix now"), the same
    trust every skill report has; no grant changed.
  - 33cea03's Step 2 routing and Step 4 adoption change only what /spec writes to SPEC.md and which
    BACKLOG headings get an ACTIVE annotation.
  - CLAUDE.md's new text matches the skills and the script, holds no secret, and grants nothing.
  - The lint additions are grep and awk text checks with fixed patterns over repo files.
- Not verified: Windows and macOS at this HEAD; whether Claude Code's Edit and Write tools resolve
  a symlinked working document (the skills write TESTING.md, SPEC.md, CODEREVIEW.md, and
  SECURITY.md that way); the hook's 30 s cancellation; the Monitor bypass.

Post-fix re-check (2026-11-07). Scope: /codefix's uncommitted changes, on d12ce05, to CLAUDE.md,
bin/spec-backlog-apply.sh, tests/lint-skills.sh, and tests/test-spec-backlog-apply.sh. All eight
dimensions were reviewed for them.

- Read in full: the script (336 lines) and the four files' diff against HEAD. The skills' calls to
  the script were read to confirm that each says to run it from the project root and to stop and
  report on a non-zero exit rather than hand-edit BACKLOG.md.
- Suites, with XDG_CACHE_HOME in the scratchpad: test-spec-backlog-apply.sh 98/98 and
  lint-skills.sh 542/542. tests/run-all.sh was not run, because test-review-external.sh calls the
  real provider APIs (NOTE above). Shellcheck 0.8.0 is clean on the script, and at warning level
  on its test.
- The resolved WARN's reproductions, re-run in scratch clones with BACKLOG.md tracked as mode
  120000 two levels up: `append:`, `clear`, `purge-origin:`, `delete:`, `adopt:`, and a mixed
  manifest each exited 1 with the ERROR line and left the link, the target, and `git status`
  unchanged. A dangling link refused `append:` and `clear`, and its target was not created. A link
  to a directory, a FIFO (no hang), and a directory named BACKLOG.md were refused; a regular file
  still took an append; a manifest with no ops exits 0 before the check and touches nothing.
  HEAD's script, as a control, appended the entry through the link, and bash ran its code span
  when it sourced the outside file. With the guard deleted, 6 of the 98 checks fail and the lint
  pin stops matching.
- Checked and not findings: a gap between the guard and the writes needs a process racing the
  script inside the working tree, which a cloned repo cannot supply. Git checks out no hard links,
  and an extractor that lets a hard link escape also lets a member path escape. Reasoned, not run:
  with core.symlinks off (the Windows default) a tracked link checks out as a regular file holding
  the link text, which the script edits in place, and on a case-insensitive filesystem `-L` sees a
  tracked `backlog.md` link. The new tests write only inside their mktemp directory, whose `rm -rf`
  removes the links without following them. The lint additions are fixed grep patterns, and the
  CLAUDE.md change is prose.
- Not a security finding, passed to the code review: the new fence toggles let one lone fence line
  inside an entry hide every later heading. With `### a` holding a single fence line, followed by
  `### b` (Origin spec) and `### c (ACTIVE in spec ...)` (Origin tester design), `delete: a` and
  `purge-origin: tester design` each removed all three entries, printing only `DELETED: a` or
  `PURGED: a` and `BACKLOG.md: 0 entries`; HEAD's script kept b and c. That bypasses purge-origin's
  ACTIVE carve-out. Text a steered model writes into an entry can trigger it, and git restores the
  file.
- Not verified: whether Claude Code's Read, Edit, and Write tools follow a link. A scratchpad test
  was refused by the permission layer and not retried. The guard covers only the script, so /spec
  Step 3c's turn-close capture, which still writes BACKLOG.md through Edit or Write (CODEREVIEW.md
  NOTE), is outside it.

Post-fix re-check 2 (2026-11-07). Scope: fix cycle 2's uncommitted changes, on d12ce05, to
bin/spec-backlog-apply.sh, tests/lint-skills.sh, and tests/test-spec-backlog-apply.sh. Cycle 2
replaces cycle 1's whole-file fence toggle with one that stops at the first `### ` outside a fence
(script lines 46-50, 159, 203-204, 232-233, 288-290, 324-326), adds ten tests, and adds a lint pin
that counts the five header-only toggles (tests/lint-skills.sh:957-965). All eight dimensions were
reviewed for the three files.

- Read in full: the script (343 lines) and the three files' diff against HEAD.
- Suites, with XDG_CACHE_HOME in the scratchpad: test-spec-backlog-apply.sh 108/108 and
  lint-skills.sh 543/543. Shellcheck 0.8.0 is clean on the script, and at warning level on its
  test. With the five toggles reverted to cycle 1's form, 7 of the 108 checks fail (among them
  "stray fence purge: ACTIVE entry lost"), and the lint pin's count drops from 5 to 0.
- The first re-check's stray-fence fixture (`### a` holding one lone fence line, then `### b` and
  `### c (ACTIVE ...)`): `delete: a`, `purge-origin: tester design`, and `adopt: b` now give HEAD's
  result, keeping b and c. A lone fence line in a middle entry, before a `## ` theme, is plain text
  too.
- Differential fuzz, five seeds of 1,500 random BACKLOG.md files and manifests built from fence,
  `~~~`, indented, `## `, ACTIVE, Origin, `end-append`, and `clear` lines: a Python model of the
  documented semantics matched the script's file, output lines, and exit code in all 7,500 cases.
  The ACTIVE and header invariants held in every case checked (purge-only manifests in seeds 1 to
  3, and the 1,403 manifests without `clear` or `delete:` in seeds 4 and 5): no ACTIVE heading was
  lost and the lines above the first entry were unchanged. On the 5,215 cases whose header holds no
  fence, HEAD's script gave the same result except twice (the last item below).
- Checked and not findings:
  - An unclosed fence in the header now hides every entry from every op: purge-origin removes
    nothing, delete and adopt report MISS (exit 1), the append collision check misses (a duplicate
    heading), and clear removes no entry. Hiding acts only on lines above the first entry, which
    every op prints unchanged, so it cannot widen what an op removes. The CODEREVIEW.md fence NOTE
    already records clear's no-op.
  - The symlink guard is unchanged. Through a live link, clear, delete, adopt, purge-origin, and
    append each exited 1 and left the link and its target's hash unchanged.
  - The manifest parser is unchanged in both fix cycles. A body line equal to `end-append` ends the
    append block early, and the lines after it run as ops: `end-append` then `clear` in a body
    removed an ACTIVE entry. This qualifies the main scan's note that `clear` is recognized only
    outside an `append:` block. It is the same class as a body line equal to the heredoc's
    `MANIFEST` delimiter (above): the text is in the command the classifier sees, and the effect
    stops at BACKLOG.md ops a steered model could write directly. The CODEREVIEW.md suggestion to
    refuse `clear` beside any other op would stop the `clear` form.
  - The new tests write only in their mktemp directory, and the lint addition is a fixed grep
    pattern.
- Not a security finding, passed to the code review: an op can move a fence into the header. A
  fence line under a `## ` theme after the first entry is body text until every entry above it is
  removed; then it is header text and, if unclosed, hides every later entry, in the same run and in
  later runs. With `### a` (Origin tester design), then `## Notes` and one fence line, then `### b`
  and `### c (ACTIVE ...)`: `purge-origin: tester design` removed a and printed `BACKLOG.md: 0
  entries`; a later `delete: b` reported MISS, `append: b` wrote a second `### b`, and `clear`
  removed nothing. HEAD's script also counted 0 entries there and its clear also did nothing, but
  its delete removed b. These are the two fuzz differences against HEAD. Nothing is lost.
- Probes ran in scratchpad directories. Nothing left the machine, and zat.env's tree was not
  changed apart from this file.
- Not verified: Windows and macOS at this working tree.

Git history checked for secrets: `git log -p --follow -3` for each of the eight files, and their
f564cd4..d12ce05 diff, pattern-scanned for OpenAI, Anthropic, Google, GitHub, AWS, Slack, Hugging
Face, and Tailscale keys, private-key headers, and generic key, token, secret, and password
assignments. No hits. None of the eight files handles credentials. PII: only the fixture address
`test@test.invalid`. Post-fix: the four files' working-tree diff, with the same patterns, has no
hits and no email address. Post-fix 2: the three files' working-tree diff, scanned the same way,
has no hits and no email address.

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
  after 82379d2, one after a token over 1,024 characters that holds both quote kinds or a
  backslash, or after a comment line that ends in a backslash, regression NOTE). This does not
  cover a recognized push checked against the wrong ref or the wrong repo (the refspec WARN and
  target-repo NOTE), a spelling that is not a wrapper (the walker and regression NOTEs), or a
  recognized push whose hook times out or fails (the tokenizing NOTE and the `onFailure` WARN).
  Whether the Windows spelling `git.exe push` belongs here is open (NOTE above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when configured, the full
  git diff goes to OpenAI and Google, so any secrets in the diff would be exposed. Sending the diff is
  the script's explicit purpose, and the user opts in by configuring keys. Since 253ad52, /codereview
  Step 5.5 skips the providers when the review reports a secret in the diff (see the markdown gap NOTE
  above); /codereview external has no such check.

---
*Prior review (2026-11-03, scope: paths, at f564cd4, with three post-fix re-checks of the fixes
82379d2 then committed): four files (CLAUDE.md, the pre-push hook, its tests, and lint), 0 BLOCK /
9 WARN / 18 NOTE at the last re-check, no secrets. It found the quadratic scanner that held a long
push past the hook's 30 s timeout, tracked the regressions each /codefix cycle added until cycle 3
bounded the heredoc tracking, re-ran every open gate finding, and carried nineteen findings in
other files.*

<!-- SECURITY_META: {"date":"2026-11-07","commit":"d12ce0592853aecfd10a0e4309b40a1c641bee36","scope":"paths","scanned_files":["CLAUDE.md","bin/spec-backlog-apply.sh","claude/skills/spec/SKILL.md","claude/skills/tester/SKILL.md","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/test-pre-push-hook.sh","tests/test-spec-backlog-apply.sh"],"block":0,"warn":9,"note":19} -->
