## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `bin/codereview-skip`, `tests/lint-skills.sh`, and
`tests/test-review-external.sh` in full at HEAD f541aa2: 0 BLOCK / 0 WARN / 3 NOTE. The
prior WARN (test-suite /tmp paths where another account could plant a binary) is fixed.
Two new NOTEs concern the skip marker: it can outlive the push it was created for, and its
write follows a symlink. Both were reproduced in scratch copies. The invalid-key NOTE
carries over unchanged and was re-verified. No secrets in the files or their history, and
no PII.

### Findings

```
[NOTE] bin/codereview-skip:4-6, 22 — the skip marker never expires and is not tied to a
diff, and a tag-only push leaves it in place, so a "push now" bypass can skip review of a
later, different push
  Attack vector: no adversary is needed. The user says "push now" and the agent runs
    codereview-skip. If the next push the hook sees is tag-only, the hook exits at
    hooks/pre-push-codereview.sh:201-203, before the skip check at lines 227-230, and the
    marker stays. The same happens when the push never reaches the Claude Code hook, for
    example when the user pushes from their own terminal after the agent created the
    marker (the hook is a PreToolUse hook, not a git hook). Later the agent pushes new
    commits that nobody reviewed. The hook finds the marker, deletes it, and exits 0.
    /codereview never runs, and nothing tells the user.
  Evidence: reproduced in a scratch repo with a private XDG_CACHE_HOME and synthetic hook
    input; nothing was pushed. After codereview-skip, `git push origin v1.0` returned 0 and
    left the marker. After a new commit, `git push` returned 0 and consumed it. The same
    push with no marker returned 2. A marker backdated 30 days was still honored, because
    the hook tests only `-f` (line 227). The header comment says the marker "is consumed by
    the hook on the next push attempt", which holds only for pushes that reach line 227.
    The accepted heuristic-detection risk covers is_git_push and is_tag_only_push, not the
    marker's lifetime. No marker was pending at scan time. Confidence: high on the
    mechanism, low on likelihood.
  Remediation: bind the bypass to the diff the user approved. Have codereview-skip write
    the output of `codereview-marker hash` into the marker, and have the hook honor the
    marker only when it matches the current hash, deleting it either way. A short age
    limit, such as `find "${SKIP_MARKER}" -mmin -15`, also works. Add a tag-then-code case
    to tests/test-pre-push-hook.sh.

[NOTE] bin/codereview-skip:18-22 — the comment says a plain touch is safe because
codereview-marker creates the marker directory at 0700, but nothing enforces that mode or
the directory's owner, and touch follows a symlink at the skip path
  Attack vector: requires XDG_CACHE_HOME to point into a directory another local account
    can write. The XDG spec treats that directory as user-specific, but nothing here checks
    it. That account creates `claude-codereview` there, owned by itself with mode 0777, and
    plants `skip-<hash>` as a symlink. The hash is the first 8 hex digits of the md5 of the
    repo path, so it is predictable. The user's `chmod 700` then fails, and
    codereview-skip's touch creates the symlink's target with the user's rights. The
    account can also plant skip markers to bypass the gate. The push marker lives in the
    same directory, and `codereview-marker write` (bin/codereview-marker:117, out of scope)
    would truncate and overwrite a planted symlink's target.
  Evidence: marker_dir (bin/codereview-marker:73-78) runs inside a command substitution,
    where bash clears errexit, so a failed chmod is ignored and the path is still printed.
    In a scratch run with chmod made to fail, `codereview-marker skip-path` exited 0, the
    directory stayed 0775, and codereview-skip created the marker in it. With a symlink
    planted at skip-<hash>, codereview-skip created the symlink's target. A noclobber write
    (`set -C; : >`) refused the same symlink. Not exposed on this host: XDG_CACHE_HOME is
    unset, and ~/.cache and ~/.cache/claude-codereview are 0700 and owned by the user.
    Confidence: high on the mechanism, low on exposure.
  Remediation: in marker_dir, exit 1 unless the path is a real directory owned by the user
    after the chmod (`[[ -d "${d}" && ! -L "${d}" && -O "${d}" ]]`). In codereview-skip,
    create the marker without following a symlink:
    `( set -C; : > "${SKIP_PATH}" ) 2>/dev/null || [[ -f "${SKIP_PATH}" && ! -L "${SKIP_PATH}" ]]`.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294)
send the caller's unpushed commit subjects to api.openai.com and
generativelanguage.googleapis.com (carried forward from the 379af38 scan; the lines are
unchanged)
  Attack vector: no adversary is involved. This data leaves the machine without the
    user's opt-in. Everywhere else, sending data to these providers requires configuring a
    key. The script builds its COMMITS block from `git log @{upstream}..HEAD` in the
    caller's working directory (bin/review-external.sh:208-215, 256-258), and
    tests/run-all.sh runs the suite from wherever it was started, normally the repo root.
  Evidence: re-verified at f541aa2 with a curl stub that recorded request bodies, run from
    the repo root. The line-112 request to OpenAI and both line-287 requests (OpenAI and
    Google) each carried "=== COMMITS ===" with the four unpushed subjects (dd22b6d to
    f541aa2). Each body was about 2 KB. That the body crosses the wire before the 401 is
    inferred, not observed: this host's curl 7.81.0 supports HTTP/2, and curl does not hold
    a body behind Expect: 100-continue on HTTP/2. The test at lines 336-365 runs from a
    non-git directory and sends only the dummy diff. Impact is low for zat.env, whose
    subjects reach GitHub on push anyway. A fork with private history would send more.
    Confidence: high on the mechanism, low on impact.
  Remediation: run these tests against the suite's fake curl (lines 753-782) with
    FAKE_CODE=401, which also removes their network dependency. Running them from
    ${TEST_DIR} is an alternative.
```

