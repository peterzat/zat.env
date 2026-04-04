#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: auto-approve "source .venv/bin/activate" and ". .venv/bin/activate"
# commands that trigger the hardcoded eval-like builtin safety warning.

input="$(cat)"
command="$(echo "$input" | jq -r '.tool_input.command // empty')"

if [[ "$command" == "source .venv/bin/activate"* ]] || [[ "$command" == ". .venv/bin/activate"* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved venv activation"}}'
fi
