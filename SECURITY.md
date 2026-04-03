## Security Review — 2026-04-03 (scope: hooks/pre-push-codereview.sh)

**Summary:** Reviewed the pre-push codereview hook script. One defense-in-depth gap found in the tag-push bypass regex that could allow a combined branch+tag push to skip the codereview gate. No secrets, injection vectors, or actively exploitable issues.

### Findings

[WARN] hooks/pre-push-codereview.sh:34 — Tag-bypass regex matches branch pushes that include a tag-like argument
  Attack vector: Claude (or a user instructing Claude) issues a command like `git push origin main v1.0`, which pushes both the branch and the tag. The regex `git push .+ v[0-9]` matches, skipping the codereview gate for the branch push. Similarly, `git push origin main --tags` bypasses via the `--tags` glob match.
  Evidence: Line 34-36: `TAG_PATTERN='git push .+ v[0-9]'` followed by `if [[ "${INVOKED_CMD}" =~ ${TAG_PATTERN} ]] || [[ "${INVOKED_CMD}" == *"--tags"* ]]; then exit 0; fi`. The regex has no end anchor and does not verify the push is tag-only.
  Remediation: Parse the push arguments more precisely. For example, reject the bypass if any refspec in the command resolves to a branch. A simpler approach: only match `--tags` when it is the sole refspec mechanism (no branch names present), and anchor the tag pattern to reject commands containing branch-like arguments before the tag.

### Accepted Risks

- **PII in source files** (hw-bootstrap.sh:223, README.md, and other references to `peterzat`): Inherent to a personal dotfiles repo. Reviewed and accepted.

---
*Prior review (2026-04-03, scope: changes-only): Documentation-only metadata updates to CODEREVIEW.md. No findings.*

<!-- SECURITY_META: {"date":"2026-04-03","commit":"e70c427","scope":"hooks/pre-push-codereview.sh","block":0,"warn":1,"note":0} -->
