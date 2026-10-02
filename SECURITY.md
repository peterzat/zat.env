## Security Review — 2026-10-02 (scope: paths)

**Summary:** Path-scoped scan of 15 files at HEAD c03a14c, covering the 11 unpushed commits
(the uncommitted-change push check, the security surface and post-fix re-check, the
secret-in-diff skip, frontmatter quoting, and control-character stripping): 0 BLOCK / 5 WARN /
12 NOTE, and no secrets in the files or their history. The five WARNs are review-gate gaps,
each reproduced in a scratch repo or traced through documented behavior: the push gate checks
the current branch rather than the pushed refs, /pr merge accepts a review of any ancestor,
the light tier skips /security for `.txt` and `.gitconfig`, review metadata inside the
reviewed commits decides how deeply they are reviewed, and the global 0.0.0.0 bind rule
exposes Docker-published ports past UFW. Of the three prior NOTEs, control characters in
provider text are resolved by 97ab0f0 and the other two are still present.

**Post-fix re-check:** /codefix's uncommitted changes to CLAUDE.md, bin/codereview-marker,
claude/skills/codereview/SKILL.md, hooks/pre-push-codereview.sh, and the two test files were
re-scanned. The fixes hold, and each closes a gate fail-open that was reproduced against the
HEAD versions. A long uncommitted list no longer kills the hook with SIGPIPE (exit 141 at
HEAD). Commits reverted only in the working tree now block (exit 0 at HEAD). The marker
script now runs from the top level, which also closes a `diff.relative=true` bypass: at HEAD
the hook allowed an unreviewed push from a clean subdirectory. No prior finding in these files
is resolved. The fixes did not introduce a vulnerability, but the re-check found two older
WARNs in the gate that the fixes do not reach. With `ignore = all` set for a submodule, its
pointer changes are invisible to the hash, the uncommitted check, the security surface, and
the review diff. The hook also judges the repository as it was before the command ran, so
`git merge feat && git push` is allowed. The push-gate-pushed-repo NOTE gains a .git-directory
variant. Totals after the re-check: 0 BLOCK / 7 WARN / 12 NOTE.

### Findings

