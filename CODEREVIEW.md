## Review — 2026-10-01 (commit: 20a4c6c)

**Review scope:** Refresh review. Focus: 10 file(s) changed since prior review (commit 55694b7): the three NOTE batches 3f6772a (test-suite integrity), 6645cd1 (prompt and doc accuracy), and 379af38 (review-external.sh model refresh and hardening). 0 already-reviewed file(s).

**Summary:** Lint now counts each check once, fails on broken patterns, and has working codefix boundary guards; several prompt and doc accuracy fixes; review-external.sh defaults to current models (gpt-6.1-sol, gemini-3.1-pro-preview with thinking level), fixes the OpenAI cost double count, integer-checks token counts, redacts key-shaped error text, and demuxes each provider's own tagged stdout only. tests/run-all.sh 698/698 before the fix loop, 699/699 after (one new lint check). Five WARNs fixed over two /codefix cycles (20a4c6c); the fifth came from re-reviewing the first cycle's fix. /security (paths: bin/review-external.sh, tests/lint-skills.sh, tests/test-review-external.sh, zat.env-install.sh) found 0 BLOCK / 1 WARN / 2 NOTE and verified the four prior NOTEs on these files fixed.

**External reviewers:**
None configured.

**Built-in review:**
`/code-review high`: 10 findings, 10 kept after Step 6 (one also reported by the inline review); 232 s, finished well before /security.

### Findings

[WARN, fixed in 20a4c6c] claude/skills/codereview/SKILL.md:473 — The Step 5.6 child `claude -p` runs with every tool, so the verifier-only /codereview (no Edit or Write, by design) launches a process that can edit the tree it is reviewing (claude-code)
  Evidence: The launch passes no tool restriction. Under the installed auto mode, prompt-injection text in the reviewed diff could steer the child into Edit or Write calls while Steps 4 and 5 run; the edits would be in the working tree when Step 8 hashes the push marker, unseen by the inline review. CLAUDE.md's builder/verifier boundary describes /codereview as having no Edit/Write. In 20 experiment runs and two live runs the child modified nothing. Confidence: high on the mechanism, low on likelihood.
  Suggested fix: Launch with `--disallowedTools "Edit,Write,NotebookEdit"` (it needs neither, since --fix is never passed), and at collection compare `git status --porcelain` and `git diff` against a reading taken just before launch; if the tree changed, discard the built-in's findings, record `Failed (tree changed).`, and report it. Update the lint pin on the invocation.

[WARN, fixed in 20a4c6c] CLAUDE.md:63 — The "External reviewer output handling" bullet says the model defaults and the price table sit at the top of the script; only the defaults do, and the prices are `case` blocks inside call_openai and call_google (claude-code)
  Evidence: bin/review-external.sh price tables near the cost logging in each provider function. A maintainer updating for a retired model would miss them. Confidence: high.
  Suggested fix: Say the model defaults are at the top of the script and the price tables are in each provider function's cost block.

[WARN, fixed in 20a4c6c] tests/README.md:27 — The "Codereview flow gating" row says the light-review skip list has 5 steps; since 4fa79f5 lint checks 6 (3, 5, 5.5, 5.6, 6.5, 7) (claude-code)
  Evidence: tests/lint-skills.sh:153. Confidence: high.
  Suggested fix: "light review skip list (Steps 3, 5, 5.5, 5.6, 6.5, 7)".

[WARN, fixed in 20a4c6c] tests/test-review-external.sh:145 — (security) Two tests point LOCAL_REVIEW_SCRIPT and LOCAL_REVIEW_VENV at predictable /tmp paths (also line 209); review-external.sh runs `${LOCAL_REVIEW_VENV}/bin/python3` when the script path exists, so another local account that plants both paths before the test reaches them gets code run as the test user
  Evidence: SECURITY.md 2026-10-01, reproduced with planted files in a scratch copy. Predates this diff. The daydream service accounts use PrivateTmp, so exposure on this host is low. Confidence: high on the mechanism.
  Suggested fix: Put both nonexistent paths under the suite's private `${TEST_DIR}`.

