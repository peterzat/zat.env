## Review -- 2026-05-01 (commit: 38157a3)

**Review scope:** Light review. Working-tree diff touches only `README.md` (one plain documentation file). No code or configuration files modified. Two changes: (1) "Four modes" -> "Six modes" in the `/spec` section to match the existing six-bullet list, and (2) a new Roadmap preamble plus "Since v1.3 (ongoing)" section listing four already-shipped post-v1.3 enhancements.

**Summary:** Documentation update reconciling the README with the current state of `main`. Light review scope (factual accuracy of docs, right change to make) per the codereview tier policy.

**External reviewers:**
Skipped (light review).

### Findings

No issues found.

Verified: v1.3 is the most recent tag (`git tag --list 'v*'`); the six-bullet `/spec` mode list (Interview / Direct / Evolve / Propose / Plan / Backlog) at README.md:201-206 matches the new "Six modes" header; `# Durable test-architecture contract` H1 and `Origin: tester design YYYY-MM-DD` references resolve in `claude/skills/tester/SKILL.md`; Step D.5.5 pre-apply checklist exists in tester SKILL.md:413; `bin/codereview-marker` script is present and executable; `purge-origin:` / `append:` / `end-append` ops in `bin/spec-backlog-apply.sh` match the description. The four "Since v1.3" bullets are distinct from items already listed in "Done (v1.3)" (which covered Plan mode and the BACKLOG.md convention itself, not the post-v1.3 enhancements). No broken internal references, no accidental secret leaks, no factual errors.

### Fixes Applied

None.

### Accepted Risks

None.

---
*Prior review (2026-05-01): refresh review of `bin/codereview-marker` extraction (commit ba621cf and follow-on commits 6240448, 38157a3). 0 BLOCK / 1 WARN auto-fixed (directory listing entries in README.md and CLAUDE.md) / 2 NOTE (hook fail-open behavior; COST_LOG split-Bash-call vulnerability noted as future spec evolution).*

<!-- REVIEW_META: {"date":"2026-05-01","commit":"38157a3","reviewed_up_to":"38157a300190255a81c612a45e72542fe113cfbd","base":"origin/main","tier":"light","block":0,"warn":0,"note":0} -->
