## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `tests/lint-skills.sh`, and
`tests/test-review-external.sh` in full at HEAD 2f556b0: 0 BLOCK / 0 WARN / 3 NOTE, no
secrets in the files or their history, and no PII. The 5a1a7aa change, which hands both API
keys to curl through a file descriptor, held up under an execve trace and a concurrent scan
of every process command line, so the curl `-H` Accepted Risk is retired. The three NOTEs
carry over from the c6e5cab scan, re-verified at HEAD.

### Findings

```
[NOTE] bin/review-external.sh:357 — the long-context price comparison is a bash arithmetic
context, which expands a command substitution hidden in an array subscript. `_count`
(lines 278-280) makes it safe, but no test covers this sink, so a reordering would let a
provider response run commands. The Gemini comparison at line 463 is the same. Carried from
the c6e5cab scan; the code is unchanged and moved down three lines.
  Attack vector: none at HEAD. The value comes from the provider's `usage` block, which
    the script already treats as untrusted (that is why `_count` exists). If a later edit
    compares the raw jq output instead of the filtered variable, a response carrying
    "input_tokens":"PATH[$(cmd)]" runs cmd as the user. Only the provider, or someone who
    can tamper with its TLS connection, controls that field. Injected text in the diff
    cannot.
  Evidence: re-verified at 2f556b0 on a scratch clone with a stub curl. The unmodified
    script turned the payload into 0 and ran nothing. A mutant that changed only line 357
    to compare the raw jq value ran the payload (it created a marker file), and the suite
    still passed 78 of 78, including the hostile-value test at
    tests/test-review-external.sh:883-892, whose "1; while (1) { }" value targets bc. The
    `_count` comment (lines 276-277) still names bc as the only sink, and no test sends a
    hostile Gemini count. Confidence: high on the mechanism.
  Remediation: name the comparisons in the `_count` comment. Change the hostile-value test
    to a command-substitution payload, such as "PATH[$(: > ${TEST_DIR}/ran)]", and assert
    that the file does not exist. Add the same case for promptTokenCount.

[NOTE] bin/review-external.sh:372-378, 581-595 — provider text is printed with its control
characters intact, so a model steered by the code under review can put terminal escape
sequences into a finding line. The Google and local loops (lines 475-481 and 536-542) do
the same. Carried from the c6e5cab scan; the code is unchanged.
  Attack vector: the author of a diff under review embeds instructions aimed at the
    external model. This is the prompt-injection path that the accepted "third-party model
    findings" risk already assumes. The model returns a line that starts with [BLOCK],
    [WARN], or [NOTE] and carries ESC, CR, or BEL as JSON escapes. `jq -r` decodes them to
    raw bytes (lines 340 and 443-447). The tagging loop keeps the line because it checks
    only the prefix (line 373), and demux forwards it to stdout (line 588). A user who runs
    the script in a terminal, as the usage header shows (lines 9-10), gets the sequences
    interpreted. CR plus erase-line rewrites what the finding appears to say, OSC
    sequences set the window title, and a terminal that accepts OSC 52 clipboard writes
    from applications lets the line replace the clipboard. The accepted risk covers what
    the agent does with a finding. It does not cover hiding a finding's text from a human
    or driving the human's terminal.
  Evidence: re-verified at 2f556b0 against a stub curl. The finding text
    "[BLOCK] evil.py:1 -- real finding\r\e[2K[NOTE] evil.py:1 -- cosmetic only\e]0;title\a"
    came out on stdout tagged "(openai)", with raw CR, ESC [2K, and ESC ]0;title BEL bytes
    (checked with od -c). A terminal would show only the NOTE text. Not verified: that
    OpenAI or Gemini models emit raw control characters when steered, how Claude Code's
    transcript renders such bytes when /codereview runs the script, and the user's
    terminal settings. tmux's default `set-clipboard external` does not accept OSC 52 from
    applications. The provider error text at lines 335 and 438 passes control characters
    the same way, but only the provider controls it. Confidence: high on the mechanism,
    low on exploitability.
  Remediation: in demux, strip C0 control characters other than tab and newline, and DEL,
    from both files before classifying lines (`LC_ALL=C tr -d '\000-\010\013-\037\177'` on
    "${out}" and "${err}"). Add a fake-curl test whose finding carries \u001b and \r, and
    assert that neither byte reaches stdout.

[NOTE] tests/test-review-external.sh:112-118 — the invalid-key tests (also lines 287-294)
send the caller's unpushed commit subjects to api.openai.com and
generativelanguage.googleapis.com (carried forward from the 379af38 scan; the lines are
unchanged)
  Attack vector: no adversary is involved. This data leaves the machine without the
    user's opt-in. Everywhere else, sending data to these providers requires configuring a
    key. The script builds its COMMITS block from `git log @{upstream}..HEAD` in the
    caller's working directory (bin/review-external.sh:208-216, 255-263), and
    tests/run-all.sh runs the suite from wherever it was started, normally the repo root.
  Evidence: re-verified at 2f556b0 without sending anything. The suite ran from the repo
    root with a recording stub ahead of curl on PATH. Three requests carried
    "=== COMMITS ===" with the two unpushed subjects (5a1a7aa and 2f556b0): two to
    api.openai.com (the tests at lines 112 and 287) and one to
    generativelanguage.googleapis.com (line 287). The test at lines 336-365 runs from a
    non-git directory and sent no COMMITS block. With curl stubbed, the suite passed 78 of
    78. Impact is low for zat.env, whose subjects reach GitHub on push anyway. A fork with
    private history would send more. Confidence: high on the mechanism, low on impact.
  Remediation: run these tests against the suite's fake curl (lines 753-784) with
    FAKE_CODE=401, which also removes their network dependency. Running them from
    ${TEST_DIR} is an alternative.
```

