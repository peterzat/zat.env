## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `tests/lint-skills.sh`,
`tests/test-review-external.sh`, and `zat.env-install.sh` in full at HEAD 379af38. Since
the 4fa79f5 scan, 3f6772a repaired the lint helpers and 379af38 hardened
review-external.sh. 0 BLOCK / 1 WARN / 2 NOTE. The WARN predates both commits and was
reproduced: a test points the local-reviewer paths at predictable /tmp names, and the
script executes a binary planted at one of them. The four prior NOTEs on these files are
resolved. Mutation and sample runs confirmed each fix. No secrets in the files or their
history, and no PII.

### Findings

```
[WARN] tests/test-review-external.sh:145-146 — the "script set but file does not exist"
test points LOCAL_REVIEW_SCRIPT and LOCAL_REVIEW_VENV at fixed names in the shared /tmp,
and review-external.sh runs `${LOCAL_REVIEW_VENV}/bin/python3` whenever the script path
exists
  Attack vector: The attacker is another local account that can write the shared /tmp.
    /proc is mounted without hidepid, so it can read the PID of
    `bash tests/test-review-external.sh` there. It creates
    /tmp/nonexistent-review-script-<pid>.py and an executable
    /tmp/nonexistent-venv-<pid>/bin/python3 before the test reaches line 150. The window
    is wide, because line 118 first makes a real network call. The test's env file then
    passes the HAS_LOCAL gate (bin/review-external.sh:131-133). call_local runs the
    planted binary as whoever runs the suite (bin/review-external.sh:483-496), with that
    user's full access. tests/run-all.sh runs it on every /codereview and after each
    /codefix pass.
  Evidence: the heredoc at line 144 is unquoted, so `$$` becomes the test shell's PID.
    The suite never creates either path. It only stats and executes them, so the
    protected_regular and protected_symlinks sysctls do not apply. In the accepted
    /tmp/cuda-keyring.deb case, protected_regular can at least refuse curl's O_CREAT open.
    Reproduced on a copy of the suite, with a scratch directory standing in for /tmp and
    curl stubbed so nothing reached the network. The two files were planted after launch,
    using only the PID. The suite then ran the planted python3 as uid 1000, passing it the
    script's --system and --input files, and reported one failure after the code had run.
    Lines 208-210 reuse the script path. They become exploitable if LOCAL_REVIEW_VENV is
    inherited from the caller's environment (line 26 unsets only the two API keys). In
    that case only the .py file needs planting, and the real venv's python runs it.
    Confidence: high on the mechanism. Low that this host has such an account today. The
    three non-system service accounts (cloudflared-daydream, daydream-egress, daydream)
    run with PrivateTmp=yes and cannot write the shared /tmp. Other local accounts were
    not checked.
  Remediation: move both paths under the suite's private TEST_DIR (mktemp -d, mode 0700).
    Set `LOCAL_REVIEW_SCRIPT=${TEST_DIR}/nonexistent-review-script.py` and
    `LOCAL_REVIEW_VENV=${TEST_DIR}/nonexistent-venv` at lines 145-146, and use the same
    script path at line 209.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294)
send the caller's unpushed commit subjects to api.openai.com and
generativelanguage.googleapis.com
  Attack vector: no adversary is involved. This data leaves the machine without the
    user's opt-in. Everywhere else, sending data to these providers requires configuring
    a key. The script builds its COMMITS block from `git log @{upstream}..HEAD` in the
    caller's working directory (bin/review-external.sh:211-215, 255-263). These tests run
    from wherever tests/run-all.sh was started, normally the repo root. The provider
    receives the request body over TLS before it rejects the fake key.
  Evidence: the line-112 test's input and env file were run from the repo root against a
    capturing curl stub. The captured user message held "=== COMMITS ===" and all six
    unpushed subjects (4fa79f5 to 379af38). The test at lines 336-365 runs from a non-git
    directory and sends only the dummy diff. Impact is low for zat.env, whose subjects go
    to GitHub on push anyway. A fork with private history would send more. Confidence:
    high on the mechanism, low on impact.
  Remediation: run these tests against the fake curl at lines 753-782 with FAKE_CODE=401,
    which also removes their network dependency. Running them from ${TEST_DIR} is an
    alternative. With curl stubbed to fail, a copy of the suite passed every
    network-dependent check.

[NOTE] zat.env-install.sh:170 — settings.json is rewritten through a `.tmp` file that the
shell creates at the process umask and then renames over the original (same pattern at
lines 224, 233, 249, 271, 288, 306), so a settings.json restricted to 0600 comes back
0664 (umask 0002) or 0644 (umask 0022) after every install run
  Attack vector: Claude Code's settings.json can hold secrets in its `env` key. Suppose a
    user stores a token there and restricts the file. The next install run widens the
    mode, and any local account that can traverse the home directory can then read the
    file.
  Evidence: on a scratch file set to 0600, the line-170 pattern left it at 0664 under this
    host's umask 0002. Inert on this host: the live settings.json has no `env` key, and
    /home/peter is 0750. The reviewer key file is not affected. Line 111 sets its directory
    to 0700 before line 114 creates the file, and line 155 sets the file to 0600. The
    carried-forward NOTE about that file's creation instant therefore had no exposure.
    Confidence: high on the mechanism, low on impact.
  Remediation: set `umask 077` after `set -euo pipefail`, or copy the original file's mode
    onto the `.tmp` file before each mv.
```

