## Review — 2026-03-28 (commit: d72eb17)

**Summary:** Reviewed 3 uncommitted changes: `settings.local.json` gains 4 new Bash permissions, `README.md` reorganizes the GEX44 hardware section to the bottom and rewrites the lead paragraphs, `CODEREVIEW.md` updated. Light review applied.

### Findings

[NOTE] `.claude/settings.local.json`:27 — `Bash(BYPASS_CODEREVIEW=1 git push)` allows a command that does not work as a bypass. The pre-push hook checks for a skip marker file only; it does not read environment variables. This permission was flagged BLOCK in the prior review and retained unchanged, so it is treated as human-reviewed and accepted.

### Fixes Applied

None.

---
*Prior review (2026-03-28, commit da70497): BLOCK — `Bash(BYPASS_CODEREVIEW=1 git push)` permission grants access to a non-functional bypass; pre-push hook uses skip-marker file, not env vars. No auto-fix applied.*

<!-- REVIEW_META: {"date":"2026-03-28","commit":"d72eb17","block":0,"warn":0,"note":1} -->