[WARN, fixed in 20a4c6c] claude/skills/codereview/SKILL.md:466 — The cycle-1 tree-change check hashes `git status --porcelain` and `git diff` over the whole tree, but /security legitimately writes SECURITY.md between the launch and the collection, so the check would discard the built-in's findings as "tree changed" on nearly every full review
  Evidence: Step 5 invokes /security after the Step 5.6 launch and before its collection; /security rewrites SECURITY.md (it did in this run, leaving it uncommitted). The reading at launch and at collection would then differ. Found in re-review of the cycle-1 fix. Confidence: high.
  Suggested fix: Take both readings with the review-output exclusions the push marker uses, for example `{ git status --porcelain -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md'; git diff -- ':!CODEREVIEW.md' ':!SECURITY.md' ':!TESTING.md' ':!SPEC.md'; } | sha256sum`, in both the launch and the collect instructions, and pin the excluded form in lint.

[NOTE] bin/review-external.sh:144 — gemini_thinking chooses thinkingLevel or thinkingBudget from the shape of GEMINI_EFFORT, not the model; a level sent to a pinned gemini-2.5 model may be rejected, and the 32768 default budget exceeds gemini-2.5-flash's cap (claude-code)
  Evidence: The budget default for every 2.5 model predates this diff (the old default applied to any model). Whether 2.5 models accept thinkingLevel was not verified. Confidence: medium-low.
  Suggested fix: For gemini-2.5 models map a level to a budget, and cap the flash default at 24576.

