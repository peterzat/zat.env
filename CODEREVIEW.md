## Review -- 2026-04-02 (commit: 8b52d4a)

**Summary:** Light review of updated hero image and caption in README.md. The screenshot was replaced with an iPhone/ShellFish/tmux photo, and the caption was updated to match. The image file (zat-env.png) was also replaced.

### Findings

[NOTE] README.md:4 -- The `alt` attribute on the `<img>` tag still says "Claude Code running on an iPad" but the image and caption now show an iPhone.
  Evidence: `<img src="zat-env.png" alt="Claude Code running on an iPad" width="480">`
  Suggested fix: Change `alt` to "Claude Code running on an iPhone" or similar.

### Fixes Applied

None.

---
*Prior review (2026-04-02, commit e5dfeee): Refresh review of venv activation allowlist addition. No issues found.*

<!-- REVIEW_META: {"date":"2026-04-02","commit":"8b52d4a","reviewed_up_to":"8b52d4ae6e7099e1d6632c8bc846233347190732","base":"origin/main","tier":"light","block":0,"warn":0,"note":1} -->