```
[WARN] hooks/pre-push-codereview.sh:248-311 — the gate hashes the checked-out branch against
its upstream and allows the push on a match, or on "nothing to review", whatever refs the push
command names.
  Attack vector: an agent pushes a ref other than the checked-out branch, such as
    `git push origin <other>`, `git push origin <other>:main`, or `git push --all origin`.
    If the current branch has a valid marker, or equals its upstream (hash exit 2), the hook
    exits 0 and the unreviewed ref reaches the remote, remote main included. The syntax is
    ordinary, and the hook recognizes the push. It checks the wrong content, so the accepted
    "detection is heuristic" risk, which covers pushes the hook fails to recognize, does not
    cover this. It is the same-repo sibling of BACKLOG.md push-gate-pushed-repo.
  Evidence: reproduced at c03a14c in a scratch repo with an isolated XDG_CACHE_HOME and
    synthetic hook input (nothing was pushed). On main with a marker from `codereview-marker
    write`, `git push origin evil`, `git push origin evil:main`, and `git push --all origin`
    each exited 0. On a branch equal to its upstream, `git push origin evil` and
    `git push origin evil:refs/heads/main` exited 0 with "nothing to review".
    tests/test-pre-push-hook.sh has no case whose refspec names another branch. Re-checked
    post-fix against the fixed hook: same results, all exit 0. On the branch equal to its
    upstream, the new uncommitted check (lines 254-269) finds nothing, because the current
    branch has no unpushed commits, so the hook still prints "nothing to review. Allowed."
    Confidence: high on the mechanism, medium on how often agents push a non-current ref.
  Remediation: gate any push whose refspec sources are not the current branch, HEAD, or a
    tag. The per-push positional walk in is_tag_only_push (lines 152-168) already isolates
    them. Block `--all`, `--mirror`, and `--branches` the same way, with a message to check
    out the ref and run /codereview. A git-native pre-push hook (core.hooksPath), which
    receives the exact local and remote refs on stdin, would close this and
    push-gate-pushed-repo together.

[WARN] claude/skills/pr/SKILL.md:184-191, 217 — /pr merge's review gate passes when the
review covers any ancestor of local HEAD, and the merge acts on the remote PR head, which the
gate never compares with local HEAD.
  Attack vector: a commit lands on the PR branch after the last /codereview: a GitHub
    "Commit suggestion", a bot, a collaborator, a push from the user's own terminal (the
    hook sees only Claude's Bash), or a "push now" skip. `git merge-base --is-ancestor
    "${REVIEWED_UP_TO}" HEAD` stays true for every later commit, and `gh pr merge --squash`
    merges the remote head even when local HEAD is behind it, so the unreviewed commit
    reaches main with the gate reporting a passing review. The gate also reads CODEREVIEW.md
    from the PR branch, so a contributor's PR satisfies it with the contributor's own
    REVIEW_META (see the review-state finding below).
  Evidence: reproduced with the skill's own commands in a scratch repo: a reviewed commit,
    a CODEREVIEW.md commit (block 0, reviewed_up_to = the reviewed commit), then a commit
    changing app.py. The gate passed (blocks=0, reviewed_up_to=45977c8, HEAD=74854c8) while
    `git diff` from the reviewed commit, review files excluded, showed the app.py change.
    Line 217 pins no head commit. The installed gh (2.4.0) has neither
    `--match-head-commit` nor the `headRefOid` field. Confidence: high.
  Remediation: replace condition 3 with "no non-review-file change since the reviewed
    commit": `git diff --quiet "${REVIEWED_UP_TO}" HEAD -- ':!CODEREVIEW.md' ':!SECURITY.md'
    ':!TESTING.md' ':!SPEC.md'`. Stop unless the remote PR head equals local HEAD
    (`git ls-remote origin "refs/heads/<branch>"`, or the last oid from `gh pr view --json
    commits`). Where gh supports it, also pass `--match-head-commit "$(git rev-parse HEAD)"`,
    which closes the window between the check and the merge.

[WARN] claude/skills/codereview/SKILL.md:269-277 — the light tier treats `.txt` and
`.gitconfig` files as plain documentation, so a diff limited to them skips /security, the
tests, the external reviewers, and the built-in review, and still gets a marker.
  Attack vector: gitconfig/aliases.gitconfig is live configuration. zat.env-install.sh:41-43
    adds it to ~/.gitconfig as an include.path by repo path (present in this user's
    ~/.gitconfig), and every adopter gets it after a pull. It can set `core.fsmonitor`,
    `core.pager`, `core.sshCommand`, or a `!` alias, each of which runs a command during
    ordinary git use. In downstream projects, `requirements*.txt` (pip manifests, which
    accept `--index-url`, `--extra-index-url`, and direct URL requirements) and
    `CMakeLists.txt` (a build script) share the extension. A command-running git setting or
    a typosquatted or redirected dependency is reviewed only for "broken links/references,
    accidental secret leaks in prose, and factual accuracy" (lines 283-284), and /security's
    supply-chain dimension never runs. The same paragraph sends `.json`, `.yaml`, and
    `.toml` to the full tier because they are "operationally live (... dependencies ...)"
    (lines 271-272).
  Evidence: the rule dates from a262d48 (2026-03-28), and fe3cb3d restated it: "the review
    is light only if every file it prints is a `.txt`, `.gitignore`, or `.gitconfig` file"
    (lines 276-277). `codereview-marker surface` lists both extensions (it filters only
    `.md`, bin/codereview-marker:133-135), so the gap is in the tier rule. In a scratch
    HOME, a `core.fsmonitor` set in a file reached through `[include] path` ran on
    `git status` (git 2.34.1). Confidence: high on the mechanism.
  Remediation: drop `.txt` and `.gitconfig` from the light tier (or keep only `.gitignore`
    and prose `.txt` files that are neither dependency manifests nor build files), and
    update the lint pin at tests/lint-skills.sh:420 to the new wording.

[WARN] claude/skills/codereview/SKILL.md:203-209, 287-337, 402-425, 559-561 — review state
that the reviewed commits can change decides how deeply those commits are reviewed, and the
changes never appear in the reviewed diff (same trust in claude/skills/security/SKILL.md:43-46
and claude/skills/pr/SKILL.md:184-191).
  Attack vector: commits the operator did not author (a contributor branch merged or checked
    out locally, a cherry-picked patch) edit CODEREVIEW.md and SECURITY.md alongside the
    code. A REVIEW_META with block 0, base origin/main, and reviewed_up_to set to the commit
    carrying the code makes the run a refresh review with an empty focus set. That code is
    then "already reviewed" (regression risk only, diff hunks only), and the built-in
    review's findings in it stay at NOTE (lines 560-561). A SECURITY.md META footer naming
    that commit with scope full makes Step 5 skip /security and carry its zero counts. An
    Accepted Risks line describing the code downgrades matching findings to NOTE (lines
    206-207, 559), and /security, told that every listed item was "explicitly reviewed and
    approved by the human", does not flag it. The review diff, the security surface, and the
    push hash all exclude these files (line 238, bin/codereview-marker:68), so no reviewer
    sees the edit, and /pr merge accepts the same REVIEW_META with no review at all. An
    honest REVIEW_META from a contributor's own /codereview run has the same effect: the
    operator's gate defers to someone else's review.
  Evidence: the deterministic part was reproduced with the skill's Step 2 and Step 5
    commands in a scratch repo. C1 changed app.py; C2 wrote only CODEREVIEW.md (REVIEW_META
    reviewed_up_to=C1, block 0, base origin/main, an Accepted Risks line) and SECURITY.md
    (META footer naming C1, scope full). All three refresh conditions held, the focus set
    was empty, the full set was app.py, `codereview-marker surface C1` printed nothing (skip
    /security), and the Step 2 review diff listed only app.py. Not verified: a full
    /codereview run against such a branch. The downgrades are model-executed. Confidence:
    high on the mechanism, medium on how the model weighs the planted entries.
  Remediation: at Step 2, list `git log --format='%h %ae %s' "$(codereview-marker
    base)"..HEAD -- CODEREVIEW.md SECURITY.md`. When a commit not authored by the operator
    (`git config user.email`) touched them, take the full tier, run /security, read prior
    META and Accepted Risks from `git show "$(codereview-marker base):<file>"`, and do not
    honor Accepted Risks entries added in the range until the user confirms them. /pr merge
    should accept only a review of the PR head itself (see the /pr merge finding).