### Coverage

All eight dimensions were reviewed. Every line of the three files was read at HEAD
2f556b0: bin/review-external.sh (598 lines), tests/lint-skills.sh (1725), and
tests/test-review-external.sh (941). Read for context only: the 5a1a7aa and 2f556b0 diffs
(including their CLAUDE.md, tests/README.md, and README.md text), the review-external.sh
call sites in claude/skills/codereview/SKILL.md (lines 86, 162, and 439), and the c6e5cab
entry of this file.

- 5a1a7aa passes each key as `-H @<(printf ...)` (bin/review-external.sh:318 and 422).
  Every check below ran locally with sentinel or fake keys:
  - An strace of every execve in a run with a stub curl: both curl execs carried
    `@/dev/fd/63` and nothing key-shaped, and no printf binary was executed. printf is the
    bash builtin, so the process-substitution subshell never execs with the key in its
    arguments. The only argv matches for the sentinel were the instrumentation's own grep.
  - A concurrent scanner read every /proc/*/cmdline 4,953 times over 7 seconds, covering
    both 3-second stub calls, with zero hits. /proc is mounted rw,relatime (no hidepid),
    so this is the view every local account has.
  - The real curl 7.81, sent to a listener bound to 127.0.0.1, delivered the header once
    from the descriptor. It stripped a trailing CR (a CRLF .env). When the header file
    could not be opened, it sent the request without the header (`-s` mutes the warning),
    which yields a 401 and the script's API-error line. That failure is safe.
  - Mutations on a scratch clone: reverting to the argv form failed both new behavioral
    tests and all three new lint checks. An external /usr/bin/printf inside the
    substitution passed the behavioral tests and failed the two lint `has` checks. The
    Google key moved into the URL query passed lint and failed the behavioral test. The
    two guards complement each other. Neither covers a key handed to some other exec'd
    helper, such as `jq --arg`, because the tests read only curl's arguments. No such site
    exists.
  - Not a finding: `set -a` around the `source` (lines 119-124) exports both keys, so every
    child (curl, jq, sed, the local reviewer) carries both in its environment. A run found
    them in the environment of jq, the stub curl, and the stub's own child.
    /proc/<pid>/environ is mode 0400 and access-checked by the kernel (from this account,
    root's PID 1 shows a readable cmdline and a denied environ). A same-uid reader can
    already read the 0600 .env, so the environment adds no exposure. `export -n
    OPENAI_API_KEY GEMINI_API_KEY` after loading would narrow it if a confined same-uid
    reader ever matters.
  - Not a finding: under `bash -x`, the trace prints the key in four places for one
    provider (the sourced assignment, the -n test, the local assignment, and the printf),
    as it printed the old `-H` argument. An agent debugging the script that way would copy
    the key into its transcript.
  - No other code site in the repo puts a reviewer key on a command line.
    zat.env-install.sh has only commented template lines, and /codereview pipes the diff
    to the script with no key arguments.
- Guard coverage, unchanged from the prior scans:
  - `_count` and `_redact` have no lint pins. Their only tests are the behavioral ones at
    tests/test-review-external.sh:883-902, and the first of those does not cover the
    comparison sink (first NOTE).
  - The `--range` leading-dash rejection has no behavioral test. The text pin at lint line
    1661 is its only guard.
  - A second, unrestricted `claude -p "/code-review high"` launch beside the line pinned at
    lint line 930 would pass. Lint lines 468-482 keep the legacy /tmp marker path and the
    inline PROJ_HASH out of the hook and codereview-skip, but not out of the codereview
    SKILL.md, which CLAUDE.md says they cover. Low impact.
- Runs, all local, with nothing sent:
  - The checks above, on scratch copies with stub curls, proxy variables pointed at a
    closed port, and a loopback listener.
  - tests/test-review-external.sh from the repo root with a recording stub (78 of 78
    passed), and tests/lint-skills.sh (443 of 443 passed).
  - The working tree was unchanged afterward.
- Not verified:
  - Whether OpenAI or Gemini models emit raw control characters when steered, and how
    Claude Code's transcript renders them.
  - The tests' behavior against the real endpoints. Running them would have sent the two
    subjects.
  - The `-H @file` form on macOS. It needs curl 7.55 or later and /dev/fd, and an
    unreadable descriptor fails safe as described above.
- Out of scope: the rest of claude/skills/codereview/SKILL.md, and the two open NOTEs on
  bin/codereview-skip (see the prior-review line).

Git history checked for secrets: bin/review-external.sh (12 commits), tests/lint-skills.sh
(53), and tests/test-review-external.sh (12). Each was checked over its last three commits
(`git log -p --follow -3`) and over its full history (`git log -p --all --follow`). The
patterns covered OpenAI, Anthropic, Google, Tailscale, GitHub, Slack, AWS, and Hugging Face
keys, plus private-key headers, and there were zero hits. The only key values ever added to
these files are the fakes `sk-invalid-test-key`, `sk-test-key`, and `fake-google-key`, and
empty values.

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

Retired this scan: **API key in `curl -H` header argument** (`bin/review-external.sh`).
5a1a7aa keeps both keys out of curl's argv; see Coverage.

---
*Prior review (2026-10-01, scope: paths, at c6e5cab): Reviewed the same three files. 0 BLOCK
/ 0 WARN / 3 NOTE, all three carried above: the GPT-6 long-context comparison as an untested
arithmetic sink, control characters in provider text, and the invalid-key tests sending
commit subjects. Its curl `-H` Accepted Risk named `-H @<file>` as the fix once reviewer
keys were configured; a key was configured, and 5a1a7aa applied the fix. Older open items
outside this scope remain tracked in CODEREVIEW.md: the two bin/codereview-skip NOTEs (the
skip marker is not bound to a diff, deferred to BACKLOG.md as skip-marker-bound-to-diff,
and the marker write follows a symlink), the settings.json umask (zat.env-install.sh:170),
the venv hook's exact-string "auto" guard, ImageMagick's coder policy, and Docker group
membership.*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"2f556b0f22291b1f0b81bb376e23f10c9cb42937","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/test-review-external.sh"],"block":0,"warn":0,"note":3} -->
