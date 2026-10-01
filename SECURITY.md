## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `tests/lint-skills.sh`, and
`tests/test-review-external.sh` in full at HEAD c6e5cab: 0 BLOCK / 0 WARN / 3 NOTE, no
secrets in the files or their history, and no PII. The new long-context price comparison
is a bash arithmetic sink that `_count` makes safe but no test covers, provider text
reaches the terminal with its control characters intact, and the invalid-key NOTE carries
over, re-verified without sending anything.

### Findings

```
[NOTE] bin/review-external.sh:354 — the new long-context comparison is a bash arithmetic
context, which expands command substitutions in its operand. `_count` (line 346) makes it
safe, but no test covers this sink, so a reordering would let a provider response run
commands. The Gemini comparison at line 460, from 379af38, is the same.
  Attack vector: none at HEAD. The value comes from the provider's `usage` block, which
    the script already treats as untrusted (that is why `_count` exists). If a later edit
    compares the raw jq output instead of the filtered variable, a response carrying
    "input_tokens":"PATH[$(cmd)]" runs cmd as the user. Only the provider, or someone who
    can tamper with its TLS connection, controls that field. Injected text in the diff
    cannot.
  Evidence: under the script's own `set -euo pipefail`, `[[ "PATH[$(cmd)]" -gt 272000 ]]`
    ran cmd and then continued, because the syntax error that follows is not fatal inside
    an && list. An unset array name stops at "unbound variable" before expansion, which is
    why the payload uses PATH. On a scratch copy with a stub curl, the unmodified script
    turned the payload into 0 and ran nothing. A mutant that changed only line 354 to
    compare the raw jq value passed the hostile-value test's assertion
    (tests/test-review-external.sh:867-876: "-- 0 in / 5 out" in under 20 seconds) and ran
    the payload. That test's "1; while (1) { }" value targets bc. In the comparison it
    raises a non-fatal syntax error. The `_count` comment (lines 276-277) names bc as the
    only sink, and no test sends a hostile Gemini count. Confidence: high on the mechanism.
  Remediation: name the comparisons in the `_count` comment. Change the hostile-value test
    to a command-substitution payload, such as "PATH[$(: > ${TEST_DIR}/ran)]", and assert
    that the file does not exist. Add the same case for promptTokenCount.

[NOTE] bin/review-external.sh:369-375, 583-589 — provider text is printed with its control
characters intact, so a model steered by the code under review can put terminal escape
sequences into a finding line. The Google and local loops (lines 472-478 and 533-539) do
the same.
  Attack vector: the author of a diff under review embeds instructions aimed at the
    external model. This is the prompt-injection path that the accepted "third-party model
    findings" risk already assumes. The model returns a line that starts with [BLOCK],
    [WARN], or [NOTE] and carries ESC, CR, or BEL as JSON escapes. `jq -r` decodes them to
    raw bytes (lines 337 and 440-444). The tagging loop keeps the line because it checks
    only the prefix (line 370), and demux forwards it to stdout (line 585). A user who runs
    the script in a terminal, as the usage header shows (lines 9-10), gets the sequences
    interpreted. CR plus erase-line rewrites what the finding appears to say, OSC
    sequences set the window title, and a terminal that accepts OSC 52 clipboard writes
    from applications lets the line replace the clipboard. The accepted risk covers what
    the agent does with a finding. It does not cover hiding a finding's text from a human
    or driving the human's terminal.
  Evidence: reproduced on a scratch copy against a stub curl. The finding text
    "[BLOCK] evil.py:1 -- real finding\r\u001b[2K[NOTE] evil.py:1 -- cosmetic
    only\u001b]0;title\u0007" came out on stdout tagged "(openai)", with raw CR, ESC [2K,
    and ESC ]0;title BEL bytes (checked with od -c). A terminal would show only the NOTE
    text. Not verified: that OpenAI or Gemini models emit raw control characters when
    steered (public prompt-injection research has shown models emitting ANSI escape
    sequences into CLI tools' output), how Claude Code's transcript renders such bytes when
    /codereview runs the script, and the user's terminal settings. tmux's default
    `set-clipboard external` does not accept OSC 52 from applications. The provider error
    text at lines 332 and 435 passes control characters the same way, but only the
    provider controls it. Confidence: high on the mechanism, low on exploitability.
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
  Evidence: re-verified at c6e5cab without sending anything. The suite ran from the repo
    root with a recording stub ahead of curl on PATH. Three requests carried
    "=== COMMITS ===" with the five unpushed subjects (4333ebf to c6e5cab): two to
    api.openai.com (the tests at lines 112 and 287) and one to
    generativelanguage.googleapis.com (line 287), about 2 KB each. The test at lines
    336-365 runs from a non-git directory and sent no COMMITS block. With curl stubbed,
    the suite passed 76 of 76 checks. Impact is low for zat.env, whose subjects reach
    GitHub on push anyway. A fork with private history would send more. Confidence: high
    on the mechanism, low on impact.
  Remediation: run these tests against the suite's fake curl (lines 753-782) with
    FAKE_CODE=401, which also removes their network dependency. Running them from
    ${TEST_DIR} is an alternative.
```