[WARN] claude/global-claude.md:104 — the convention loaded into every session binds every
service to 0.0.0.0. That is safe only behind a host firewall that sees the service's traffic,
which Docker-published ports bypass and which the documented setup path never enables.
  Attack vector: an agent follows this line and claude/references/networking.md:14 ("Docker
    containers: `-p PORT:PORT` (binds `0.0.0.0`). Never `-p 127.0.0.1:PORT:PORT`...") to
    start a container for a dev UI or model server (Jupyter, Gradio, ComfyUI, an
    OpenAI-compatible server). Docker publishes the port through its own NAT and FORWARD
    rules, which apply before UFW's (Docker documents that published ports bypass ufw), so
    the service answers on the box's public address. Many such services have no
    authentication, and Jupyter without a token runs code for the caller. On a box built
    with hw-bootstrap.sh, which installs Docker and never enables UFW (no ufw command in
    hw-bootstrap.sh or docs/hardware-setup.md), every service bound to 0.0.0.0 is reachable
    from the internet unless a network-level firewall blocks it. This file applies to every
    machine that installs zat.env, while the
    firewall premise lives only in the per-machine networking.md (moved out of this file in
    538ce88).
  Evidence: on this host enp4s0 holds a public /32, ufw and docker are both active,
    /etc/docker/daemon.json does not set `"iptables": false`, and docker0 is down (no
    container running now). The UFW and iptables rules are root-only, so the absence of
    DOCKER-USER restrictions was not confirmed (after.rules is the same size as the stock
    2023 backup). The Hetzner network firewall state is unknown. Confidence: high on the
    Docker and UFW mechanism, medium on exposure at a given time.
  Remediation: bind to the Tailscale address rather than all interfaces: `--host
    "$(tailscale ip -4)"` for local servers and `-p "$(tailscale ip -4):PORT:PORT"` for
    Docker, or 127.0.0.1 plus `tailscale serve`. If 0.0.0.0 stays, add DOCKER-USER rules
    that drop forwarded traffic not arriving on tailscale0, and have hw-bootstrap.sh enable
    UFW with the documented policy so new machines match the premise.

[WARN] hooks/pre-push-codereview.sh:248-311 — the hook judges the repository as it is before
the command runs, so commits that the same command creates or imports ahead of its push are
sent on the strength of the earlier state. (New in the post-fix re-check.)
  Attack vector: on a branch equal to its upstream with a clean tree, or one whose committed
    state carries a valid marker, an agent runs `git merge <local branch> && git push`,
    `git cherry-pick <sha> && git push`, `git stash pop && git commit -am wip && git push`,
    or an edit, commit, and push in one call. The hook finds nothing to review, or a
    matching marker and nothing uncommitted, and exits 0. The commits the command then
    makes are pushed unreviewed. These are ordinary agent commands. The hook recognizes the
    push, so the accepted "detection is heuristic" risk does not cover this. The new
    uncommitted check (lines 254-269) cannot see commits that do not exist yet.
  Evidence: reproduced in a scratch repo with an isolated XDG_CACHE_HOME and synthetic hook
    input. On main equal to origin/main, with an unreviewed commit on the local branch
    `feat`, `git merge --no-edit feat && git push`, `git cherry-pick feat && git push`, and
    `echo x >> a.txt && git commit -qam x && git push` each printed "nothing to review.
    Allowed." and exited 0. No test in tests/test-pre-push-hook.sh puts a history-changing
    command before the push. Confidence: high on the mechanism, medium on frequency.
  Remediation: block any command in which another statement comes before a `git push`
    (ignoring a leading `(`, `{`, or `!`), and tell the agent to run the other statements
    first and `git push` as its own Bash call. The token indices from
    _push_subcommand_indices (lines 86-118) show whether anything comes before the push.
    This also stops `cd <other> && git push` (push-gate-pushed-repo). A git-native pre-push
    hook runs when the push actually happens and would close this, the refspec WARN above,
    and push-gate-pushed-repo together.

[WARN] bin/codereview-marker:162-178 — `list_uncommitted` and `compute_hash` call `git diff`
without `--ignore-submodules`, so when a submodule has `ignore = all` (in .gitmodules, or
`diff.ignoreSubmodules=all` in any git config), its pointer changes are left out of the marker
hash, the uncommitted check, the security surface (line 156), and the review diff
(claude/skills/codereview/SKILL.md:238, 471). (New in the post-fix re-check.)
  Attack vector: in a project with a submodule, a commit moves the pointer to another commit:
    an older release with a known vulnerability, or an unreviewed upstream commit. If
    .gitmodules already sets `ignore = all`, `hash` exits 2 and the hook prints "nothing to
    review. Allowed."; the new uncommitted check uses the same diff and finds nothing. If it
    does not, the same diff can add `ignore = all` next to the bump. The review, /security,
    and the external reviewers then see only that one line, and `codereview-marker write`
    produces a marker the hook accepts. Either way the bump reaches the remote, and
    `git submodule update` checks it out for everyone. `git log --stat` hides it too.
  Evidence: reproduced in scratch repos (git 2.34.1, isolated XDG_CACHE_HOME, synthetic hook
    input). With `ignore = all` already in .gitmodules at the base, `git log origin/main..HEAD`
    listed the bump commit, `hash` exited 2, `uncommitted` printed nothing, and the fixed
    hook exited 0. With `ignore = all` added in the bump commit, the Step 2 review diff
    showed only `+ ignore = all`, `surface` printed only .gitmodules, `write` succeeded, and
    the hook exited 0. `git diff --ignore-submodules=dirty` listed `sub | 2 +-` in both
    cases. No .gitmodules exists under ~/src (depth 3) and the global git config sets no
    diff or submodule options, so no project on this host is exposed today. Confidence:
    high on the mechanism, low on how often it is reached.
  Remediation: pass `--ignore-submodules=dirty` to every `git diff` in bin/codereview-marker
    (compute_hash, list_uncommitted, list_surface). The flag overrides both settings and
    still ignores dirty submodule work trees, which a push does not send. It leaves the hash
    of a repo without submodules unchanged (zat.env: a7d614c734963c8e with and without it),
    so existing markers stay valid. Add the same flag to the review diffs in SKILL.md Steps
    2, 5.5, E.3, and E.4 (or have them call a `codereview-marker diff` subcommand), so the
    reviewer sees the bump the marker covers. Update the lint pins that match those
    commands, and add a test with an `ignore = all` submodule.

[NOTE] bin/codereview-marker:130-144 — the security surface keeps agent-instruction markdown
only by a fixed name list, so markdown that agents read as instructions under other names
counts as plain documentation.
  Attack vector: global-claude.md:96 and :104 point every session at
    claude/references/ml-gpu.md and networking.md, which agents follow as conventions.
    CLAUDE.md tells skill authors to move details into a skill's references/ directory
    (BACKLOG.md skill-size-references-split plans this for /spec), and a CLAUDE.md can
    `@`-import any markdown file. in_surface drops all of these, so a diff limited to them
    takes the light tier (no /security, no external reviewers), and in a full-tier run
    they never reach /security's file list. An edit telling agents to publish a port or to
    fetch and run an installer is reviewed as prose.
  Evidence: in_surface returns 1 for any `.md` whose basename is not in the list and whose
    path has no `.claude/` component (lines 133-143). tests/test-codereview-marker.sh:362
    and 383-385 pin docs/guide.md as omitted. Confidence: high on the mechanism, low on
    likelihood.
  Remediation: also keep `*/references/*.md` and markdown under zat.env's `claude/` tree,
    and files a CLAUDE.md `@`-imports; or invert the rule and drop only known prose paths
    (README*, docs/, CHANGELOG*).

[NOTE] claude/skills/codereview/SKILL.md:460-464 — the secret-in-diff guard relies on a step
that reports secrets, and in a full-tier review no step looks for them in plain markdown.
  Attack vector: no adversary. A diff touches code and also adds a key to a markdown file
    (a setup note, a README example), so it takes the full tier. Step 4's full-tier
    dimensions (lines 363-380) include no secret check (only the light tier's reduced
    scope does, line 283), and /security receives only `codereview-marker surface` files,
    which omit plain markdown (bin/codereview-marker:133-143). Neither reports the key, and
    Step 5.5 sends the diff, key included, to OpenAI and Google. A first push is covered by
    the full /security audit. General diff egress is an Accepted Risk; the point is that the
    253ad52 guard is narrower than its wording.
  Evidence: traced through the skill text and the surface code; not run end to end.
    Confidence: high on the mechanism.
  Remediation: before Step 5.5, grep the exact diff it will send for key patterns (`sk-`,
    `sk-ant-`, `AIza`, `ghp_`, `github_pat_`, `AKIA`, `xox[bp]-`, `hf_`, private-key
    headers) and skip the providers on a match, or add a whole-diff secret check to Step 4.

[NOTE] claude/skills/codereview/SKILL.md:405-410, 437-441 — the model extracts the commit
field of SECURITY.md's META footer and pastes it into a shell command, so codereview-marker's
leading-dash check (bin/codereview-marker:146-155) runs only after the shell has expanded it.
  Attack vector: a commit that edits SECURITY.md appends a `$(...)` command substitution,
    or a backtick span, to the footer's commit value. Step 5 says to "extract the commit
    field" and run `codereview-marker surface <meta-commit>`. If the model substitutes the
    value unquoted or inside double quotes, the substitution runs under the skill's
    `Bash(*)` grant before the script sees its argument. The script's own comment treats
    that footer as repo-controlled input. Step 2 already avoids this for reviewed_up_to by
    extracting with a hex-only `grep -oP` inside the command substitution (lines 295, 316).
  Evidence: traced through the skill text; not tested against a live model, which may well
    notice and refuse such a value. Confidence: medium on the mechanism, low on likelihood.
  Remediation: extract inside the command, as Step 2 does, with a hex-only `grep -oP`
    (7 to 40 hex characters) on the footer's commit field, or add a codereview-marker
    subcommand that reads the footer itself, and update the lint pin at
    tests/lint-skills.sh:401.

[NOTE] claude/skills/pr/SKILL.md:152 — the PR template puts free text derived from commit
messages inside double-quoted shell arguments.
  Attack vector: `gh pr create --title "<title>" --body "<body>"`. A body built from commit
    messages often contains markdown code spans, and a subject can carry `$(...)`. Inside
    double quotes bash runs both as commands, under the skill's `Bash(*)` grant. A subject
    from someone else's commit chooses the command, and even benign text such as "adds
    `codereview-marker write`" would run that command and write the push marker.
  Evidence: traced through the template; not run. Whether the model follows the template
    literally or switches to a quoted heredoc was not observed. Confidence: medium on the
    mechanism, low on likelihood.
  Remediation: write the body with a quoted heredoc (`cat > "$f" <<'EOF'`) and pass
    `--body-file "$f"` (supported by the installed gh 2.4.0); build the title the same way.

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is
an inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for
the rest of the turn that invokes it.
  Attack vector: the skills documentation says a skill's `allowed-tools` "grants permission
    for the listed tools during the turn that invokes the skill" and "clears when you send
    your next message", and that the grant applies when Claude invokes the skill itself.
    The post-ExitPlanMode hook tells the model to run `/spec plan`, so a turn that leaves
    plan mode can carry unprompted Bash, Write, and Edit into implementation, where content
    the model reads (an issue, a fetched page, a file) can steer a command. Before 6f43afe
    the frontmatter was ignored and /spec ran under the session's rules. /codereview's
    `Bash(*)` (codereview SKILL.md:16) is declared again for the same reason, though whether
    a forked skill applies its grant is not documented; it reads attacker-controllable diffs
    and runs automatically on every gate block. The added
    exposure is small in modes where the Accepted `Bash(python3 *)`-class allow rules
    already permit arbitrary execution. How auto mode treats a skill grant is not
    documented; it drops broad `Bash(*)` allow rules from settings.
  Evidence: the quoted documentation text was checked against a saved copy of the Claude
    Code docs (skills page, "Pre-approve tools for a skill" and "Restrict Claude's skill
    access"). `git diff origin/main` shows 6f43afe removed `disable-model-invocation: true`
    and set `context: inline` on /spec. Not tested empirically. Confidence: high on the
    documented grant, low on the added impact.
  Remediation: narrow /spec's grant to what it runs (for example `Bash(git log *)`,
    `Bash(git status *)`, `Bash(spec-backlog-apply.sh *)`, Read, Grep, Glob) and let Write
    and Edit fall to the session's rules. Consider the same narrowing for /codereview (git,
    codereview-marker, review-external.sh, the project test runner) and the read-only
    /architect.