### Coverage

All eight dimensions were reviewed. Every line of all four files was read:
bin/review-external.sh (592 lines), tests/lint-skills.sh (1681), tests/test-review-external.sh
(903), and zat.env-install.sh (347).

- Prior NOTEs, all resolved:
  - Token counts reaching bc. `_count` (bin/review-external.sh:277-279) accepts digits
    only, and the test at lines 845-854 covers a hostile count.
  - Tagged status lines promoted to findings. Each provider's stdout and stderr now go to
    separate files, and `demux` (lines 575-592) promotes only stdout lines that carry
    that provider's own tag.
  - A partial OpenAI key in error text. `_redact` (lines 284-286) masks key-shaped text
    in both providers' error messages. Sample runs masked an OpenAI 401 message, an
    `sk-svcacct-` key, and Google's `api_key:AIza...` suspension text.
  - The always-passing lint guards. `hasnt` now fails on a grep error (lint lines 26-37),
    and line 180 caught a mutant that added Write to codefix's allowed-tools.
  - Lint passes at HEAD (436 checks, no grep errors).
- Input handling in review-external.sh. Every JSON request body is built with
  `jq --arg/--rawfile`. Both provider URLs have a fixed host, curl does not follow
  redirects, and the Gemini key travels in a header. A `--range` value that begins with
  `-` is rejected (line 101). `--check` prints model names, never keys. Two observations,
  neither a finding:
  - `set -a` (line 120) exports the API keys to every child process. Only processes
    running as the same user can read another process's environment.
  - CLAUDE_REVIEWER_ENV (line 118) can redirect the config path, but only someone who
    already controls the caller's environment can set it.
- Guard coverage:
  - A mutant that sends provider stderr to stdout inside `demux` passes lint. The
    behavioral demux test (tests/test-review-external.sh:868-894) catches it; a replica
    run against the mutant showed it.
  - A mutant that accepts any provider tag fails lint line 1629.
  - `_count` and `_redact` have no lint pins, only the behavioral tests at lines 845-864.
  - The `--range` leading-dash rejection still has no behavioral test. The text pin at lint
    line 1617 is its only guard.
  - CLAUDE.md says lint keeps `/tmp/.claude-codereview-` and `md5sum | cut -c1-8` out of
    the codereview SKILL.md, but lint lines 471-482 check only the hook and
    codereview-skip. As before, this has low impact.
- Host observation, updating the 4fa79f5 scan. All three service accounts run with
  PrivateTmp=yes, ProtectHome=yes, ProtectSystem=strict, and NoNewPrivileges=yes, so none
  of them can reach the shared /tmp or /home. daydream-egress and daydream-prod also set
  ProtectProc=invisible. cloudflared-daydream uses ProtectProc=default and can read every
  process's cmdline. See the curl-header entry under Accepted Risks. No external reviewer
  keys are configured (`review-external.sh --check` exits 1).
- Not verified:
  - The runtime values of the protected_* sysctls (permission denied in the sandbox).
  - Which other local login accounts exist (enumeration was not permitted).
  - tests/test-review-external.sh was not run against the real network. A copy with curl
    stubbed passed 73 of 74 checks. The one failure was the planted-file demonstration.
- Out of scope: claude/skills/codereview/SKILL.md, which consumes the script's stdout and
  stderr, and the README and CLAUDE.md changes in 6645cd1.

Git history checked for secrets: bin/review-external.sh (10 commits), zat.env-install.sh
(31), tests/test-review-external.sh (9), and tests/lint-skills.sh (55). Each was checked
over its last three commits (`git log -p --follow -3`) and over its full history
(`git log -p --all --follow`). The patterns covered OpenAI, Anthropic, Google, Tailscale,
GitHub, Slack, and AWS keys, plus private-key headers, and there were zero hits. The only
key assignments in history are template placeholders and the fake test keys.

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
*Prior review (2026-10-01, scope: paths, at 4fa79f5): Reviewed `tests/lint-skills.sh`
only. 0 BLOCK / 0 WARN / 1 NOTE: two codefix role-separation guards always passed, and no
check enforced that codefix lacks Write. 3f6772a resolved it, and this scan confirmed the
fix by mutation. That entry also carried open items from earlier scans. 379af38 resolved
the three review-external.sh NOTEs among them, confirmed here. Three remain open because
their files are unchanged and outside this scope. The venv hook's auto-mode guard matches
only the exact string "auto" (hooks/allow-venv-source.sh:12-14). ImageMagick's stock
coder policy reaches the SVG coder from `.png`-named input (hw-bootstrap.sh:48). Docker
group membership is a passwordless path to root (hw-bootstrap.sh:197).*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"379af38866fbe40483c7180c8e26ed643247a45b","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/test-review-external.sh","zat.env-install.sh"],"block":0,"warn":1,"note":2} -->