### Coverage

All eight dimensions were reviewed. Every line of the three files was read:
bin/codereview-skip (22 lines), tests/lint-skills.sh (1698), and
tests/test-review-external.sh (903). Read for context only: bin/codereview-marker,
hooks/pre-push-codereview.sh, the curl and COMMITS code in bin/review-external.sh, and
Step 5.6 of claude/skills/codereview/SKILL.md.

- Prior findings on these files:
  - The WARN at tests/test-review-external.sh:145-146 (and 209) is fixed in 20a4c6c. Both
    nonexistent local-reviewer paths now sit under the suite's TEST_DIR, which `mktemp -d`
    creates at 0700. Neither test file has a fixed /tmp path or a `$$`-derived path left.
  - The invalid-key NOTE is still open (above).
- Changes since 379af38: the codereview-skip usage comment, four lint changes (the spec
  no-confirmation guard, the `--disallowedTools` pin, the tree-change exclusion pin, and
  the tester relabels), and the test-path fix.
  - The new usage comment says the hook checks the whole command line, so
    `codereview-skip && git push` is blocked. This session matched it. The live hook,
    registered with `"if": "Bash(git push*)"`, blocked a compound test command whose first
    word was not git and which contained a scratch `git push`, before any of it ran.
  - codereview-skip is not in the permission allow list. On this host (defaultMode auto,
    classifyAllShell true), the classifier sees it.
- lint-skills.sh is a static checker. Its patterns are hard-coded. It evaluates nothing,
  sources nothing, writes no files of its own, and makes no network calls. The line
  numbers it passes to sed and to `[[ -lt ]]` come from `grep -n` and `grep -c`, so they
  are always numeric and cannot carry an arithmetic-expansion payload. shellcheck runs
  statically.
- test-review-external.sh: every temp path comes from mktemp. The fake curl and the fake
  venvs live in private directories, and the fake curl reads only the suite's own files.
- Guard coverage. Lint passes at HEAD (438 checks, run on a scratch copy).
  - Removing or narrowing `--disallowedTools` fails the line-930 check. Reverting the
    collect reading to `{ git status --porcelain; git diff; }` fails lines 944-950.
  - A second, unrestricted `claude -p "/code-review high"` launch added beside the pinned
    line passes lint. The pin checks that the restricted line exists, not that every
    launch carries the restriction.
  - As in the prior scan, CLAUDE.md says lint keeps `/tmp/.claude-codereview-` and
    `md5sum | cut -c1-8` out of the codereview SKILL.md, but lines 471-482 check only the
    hook and codereview-skip. Low impact.
