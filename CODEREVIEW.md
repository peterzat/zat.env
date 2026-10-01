## Review — 2026-10-01 (commit: 05924f6)

**Review scope:** Refresh review. Focus: 15 file(s) changed since prior review (commit 3a2f92b), the whole unpushed diff. The same 11 commits were reviewed at full depth earlier this session at 21ac0f3, before a rebase onto origin/main (5 commits from 2026-08-20); `git range-diff` shows 9 of 11 commits patch-identical, so this pass re-reviewed the two that changed (c33a94b context only, 24a0797 conflict resolution in README.md:162 and the install comment) and the interactions with the 2026-08-20 changes.

**Summary:** v1.5 Opus 5.5 re-baseline on top of the 2026-08-20 macOS and security work: skill effort levels, re-check passes removed, confidence-reporting principle, rolling-file carry-forward guard, install changes (effortLevel seed, stale-link pruning, classifyAllShell), ImageMagick hint, README/CLAUDE.md docs, lint. tests/run-all.sh 682/682 before and after the fix loop. Two documentation WARNs fixed in one /codefix cycle (05924f6). /security (paths: bin/review-external.sh, hw-bootstrap.sh, tests/lint-skills.sh, zat.env-install.sh, deleted bin/claude-fixed-reasoning): 0 BLOCK / 1 WARN / 5 NOTE.

**External reviewers:**
None configured.

### Findings

[WARN, fixed in 05924f6] README.md:757 — "Done (v1.5)" describes the release as only the Opus 5.5 re-baseline, but v1.5 also ships the five 2026-08-20 commits (9c5ed5b, f432dec, 3a2f92b and their review records), none of which the section mentions
  Evidence: `git tag --contains 9c5ed5b` is empty, so they are post-v1.4 and ship in v1.5. The section's intro ("A re-baseline on Anthropic's guidance for Claude Opus 5.5") and README.md:741 ("v1.5 does not advance this arc: it re-baselines the existing harness") omit macOS support (9c5ed5b: bash 3.2 arrays, BSD stat, gtimeout, PATH warning), the test runner counting a dead suite as a failure (f432dec), the `review-external.sh --range` leading-dash rejection (an arbitrary-file-write primitive) and provider-tag findings demux (3a2f92b), the reviewer credential lockdown to 0700/0600 on every install, and the deny list unioned with hand-added entries. Confidence: high.
  Suggested fix: Add an "Also in this release" group to Done (v1.5) with one bullet per change above, and adjust the section intro and README.md:741 so v1.5 reads as the Opus 5.5 re-baseline plus macOS support and security fixes.

[WARN, fixed in 05924f6] README.md:162 — The install description (and zat.env-install.sh:181, 226) says that in auto mode every shell command goes through the auto-mode classifier, but the installer also registers hooks/allow-venv-source.sh, which pre-approves `. .venv/bin/activate && <anything>` and `source .venv/bin/activate && <anything>`
  Evidence: hooks/allow-venv-source.sh:12-16 emits `permissionDecision: allow` for any command with that prefix, including later `;` or `|` chains (confirmed by /security with test strings). Whether a hook allow skips the auto-mode classifier was not tested. The claim was introduced by 24a0797; the hook predates this diff. Confidence: high that the claim overstates; medium that the classifier is skipped.
  Suggested fix: Qualify the claim in README.md:162 and the two install comments: every shell command goes through the classifier except venv-activation chains, which hooks/allow-venv-source.sh pre-approves. Do not change the hook here (see the NOTE below).

[NOTE] hooks/allow-venv-source.sh:12 — (security, rated WARN by /security) The hook approves any command that begins with a venv activation followed by `&& `, so in auto mode it is a path around the classifier for arbitrary chained commands
  Evidence: SECURITY.md 2026-10-01. Recorded here as NOTE rather than WARN because the fix changes hook behavior for every downstream user (CLAUDE.md upstream-fix rule: confirm with the user first), and tightening it may bring back a prompt for chained activation. Raised to the user.
  Suggested fix: User decision: approve bare activation only, reject chains containing `;`, `|`, `||`, `&&` beyond the first, `$(` or backticks, or emit no decision when the session is in auto mode.

[NOTE] zat.env-install.sh:226 — The comment (and README.md:768) states as fact that narrow allow rules such as `Bash(git *)` resolve before the auto-mode classifier, so a force push would skip its check
  Evidence: The auto-mode docs give `Bash(npm test)` as the narrow example and suspend only broad rules such as `Bash(*)` or wildcarded interpreters; whether `Bash(git *)` counts as narrow was not confirmed. The setting is correct either way. Confidence: medium that the wording overstates.
  Suggested fix: Hedge ("narrow allow rules can resolve before the classifier") or confirm the behavior.

[NOTE] claude/skills/security/SKILL.md:23 — "is not a finding" (no attack path) and the BLOCK definition's "a theoretical concern without one is not a BLOCK" (line 116) leave it unclear whether a vulnerability with a partly traced path is dropped or reported as NOTE
  Evidence: The same principle routes uncertain findings to NOTE. Confidence: medium.
  Suggested fix: A finding whose path you could not trace completely is a NOTE; a concern with no path described at all is not a finding.

