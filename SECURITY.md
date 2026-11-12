## Security Review — 2026-11-12 (scope: paths)

**Summary:** Path-scoped scan, at HEAD 721b632, of the four files `codereview-marker surface 1d1b5da`
lists: CLAUDE.md, the codefix and security skills, and tests/lint-skills.sh. c5bf5e6 gives each
finding one Status line and condenses carried NOTEs, and 9787b0b keeps /security and /codefix in the
foreground and stops /security from running suites or spawning subagents; both narrow what a fork
runs. Three new NOTEs: the secret-history command /security tells the model to build takes a
committed file name with no `--`, so a path beginning with `--output=` empties a file of the
committer's choosing (the git step reproduced here); /codefix fixes BLOCK and WARN findings from
CODEREVIEW.md's carried-forward block, which skip /codereview's filters; and a condensed NOTE is
re-checked from one sentence. None of the 25 prior findings is in these files, so all are carried,
with Status lines built from SECURITY.md's history. No secrets. Totals: 0 BLOCK / 1 WARN / 27 NOTE.

### Findings

```
[WARN] claude/global-claude.md:108 — the convention loaded into every session binds every service
to 0.0.0.0. That is safe only behind a host firewall that sees the service's traffic, which
Docker-published ports bypass and which the documented setup path never enables.
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
  Status: found 2026-10-02 at c03a14c; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] claude/skills/security/SKILL.md:91-93 — the secret-history step has the model paste a file
name into `git log -p --follow -3 <file>`, with no `--` before it, and the names come from the
repository, so a committed path that begins with `--output=` makes git empty a file of the
committer's choosing, and a name holding `$(...)`, a backtick span, or a single quote runs a command
when pasted inside quotes.
  Attack vector: anyone whose commit the user pulls (a collaborator on a shared branch, a
    contributor's PR branch checked out for review) adds a file at the path
    `--output=/home/<user>/.claude/settings.json`; git's path checks refuse components such as `.`,
    `..`, and `.git`, not a leading dash, and `<user>` is often guessable from commit metadata.
    Before the next push, /codereview's Step 5 lists the files changed since the last scan with
    `codereview-marker surface`, which prints each name raw (bin/codereview-marker:149-160: `-z`,
    `core.quotePath=false`, `printf '%s\n'`), and hands the list to /security
    (claude/skills/codereview/SKILL.md:464-465). The file is agent configuration under `.claude/`,
    which Step 2 puts first (lines 79-83) and Step 3 says to check for committed secrets, so the
    model runs the template: `git log -p --follow -3 --output=/home/<user>/.claude/settings.json`.
    Git opens the target for writing, then exits 128 because `--follow` has no pathspec left, and
    the user's global Claude Code settings (the file that registers the push-gate hook and holds the
    permission rules) are left empty. Any file the user can write is reachable the same way;
    `--output=../<name>` needs no home path and reaches the repo's parent directory. If the model
    drops `--follow`, git instead writes the last three commits' log into the target, where in
    `~/.bashrc` a commit-message line (indented four spaces) runs at the next shell start. A name
    such as `x$(<cmd>).py` runs `<cmd>` when pasted bare or inside double quotes, and one that also
    holds a single quote escapes single quotes; /codefix's syntax checks
    (claude/skills/codefix/SKILL.md:73-74) paste the changed file's name into a command the same
    way. Outside auto mode, both skills' `Bash(*)` grants run these unprompted.
  Evidence: this scan, git 2.34.1, a scratchpad file: `git log -p --follow -3 --output=<file>`
    printed "fatal: --follow requires exactly one pathspec", exited 128, and left the existing
    8-byte file at 0 bytes. The listing was read in bin/codereview-marker, not run on such a name:
    three probes that would have committed one in a scratch repo were refused by this host's
    auto-mode classifier, so git's acceptance of a leading-dash path was not run here either. Not
    run through the skill or a live model. Confidence: high on the git step, medium on the model
    pasting such a name as the template shows, low on likelihood (the name is visibly odd).
  Remediation: put the path after `--`, in single quotes, in the template (`git log -p --follow -3
    -- '<file>'`), and tell the scan to report, not paste, any in-scope path that starts with `-` or
    holds a quote, `$`, a backtick, `;`, `|`, `&`, `<`, `>`, or a newline: a committed name like
    that is a finding by itself. For a deterministic guard, have `codereview-marker surface`, which
    already refuses a ref that starts with `-`, refuse such paths with a message, so /codereview
    stops before any skill pastes one. Pin both in tests/lint-skills.sh.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-12 at 721b632

[NOTE] claude/skills/codefix/SKILL.md:42-45 — /codefix takes every BLOCK and WARN anywhere in
CODEREVIEW.md as its spec, including those under `## Prior review carried forward (uncommitted; not
current findings)`, a verbatim copy of what CODEREVIEW.md held when the review began, so a finding
there skips the filters /codereview applies to its own: Step 1's still-present check and Accepted
Risks downgrade, and Step 6's user-decision hold.
  Attack vector: a contributor's patch or branch includes a CODEREVIEW.md (the harness commits one
    with every review) holding a WARN whose suggested fix pins a CI action, a dependency, or a
    package index to something the contributor chose. The user brings it into the working tree
    without committing (`git apply`, `git merge --no-commit`, `git cherry-pick -n`, or a conflicted
    merge resolved but not yet committed) and runs /codereview, which reviews uncommitted work.
    Step 1 finds CODEREVIEW.md modified, so the preliminary entry Step 6.5 writes in Step 9's
    format (claude/skills/codereview/SKILL.md:607-608) carries the contributor's file verbatim under
    that heading (lines 705-711). When the run has a BLOCK or WARN of its own that is not held,
    Step 7 runs /codefix, which reads the planted WARN from the block and applies its fix; only a
    finding already marked `Requires a user decision; not for /codefix.` is skipped (line 44). The
    review diff excludes CODEREVIEW.md (codereview line 248), so no reviewer reads the planted
    text; the post-fix /security re-check and the re-review see only the change, and a pin reads as
    hardening. This is a second route beside the carried NOTE on out-of-diff fixes, which goes
    through Steps 1 and 6.
  Evidence: lines 42-45 extract from the whole file; codereview SKILL.md:213-219 apply Step 1's
    filters to "the most recent entry". The CODEREVIEW.md entry for 1d1b5da reports the same read
    as a staleness NOTE (claude-code). Traced through the skill text; not run against a live model.
    Confidence: medium on the mechanism (Step 6.5 says only "the same format as Step 9"), low on
    likelihood (someone else's CODEREVIEW.md must be in the uncommitted working tree when a review
    starts).
  Remediation: have /codefix read only the current entry, up to its `---` line, which also closes
    the staleness NOTE. Or have Step 6.5 leave the carried block out of the preliminary entry and
    add it in Step 9.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-12 at 721b632

[NOTE] claude/skills/security/SKILL.md:159-167 — a carried NOTE is cut to one sentence and its
Status line, and when its file returns to a scan's scope the re-check starts from that sentence:
nothing tells the scan to read the finding's last full text (the cases its evidence lists, its
attack vector, its remediation) from SECURITY.md's history before re-checking it or reporting it
resolved.
  Attack vector: no adversary. Some NOTEs are lists of concrete cases: the hook walker NOTE names
    about 40 push spellings the gate misses, and condensed it says only that the walker misses a
    push in some spellings that are not wrappers. When hooks/pre-push-codereview.sh next changes
    (the heredoc-aware rewrite, BACKLOG `push-gate-quoted-text-false-positive`), a path-scoped scan
    re-checks it. Working from the sentence, it may try the spellings it thinks of, find them
    refused, and report the NOTE resolved, or rewrite it with a shorter list; the spellings it did
    not try then appear in no current finding, and no later scan brings them back. Line 155 says
    git history holds earlier versions, but the re-check rule (lines 159-161) does not send the
    scan there.
  Evidence: lines 152-155 and 159-167. This scan applies the rule for the first time: the prior
    entry's 24 NOTEs, about 460 lines, are carried below in about 100, and their full text is in
    SECURITY.md at 8d5ff93. Confidence: medium on the mechanism (a max-effort scan may search the
    history unprompted), low that a real case is lost.
  Remediation: in the in-scope branch, have the scan first read a condensed finding's last full
    text (`git log -p -- SECURITY.md`, searching for its first line) and re-check each case it
    lists, reporting it resolved only when none still holds, and pin that sentence in
    tests/lint-skills.sh. Or carry NOTEs whole: the Status line already keeps a finding from
    growing with each scan.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-12 at 721b632

[NOTE] claude/skills/codereview/SKILL.md:115-126, 148, 175 — External-Only Mode pastes the range
into shell commands (inside double quotes in Step E.2, bare in Steps E.3 and E.4), and git accepts
`$(...)`, backticks, `;`, and `|` in branch names, so a branch name someone else chose can run a
command as the user.
  Status: found 2026-11-07 at 1d1b5da; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/pr/SKILL.md:185, 200-210 — the read that condition 4 gives for pulled PR
changes (`git log -p "${REVIEWED_UP_TO}..HEAD"` or `/codereview external "${REVIEWED_UP_TO}"`, also
at README.md:470-472 and 838) can be emptied by the pulled commits themselves, through a `-diff`
attribute or a moved `reviewed_up_to`; the fix is deferred with BACKLOG
`pr-merge-reviewed-changes-hash`.
  Status: found 2026-11-07 at 03aacf2; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/pr/SKILL.md:11, 159-176 — /pr status and inspect pass PR bodies, comments, and
review text, which anyone who can comment on the PR writes, into a fork whose `allowed-tools`
pre-approves `Bash(*)`, and the skill never says that text is data.
  Status: found 2026-11-07 at 03aacf2; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:213-219, 576-582 — since 500153c, a finding carried into a
review goes to /codefix with its suggested fix even when its file is outside the diff, and a
carried finding's text is repo content (CODEREVIEW.md's prior entry, or a SECURITY.md finding
/security carries without re-checking, claude/skills/security/SKILL.md:142-145), so a planted
finding can steer a fix outside the visible diff.
  Status: found 2026-11-07 at 895c3d3; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/pr/SKILL.md:232-240 — the `--match-head-commit` guard ahead of the merge
applies only when `gh pr merge --help` lists the flag, and this host's gh 2.4.0 (Ubuntu 22.04's
package) does not, so a commit pushed between the head check and `gh pr merge` merges unreviewed.
  Status: found 2026-11-07 at 895c3d3; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] bin/spec-backlog-apply.sh:64, 158-162 — the symlink guard checks only the last path
component, and the script resolves BACKLOG.md against the caller's working directory, so a run from
inside a tracked directory link creates and fills a BACKLOG.md outside the repo.
  Status: found 2026-11-07 at d12ce05; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:80-137, 255-258, 272-273 — past the bounds 82379d2 put on its
heredoc tracking (16 quoted markers, 256-character delimiter words, the 1,024-character fallback
cutoff), and after a few delimiter spellings or a comment line that ends in a backslash, a push that
bash runs reads as no push.
  Status: found 2026-11-03 at f564cd4; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:218-240, 247-277, 282-310, 330-398 — the walker misses a push in
some spellings that are not wrappers (quoted or escaped `git` and `push`, `coproc`, `timeout 1.5m`,
aliases, brace expansion, an escaped operator inside a word), and a statement can run before the
push inside a value the hook steps past.
  Status: found 2026-11-03 at 8e8dee7; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:487-525 — two spellings make the hook judge a repo other than
the one git pushes from: a layout whose config sets `core.worktree`, and `git -C - push`, where
`cd -P -- -` goes to $OLDPWD.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:94-152, 188-240, 295-310 — the hook's run time grows with the
square of the command's length in a few shapes (a long quoted word it steps over, a long run of
trailing backslashes, many quoted heredoc markers), so a long command can outlast the 30 s timeout
and then runs, since the gate entries set no `onFailure` (accepted risk).
  Status: found 2026-10-13 at 6c9741a; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:337, 461 — the walker treats only a token named `git`, or a
path ending in /git, as git, so `git.exe push` (which runs git in Git Bash) passes the gate, and
`gh` has the same gap; listed for a decision.
  Status: found 2026-10-13 at 6c9741a; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] hooks/pre-push-codereview.sh:845-848 — the skip marker is honored at any age and for any
diff, ahead of push_sends_commits_outside_head, so a marker left by a tag-only or terminal push lets
a later unreviewed agent push through; deferred to BACKLOG.md (skip-marker-bound-to-diff).
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at d12ce05; carried, not re-checked

[NOTE] claude/skills/spec/SKILL.md:8-9 — since 6f43afe made the frontmatter parse, /spec is an
inline, model-invocable skill whose `allowed-tools` grants `Bash(*)`, Write, and Edit for the rest
of the turn that invokes it.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] zat.env-install.sh:200, 213 — every settings.json write creates a new file at the process
umask and moves it into place (also lines 267, 276, 285, 307, 353, 370, 388), so a settings.json the
user restricted to 0600 comes back 0644 or 0664 on each run.
  Status: found 2026-10-13 at 0ccfae7; last checked 2026-11-07 at 895c3d3; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:248, 492 — the review diffs honor the repository's own
.gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as "Binary files
a/<f> and b/<f> differ", while the marker hash still binds its content (same in the external-mode
diffs at lines 148 and 175).
  Status: found 2026-10-13 at 6c9741a; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:481-485 — the secret-in-diff guard relies on a step that
reports secrets, and in a full-tier review no step looks for them in plain markdown, so a key added
to a markdown file goes to the external reviewers with the diff.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:426-430, 458-462 — the model extracts the commit field of
SECURITY.md's META footer and pastes it into a shell command, so codereview-marker's leading-dash
check (bin/codereview-marker:152) runs only after the shell has expanded it.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] bin/review-external.sh:276-278 — without bc, `_calc` splices the cost expression into awk
program text, and awk's `system()` runs commands, so a non-integer operand would execute as the
user; `_count` is the only guard.
  Status: found 2026-10-13 at 6c9741a; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] bin/codereview-marker:131-144 — the security surface keeps agent-instruction markdown only by
a fixed name list, so markdown that agents read as instructions under other names
(claude/references/*.md, a skill's references/, `@`-imported files) counts as plain documentation.
  Status: found 2026-10-02 at c03a14c; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] bin/review-external.sh:365 — the long-context price comparison is a bash arithmetic context,
which expands a command substitution hidden in an array subscript; `_count` (lines 284-286) makes
it safe, but no test covers this sink, and the Gemini comparison at line 471 is the same.
  Status: found 2026-10-01 at c6e5cab; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] bin/codereview-marker:104-109, 188 — marker_dir ignores mkdir and chmod failures and checks
neither the directory's owner nor whether it is a symlink, and `write` follows a symlinked marker
path; deferred to BACKLOG.md (marker-dir-ownership-check).
  Status: found 2026-10-02 at c03a14c; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] bin/codereview-marker:170-178 — the marker hashes only the net diff against the base, so a
secret committed and then deleted inside the pushed range ships in history without review; deferred
to BACKLOG.md (push-gate-net-diff-secret).
  Status: found 2026-10-02 at c03a14c; last checked 2026-10-13 at 6c9741a; carried, not re-checked

[NOTE] claude/skills/pr/SKILL.md:152 — the PR template puts free text derived from commit messages
inside double-quoted shell arguments, where backticks or `$(...)` run as commands under the skill's
`Bash(*)` grant.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-07 at 1d1b5da; carried, not re-checked

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294) send the
caller's unpushed commit subjects to api.openai.com and generativelanguage.googleapis.com.
  Status: found 2026-10-01 at 379af38; last checked 2026-10-02 at c03a14c; carried, not re-checked
```

