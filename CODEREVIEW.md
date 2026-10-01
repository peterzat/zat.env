## Review — 2026-10-01 (commit: 93127a9)

**Review scope:** Refresh review. Focus: 10 file(s) changed since prior review (commit 05924f6), the whole unpushed diff (one commit, 93127a9). 0 already-reviewed file(s).

**Summary:** The venv-activation hook now makes no decision in auto mode, so the auto-mode classifier judges activation chains instead of a hook `allow` skipping it; other modes keep the auto-approval. Adds a 13-check hook suite (registered in run-all.sh; its three auto-mode checks fail against the previous hook), a global convention to run venv tools directly, lint pins, and doc updates removing the venv-chain exception. tests/run-all.sh 698/698 across 6 suites. /security (paths: the hook, its test, run-all.sh, lint, install) found 0 BLOCK / 0 WARN / 2 NOTE and confirmed the prior venv-hook WARN closed; one NOTE is listed below and the other is recorded under Accepted Risks as the user's decision.

**External reviewers:**
None configured.

### Findings

No BLOCK or WARN findings. The hook change is correct for every permission mode, malformed input fails safe (no decision), the docs and comments now match the behavior, and the commit is a single concern.

[NOTE] hooks/allow-venv-source.sh:12 — (security) The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Evidence: SECURITY.md 2026-10-01: "Auto", " auto", null, and a missing field each got allow; test line 63 pins allow for a missing field (kept on purpose for pre-auto-mode behavior). The value forked skills receive was not verified, and the commit's live check cannot tell a hook allow from a classifier allow, though this session's transcript records the mode as `auto`. Confidence: high on mechanism, low that any current context sends something other than "auto".
  Suggested fix: Approve only for an explicit list of modes (default, acceptEdits, plan, dontAsk, bypassPermissions) and make no decision otherwise; update test line 63 and the lint pin at tests/lint-skills.sh:1225.

[NOTE] tests/README.md:11 — "Runs both suites" is stale (run-all.sh now runs 6), and the lint category table omits "Skill effort levels", "Uncommitted prior entry guard", and "Security guards" (tests/README.md:20)
  Evidence: tests/run-all.sh:50-55; `grep '^echo "==> ' tests/lint-skills.sh`. Confidence: high, low impact.
  Suggested fix: Say "Runs every suite" and add the missing table rows.

[NOTE] zat.env-install.sh:229 — (carried forward) The comment, and README.md:768, state as fact that narrow allow rules such as `Bash(git *)` resolve before the auto-mode classifier
  Evidence: The auto-mode docs give `Bash(npm test)` as the narrow example; whether `Bash(git *)` counts as narrow was not confirmed. The setting is correct either way. Confidence: medium.
  Suggested fix: Hedge ("can resolve before the classifier") or confirm.

[NOTE] claude/skills/security/SKILL.md:23 — (carried forward) "is not a finding" (no attack path) and the BLOCK definition's "not a BLOCK" (line 116) leave unclear whether a partly traced vulnerability is dropped or reported as NOTE
  Suggested fix: A finding whose path you could not trace completely is a NOTE; a concern with no path at all is not a finding.

[NOTE] claude/skills/codereview/SKILL.md:43 — (carried forward) "Finish the run" lists finish points as if exhaustive; Step 0, Step 2 (empty diff), and Steps E.1 to E.3 legitimately stop earlier
  Suggested fix: Add "or where a step says to stop".

[NOTE] CLAUDE.md:53 — (carried forward) The "Uncommitted prior entry guard" bullet says /codereview checks `git status --porcelain` in Step 9; since a4e8a4e the reading is taken in Step 1 and Step 9 uses it
  Suggested fix: Say /codereview takes the reading in Step 1, before Step 6.5 writes a preliminary entry.

[NOTE] hw-bootstrap.sh:48 (with claude/global-claude.md:96) — (carried forward, security) ImageMagick's stock coder policy handles a `.png`-named SVG with the SVG coder, and the convention has Claude run `convert` on images it inspects
  Suggested fix: Use `convert png:in.png ...` in the convention, and/or install a raster-only coder allowlist.

[NOTE] bin/review-external.sh:306 — (carried forward, security) Provider-reported token counts reach `bc` unvalidated (also :400-410); a hostile provider response could hang the review
  Suggested fix: Validate the counts as digits before arithmetic.

[NOTE] bin/review-external.sh:522 — (carried forward, security) A status line carrying any `(provider)` tag still passes as that provider's finding; free text after a valid tag is unconstrained
  Suggested fix: Write each provider's stderr to its own file and tag at the demux.

[NOTE] bin/review-external.sh:292 — (carried forward) OpenAI `.error.message` is forwarded verbatim; on an auth failure a public key prefix plus four characters can reach CODEREVIEW.md. Inert while no provider is configured.
  Suggested fix: Redact key-shaped strings from provider error text.

[NOTE] zat.env-install.sh:114 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod at :155; it holds only commented template text then.
  Suggested fix: None needed.

[NOTE] zat.env-install.sh:184 — (carried forward) Deny entries accumulate across installs; removing one requires editing settings.json. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] hw-bootstrap.sh:197 — (carried forward, security) Docker group membership lets anything running as the user, including the agent, obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

None.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit 05924f6): Refresh review of the v1.5 Opus 5.5 re-baseline after the rebase onto the 2026-08-20 macOS and security work; two documentation WARNs fixed by /codefix (v1.5 notes missing the 2026-08-20 changes, an overstated auto-mode claim); 0 BLOCK / 0 WARN / 14 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"93127a9","reviewed_up_to":"93127a95036ac8fb0af7963324997e4a6a577390","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":13} -->
