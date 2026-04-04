#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: auto-approve "source .venv/bin/activate" and ". .venv/bin/activate"
# commands that trigger the hardcoded eval-like builtin safety warning.

input="$(cat)"
command="$(echo "$input" | jq -r '.tool_input.command // empty')"

# Match exact activation or "activate && <next command>" (the typical chained form).
# Reject other suffixes to prevent auto-approving arbitrary piggybacked commands.
if [[ "$command" == "source .venv/bin/activate" ]] \
  || [[ "$command" == "source .venv/bin/activate && "* ]] \
  || [[ "$command" == ". .venv/bin/activate" ]] \
  || [[ "$command" == ". .venv/bin/activate && "* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved venv activation"}}'
fi
