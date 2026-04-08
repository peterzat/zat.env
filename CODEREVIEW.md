## Review -- 2026-04-08 (commit: 7b90170)

**Summary:** Refresh review. Focus: 2 file(s) changed since prior review (commit 5124de5). 0 already-reviewed file(s). One BLOCK found and auto-fixed in zatmux (WORK_DIR pointed to non-existent directory after dot-to-underscore session name sanitization). Two NOTEs carried forward from prior review.

**External reviewers:**
none configured

### Findings

[NOTE] hooks/post-codereview-external.sh:8-11 -- Header comment claims mtime filtering that does not exist
  Evidence: Lines 8-11 say "CODEREVIEW.md is newer than the results file (filtering out sub-skill completions like /security or /codefix)" but no mtime comparison exists in the code. The actual sub-skill guard is placeholder detection (lines 45-57). The comment is misleading about the guard mechanism.
  Suggested fix: Remove the mtime claim from the comment. The placeholder-based guard is the actual mechanism.

[NOTE] README.md:840-879 -- Directory overview omits bin/ from repo tree
  Evidence: The `~/bin/` listing at line 831 shows the symlinked scripts, but the `src/zat.env/` subtree (lines 840-879) does not include the `bin/` directory. The bin/ directory is tracked in git and is part of the repo, but the overview only shows it at the symlink destination.
  Suggested fix: Add the `bin/` subtree back under `src/zat.env/` in the directory overview, alongside hooks/ and tests/.

### Fixes Applied

- bin/zatmux:20-22: Introduced `PROJECT` variable to hold the original `BASH_REMATCH[1]` value. SESSION is derived from PROJECT with dot-to-underscore sanitization. WORK_DIR now uses PROJECT (the real directory name) instead of SESSION (the sanitized tmux session name). Tests: 89/89 pass.

### Accepted Risks

None.

---
*Prior review (2026-04-08, commit 5124de5): Refresh review of external reviewer pipeline hardening. 0 BLOCK, 0 WARN, 2 NOTE. Auto-fix: guarded test-external-hooks.sh for machines without API keys.*

<!-- REVIEW_META: {"date":"2026-04-08","commit":"7b90170","reviewed_up_to":"7b901704bfd96abcbdd070cbbfe4de53076178ce","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":2,"external_reviewers":[]} -->
