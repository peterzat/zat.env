## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `tests/lint-skills.sh` at HEAD 4fa79f5, the only non-Markdown file
changed since the 93127a9 scan. 4fa79f5 added eight checks for the new built-in
`/code-review` step and added Step 5.6 to the light-review skip list. 0 BLOCK / 0 WARN /
1 NOTE. The script executes nothing taken from the files it inspects and writes no files.
The new checks compile and match their targets. The NOTE predates this commit. Two
/codefix role-separation guards cannot fail, and no check enforces the documented "codefix
has no Write" boundary. The lint passes at HEAD. No secrets in the file or its history, and
no PII.

### Findings

```
[NOTE] tests/lint-skills.sh:172,174 — two codefix role-separation guards always pass, and
no check enforces that codefix lacks Write
  Attack vector: /codefix takes BLOCK and WARN findings as its spec. These include findings
    relayed from external models and, since 4fa79f5, from the built-in reviewer, and both
    read diff content an attacker can author. A finding aimed at
    claude/skills/codefix/SKILL.md, or an ordinary edit, could add Write or a Skill grant to
    codefix's allowed-tools. It could also tell codefix to update CODEREVIEW.md, whose
    REVIEW_META block count gates /pr merge. tests/run-all.sh would still pass, although
    CLAUDE.md lists this tool boundary as enforced by lint.
  Evidence: line 172 passes `Skill(` to `grep -E`. GNU grep 3.7 rejects that pattern
    ("Unmatched ( or \(", exit 2). Line 29 discards stderr, and `hasnt` treats any non-zero
    exit as "absent", so the check always passes. Line 174 joins its alternatives with `\|`.
    ERE reads `\|` as a literal pipe, so the pattern matches only a line that contains
    literal `|` characters. A scratch copy of codefix/SKILL.md had `Write, Skill(codereview)`
    added to allowed-tools and an added line telling codefix to "update CODEREVIEW.md to
    mark each finding resolved, then invoke Skill(codereview)". It passed both checks.
    Line 170 checks only that "Edit" appears somewhere in the file, and no check reads
    codefix's allowed-tools for Write. An instrumented run of every `has` and `hasnt` call
    found no other pattern that fails to compile, and the real run printed no grep errors.
    Confidence: high on the mechanism (reproduced). Low on security impact: codefix
    already holds `Bash(*)`, so its tool list is a soft limit, and lines 248 and 567-570
    still pin the do-not-modify prose.
  Remediation: make `hasnt` fail, not pass, when grep exits 2 or higher. For example, set
    `rc=0; grep -qE -- "$2" "$1" 2>/dev/null || rc=$?` and then branch on rc with a `case`.
    Replace line 172 with
    `hasnt "${SKILLS}/codefix/SKILL.md" '^allowed-tools:.*(Skill|Write)'`, which passes on
    the current file and catches the mutant. Drop line 174, or narrow it, because a
    correctly written alternation fails at once on codefix/SKILL.md:28 ("Do not update
    CODEREVIEW.md").
```

### Coverage

All eight dimensions were reviewed. `tests/lint-skills.sh` was read in full (1683 lines).

- Input/output sanitization. The script runs only these commands: grep, `sed -n` with line
  numbers from `grep -n | cut`, awk with fixed programs, tr, and shellcheck over repo
  paths. Its `-lt` comparisons see only those digit strings. Labels print through
  `printf %s` and contain no file content.
- New in 4fa79f5 (lines 903-935). Every pattern compiles and matches its target in
  claude/skills/codereview/SKILL.md. The pinned `mktemp /tmp/.claude-builtin-review-XXXXXX`
  follows the existing cost-log practice. Its name cannot be predicted, and mktemp creates
  the file 0600 with O_EXCL. The host's sysctl config also sets `fs.protected_symlinks=1`
  and `fs.protected_regular=2`. The runtime values could not be read from the sandbox.
- Security pins. These were checked against their targets at HEAD, and all matched: the
  hook's fail-closed checks (494-502), the marker path and PROJ_HASH checks (442-485), the
  security-guard section (1625-1636), and the venv hook check (1259). Three limits apply:
  - The fail-closed awk check covers only the `hash` error branch.
    tests/test-pre-push-hook.sh:454-475 covers the missing-from-PATH branch (hook lines
    215-219) instead.
  - The `--range` leading-dash rejection has no behavioral test in
    tests/test-review-external.sh, so the text pin at line 1625 is its only regression
    guard.
  - CLAUDE.md says lint keeps `/tmp/.claude-codereview-` and `md5sum | cut -c1-8` out of
    the codereview SKILL.md, but lines 464-475 check only the hook and codereview-skip.
    The impact is low. The hook reads only the XDG marker path, so an inline /tmp marker
    would block pushes rather than let them through.
- Dependency, infrastructure, data exposure, PII: none in scope. The script uses system
  tools only, and shellcheck is optional.
- Out of scope and not reviewed: claude/skills/codereview/SKILL.md, which carries this
  commit's behavioral change. That change adds a background `claude -p "/code-review high"`
  child whose findings go through Step 6 to /codefix. Codereview Step 5 builds
  SCAN_FILES with `':!*.md'`, so skill prompts never reach a path-scoped scan. Two spot
  checks only. The live settings hold `defaultMode: "auto"` and
  `autoMode.classifyAllShell: true`, so the child runs under the same classifier as the
  parent. The child reads the same diff the parent reads, so it adds no new principal,
  unlike the third-party external reviewers.
- Host observation, also out of scope. Besides peter, processes run as
  `cloudflared-daydream` (cloudflared), `daydream-egress`, and `daydream`, and /proc is
  mounted without `hidepid`. Two accepted risks below assume a single-user host: the API
  key in curl's argv, and the predictable `/tmp/cuda-keyring.deb`. A compromised service
  process would count as a second local user for both. The argv exposure stays inert while
  no external reviewer keys are configured.

Git history checked for secrets: `tests/lint-skills.sh`, over the last three commits
(`git log -p --follow -3`) and over its full history (52 commits, `git log -p --all
--follow`). The patterns covered OpenAI, Google, Tailscale, GitHub, Slack, and AWS keys,
private-key headers, and generic key/secret/password/token assignments; there were zero
hits. The file handles no credentials.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:183-224`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution. The deny entries are prefix matches and cannot
  enumerate every spelling. Accepted 2026-08-20 because README.md:162 and the script
  comment (lines 178-182) state plainly that the deny list is a speed bump.
  `autoMode.classifyAllShell` sends these commands through the classifier in auto mode,
  so the risk as accepted applies to the other permission modes. This host now has the
  setting (verified 2026-10-01).
- **Venv-activation chains auto-approved outside auto mode**
  (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes,
  the hook returns allow for `. .venv/bin/activate && <anything>`, including pipes,
  `$(...)`, and further commands. The user kept this behavior on 2026-10-01 when
  approving the auto-mode fix, as recorded in CODEREVIEW.md Accepted Risks. The hook
  exists to avoid the eval-like-builtin prompt, and its reach matches the accepted
  interpreter grants in those modes. This was the second NOTE of the 93127a9 scan.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  provider stdout branches): a model steered by attacker-authored code under review can
  emit a correctly tagged finding line that /codefix consumes as a spec. This is distinct
  from the tagged-status NOTE in the prior-review paragraph, which concerns the status
  channel and misattribution.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted. The file in this review's scope contains none.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 86, Tailscale
  line 201, Claude Code line 209): remote code execution by design over HTTPS to
  first-party vendor domains, which is the documented purpose of a bootstrap script. Not
  checksum-pinned, consistent with first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:184-189): `curl -o` to a
  predictable path, then `sudo dpkg -i`. A TOCTOU vector only on a multi-user host;
  immaterial on the documented single-user target. See the host observation in Coverage.
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
- **API key in `curl -H` header argument** (`bin/review-external.sh:275, 366`): the
  header argument is visible in `/proc/<pid>/cmdline` to any local user while curl runs.
  Not exploitable on this single-user dev box. See the host observation in Coverage.

---
*Prior review (2026-10-01, scope: paths, at 93127a9): Reviewed `hooks/allow-venv-source.sh`,
`tests/lint-skills.sh`, `tests/run-all.sh`, `tests/test-allow-venv-hook.sh`, and
`zat.env-install.sh`. 0 BLOCK / 0 WARN / 2 NOTE. That scan confirmed that 93127a9 closed
the a4e8a4e WARN, under which the venv hook approved activation chains in auto mode. Its
first NOTE is still open, since the hook has not changed. The auto-mode guard
(hooks/allow-venv-source.sh:12-14) matches only the exact string "auto". Any other
permission_mode value, including a missing field, falls through to allow. Its lint pin is
now at tests/lint-skills.sh:1259. The user accepted its second NOTE, now under Accepted
Risks. Five NOTEs from the a4e8a4e scan also remain open, since their files are unchanged.
In `bin/review-external.sh`, a tagged status line is promoted into the findings stream
under whichever provider it names (lines 522-526). A partial OpenAI key in auth-failure
text reaches CODEREVIEW.md (line 292). Provider token counts reach `bc` unvalidated (lines
306-316, 400-410). In `hw-bootstrap.sh`, ImageMagick's stock coder policy leaves the SVG
coder reachable from `.png`-named input (line 48). Docker group membership is a
passwordless path to root (line 197).*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"4fa79f51699243a2ac7b1f49d302bd6bb54217fc","scope":"paths","scanned_files":["tests/lint-skills.sh"],"block":0,"warn":0,"note":1} -->
