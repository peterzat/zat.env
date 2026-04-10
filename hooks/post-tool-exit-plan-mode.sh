#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: after the user exits Claude Code's built-in plan mode,
# inject a reminder pointing at `/spec plan` as the path to convert the saved
# plan into a persistent SPEC.md. Always fires when ExitPlanMode is the tool.
#
# Design rationale: plan mode is built into Claude Code and outside zat.env's
# control, so its prompt cannot be modified to document the /spec handoff.
# This PostToolUse hook is the deterministic place to remind the main-context
# Claude (and the user) that /spec plan exists, right after the plan has been
# saved. This answers the "how do we remember" question for the plan-mode ->
# /spec plan handoff. See the /spec skill's Step 3e for the consumer side.
#
# Installed via ~/.claude/settings.json by zat.env-install.sh with matcher
# "ExitPlanMode". The hook is scoped to ExitPlanMode by the matcher, but we
# double-check tool_name as a safety net in case the matcher is ever broadened.
#
# Output contract: plain text on stdout is added as context that the next-turn
# model sees. No JSON is required for this simple reminder case.

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty' 2>/dev/null || true)

# Matcher should already scope this, but guard against misconfiguration.
if [[ "${TOOL_NAME}" != "ExitPlanMode" ]]; then
  exit 0
fi

cat <<'EOF'
Plan saved to ~/.claude/plans/. If this work is non-trivial and would benefit
from a persistent, review-gated spec (survives sessions, integrates with
/codereview, produces testable acceptance criteria), run `/spec plan` now
instead of implementing directly. Plan mode is good for one-off scratch
planning; `/spec plan` is the commit point when the thinking needs to become
a contract. Use `/spec plan <slug>` to adopt a specific plan instead of the
most recent one.
EOF

exit 0
