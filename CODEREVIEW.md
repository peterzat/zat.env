## Review — 2026-08-20 (commit: 3a2f92b)

**Review scope:** Refresh review. Focus: 6 file(s) changed since the prior review (commit 9c5ed5b). 2 already-reviewed file(s) (`bin/spec-backlog-apply.sh`, `tests/test-codereview-marker.sh`) checked for interactions only.

**Summary:** Acted on the three security WARNs deferred by the prior entry, plus the documentation NOTEs. Closed a verified arbitrary-file-write primitive in `--range`, tightened the reviewer credential file to 0600 in a 0700 directory, stopped the installer silently discarding hand-added deny rules, and corrected two inaccurate README claims. A follow-up `/security` scan of the changed files returned 0 BLOCK / 0 WARN / 2 NOTE and verified all three prior WARNs closed by execution rather than by reading the diff. One of its NOTEs (untagged status lines posing as findings) was cheap and safe to fix, so it was fixed in the same pass. Suite went from 636 to 642 checks, all passing.

**External reviewers:**
None configured.

### Findings

No new BLOCK or WARN findings. The reviewer's own pass over the focus set found no correctness, regression, or spaghetti issues: every change is a direct remediation of a recorded finding, each was verified by execution, and the set is cohesive under one purpose.

[NOTE] bin/review-external.sh:292 — OpenAI `.error.message` is forwarded verbatim to stderr
  On an auth failure the provider's message reaches the cost log, and codereview Step 5.5 copies that log into CODEREVIEW.md, which is tracked and pushed. Observed with a bad key: `Incorrect API key provided: sk-test-****real`. The redaction is OpenAI's own, so the leak is a public prefix plus 4 characters, not key recovery. Currently inert: no providers are configured and the live `.env` holds only comments. Not fixed; filtering provider error text would cost more clarity than it buys.

[NOTE] bin/review-external.sh — free text after a valid provider tag is still unconstrained
  The demux fix below stops *untagged* status lines from posing as findings, but a hostile provider that returns a correctly tagged `[BLOCK] (openai) ...` line still controls the text after the tag, and that text reaches `/codefix`, which holds Edit. Requires attacker-authored code under review plus a hostile or compromised provider. Retained from the prior entry, narrowed in scope.

[NOTE] zat.env-install.sh:105-147 — brief 0644 window on first creation
  The file is created at the process umask and chmod'd immediately after. At that instant it contains only commented template text with no secrets, so the window is not exploitable. Left as is rather than restructuring the heredoc around a `umask 077` subshell.

[NOTE] zat.env-install.sh:166-183 — deny entries now accumulate permanently
  Unioning the deny list is what stops hand-added rules being dropped, but it also means a re-install can no longer remove a deny entry; that requires editing `settings.json` directly. Deny entries only narrow permissions, so accumulation is safe, but it is a deliberate behavior change from the previous clean-slate semantics.

### Fixes Applied

- [WARN] bin/review-external.sh:93-103 — reject a `--range` beginning with `-`. Verified: `--range=--output=<path>` and `--range --output=<path>` both exit 2 with the victim file intact; benign ranges still work; the no-arg fail-open (exit 0) and `--check` fail-loud (exit 1) contracts are unchanged.
- [NOTE→fixed] bin/review-external.sh:511-530 — findings demux now matches `FINDING_RE` (`[SEVERITY] (provider)`) instead of severity shape alone. All three providers tag on their stdout path, so no legitimate finding is lost; untagged severity-shaped status lines fall through to stderr, where they stay visible.
- [WARN] zat.env-install.sh:101-103,144-147 — `chmod 700` the reviewer config dir and `chmod 600` its `.env`, unconditionally on every run. Independently verified by running the installer against a throwaway HOME pre-seeded with a 0644 `.env`: it came back 0600 in a 0700 dir with contents intact, and the directory is locked before the file is written.
- [WARN] zat.env-install.sh:166-215 — allow list still reset wholesale; deny list now unioned with existing entries. Verified across three settings shapes including one with no `.permissions` key; hand-added `Bash(sudo *)` survives, session-added allow entries are discarded, second run is idempotent, malformed input fails safe.
- [NOTE] README.md:95-98 — dropped "no macOS-specific code paths exist"; names the single `jq`-hint branch instead.
- [NOTE] README.md:162 — deny list described as a prefix-matching speed bump, not a security boundary.
- [NOTE] zat.env-install.sh:306-313 — PATH warning now also instructs restarting Claude Code.
- tests/lint-skills.sh:1500-1517 — new "Security guards" section, six pins, each verified to match zero times against the pre-fix files.
- CLAUDE.md — recorded the new contract points (dash rejection, credential file mode, deny-list union).

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters under `defaultMode: auto`** (zat.env-install.sh:166-215): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Auto mode is the deliberate design; the remediation was to stop overstating the deny list in README.md and in the script's own comment rather than to narrow the grant. Recorded by the 2026-08-20 follow-up scan.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.

---
*Prior review (2026-08-20, commit 9c5ed5b): Full-depth review of the macOS portability commit. 2 BLOCK / 6 WARN / 2 NOTE. Both BLOCKs were test-infrastructure defects that made `tests/run-all.sh` report `All 238 checks passed` on macOS while 395 of 633 checks never ran: `lint-skills.sh` aborted on GNU-only `grep -oP`, and the runner discarded suite exit codes. Both fixed and verified; three security WARNs were deferred and are resolved by the current entry.*

<!-- REVIEW_META: {"date":"2026-08-20","commit":"3a2f92b","reviewed_up_to":"3a2f92b003f57dce83e0f664e62637480a7a4d41","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":4} -->