- Out of scope, for the next scan that covers claude/skills/codereview/SKILL.md. The
  built-in child at line 473 loses only Edit, Write, and NotebookEdit, and keeps Bash. The
  tree-change hash (lines 466 and 491) cannot see:
  - the four excluded review files
  - gitignored paths
  - `.git/` (config, hooks)
  - paths outside the repo

  The child's tool calls run in the background and never appear in the user's transcript.
  If the reviewed diff carries prompt injection, the auto-mode classifier is the remaining
  check. A read-only launch mode would close the gap. Whether /code-review works in one
  was not checked.
- Not verified:
  - That the invalid-key request bodies cross the wire before the 401. A local listener
    test was not permitted.
  - Test suite results. The suites were not run in this scan because an offline run with
    curl stubbed was not permitted. The relocated test paths were checked by reading.
  - Whether Claude Code runs PreToolUse hooks before the auto-mode classifier. If the
    classifier can deny a push first, a denied push also leaves the skip marker
    unconsumed.

Git history checked for secrets: bin/codereview-skip (3 commits), tests/lint-skills.sh
(51), and tests/test-review-external.sh (10). Each was checked over its last three commits
(`git log -p --follow -3`) and over its full history (`git log -p --all --follow`). The
patterns covered OpenAI, Anthropic, Google, Tailscale, GitHub, Slack, and AWS keys, plus
private-key headers, and there were zero hits. The only key values ever added to the test
suite are the fakes `sk-invalid-test-key`, `sk-test-key`, and `fake-google-key`, and empty
values.

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
  tagging loops at lines 366-372, 469-475, and 530-536): a model steered by
  attacker-authored code under review can emit a correctly tagged finding line that
  /codefix consumes as a spec. The own-tag demux added in 379af38 closes the status
  channel only. It does not limit what a model writes on its own stdout.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted. The files in this review's scope contain none.
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
  is intentionally simple and biased toward over-detection.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): when
  configured, the full git diff goes to OpenAI and Google, so any secrets in the diff
  would be exposed. Sending the diff is the script's explicit purpose, and the user opts
  in by configuring keys.
- **API key in `curl -H` header argument** (`bin/review-external.sh:314, 416`): the
  header argument is visible in `/proc/<pid>/cmdline` to any local user while curl runs.
  Not exploitable on this single-user dev box. Host update, 2026-10-01: of the three
  service accounts, cloudflared-daydream (ProtectProc=default) can read these cmdlines.
  The other two cannot (ProtectProc=invisible). The exposure stays inert while no reviewer
  keys are configured, which was the case on 2026-10-01. If keys are added, passing the
  header as `-H @<file>` keeps it out of argv.

---
*Prior review (2026-10-01, scope: paths, at 379af38): Reviewed bin/review-external.sh,
tests/lint-skills.sh, tests/test-review-external.sh, and zat.env-install.sh. 0 BLOCK / 1
WARN / 2 NOTE. 20a4c6c fixed the WARN (test-suite /tmp paths where another account could
plant a binary the suite would run), confirmed here. The invalid-key NOTE is carried above.
Also still open: the NOTE that zat.env-install.sh:170 rewrites settings.json at the
process umask. That file is unchanged and outside this scope. That scan confirmed four
earlier NOTEs fixed. Three older items also remain open, all in files unchanged since and
outside this scope: the venv hook's exact-string "auto" guard
(hooks/allow-venv-source.sh:12-14), ImageMagick's stock coder policy (hw-bootstrap.sh:48),
and Docker group membership as a passwordless path to root (hw-bootstrap.sh:197).*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"f541aa22b84cecc771deffb3665117af997d7dd3","scope":"paths","scanned_files":["bin/codereview-skip","tests/lint-skills.sh","tests/test-review-external.sh"],"block":0,"warn":0,"note":3} -->
