## Review -- 2026-04-08 (commit: 2ae4a3a)

**Summary:** Full review of 20 unpushed commits (v1.3 changes): external reviewer redesign from async hooks to synchronous stdin/stdout script, builder/verifier separation with /codefix, spec direct mode fix, install script stale hook pruning, structural lint expansion (195 checks), and test runner addition. 16 files changed (1077 insertions, 1320 deletions). 215/215 tests pass. Security scan clean (0 findings across 6 files).

**External reviewers:**
[openai] o3 (high) -- 40101 in / 5641 out / 5504 reasoning -- ~$0.1693

### Findings

[NOTE] README.md:804-841 -- Directory overview omits bin/ from the src/zat.env/ subtree
  Evidence: The repo has a `bin/` directory with 4 tracked scripts, but the directory overview under `src/zat.env/` does not include it. The scripts appear at `~/bin/` (their symlink destination) but not at their source location in the repo.
  Suggested fix: Add `bin/` with its contents under the `src/zat.env/` subtree in the directory overview.

### Fixes Applied

- (openai) zat.env-install.sh:133,207: Restored `"Skill(codefix)"` to the permissions allow list and added "codefix" to the verify output message. The removal was unintentional, introduced during the external reviewer cruft cleanup.

### Accepted Risks

None.

---
*Prior review (2026-04-08, commit 7b90170): Refresh review. 0 BLOCK, 0 WARN, 2 NOTE (misleading hook comment, bin/ omitted from directory overview). Zatmux WORK_DIR fix auto-applied.*

<!-- REVIEW_META: {"date":"2026-04-08","commit":"2ae4a3a","reviewed_up_to":"2ae4a3afa2328444fac3f76ea220947ec488943d","base":"origin/main","tier":"full","block":0,"warn":0,"note":1} -->