[NOTE] tests/test-review-external.sh:848 — The hostile-token test detects a regression by elapsed time, but nothing bounds the run, so a regression would hang the suite rather than fail the check (claude-code)
  Suggested fix: Bound the run (the script's own TIMEOUT_CMD pattern), so a hang becomes a failure.

[NOTE] bin/review-external.sh:168 — `--check` prints an invalid GEMINI_EFFORT but still counts Google as configured and exits 0, so /codereview external's pre-flight passes for a provider the real run will skip (claude-code)
  Evidence: The same behavior existed before this diff with a non-numeric budget. Confidence: high on the mechanism, low impact.
  Suggested fix: Do not count Google as configured when its thinking setting is invalid.

[NOTE] bin/review-external.sh:284 — `_redact` has no word boundary, so words containing "sk-" (for example "task-" or "risk-") in provider error text are partly redacted (also claude-code)
  Evidence: Cosmetic; it only affects error text. BSD sed lacks `\b`, so the fix needs a portable boundary such as `(^|[^A-Za-z0-9])`.
  Suggested fix: Anchor the match on a non-alphanumeric character or line start.

[NOTE] bin/review-external.sh:456 — The new price tables drop the gemini-2.5-flash rate and the o3-priced fallback, so those models now log cost "?" (claude-code)
  Evidence: Deliberate: the old flash rates were stale and the o3 fallback mispriced every unknown model. "?" is honest. Confidence: high.
  Suggested fix: None, or add verified rates for models in actual use.

[NOTE] tests/lint-skills.sh:294 — The double-count fix leaves 28 failure branches that update FAILS and TOTAL inline and print by hand, duplicating fail() (claude-code)
  Suggested fix: Replace those branches with `fail "..."`.

[NOTE] bin/review-external.sh:151 — gemini_thinking accepts `minimal`, which the header, the install template, and the validation message do not list (claude-code)
  Suggested fix: Document `minimal`, or drop it, since Pro models do not accept it.

[NOTE] tests/test-review-external.sh:112 — (security) The invalid-key tests call the real OpenAI and Google APIs from the repo root, so each run sends the unpushed commit subjects to both providers without opt-in
  Evidence: SECURITY.md 2026-10-01. Predates this diff. Low impact.
  Suggested fix: Run them against the suite's fake curl with FAKE_CODE=401.

[NOTE] zat.env-install.sh:170 — (security) Each settings.json rewrite creates a new .tmp file and moves it into place, so a 0600 settings.json comes back at the default umask (0664 under umask 0002); same pattern at 224, 233, 249, 271, 288, 306
  Evidence: SECURITY.md 2026-10-01. Inert today: no secrets in settings.json and the home directory is 0750.
  Suggested fix: `umask 077` at the top of the script.

[NOTE] bin/review-external.sh — The default Gemini model, gemini-3.1-pro-preview, is a preview; a preview can be withdrawn on short notice, and a retired default would show only as an API-error line in the cost log
  Evidence: It is Google's named replacement for gemini-2.5-pro, whose access is limited to existing users. Confidence: medium.
  Suggested fix: Switch to the stable 3.x Pro ID when Google publishes one.

[NOTE] commits 6645cd1, 379af38 — Each bundles several independent fixes (six wording fixes; a model refresh with three hardening changes)
  Evidence: The user asked for these as batches. Confidence: low that this matters.
  Suggested fix: None.

[NOTE] hw-bootstrap.sh:48 — (carried forward, security) ImageMagick still installs with the stock coder policy; 6645cd1 makes the convention name the input format (`png:in.png`), which blocks a disguised SVG, but the policy itself still allows the SVG and MVG coders
  Suggested fix: Optionally install a raster-only coder allowlist in hw-bootstrap.sh.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:480 — Whether a forked /codereview (`context: fork`) can wait on a background Bash task without polling is unverified; this run executed inline, where the completion notice arrived normally (claude-code)
  Evidence: The built-in argues a forked agent's only way to wait is to end its turn, which could end the review early. Step 7 already relies on forks receiving completion notices for background skill forks, and an early end leaves no marker, so the push is blocked rather than passed. Confidence: medium-low.
  Suggested fix: Watch the first user-typed /codereview; if it ends early at Step 5.6, collect the built-in in the foreground there instead.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:469 — Launching after Step 3 means the built-in never overlaps the test run, so a slow test suite can push its completion past Steps 4 and 5 (claude-code)
  Evidence: By design: launching after the tests avoids two test runs colliding on ports, databases, or temp files (user decision 2026-10-01). In this run it finished about 10 minutes before /security.
  Suggested fix: None now; revisit if Step 5.6 waits become common.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:472 — `2>/dev/null` discards the built-in's stderr, so a recurring failure (expired auth, a changed CLI flag) shows only as `Failed (skipped).` with no reason (claude-code)
  Suggested fix: Send stderr to a sibling mktemp file and record its first line on failure.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md:472 — The built-in resolves its own scope; on a first push it reviews only the last commit while the gate covers the whole tree, and the Step 9 line does not say so (claude-code)
  Evidence: Coverage gap only; the inline review covers the full scope. README documents the scope difference.
  Suggested fix: Have the Step 9 "Built-in review" line note the range the built-in reported reviewing when it differs from the gate's base.

[NOTE] (carried forward) claude/skills/codereview/SKILL.md — The skill is now 672 lines against the CLAUDE.md guideline of about 500; this diff added 57 (claude-code)
  Suggested fix: Move Step 5.6's launch and collect mechanics, or other long sections, to claude/skills/codereview/references/.

[NOTE] (carried forward) (security) The dev box runs service accounts besides peter (cloudflared-daydream, daydream-egress, daydream), and `/proc` does not hide one user's processes from another, so the Accepted Risks that assume a single-user host deserve a second look
  Evidence: SECURITY.md 2026-10-01. The API-key-in-cmdline exposure is inert while no external reviewer keys are configured.
  Suggested fix: Re-evaluate those acceptances.

[NOTE] (carried forward) hooks/allow-venv-source.sh:12 — (security) The auto-mode guard matches only the exact string "auto"; a missing, null, or differently spelled `permission_mode` falls through to `allow`
  Evidence: SECURITY.md 2026-10-01: "Auto", " auto", null, and a missing field each got allow; test line 63 pins allow for a missing field (kept on purpose for pre-auto-mode behavior). The value forked skills receive was not verified, and the commit's live check cannot tell a hook allow from a classifier allow, though this session's transcript records the mode as `auto`. Confidence: high on mechanism, low that any current context sends something other than "auto".
  Suggested fix: Approve only for an explicit list of modes (default, acceptEdits, plan, dontAsk, bypassPermissions) and make no decision otherwise; update test line 63 and the lint pin at tests/lint-skills.sh:1225.

[NOTE] (carried forward) zat.env-install.sh:114 — (carried forward) The reviewer .env exists at the process umask for an instant on first creation before the chmod at :155; it holds only commented template text then.
  Suggested fix: None needed.

[NOTE] (carried forward) zat.env-install.sh:184 — (carried forward) Deny entries accumulate across installs; removing one requires editing settings.json. Deliberate; deny entries only narrow.
  Suggested fix: None needed.

[NOTE] (carried forward) hw-bootstrap.sh:197 — (carried forward, security) Docker group membership lets anything running as the user, including the agent, obtain root without a password.
  Suggested fix: Accept as a risk, or move to rootless Docker.

### Fixes Applied

- [WARN] claude/skills/codereview/SKILL.md:473 — The Step 5.6 child runs with `--disallowedTools "Edit,Write,NotebookEdit"`, and a working-tree reading taken at launch and at collection discards its findings if the tree changed. (claude-code)
- [WARN] claude/skills/codereview/SKILL.md:466 — The tree-change readings exclude CODEREVIEW.md, SECURITY.md, TESTING.md, and SPEC.md, so /security writing SECURITY.md does not discard the built-in's findings; lint pins the excluded form at launch and collection. (found in re-review)
- [WARN] CLAUDE.md:63 — The price tables are described as case blocks in each provider function. (claude-code)
- [WARN] tests/README.md:27 — The light-review skip list is listed as Steps 3, 5, 5.5, 5.6, 6.5, 7. (claude-code)
- [WARN] tests/test-review-external.sh:145 — The nonexistent local-reviewer paths live under the suite's private TEST_DIR. (security)

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh, LICENSE, NOTICE, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.
- **Pre-push gate is advisory; detection is heuristic, not a shell parser** (hooks/pre-push-codereview.sh): `is_git_push` misses wrapper/prefix invocations (`env`, `command`, `bash -c`, `eval`, absolute-path, `xargs`, env-var prefix), and `is_tag_only_push`'s name-based tag test treats a branch named `v[0-9]...` as a tag. Both let a push bypass the codereview gate. Accepted because the gate is an advisory guard against an unsupervised agent, not a security boundary against the human operator, who owns the box and can bypass via `codereview-skip` or `git push --no-verify`.
- **Allow list grants general-purpose interpreters** (zat.env-install.sh:185-217): `Bash(python3 *)` auto-approves `python3 -c '<anything>'`, and `Bash(node *)`, `Bash(pip *)`, `Bash(make *)`, `Bash(git *)` are equivalent. The deny list cannot constrain this, since entries are prefix matches. Since 24a0797, `autoMode.classifyAllShell` sends these through the auto-mode classifier in auto mode (the default), and since 93127a9 so are venv-activation chains; the grant still applies unprompted in the other permission modes. Recorded by the 2026-08-20 scan; re-scoped 2026-10-01.
- **API key visible in `curl -H "Authorization: Bearer ${api_key}"`** (`bin/review-external.sh`): Header argument is visible in `/proc/<pid>/cmdline` to local users during the curl invocation window. Not exploitable on this single-user dev box.
- **Diff content forwarded to third-party APIs** (`bin/review-external.sh`): The full git diff is sent to OpenAI and Google when configured. Secrets in the diff would be exposed. This is the script's explicit purpose and the user opts in by configuring keys.
- **Venv-activation chains auto-approved outside auto mode** (hooks/allow-venv-source.sh:20-24): in default, acceptEdits, plan, and dontAsk modes the hook still returns `allow` for `. .venv/bin/activate && <anything>`, including pipes, `$(...)`, and further commands. Kept deliberately by the user on 2026-10-01 when the auto-mode fix was approved: the hook exists to avoid the eval-like-builtin prompt, and its reach matches the accepted `Bash(python3 *)` and `Bash(make *)` grants in those modes. Recorded by the 2026-10-01 security scan.

---
*Prior review (2026-10-01, commit 55694b7): First live run of Step 5.6 (built-in /code-review high), which produced all three WARNs (built-in classification rules, is_error read, README wording), all fixed; 0 BLOCK / 0 WARN / 22 NOTE.*

<!-- REVIEW_META: {"date":"2026-10-01","commit":"20a4c6c","reviewed_up_to":"20a4c6c83f9c2be7bd0ab38618a766f725d927e5","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":22} -->