[NOTE] claude/skills/codereview/SKILL.md:43 — "Finish the run" lists finish points as if exhaustive, but Step 0 (unknown mode), Step 2 (empty diff), and Steps E.1 to E.3 legitimately stop earlier
  Evidence: The principle permits an early stop only "when a step is blocked on something the user must resolve". Confidence: medium-low that this causes misbehavior.
  Suggested fix: Add "or where a step says to stop".

[NOTE] tests/README.md:20 — The lint category table omits "Skill effort levels" and "Uncommitted prior entry guard" (added in this diff) and "Security guards" (added 2026-08-20); lint now has 28 categories
  Evidence: `grep '^echo "==> ' tests/lint-skills.sh` against the table. Confidence: high, low impact.
  Suggested fix: Add the missing rows.

[NOTE] CLAUDE.md:52 — The "Uncommitted prior entry guard" contract bullet says /codereview checks `git status --porcelain` in Step 9; since a4e8a4e the reading is taken in Step 1 and Step 9 uses it
  Evidence: Lint pins only the command text in the skill. Confidence: high, low impact.
  Suggested fix: Say /codereview takes the reading in Step 1, before Step 6.5 writes a preliminary entry.

[NOTE] commit c33a94b — Bundles the /codereview "Finish the run" principle with the effort-level and install changes
  Evidence: Both are parts of the Opus 5.5 re-baseline and the message lists each, but they change different behaviors. Confidence: medium-low that this is a mixed concern.
  Suggested fix: None now; keep such changes in separate commits.

[NOTE] hw-bootstrap.sh:48 (with claude/global-claude.md:96) — (security) ImageMagick installs with the stock coder policy; a `.png`-named file with SVG content is handled by the SVG coder, and the new convention has Claude run `convert` on images it inspects
  Evidence: SECURITY.md 2026-10-01 (SVG coder handling confirmed; an explicit `png:in.png` prefix blocks it, also confirmed). Confidence: medium on impact.
  Suggested fix: Use `convert png:in.png ...` in the convention, and/or install a raster-only coder allowlist in hw-bootstrap.sh.

[NOTE] bin/review-external.sh:306 — (security) Provider-reported token counts reach `bc` unvalidated (also :400-410); a hostile provider response could hang the review
  Evidence: SECURITY.md 2026-10-01, injected loop confirmed in bc. Requires a hostile or compromised provider. Confidence: high on mechanism.
  Suggested fix: Validate the counts as digits before arithmetic.

[NOTE] bin/review-external.sh:522 — (security) The 3a2f92b demux fix stops untagged status lines from posing as findings, but a status line carrying any `(provider)` tag still passes as that provider's finding; free text after a valid tag is likewise unconstrained
  Evidence: SECURITY.md 2026-10-01, reproduced with a stub local reviewer and stub curl. Carries forward the 2026-08-20 NOTE. Confidence: high on mechanism, low on reachability.
  Suggested fix: Write each provider's stderr to its own file and tag at the demux.

[NOTE] bin/review-external.sh:292 — (carried forward) OpenAI `.error.message` is forwarded verbatim; on an auth failure a public key prefix plus four characters can reach CODEREVIEW.md
  Evidence: CODEREVIEW.md and SECURITY.md 2026-08-20. Inert while no provider is configured.
  Suggested fix: Redact key-shaped strings from provider error text.

[NOTE] zat.env-install.sh:105 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod; it holds only commented template text then
  Evidence: CODEREVIEW.md 2026-08-20.
  Suggested fix: None needed.

[NOTE] zat.env-install.sh:183 — (carried forward) Deny entries now accumulate across installs; removing one requires editing settings.json
  Evidence: CODEREVIEW.md 2026-08-20. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] hw-bootstrap.sh:197 — (security) Docker group membership lets anything running as the user, including the agent, obtain root without a password
  Evidence: SECURITY.md 2026-10-01. Pre-existing.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

- [WARN] README.md:757, 741 — Done (v1.5) gained an "Also in this release, macOS support and security fixes" group (macOS support, dead-suite failure, `--range` leading-dash rejection, provider-tag demux, credential lockdown, deny-list union); the section intro and the roadmap direction now mention them.
- [WARN] README.md:162; zat.env-install.sh:181, 226 — The auto-mode claim now names the exception: venv-activation chains, which hooks/allow-venv-source.sh pre-approves. The hook itself is unchanged, pending the user's decision.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), apart from venv-activation chains (see the hooks/allow-venv-source.sh NOTE); the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.

---
*Prior review (2026-08-20, commit 3a2f92b): Refresh review that closed the `review-external.sh --range` option-injection file-write primitive, locked the reviewer credential file to 0600 in a 0700 directory, unioned hand-added deny rules, and stopped untagged status lines posing as findings; 0 BLOCK / 0 WARN / 4 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"05924f6","reviewed_up_to":"05924f65ec3b09938edc9286f896526244ba38a8","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":14} -->
