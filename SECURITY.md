## Security Review — 2026-11-13 (scope: paths)

**Summary:** Path-scoped scan, at HEAD 9702e80, of the four files `codereview-marker surface
9afc578` lists: CLAUDE.md, claude/global-claude.md, tests/lint-skills.sh, and zat.env-install.sh.
3bc1f1f adds a per-model effort seed, which changes no grant or gate. 9702e80 takes the 0.0.0.0
rule out of global-claude.md and has networking.md bind the Tailscale address, which resolves the
global-claude.md:108 WARN. One new WARN, older than both commits: every install rebuilt
`.permissions` and silently dropped the user's `ask` rules and bypass-mode lock, which narrow what
runs just as the deny entries it keeps do. Three new NOTEs: the new bind commands fall back to every
interface when `tailscale ip -4` prints nothing; global-claude.md:112 calls `.env` files ignored
when only files named exactly `.env` are; the installer replaces any existing `core.excludesfile`.
The installer umask NOTE still holds. No secrets. A first post-fix pass over tests/lint-skills.sh
and zat.env-install.sh found that /codefix's change kept `ask`, `disableBypassPermissionsMode`, and
`disableAutoMode`, but the rebuild still dropped `blockReadsOutsideWorkingDirectories`, which Claude
Code writes to user settings when the user blocks outside reads at auto mode's one-time prompt, and
2.1.317's `blockWritesOutsideWorkingDirectories`. A second post-fix pass, after /codefix added both
keys to the carried list, found the WARN resolved: the list now holds every narrowing `permissions`
key that Claude Code 2.1.311, 2.1.316, and 2.1.317 define. It added one NOTE: on an empty
settings.json every installer settings step writes nothing and still reports success, so the push
gate is never registered. The installer umask and excludesfile NOTEs still hold. Totals: 0 BLOCK /
0 WARN / 34 NOTE.

### Findings

