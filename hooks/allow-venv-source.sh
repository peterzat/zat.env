#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: auto-approve "source .venv/bin/activate" and ". .venv/bin/activate"
# commands that trigger the hardcoded eval-like builtin safety warning.

input="$(cat)"

# In auto mode, make no decision so the auto-mode classifier judges the whole
# command. An "allow" here skips the classifier and the permission rules, so it
# would wave through anything chained after the activation.
if [[ "$(echo "$input" | jq -r '.permission_mode // empty')" == "auto" ]]; then
  exit 0
fi

command="$(echo "$input" | jq -r '.tool_input.command // empty')"

# Match exact activation or "activate && <next command>" (the typical chained form).
# Reject other suffixes to prevent auto-approving arbitrary piggybacked commands.
if [[ "$command" == "source .venv/bin/activate" ]] \
  || [[ "$command" == "source .venv/bin/activate && "* ]] \
  || [[ "$command" == ". .venv/bin/activate" ]] \
  || [[ "$command" == ". .venv/bin/activate && "* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved venv activation"}}'
fi