[NOTE] bin/review-external.sh:357 — the long-context price comparison is a bash arithmetic
context, which expands a command substitution hidden in an array subscript. `_count` (lines
278-280) makes it safe, but no test covers this sink. The Gemini comparison at line 463 is the
same. Re-checked at c03a14c: still present, code unchanged.
  Attack vector: none at HEAD. If a later edit compares the raw jq output instead of the
    `_count` value, a provider response carrying "input_tokens":"PATH[$(cmd)]" runs cmd as
    the user. Only the provider, or someone who can tamper with its TLS connection, controls
    that field.
  Evidence: lines 349, 357, 456, and 463 are unchanged since the 2f556b0 scan, whose mutant
    run executed the payload while the suite still passed. The hostile-value test
    (tests/test-review-external.sh:883-892) still sends "1; while (1) { }", which targets
    bc, and no test sends a hostile Gemini count. Confidence: high on the mechanism.
  Remediation: name the comparisons in the `_count` comment, change the hostile-value test
    to a command-substitution payload such as "PATH[$(: > ${TEST_DIR}/ran)]" and assert the
    file does not exist, and add the same case for promptTokenCount.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294)
send the caller's unpushed commit subjects to api.openai.com and
generativelanguage.googleapis.com. Re-checked at c03a14c: still present.
  Attack vector: no adversary. The data leaves the machine without the user's opt-in:
    everywhere else, sending data to these providers requires configuring a key. The script
    builds its COMMITS block from `git log @{upstream}..HEAD` in the caller's directory.
  Evidence: the suite ran from the repo root with a recording stub ahead of curl on PATH.
    Three of the four real-curl requests carried "=== COMMITS ===" with the current
    unpushed subjects (c03a14c and earlier): two to api.openai.com and one to
    generativelanguage.googleapis.com. With curl stubbed the suite passed 80 of 80.
    Confidence: high on the mechanism, low on impact.
  Remediation: run these tests against the suite's fake curl with FAKE_CODE=401, or from
    ${TEST_DIR}.