```
[NOTE] claude/references/networking.md:13-14 — the bind commands that replaced the 0.0.0.0 rule,
which claude/global-claude.md:108 points to, put `$(tailscale ip -4)` directly in the bind argument,
and that command prints nothing when the Tailscale daemon is stopped or unreachable, so the service
binds every interface instead: `--host ""` for a server built on asyncio such as uvicorn, and
`-p ":PORT:PORT"` for Docker, whose published ports UFW does not filter.
  Attack vector: no adversary is needed to open the port. Tailscale is down when a service starts
    (after `tailscale down`, an expired node key, a reboot before tailscaled is up, or on a box not
    yet joined), and an agent or the user starts a dev UI or model server with the documented
    command. The substitution's error goes to stderr, the server starts on all interfaces, and the
    command reports success. A container started this way answers on the public address past UFW,
    and many such services have no authentication by default (Gradio, vLLM's OpenAI-compatible
    server). On this host a non-Docker server stays behind UFW (line 26 says it is active; its
    rules are root-only and were not read), and this account cannot run docker (it is not in the
    docker group, and sudo asks for a password), so the public case needs the user's own `sudo
    docker run`.
  Evidence: this scan: `tailscale --socket=<nonexistent> ip -4` (tailscale 1.104.6) exited 1 with
    empty stdout. /usr/lib/python3.10/asyncio/base_events.py:1474-1475 maps `host == ''` to every
    interface, and uvicorn 0.54.0 keeps `--host` as given (config.py:253) and passes it to
    `loop.create_server` (server.py:182-186), or binds it directly (config.py:603). Docker was not
    run, because this account cannot reach the daemon; go-connections' `ParsePortSpec`, which
    parses `-p`, rejects only a non-empty host that is not an IP. The form is the one this file's
    previous WARN proposed. Confidence: high on the empty substitution and uvicorn, medium on
    Docker, low on likelihood.
  Remediation: resolve the address once and stop when it is empty: `TS_IP=$(tailscale ip -4) && [
    -n "$TS_IP" ] && <server> --host "$TS_IP"`, and `-p "${TS_IP:?Tailscale is down}:PORT:PORT"` for
    Docker. Pin that form in tests/lint-skills.sh in place of the bare `tailscale ip -4` pin (line
    1632).
  Status: found 2026-11-13 at 9702e80; last checked 2026-11-13 at 9702e80

[NOTE] claude/global-claude.md:112 — the convention every session loads says "`.env` files are
globally gitignored", but the global excludes file the installer sets (zat.env-install.sh:76,
gitconfig/ignore-global:10) ignores only files named exactly `.env`, so `.env.local`,
`.env.production`, and similar names that frameworks use for secrets are not ignored.
  Attack vector: no adversary. An agent in a project whose own .gitignore does not cover the
    variant puts a key in `.env.local` or `.env.production`, relying on line 112, and a later `git
    add -A` commits it. A full-tier /codereview may flag it before a push (the file is in the
    security surface), but the key is already in local history, and a push made with
    `codereview-skip` does not wait for a review.
  Evidence: scratch repo at this scan under the global excludes file: `.env` and `app/.env` were
    ignored; `.env.local`, `.env.production`, and `secrets.env` were listed as untracked.
    Confidence: high on the mechanism, low on likelihood (framework templates such as
    create-next-app's ignore these names themselves).
  Remediation: say at line 112 that only files named `.env` are ignored globally and that variants
    need the project's .gitignore, or add `.env.*` with exceptions such as `!.env.example` to
    gitconfig/ignore-global.
  Status: found 2026-11-13 at 9702e80; last checked 2026-11-13 at 9702e80

[NOTE] zat.env-install.sh:76 — the installer sets `core.excludesfile` to the repo's ignore-global on
every run, replacing any global ignore file the user already had, with no message, so the patterns
that file held, secret patterns included, stop applying in every repository.
  Attack vector: no adversary. An adopter's existing global ignore covers credential files that
    ignore-global's four secret patterns (`.env`, `*.pem`, `*.key`, `*.secret`) do not, such as
    `.env.*`, `*.tfvars`, or `credentials.json`. After the install those files show as untracked
    in every repository without its own rule, and a `git add -A` stages them. The old file stays on
    disk, and nothing says it was disconnected; README.md:222 describes the new pointer, not the
    replacement.
  Evidence: line 76 runs `git config --global core.excludesfile` unconditionally. In a scratch global
    config (git 2.34.1, GIT_CONFIG_GLOBAL), a second `git config --global core.excludesfile` left
    only the second value. On this host the setting points at ignore-global. Confidence: high on
    the mechanism, low on likelihood (it needs a prior global ignore that names secret files).
  Remediation: when `git config --global core.excludesfile` already names a different file, leave
    it and print a warning that names both files, or point the setting at a user-owned file seeded
    from ignore-global with the old file's patterns appended (the seeded file a CODEREVIEW.md NOTE
    on gitconfig/ignore-global:24 proposed for another reason).
  Status: found 2026-11-13 at 9702e80; last checked 2026-11-13 at 9702e80

[NOTE] zat.env-install.sh:200, 218 — every settings.json write creates a new file at the process
umask and moves it into place (also lines 276, 285, 294, 316, 362, 379, 397), so a settings.json the
user restricted to 0600 comes back 0644 or 0664 on each run, and the directories the script creates
with `mkdir -p` (lines 86, 97, 117) take the same umask.
  Attack vector: settings.json can hold secrets in its `env` block, and its hooks run as the user.
    Where another account can traverse the home directory (macOS creates /Users/<name> as 0755),
    that account can read the file after a re-run. With umask 0002 and a primary group shared with
    other accounts, it can also edit the hooks, or replace entries in a group-writable ~/.claude or
    ~/bin, where ~/bin/codereview-marker is the script the push gate runs by name. Not reachable on
    this host: the home directory is 0750, and group peter has no other members. The installer
    itself writes no secret there.
  Evidence: no `umask` command in the script (lines 147 and 191 mention it only in comments);
    umask 0002 here; ~/.claude/settings.json at 0664; ~/.claude, ~/.claude/skills, and ~/bin at 0775
    (which run created them is not known); the home directory at 0750; group peter with no other
    members. Every write listed above, the permissions write at line 276 included, uses the same
    `jq ... > tmp && mv` pattern, and a 0600 file rewritten that way came back 0664 under umask 0002.
    Confidence: high on the mechanism, low on reachability.
  Remediation: `umask 077` at the top of the installer, so the files and directories it creates
    are owner-only, or restore the file's previous mode after each rewrite.
  Status: found 2026-10-13 at 0ccfae7; last checked 2026-11-13 at 9702e80

[NOTE] zat.env-install.sh:199-201, 218, 362-363 — the installer writes `{}` only when settings.json
is missing; on one that exists but is empty or holds only white space, every jq step exits 0 with
no output, so each step moves an empty file into place and prints its success line, "Added pre-push
hook (Bash, Monitor, and PowerShell)" included, and the run ends with no hook, permission, or
classifyAllShell entry written.
  Attack vector: no adversary. ~/.claude/settings.json is left empty (a `touch`, an editor saving an
    empty buffer) and the user runs the installer. Claude Code loads an empty settings file as `{}`
    with no error, so sessions run with no push gate, no deny entries, and no classifyAllShell. A
    push then reaches the user as an ordinary permission prompt, or the auto-mode classifier, with
    no /codereview or /security run first, while the install output said the gate was added. The
    run's only sign is a blank effort line ("effortLevel: , per model: , autoUpdatesChannel: ,");
    the session's is a prompt for commands the allow list would have covered.
  Evidence: this pass ran lines 195-398, extracted unedited, with CLAUDE_DIR set to a scratch
    directory: on a 0-byte settings.json the section exited 0, printed every success line, and left
    the file at 0 bytes; on `{}` it wrote `defaultMode: "auto"` and the three hook entries. jq 1.6
    exits 0 with no output on a 0-byte or white-space-only file. Claude Code 2.1.311 and 2.1.317
    return `{settings:{}, errors:[], loadState:"loaded"}` for a settings file whose text trims to
    empty. No source of an empty settings.json was traced, in the repo's docs or on this host.
    Confidence: high on the mechanism, low on likelihood.
  Remediation: before the first settings step, write `{}` when the file is missing or holds only
    white space, and stop with an error when `jq -e 'type == "object"'` fails on it; have each step
    fail the run when jq fails instead of printing its success line. Pin the guard in
    tests/lint-skills.sh.
  Status: found 2026-11-13 at 9702e80; last checked 2026-11-13 at 9702e80

[NOTE] claude/skills/security/SKILL.md:91-93 — the secret-history step has the model paste a file
name into `git log -p --follow -3 <file>`, with no `--` before it, and the names come from the
repository, so a committed path that begins with `--output=` makes git empty a file of the
committer's choosing, and a name holding `$(...)`, a backtick span, or a single quote runs a command
when pasted inside quotes.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/security/SKILL.md:67-68, 93 — the changes-only diffs and the secret-history
command read git's diff output, which honors the repository's own .gitattributes, so a text file
marked `-diff` or `binary` shows only as "Binary files a/<f> and b/<f> differ": a secret committed
and later removed in such a path never reaches the history check, and a changes-only scan cannot
see what changed in it.
  Status: found 2026-11-13 at 9afc578; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/security/SKILL.md:19, 63-76 — the scope argument is substituted into the
skill's own prompt, inside a backtick code span at line 19 and again at line 63, and /codereview
fills it with repository file names, so a committed name that holds a backtick puts the rest of its
text among the scan's instructions, and a file named `post-fix` or `changes-only` switches the
scan's mode.
  Status: found 2026-11-12 at e3b6b5f; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/security/SKILL.md:52-59, 185-205 — Step 1 reads SECURITY.md, CODEREVIEW.md,
and SPEC.md, and Step 5 writes SECURITY.md, by name, with no check that each is a regular file, so
a review file committed as a symlink points the scan's read, and any write that follows the link,
at a file outside the repository; bin/spec-backlog-apply.sh refuses exactly this for BACKLOG.md
(lines 60-62, 158-161).
  Status: found 2026-11-12 at e3b6b5f; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/security/SKILL.md:159-168 — a carried NOTE is cut to one sentence and its
Status line, and when its file returns to a scan's scope the re-check starts from that sentence:
nothing tells the scan to read the finding's last full text (the cases its evidence lists, its
attack vector, its remediation) from SECURITY.md's history before re-checking it or reporting it
resolved.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:115-126, 148, 175 — External-Only Mode pastes the range
into shell commands, inside double quotes in Step E.2 and bare in Steps E.3 and E.4, and git
accepts shell syntax in branch names, so a branch name someone else chose can run a command as the
user.
  Status: found 2026-11-07 at 1d1b5da; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:213-219, 576-582 — a finding carried into a review goes to
/codefix with its suggested fix even when its file is outside the diff, and a carried finding's
text is repository content: CODEREVIEW.md's prior entry, or a SECURITY.md finding that /security
carries without re-checking it (claude/skills/security/SKILL.md:163-168), so a planted finding can
steer a fix outside the visible diff.
  Status: found 2026-11-07 at 895c3d3; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:248, 492 — the review diffs honor the repository's own
.gitattributes, so a text file marked `-diff` or `binary` reaches every diff reader as "Binary
files a/<f> and b/<f> differ", while the marker hash still binds its content (the external-mode
diffs at lines 148 and 175 do the same).
  Status: found 2026-10-13 at 6c9741a; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:481-485 — the secret-in-diff guard relies on a step that
reports secrets, and in a full-tier review no step is told to look for them in plain markdown, so a
key added to a markdown file goes to the external reviewers with the diff.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codereview/SKILL.md:426-430, 458-462 — the model extracts the commit field of
SECURITY.md's META footer and pastes it into shell commands, so codereview-marker's leading-dash
check (bin/codereview-marker:152) runs only after the shell has expanded the value.
  Status: found 2026-10-02 at c03a14c; last checked 2026-11-13 at 9afc578; carried, not re-checked

[NOTE] claude/skills/codefix/SKILL.md:42-45 — /codefix takes every BLOCK and WARN anywhere in
CODEREVIEW.md as its spec, including those under `## Prior review carried forward (uncommitted; not
current findings)`, so a finding there skips the filters /codereview applies to its own.
  Status: found 2026-11-12 at 721b632; last checked 2026-11-12 at 721b632; carried, not re-checked

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

Resolved: the claude/global-claude.md:108 WARN. 9702e80 removed the bind rule from the file every
session loads (tests/lint-skills.sh:1630 pins its absence), and networking.md, which line 108 now
sends only sessions on the machine it describes to, binds services and Docker publishes to the
Tailscale address; the networking.md:13-14 NOTE above covers what is left. The installer umask NOTE
was re-checked and still holds. The ten NOTEs in the security and codereview skills, re-checked at
9afc578, are outside this scan's scope and are carried, condensed; the other 19 prior NOTEs are
carried with their Status lines unchanged. The zat.env-install.sh:233-276 WARN, found by this scan,
is resolved: the permissions step now carries `ask`, `disableBypassPermissionsMode`,
`disableAutoMode`, `blockReadsOutsideWorkingDirectories`, and `blockWritesOutsideWorkingDirectories`
over (line 275), and the second post-fix pass below confirmed it.

### Coverage

All eight dimensions were reviewed for the four files at HEAD 9702e80; the working tree matched
HEAD throughout.

- Read in full: claude/global-claude.md (112 lines), CLAUDE.md (82), and zat.env-install.sh (446).
  tests/lint-skills.sh (2,197) was read through its diff since 9afc578 (15 added lines at 1611-1617
  and 1626-1633, none removed), its helpers (lines 1-43), the effort and networking pins in context
  (1596-1640), the security guards (2005-2030), and the PyYAML section (2085-2125), with a grep of
  every exec, interpreter, write, network, and arithmetic context; its other lines were not read one
  by one. Each file's diff since its last scan was read: 3bc1f1f and 9702e80 since 9afc578; for
  global-claude.md only line 108 changed since its last scan at 6c9741a; for zat.env-install.sh
  only 3bc1f1f since 895c3d3.
- Read outside the scope to trace findings: claude/references/networking.md (28 lines; the change
  that resolves the WARN lives there, and `codereview-marker surface` left it out as plain markdown,
  the case the bin/codereview-marker:131-144 NOTE describes); gitconfig/ignore-global; README.md
  lines 222-224 and 681-687; hw-bootstrap.sh lines 195-204; the umask NOTE's full text in
  SECURITY.md at 3b69fbc, 03aacf2, and c09fc07, and the 2026-08-20 CODEREVIEW.md WARN that first
  reported the permissions replacement (97a15bb); /usr/lib/python3.10/asyncio/base_events.py lines
  1468-1480 and uvicorn 0.54.0's config.py and server.py in a local venv; ~/.claude/settings.json
  (a key summary only; it has no env keys); Claude Code 2.1.311's binary strings for the permission
  keys.
- Probes, writing only to a new scratchpad directory (sec-probe-1113b, left in place): the
  installer's permissions jq program (lines 232-271, extracted unedited) on a sample settings file,
  and the remediation's filter on the same sample; `tailscale --socket=<nonexistent> ip -4`; four
  `docker create -p` specs, each refused at the daemon socket before parsing, so they showed
  nothing; a scratch repo under the global excludes file with five env-file names; a scratch global
  config set twice through GIT_CONFIG_GLOBAL. No suite ran, no probe ran a push or touched the live
  settings, git config, Tailscale, or Docker state, and no network call was made.
- Checked and not findings:
  - 3bc1f1f's per-model seed changes effort, not a grant, a gate, or a trust decision. Its jq takes
    the model list as a constant through `--argjson`; a non-object `modelSettings` value makes that
    one step fail, which also skips the update-channel and thinking-summary seeds, none of them
    security settings.
  - Every settings step is `jq ... > tmp && mv`, and `set -e` does not stop on a failure left of
    `&&`, so a settings.json jq rejects (invalid JSON, a hook entry with no `hooks` array) leaves
    the gate registration and the permission steps unapplied while each still prints its success
    line. Not traced to a settings file Claude Code itself accepts; the closing Verify lines
    (445-446) show the result.
  - The reviewer credential directory and file are 700 and 600 here; the installer chmods both on
    every run (lines 149, 193), and lint pins both (2013-2016).
  - Live settings: `autoMode.classifyAllShell` is true; the gate is registered for `Bash|Monitor`
    and `PowerShell` with no `if` and no `onFailure` (accepted risk); the deny list holds the six
    managed entries.
  - A Tailscale-bound service is reachable from the two libvirt guests on this host's local
    bridges, which route through it (ip_forward 1, loose rp_filter), unless host rules stop them
    (root-only, not read). networking.md claims isolation from the public IP only, and a 0.0.0.0
    bind reached the guests too, so this is not a finding against the change.
  - CLAUDE.md holds no instruction that widens a grant or skips a gate; its two changed lines
    describe the effort seed. global-claude.md's other sections are unchanged since its last scan,
    and the Images section still names the decoder.
  - tests/lint-skills.sh is still a static checker (grep, awk, shellcheck, and a fixed `python3 -c`
    that calls `yaml.safe_load`); its numeric comparisons read `grep -c` and `grep -n` output.
- Not verified: how auto mode treats an `ask` rule; Docker's handling of an empty host IP; this
  host's firewall rules; Windows and macOS.

Git history checked for secrets: `git log -p --text --follow -3 --` for each of the four files
(CLAUDE.md: 3bc1f1f, 9afc578, e3b6b5f; global-claude.md: 9702e80, 6c9741a, 6f43afe; lint: 9702e80,
3bc1f1f, 9afc578; the installer: 3bc1f1f, 1608332, 4132078), plus the installer's full history (35
commits), since it writes the reviewer credential template, pattern-scanned for OpenAI, Anthropic,
Google, GitHub, GitLab, AWS, Slack, Hugging Face, npm, and Tailscale keys, private-key headers, and
generic key, token, secret, and password assignments. No hits beyond the template's commented
placeholders. None of the four files carries a `diff` or `binary` attribute. PII: none in the four
files (email, phone, and name patterns).

No marker was written. zat.env's tree was not changed apart from this file.

Post-fix pass (tests/lint-skills.sh and zat.env-install.sh, as /codefix left them in the working
tree on 9702e80): all eight dimensions were reviewed for the two files.

- Read: zat.env-install.sh in full (449 lines); tests/lint-skills.sh through its diff (two added
  lines, the pin at 2019-2020) with the `has` helper (lines 18-23) and the security-guard pins
  (2004-2030). Read outside the scope to trace the WARN: the README.md diff (line 224) and
  README.md:221-230; CLAUDE.md:9; Claude Code 2.1.311 and 2.1.317 binary strings for the
  permissions schema, the restrictive-key list, and the outside-read prompt; a key summary of
  ~/.claude/settings.json and the one `hasSeenAutoModeOutsideReadPrompt` field of ~/.claude.json.
- Probes, writing only to a new scratchpad directory (sec-probe-postfix, left in place): the HEAD
  and working-tree permissions jq programs, each extracted unedited, on ten sample settings files;
  the two remediation forms on the same samples; a 0600 file rewritten with `jq ... > tmp && mv`
  under umask 0002. No suite ran, and no probe touched the live settings, git config, or Claude
  Code state.
- Checked and not findings:
  - The carried object holds only `ask`, `disableBypassPermissionsMode`, and `disableAutoMode`, on
    the right of `+`, so the user's old block cannot override `defaultMode`, `allow`, or `deny`.
    Null values are dropped; an empty `ask` or a `false` is kept as the user wrote it.
  - A non-object `.permissions` (array, string, `false`) makes the step fail at HEAD and in the
    working tree alike (jq 1.6: "Cannot index array with "deny""), so the change adds no failure
    mode. The success line at 276 still prints when jq fails, the pattern the first pass recorded.
  - The new lint pin is a fixed `grep -E` pattern; it matches line 274 once and runs nothing.
  - Carrying `disableAutoMode` while the step sets `defaultMode: "auto"` keeps a choice the user
    made; Claude Code counts the key as restrictive.
- Not in this pass's scope: claude/references/networking.md also changed in this fix cycle, and its
  diff applies the networking.md:13-14 NOTE's remediation, but `codereview-marker surface` leaves it
  out as plain markdown (the case the bin/codereview-marker:131-144 NOTE describes), so that NOTE
  was not re-checked and stands as written.
- Not verified: what auto mode does with a read outside the working directories beyond the prompt
  text quoted in the WARN; which answer this host gave at that prompt.

Git history checked for secrets in this pass: HEAD is unchanged since the first pass; `git log -p
--text --follow -3 --` for both files (the installer: 3bc1f1f, 1608332, 4132078; lint: 9702e80,
3bc1f1f, 9afc578) and the uncommitted diff were pattern-scanned again, with no hits. Neither file
carries a `diff` or `binary` attribute. PII: none in the diff.

Second post-fix pass (tests/lint-skills.sh and zat.env-install.sh, as /codefix's second change left
them in the working tree on 9702e80): all eight dimensions were reviewed for the two files.

- Read: zat.env-install.sh in full (450 lines); tests/lint-skills.sh through its diff against HEAD
  (the pin at 2019-2020, which now names five keys) with its helpers (lines 1-43) and the
  security-guard pins (2004-2031). Read outside the scope to trace the fix: the README.md diff (line
  224), which names the same five keys; Claude Code 2.1.311, 2.1.316, and 2.1.317 binary strings
  for the `permissions` schema, the restrictive-key tables, and the settings-file loader.
- Probes, writing only to a new scratchpad directory (sec-probe-postfix2, left in place): the
  working-tree permissions jq program (lines 235-275, extracted unedited) on seven sample settings
  files; the installer's settings section (lines 195-398, extracted unedited) run with CLAUDE_DIR
  set to scratch directories holding a 0-byte settings.json and `{}`; `core.excludesfile` set twice
  in a scratch GIT_CONFIG_GLOBAL (git 2.34.1 kept only the second value); a 0600 file rewritten with
  `jq ... > tmp && mv` under umask 0002 (it came back 0664). No suite ran, and no probe touched the
  live settings, git config, or Claude Code state.
- Checked and not findings:
  - The carried list holds every narrowing `permissions` key in the restrictive-key tables of the
    three binaries on this host: `disableBypassPermissionsMode`, `disableAutoMode`, and
    `blockReadsOutsideWorkingDirectories` in 2.1.311, and those plus
    `blockWritesOutsideWorkingDirectories` in 2.1.316 and 2.1.317; `deny` is unioned and `ask`
    carried. In a sample with every key set, all five survived and `additionalDirectories`, which
    widens, was dropped, as were `blockReadsExemptPaths` and `workingDirectoriesAsGiven`, which
    2.1.317 reads only from `--settings`. A `false` block key is kept as written and does nothing,
    since `true` in any settings source wins; `null` values are dropped. The carried object names
    only those five keys and sits on the right of `+`, so it cannot override `defaultMode`, `allow`,
    or `deny`.
  - `defaultMode` is still set to `auto` on every run, replacing a `plan` or `dontAsk` the user
    chose, which Claude Code counts as narrowing. README.md:224 and line 277 name `defaultMode` as
    installer-set, so the replacement is stated.
  - The list is fixed, so a narrowing key a later Claude Code adds to `permissions` (the schema is
    `.passthrough()`) is dropped until the list and the lint pin name it, as
    `blockWritesOutsideWorkingDirectories` (added in 2.1.314) was. Not reported: no such key exists
    in the versions on this host.
  - The first pass's bullet on jq failures (each step still prints its success line) was not traced
    to a settings file Claude Code accepts. An empty file is one, though there jq succeeds with no
    output rather than failing (the new zat.env-install.sh:199-201 NOTE).
  - The lint pin is a fixed `grep -E` pattern that matches line 275 once and runs nothing.
- Not verified: whether Claude Code accepts a settings.json with comments or trailing commas, which
  jq 1.6 rejects (that would be a second such case); how Claude Code treats a carried block key of
  the wrong type.

Git history checked for secrets in the second post-fix pass: HEAD is unchanged since the first
pass; `git log -p --text --follow -3 --` for both files (the installer: 3bc1f1f, 1608332, 4132078;
lint: 9702e80, 3bc1f1f, 9afc578) and the uncommitted diff were pattern-scanned again, with
credential assignments matched case-insensitively, and had no hits. Neither file carries a `diff`
or `binary` attribute. PII: none in the diff.

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
- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:234-276`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)` each reach
  arbitrary execution. The deny entries are prefix matches and cannot enumerate every spelling.
  Accepted 2026-08-20 because README.md:224 and the script comment (lines 229-233) state plainly that
  the deny list is a speed bump. `autoMode.classifyAllShell` sends these commands through the
  classifier in auto mode, so the risk as accepted applies to the other permission modes. The Linux
  host has the setting (verified 2026-10-01, 2026-10-13, 2026-11-03, 2026-11-07, and 2026-11-13),
  and so did the Windows host (verified 2026-10-13). The hook's `git diff` before approval (its own
  entry above) is not covered by this, because it runs ahead of the classifier.
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
*Prior review (2026-11-13, scope: paths, at 9afc578): the four files `codereview-marker surface
e3b6b5f` listed (CLAUDE.md, the codereview and security skills, tests/lint-skills.sh); 0 BLOCK / 1
WARN / 30 NOTE, no secrets. It re-checked the nine NOTEs in the two skills, rewrote the five
/codereview NOTEs from their full text, and added one: the history and changes-only diffs honor a
`-diff` attribute.*

<!-- SECURITY_META: {"date":"2026-11-13","commit":"9702e800dcc03e18b01c93428cfce7c3ef86c198","scope":"paths","scanned_files":["CLAUDE.md","claude/global-claude.md","tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":0,"note":34} -->