No prior finding was re-checked or resolved: none of their files is in this scan's scope. The
Status lines for the 25 carried findings were built from SECURITY.md's history (the commit each
entry's META footer names, and each scan's `scanned_files`), since their text predates the
format. The settings.json umask NOTE's text dated it 2026-11-03; it was first listed at 0ccfae7.

### Coverage

All eight dimensions were reviewed for the four files at HEAD 721b632; the working tree matched HEAD
throughout.

- Read in full: claude/skills/security/SKILL.md (257 lines; it is this scan's prompt),
  claude/skills/codefix/SKILL.md (98), and CLAUDE.md (82). tests/lint-skills.sh (2,169) was read
  through its diff since 1d1b5da (lines 1109-1137), its helpers (lines 1-43), and its shellcheck and
  frontmatter sections (lines 2017-2079), with a grep of every write, exec, and interpreter call: it
  is a static checker that writes nothing, and it pipes each frontmatter block to a fixed `python3
  -c` program that calls `yaml.safe_load`. Each file's diff since the scan that last covered it was
  read: the security skill since c03a14c (c5bf5e6, 9787b0b), codefix since 895c3d3 (9787b0b), and
  CLAUDE.md and lint since 1d1b5da.
- Read outside the scope to trace the new NOTEs: claude/skills/codereview/SKILL.md Steps 1, 5, 6,
  6.5, 7, and 9, and bin/codereview-marker's surface listing (lines 128-160).
- Probes, with git 2.34.1, writing only to new scratchpad directories: `git log -p --follow -3
  --output=<file>` exited 128 and left an existing 8-byte file empty. Three more, which would have
  committed a file whose name holds `$(...)` or begins with a dash in a scratch repo, were refused
  by this host's auto-mode classifier and not run. Under the skill's new rule no suite ran, so
  lint-skills.sh was not run; the suites are /codereview's to run. No probe named a push, and no
  network call was made.
- Checked and not findings:
  - The new rules narrow what a fork executes: no project suites (9787b0b counts 62 of 162
    zat-hermes /security forks that ran one, executing repo code under `Bash(*)`), no subagents,
    and no background work. Both skills keep `Bash(*)` (security line 11, codefix line 9), so text
    in the code a scan reads could still steer a command, unprompted outside auto mode. That is the
    accepted allow-list risk's class, and the /spec grant NOTE's remediation (narrow the grant)
    would apply here too. This host runs defaultMode auto with classifyAllShell true (CLI 2.1.311).
  - The Status line and the new carry marker: no skill, hook, script, or test reads the old
    `(carried from ..., not re-checked)` text, and /codereview and /pr read only the META footer,
    whose counts are unchanged. A planted Status line can make a finding look older, which the
    accepted review-files risk covers.
  - The carried NOTE on out-of-diff fixes cites security SKILL.md:142-145 and codefix
    SKILL.md:40-44 as links in its chain. At HEAD they are security lines 162-167 and codefix lines
    42-45, and both links hold: a carried WARN keeps its full text, remediation included, and
    /codefix takes the suggested fix as its spec.
  - The new lint pins are fixed `grep -qE --` patterns with no metacharacters that change their
    meaning, and `hasnt` fails on a grep error. `python3 -c` puts the working directory on
    sys.path, so a `yaml.py` where lint runs would load; anyone who can put one in zat.env can edit
    lint itself.
  - CLAUDE.md's new text matches the two skills and the lint pins.
- Not verified: the model-mediated steps of the three new NOTEs, against a live model or this host's
  classifier; git's acceptance of a committed path that begins with a dash; Windows and macOS.

Git history checked for secrets: `git log -p --follow -3` for each of the four files (commits
9787b0b, c5bf5e6, b8746a8, 72dee81, 500153c, c33a94b, and 6f43afe), pattern-scanned for OpenAI,
Anthropic, Google, GitHub, GitLab, AWS, Slack, Hugging Face, npm, and Tailscale keys, private-key
headers, generic key, token, secret, and password assignments, and email addresses. No hits. None
of the four files handles credentials. PII: none in the four files.

Nothing left the machine, and no marker was written. zat.env's tree was not changed apart from this
file.

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
  host has the setting (verified 2026-10-01, 2026-10-13, 2026-11-03, and 2026-11-07), and so did the
  Windows host (verified 2026-10-13). The hook's `git diff` before approval (its own entry above) is
  not covered by this, because it runs ahead of the classifier.
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
*Prior review (2026-11-07, scope: paths, at 1d1b5da): the six files `codereview-marker surface
03aacf2` listed; 0 BLOCK / 1 WARN / 24 NOTE, no secrets. It resolved the External-Only leading-dash
NOTE (b8746a8's `--end-of-options`), added a NOTE that the same range still reaches the shell as
pasted text, and honored the operator's move of the /pr merge and review-files WARNs to Accepted
Risks.*

<!-- SECURITY_META: {"date":"2026-11-12","commit":"721b63214433918519a515129456221b51294e86","scope":"paths","scanned_files":["CLAUDE.md","claude/skills/codefix/SKILL.md","claude/skills/security/SKILL.md","tests/lint-skills.sh"],"block":0,"warn":1,"note":27} -->