[NOTE] hooks/pre-push-codereview.sh:226-230 — the skip marker is honored at any age and for
any diff, so a marker left by a tag-only push or a terminal push lets a later, unreviewed
agent push through. Deferred to BACKLOG.md (skip-marker-bound-to-diff).
  Attack vector: as recorded in that entry. A leftover marker plus a later agent push.
  Evidence: lines 226-230 are unchanged; the 2026-10-01 scan reproduced a 30-day-old marker
    being honored. Confidence: high on the mechanism, low on frequency.
  Remediation: store `codereview-marker hash` in the marker and honor it only on a match,
    or add an age limit.

[NOTE] bin/codereview-marker:104-109, 188 — marker_dir ignores mkdir and chmod failures and
checks neither the directory's owner nor whether it is a symlink, and `write` follows a
symlinked marker path. Deferred to BACKLOG.md (marker-dir-ownership-check).
  Attack vector: needs XDG_CACHE_HOME in a directory another account can write, where that
    account pre-creates the directory or plants a symlink at the marker path.
  Evidence: errexit is off inside the `$(marker_dir)` command substitution; a copy of the
    function under `set -euo pipefail`, run against a read-only parent, returned the path
    after mkdir failed. On this host ~/.cache and ~/.cache/claude-codereview are 0700 and
    owned by the user, so it is not exploitable here. Confidence: high on the mechanism, low
    on reachability.
  Remediation: verify a real directory owned by the current user with mode 0700 and fail
    otherwise, then write the marker to a temp file in that directory and rename it into
    place, so a planted symlink is replaced rather than followed.