### Coverage

All eight dimensions were reviewed. Every line of the three files was read at HEAD
c6e5cab: bin/review-external.sh (595 lines), tests/lint-skills.sh (1715), and
tests/test-review-external.sh (925). Read for context only: tests/run-all.sh, BACKLOG.md,
and the 379af38 and f541aa2 entries of this file.

- Changes since the f541aa2 scan:
  - e01371d added the GPT-6 long-context price tier (bin/review-external.sh:352-361) and
    a leading zero for costs under $1 (`_calc`, line 270). The comparison is the first
    NOTE above. The `_calc` change pipes bc's output through a fixed sed expression. bc's
    input is still built only from `_count`-filtered integers and the hard-coded prices.
  - 30aeb8c added the lint check at tests/lint-skills.sh:1000-1015. Both operands of its
    `(( ))` come from `grep -oE` digit patterns, so no expression can reach the
    arithmetic.
  - The test changes (tests/test-review-external.sh:828-865) use the suite's fake curl and
    files in TEST_DIR. They make no network calls.
- Robustness, not a finding: a token count with a leading zero, such as "0999", passes
  `_count`, and the comparison reports "value too great for base". The error is not fatal,
  so the run continues and bc reads the value as decimal.
- Guard coverage:
  - `_count` and `_redact` still have no lint pins. Their only tests are the behavioral
    ones at tests/test-review-external.sh:867-886, and the first of those does not cover
    the comparison sink (first NOTE).
  - The `--range` leading-dash rejection still has no behavioral test. The text pin at
    lint line 1651 is its only guard.
  - Unchanged from the prior scans: a second, unrestricted `claude -p "/code-review high"`
    launch beside the line pinned at lint line 930 would pass. Lint lines 468-482 keep the
    legacy /tmp marker path and the inline PROJ_HASH out of the hook and codereview-skip,
    but not out of the codereview SKILL.md, which CLAUDE.md says they cover. Low impact.
- Runs, all local, with nothing sent:
  - The arithmetic and script checks above, on scratch copies with a stub curl, a non-git
    working directory, and proxy variables pointed at a closed port.
  - tests/test-review-external.sh from the repo root with a recording stub (76 of 76
    passed), and tests/lint-skills.sh (440 of 440 passed).
  - The working tree was unchanged afterward.
- Not verified:
  - Whether OpenAI or Gemini models emit raw control characters when steered, and how
    Claude Code's transcript renders them.
  - The tests' behavior against the real endpoints. Running them would have sent the five
    subjects.
- Out of scope: claude/skills/codereview/SKILL.md, which consumes the script's output, and
  the two prior NOTEs on bin/codereview-skip (see the prior-review line).

Git history checked for secrets: bin/review-external.sh (11 commits), tests/lint-skills.sh
(52), and tests/test-review-external.sh (11). Each was checked over its last three commits
(`git log -p --follow -3`) and over its full history (`git log -p --all --follow`). The
patterns covered OpenAI, Anthropic, Google, Tailscale, GitHub, Slack, AWS, and Hugging
Face keys, plus private-key headers, and there were zero hits. The only key values ever
added to these files are the fakes `sk-invalid-test-key`, `sk-test-key`, and
`fake-google-key`, and empty values.

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
  tagging loops at lines 369-375, 472-478, and 533-539): a model steered by
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
- **API key in `curl -H` header argument** (`bin/review-external.sh:315, 419`): the
  header argument is visible in `/proc/<pid>/cmdline` to any local user while curl runs.
  Not exploitable on this single-user dev box. Host update, 2026-10-01: of the three
  service accounts, cloudflared-daydream (ProtectProc=default) can read these cmdlines.
  The other two cannot (ProtectProc=invisible). The exposure stays inert while no reviewer
  keys are configured, which was the case on 2026-10-01. If keys are added, passing the
  header as `-H @<file>` keeps it out of argv.

---
*Prior review (2026-10-01, scope: paths, at f541aa2): Reviewed bin/codereview-skip,
tests/lint-skills.sh, and tests/test-review-external.sh. 0 BLOCK / 0 WARN / 3 NOTE. Two
NOTEs concern bin/codereview-skip, which is outside this scope and unchanged since. The
skip marker never expires and is not tied to a diff (deferred to BACKLOG.md as
skip-marker-bound-to-diff). The marker write follows a symlink, and marker_dir does not
enforce the directory's mode or owner (still open). The third NOTE, on the invalid-key
tests, is carried above. That scan confirmed the 379af38 WARN on predictable /tmp test
paths fixed. Older open items outside this scope remain tracked in CODEREVIEW.md: the
settings.json umask (zat.env-install.sh:170), the venv hook's exact-string "auto" guard,
ImageMagick's coder policy, and Docker group membership.*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"c6e5cab8a0bd05d20cf291d27f97d555e5de5554","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/test-review-external.sh"],"block":0,"warn":0,"note":3} -->
