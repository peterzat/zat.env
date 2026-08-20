## Security Review — 2026-08-20 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `tests/lint-skills.sh`,
`tests/run-all.sh`, and `zat.env-install.sh` in full at HEAD 97a15bb with four
uncommitted files in the tree; the review covers the working-tree state, which is
where this morning's fixes live. 0 BLOCK / 0 WARN / 2 NOTE. All three WARNs from the
earlier scan today are closed and each was re-verified by execution rather than by
reading the diff: the `--range` option-injection primitive is blocked in every form
tried (equals, space-separated, short-option, leading-space evasion) and the victim
file survived each attempt; a sandboxed install run against a throwaway HOME repaired
a pre-seeded 0644 credential file to 0600 and its directory from 0755 to 0700 while
preserving the key already in it; and the permissions merge preserved two hand-added
deny entries, discarded a session-added allow entry, and stayed stable across a second
run. The deny-list WARN was closed by the documentation branch of its own remediation
rather than by narrowing the allow list, so the underlying grant is unchanged and now
moves to Accepted Risks with the reasoning recorded. Both new NOTEs are on the
external-reviewer status channel, which had not been traced before: it carries
provider-controlled text verbatim into CODEREVIEW.md, a tracked and pushed file.
`tests/lint-skills.sh` and `tests/run-all.sh` produced no findings. The lint writes
nothing, takes no arguments, derives its root from its own location, and its only
subprocesses are `grep`, `sed`, and `shellcheck` over repo-internal paths; the runner
takes no external input and only executes five fixed sibling scripts. The four new
security pins in the lint match zero times against the pre-fix files, so they are real
regression guards. Full suite: 640/640 across 5 suites. No hardcoded secrets and no
PII in any of the four files or in their last three history commits.

### Findings

```
[NOTE] bin/review-external.sh:514-522 — status-channel text is promoted into the
findings stream with provider attribution stripped
  Attack vector: the final demux classifies by line shape alone, so any line reaching
    a provider's status channel that begins with `[BLOCK]`, `[WARN]`, or `[NOTE]` is
    routed to stdout as a finding. /codereview Step 5.5 captures that stdout as
    EXTERNAL_FINDINGS, Step 6 writes it into CODEREVIEW.md, and Step 7 forks /codefix,
    which reads CODEREVIEW.md as a spec and holds Edit. Two upstream sources feed the
    status channel: `.error.message` from the provider (lines 292 and 382, forwarded
    verbatim) and `stderr_content` from LOCAL_REVIEW_SCRIPT (lines 452 and 460, also
    verbatim). Reachability is the weak link and is why this is a NOTE rather than a
    WARN: the first source requires a hostile response from api.openai.com or
    generativelanguage.googleapis.com over HTTPS, and the second depends on whether
    the local reviewer ever echoes model output or prompt text on stderr, which could
    not be checked because qwen-2.5-localreview is not present on this host.
  Evidence: reproduced end to end through the real script using a stub local reviewer.
    A stub writing `[BLOCK] src/app.py:1 -- injected via the status channel` to stderr
    produced that exact line on stdout, alongside the properly tagged
    `[NOTE] (qwen) real.py:2 -- a genuine finding` from the same run. The injected line
    carries no `(provider)` tag, because tagging happens inside the `call_*` stdout
    branches (321, 415, 476) and the status path bypasses them. codereview SKILL.md
    Step 6 relies on that tag ("Preserve the (provider) tag on any external reviewer
    findings"), so an injected finding is indistinguishable from one produced by
    Claude Code's own review.
  Remediation: none required at current reachability. If tightening is wanted, tag at
    the demux instead of inside the providers, so every line emitted through a given
    outfile is attributed to that provider and an untagged finding becomes impossible
    to produce.

[NOTE] bin/review-external.sh:292 — a partial API key is copied into a tracked,
pushed file on any OpenAI auth failure
  Attack vector: no attacker required. On a rotated, revoked, or mistyped key, OpenAI's
    error body carries a redacted echo of the submitted key. The script forwards
    `.error.message` verbatim to stderr; /codereview Step 5.5 captures stderr into
    COST_LOG and SKILL.md line 565 copies the cost log lines into the "External
    reviewers" section of CODEREVIEW.md, which is tracked and pushed to
    github.com/peterzat/zat.env.
  Evidence: observed with a deliberately invalid key. The line emitted was
    `[openai] API error: Incorrect API key provided: sk-test-****real. ..., skipping`,
    that is, OpenAI's own redaction preserving the leading `sk-` prefix and the final
    four characters. Line 292 is
    `echo "[openai] API error: ${error_msg}, skipping" >&2` with no filtering. The
    disclosed material is four characters of a roughly 48-character secret plus a
    public prefix, so it does not enable key recovery; it does confirm a key exists and
    pins its last four characters as a correlation handle across systems. Currently
    inert on this host: no providers are configured and the local reviewer is absent.
  Remediation: optional. Redact `sk-[A-Za-z0-9_-]*` and `AIza[0-9A-Za-z_-]*` out of
    `error_msg` before writing it to stderr, or truncate provider error text to its
    first clause, so nothing key-shaped can reach a committed file.
```