[NOTE] hooks/pre-push-codereview.sh:193-198 — without jq the command parses as empty, is not
detected as a push, and the hook exits 0. Deferred to BACKLOG.md (push-gate-jq-fail-open).
  Attack vector: a machine without jq on the hook's PATH; any push passes ungated.
  Evidence: with jq removed from PATH, a `git push` payload in a scratch repo with an
    unreviewed change exited 0; with jq present it exited 2. Confidence: high on the
    mechanism, low on reachability (jq is an install prerequisite).
  Remediation: fail closed when jq is missing or the payload does not parse and the raw
    input contains both `git` and `push`.

[NOTE] hooks/pre-push-codereview.sh:211-311 — the hook evaluates the repo at its working
directory, not the repo being pushed. Deferred to BACKLOG.md (push-gate-pushed-repo).
  Attack vector: `git -C <other> push`, or `cd <other> && git push`, from a clean repo or a
    non-git directory pushes <other> without review. The post-fix re-check found a variant
    in the same repo: with the working directory inside the repo's own .git directory,
    `git rev-parse --show-toplevel` fails, line 211 takes that to mean "not in a git repo"
    and exits 0, and `git push` still works from there.
  Evidence: during this scan the live hook blocked a push into a scratch bare repo, issued
    from this session, on zat.env's own unreviewed diff, which is the converse effect of the
    same cwd-based check. Post-fix, in a scratch repo, `--show-toplevel` inside .git exited
    128, the fixed hook run from .git exited 0 with no output, and `git push origin main`
    from .git sent an unreviewed commit to a scratch bare remote. Whether Claude Code runs
    the hook in the Bash tool's directory after an earlier `cd .git` was not verified.
    Confidence: high on the mechanism, low on reachability of the .git variant.
  Remediation: resolve the target repo from the command (`-C`, `--git-dir`, a leading
    `cd <dir> &&`) and evaluate the marker there, failing closed when it cannot be resolved,
    or move to a git-native pre-push hook. For the .git variant, pass through only when
    `git rev-parse --git-dir` fails, and block when it succeeds but `--show-toplevel` does
    not (inside .git, or a bare repo).

[NOTE] bin/codereview-marker:170-178 — the marker hashes only the net diff against the base,
so a secret committed and then deleted inside the pushed range ships in history without
review. Deferred to BACKLOG.md (push-gate-net-diff-secret).
  Attack vector: no adversary needed; an agent commits a key, removes it in a later commit,
    and the review sees only the net diff.
  Evidence: compute_hash diffs the base against the working tree; /codereview reviews the
    same net diff. Confidence: high on the mechanism, low on frequency.
  Remediation: scan the per-commit diffs of `<base>..HEAD` for key patterns before writing
    the marker.
```

### Coverage

All eight dimensions were reviewed for the 15 files at HEAD c03a14c.

- Read in full: bin/codereview-marker (213 lines), hooks/pre-push-codereview.sh (310),
  bin/review-external.sh (607), claude/global-claude.md (108),
  claude/skills/codereview/SKILL.md (741), claude/skills/pr/SKILL.md (239),
  claude/skills/architect/SKILL.md (206), claude/skills/security/SKILL.md (230; it is the
  prompt for this scan), CLAUDE.md (79), tests/test-codereview-marker.sh (448), and
  tests/test-pre-push-hook.sh (557).
- Read in part: claude/skills/spec/SKILL.md (659) and claude/skills/tester/SKILL.md (579).
  Read were the frontmatter, the diffs since origin/main, the manifest and heredoc sections
  (spec Step 3g and the BACKLOG.md format; tester D.6 and D.7), and every line a grep for
  shell constructs matched (code fences, heredocs, `$(`, git, gh, curl, rm, chmod, sudo,
  eval, source). The rest is interview, proposal, and audit guidance, not read line by line
  in this run.
- tests/lint-skills.sh (1877) and tests/test-review-external.sh (962) were read through
  their diffs since the 2f556b0 scan, which read every line. The new frontmatter check uses
  `yaml.safe_load`.
- Runs, all local, with XDG_CACHE_HOME in the scratchpad and a recording curl stub ahead of
  the real curl: test-codereview-marker.sh 67/67, test-pre-push-hook.sh 74/74,
  test-review-external.sh 80/80, lint-skills.sh 488/488. Scratch reproductions covered the
  refspec gap, the /pr merge gate, the review-state chain, the jq fail-open, the marker_dir
  errexit behavior, and an included gitconfig's core.fsmonitor. Nothing was pushed, and the
  working tree was unchanged afterward.
- Checked and not findings:
  - `_sanitize` (bin/review-external.sh:587-589) resolves the prior control-character NOTE.
    jq emits valid UTF-8, and removing whole C1 code points from valid UTF-8 cannot form a
    new C2 80-9F pair. Bidi and zero-width characters pass but cannot move the severity tag
    the own-tag regex requires.
  - Binary files enter the marker hash only through abbreviated blob IDs. A prefix-colliding
    swap changed the hash anyway, because git lengthened the abbreviation (0f29b0a to
    0f29b0a0) while the reviewed blob stayed in the object store. Only a swap plus pruning
    the reviewed blob would keep it, and an agent able to do that can run
    `codereview-marker write`. `--full-index` in compute_hash would remove even that case.
  - `uncommitted` output reaches the block message without `-z`, so git C-quotes control
    characters in file names.
  - The spec and tester manifests use a quoted `'MANIFEST'` delimiter. Only a body line
    equal to that word could end one early.
  - The Step 5.6 child `claude -p` starts in auto mode on this host (settings defaultMode
    auto, classifyAllShell true), so its Bash calls reach the classifier.
- Not verified: UFW and iptables rule contents (root-only), the Hetzner network firewall,
  how auto mode treats a skill's `allowed-tools`, and model behavior for the model-executed
  steps in the review-state, META commit extraction, and PR-template findings.
- Out of scope but used as context: claude/references/networking.md, hw-bootstrap.sh,
  docs/hardware-setup.md, zat.env-install.sh, hooks/post-tool-exit-plan-mode.sh, and
  bin/codereview-skip.

Git history checked for secrets: all 15 files over their full history (`git log -p --all
--follow`; CLAUDE.md 46 commits, tests/lint-skills.sh 61, claude/skills/codereview/SKILL.md
43, the rest 5 to 40), which subsumes the last three commits. Patterns covered OpenAI,
Anthropic, Google, GitHub, AWS, Slack, Hugging Face, and Tailscale keys, private-key headers,
and generic key, token, secret, and password assignments, with zero hits. The only key values
ever assigned are the fakes `sk-invalid-test-key`, `sk-test-key`, and `fake-google-key`. PII:
`test@test.invalid` (reserved) and the `/home/peter` fixture path at
tests/test-pre-push-hook.sh:127, covered by the accepted PII risk.

Post-fix re-check (the six files /codefix changed, uncommitted on c03a14c). All eight
dimensions were reviewed for them.

- Read in full: bin/codereview-marker (217 lines), hooks/pre-push-codereview.sh (329), and
  claude/skills/codereview/SKILL.md (743). Read through their diffs with the surrounding
  setup code: CLAUDE.md (one sentence), tests/test-codereview-marker.sh (+11), and
  tests/test-pre-push-hook.sh (+44).
- Runs, with XDG_CACHE_HOME in the scratchpad: test-codereview-marker.sh 69/69,
  test-pre-push-hook.sh 76/76, lint-skills.sh 488/488. Against the HEAD hook and script, the
  four new checks fail (exit 141; exit 0; the subdirectory listing; the hash mismatch), so
  they exercise the fixed defects. Scratch experiments covered the submodule cases, the
  `diff.relative` bypass, compound commands, the hook run from .git, and the refspec WARN
  against the fixed hook. The one real push went to a scratch bare repo, and the working
  tree was unchanged afterward.
- Checked and not findings:
  - `cd "${top}"` in require_git receives an absolute path from git, so CDPATH and
    leading-dash parsing do not apply and nothing reaches stdout. A failed cd exits 1 under
    errexit, which the hook treats as fail-closed for path, skip-path, hash, and
    uncommitted. The marker path is unchanged, because proj_hash already hashed the top
    level.
  - `sed -n '1,20s/^/  /p'` reads all of its input, so the writer is never cut off. File
    names still reach the block messages C-quoted. Their text is no more attacker-influenced
    than the `git status` output the agent already reads.
  - With skip-worktree, assume-unchanged, or `git rm --cached` entries, HEAD cannot differ
    from the base while both the hash and the uncommitted check pass, because both compare
    the index-backed blobs. The submodule case above is the exception, since `git diff`
    there omits the path entirely.
  - The Step 7 wording only selects the /security mode. A wrong choice either updates an
    older entry in place, whose commit field stays (so the next surface check scans more,
    not less), or carries this run's entry forward with its findings still counted by the
    Step 4 carry rule.
- Not verified: whether Claude Code runs the hook in the Bash tool's current directory after
  a `cd`, which decides how reachable the .git variant of push-gate-pushed-repo is.
- Git history: a pattern scan of `git diff HEAD` found no secrets in the uncommitted changes.
  The two pattern hits were this file's own text (the remediation pattern list and the fake
  key names). The full history of all six files was checked above at c03a14c.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:183-224`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution. The deny entries are prefix matches and cannot
  enumerate every spelling. Accepted 2026-08-20 because README.md:162 and the script
  comment (lines 178-182) state plainly that the deny list is a speed bump.
  `autoMode.classifyAllShell` sends these commands through the classifier in auto mode,
  so the risk as accepted applies to the other permission modes. This host has the
  setting (verified 2026-10-01).
- **Venv-activation chains auto-approved outside auto mode**
  (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes,
  the hook returns allow for `. .venv/bin/activate && <anything>`, including pipes,
  `$(...)`, and further commands. The user kept this behavior on 2026-10-01 when
  approving the auto-mode fix, as recorded in CODEREVIEW.md Accepted Risks. The hook
  exists to avoid the eval-like-builtin prompt, and its reach matches the accepted
  interpreter grants in those modes.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  tagging loops at lines 372-378, 475-481, and 536-542): a model steered by
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
  immaterial on the documented single-user target. The three service accounts on this
  host run with PrivateTmp=yes and cannot reach it (verified 2026-10-01).
- **Pre-push gate detection is heuristic, not a shell parser**
  (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper and prefix invocations
  (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and
  `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass
  the advisory codereview gate. Accepted under the advisory-gate threat model. The hook
  is intentionally simple and biased toward over-detection. This does not cover a
  recognized push checked against the wrong ref (first WARN above).
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when
  configured, the full git diff goes to OpenAI and Google, so any secrets in the diff
  would be exposed. Sending the diff is the script's explicit purpose, and the user opts
  in by configuring keys. Since 253ad52, /codereview Step 5.5 skips the providers when
  the review reports a secret in the diff (see the markdown gap NOTE above);
  /codereview external has no such check.

---
*Prior review (2026-10-01, scope: paths, at 2f556b0): bin/review-external.sh,
tests/lint-skills.sh, and tests/test-review-external.sh. 0 BLOCK / 0 WARN / 3 NOTE: the
untested arithmetic sink and the invalid-key tests sending commit subjects (both still open
above), and control characters in provider text (resolved by 97ab0f0). It retired the curl
`-H` Accepted Risk after 5a1a7aa moved both keys to a file descriptor, verified with an execve
trace and a concurrent scan of every process command line.*

<!-- SECURITY_META: {"date":"2026-10-02","commit":"c03a14c50ce9a163d891e47a30dd0c170126a694","scope":"paths","scanned_files":["CLAUDE.md","bin/codereview-marker","bin/review-external.sh","claude/global-claude.md","claude/skills/architect/SKILL.md","claude/skills/codereview/SKILL.md","claude/skills/pr/SKILL.md","claude/skills/security/SKILL.md","claude/skills/spec/SKILL.md","claude/skills/tester/SKILL.md","hooks/pre-push-codereview.sh","tests/lint-skills.sh","tests/test-codereview-marker.sh","tests/test-pre-push-hook.sh","tests/test-review-external.sh"],"block":0,"warn":7,"note":12} -->