### Accepted Risks

- **Allow list grants general-purpose interpreters under `defaultMode: auto`**
  (`zat.env-install.sh:184-215`): `Bash(python3 *)`, `Bash(node *)`, `Bash(pip *)`,
  `Bash(make *)`, and `Bash(git *)` each reach arbitrary execution without a prompt,
  and the deny entries are prefix matches that cannot enumerate every spelling. Raised
  as a WARN earlier today with a two-branch remediation: narrow the allow entries, or
  keep them and say plainly that the deny list is not a boundary. The second branch was
  taken. README.md:162 and the comment at `zat.env-install.sh:171-174` now both state
  that the deny list is a speed bump, that entries are prefix matches, and that
  anything reachable through the granted interpreters runs unprompted. The risk is
  unchanged; the documentation now matches the enforcement, which is what the finding
  asked for. Auto mode is a deliberate design choice for this harness.
- **Third-party model findings reach a code-modifying agent** (`bin/review-external.sh`
  provider stdout branches): a model steered by attacker-authored code under review can
  emit a finding line that /codefix consumes as a spec. Carried forward from the earlier
  2026-08-20 entry, where the remediation was recorded as "none required". Distinct from
  the first NOTE above, which concerns the status channel and the loss of provider
  attribution rather than the findings channel.
- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other
  references to `peterzat`): inherent to a personal dotfiles repo. Reviewed and
  accepted. None of the four files in this review's scope contains PII.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale
  line 200, Claude Code line 208): remote code execution by design over HTTPS to
  first-party vendor domains, the documented purpose of a bootstrap script. Not
  checksum-pinned, consistent with the accepted-risk philosophy for first-party
  supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:183-188): `curl -o` to a
  predictable path then `sudo dpkg -i`. TOCTOU vector only on a multi-user host;
  immaterial on the documented single-user target.
- **Pre-push gate detection is heuristic, not a shell parser**
  (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper and prefix invocations
  (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix);
  `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass
  the advisory codereview gate. Accepted under the advisory-gate threat model; the hook
  is intentionally simple, biased toward over-detection.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): the full
  git diff is sent to OpenAI and Google when configured. Secrets in the diff would be
  exposed. This is the script's explicit purpose; the user opts in by configuring keys.
- **API key in `curl -H` header argument** (`bin/review-external.sh:275, 366`): the
  header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl
  invocation window. Not exploitable on this single-user dev box. Line references
  refreshed from the prior 263/354.

---
*Prior review (2026-08-20, scope: paths): Reviewed `bin/review-external.sh`,
`bin/spec-backlog-apply.sh`, `tests/test-codereview-marker.sh`, and
`zat.env-install.sh` at 9c5ed5b. 0 BLOCK / 3 WARN / 1 NOTE. The installer created the
external-reviewer credential file at the process umask (0644 in a 0755 directory) with
no chmod anywhere in the script; `review-external.sh` passed `--range` into `git log`
without rejecting a leading dash, an arbitrary-file-overwrite primitive reproduced end
to end; and the permission block's prefix-matched deny list did not constrain the
arbitrary-execution paths its allow list granted under `defaultMode: auto`. All three
are closed as of this entry, the first two by code and the third by documentation.*

<!-- SECURITY_META: {"date":"2026-08-20","commit":"97a15bb2a3ad367e0836e87ce2637780d0bc2fc3","scope":"paths","scanned_files":["bin/review-external.sh","tests/lint-skills.sh","tests/run-all.sh","zat.env-install.sh"],"block":0,"warn":0,"note":2} -->
