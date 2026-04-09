#!/usr/bin/env bash
set -euo pipefail

# External code reviewer: reads a unified diff from stdin, sends it to
# configured LLM providers, and writes findings to stdout. Cost and status
# information goes to stderr. Exits 0 in all cases (fail-open).
#
# Usage: git diff origin/main | review-external.sh
#
# Config: ~/.config/claude-reviewers/.env
#   OPENAI_API_KEY, OPENAI_MODEL (default: o3), OPENAI_EFFORT (default: high)
#   GEMINI_API_KEY, GEMINI_MODEL (default: gemini-2.5-pro), GEMINI_EFFORT (default: 32768)
#   LOCAL_REVIEW_SCRIPT, LOCAL_REVIEW_VENV, LOCAL_MODEL (optional local GPU reviewer)
#   REVIEW_TIMEOUT (default: 300, per-provider seconds)
#
# Output (stdout): [SEVERITY] (provider) file:line -- description
# Output (stderr): cost logs, status messages
#
# If no providers are configured, exits 0 with no stdout output.
# If a provider fails, that provider is skipped (warning on stderr).

# --- Read diff from stdin ---

DIFF=$(cat)
if [[ -z "${DIFF}" ]]; then
  exit 0
fi

# --- Load config ---

REVIEWER_ENV="${CLAUDE_REVIEWER_ENV:-${HOME}/.config/claude-reviewers/.env}"
if [[ -f "${REVIEWER_ENV}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${REVIEWER_ENV}"
  set +a
fi

HAS_OPENAI=false
HAS_GOOGLE=false
HAS_LOCAL=false
[[ -n "${OPENAI_API_KEY:-}" ]] && HAS_OPENAI=true
[[ -n "${GEMINI_API_KEY:-}" ]] && HAS_GOOGLE=true
if [[ -n "${LOCAL_REVIEW_SCRIPT:-}" ]] && [[ -n "${LOCAL_REVIEW_VENV:-}" ]] && [[ -f "${LOCAL_REVIEW_SCRIPT:-}" ]]; then
  HAS_LOCAL=true
fi

if ! ${HAS_OPENAI} && ! ${HAS_GOOGLE} && ! ${HAS_LOCAL}; then
  exit 0
fi

TIMEOUT="${REVIEW_TIMEOUT:-300}"

# --- Commit summary (provides context for the diff) ---

UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || UPSTREAM="origin/$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || UPSTREAM=""
COMMIT_SUMMARY=""
if [[ -n "${UPSTREAM}" ]]; then
  COMMIT_SUMMARY=$(git log --oneline "${UPSTREAM}..HEAD" 2>/dev/null || true)
fi

# --- Review prompt (system instructions) ---

SYSTEM_PROMPT='You are a Principal Software Engineer performing an adversarial code review.

Review the provided diff. Report only findings you have high confidence in.

Evaluate against these dimensions:
1. Correctness: bugs, off-by-one errors, null handling, edge cases, race conditions
2. Security: hardcoded secrets, injection vectors, unsafe deserialization, path traversal, unvalidated input at trust boundaries
3. Code quality: dead code, duplication, inappropriate abstraction level
4. Solution approach: is there a simpler or more robust alternative?
5. Regression risk: could this break existing functionality?

Classify every finding:
- BLOCK: must fix before pushing (bugs, data loss, security vulnerabilities)
- WARN: should fix (missing error handling, untested critical paths)
- NOTE: informational only (optional improvements)

Format each finding EXACTLY as:
[SEVERITY] file:line -- description

Example:
[BLOCK] src/auth.py:42 -- token is compared with == instead of constant-time comparison, timing side-channel
[WARN] lib/config.sh:17 -- TIMEOUT is used unquoted in arithmetic context, will error on empty string

If you find no issues, output exactly: No issues found.

Do not comment on formatting, naming, or style unless they indicate a functional problem. Output only the finding lines. No preamble, no summary, no explanation paragraphs.'

# Build prompt files (avoids ARG_MAX limits).
# SYSTEM_FILE: review instructions. USER_FILE: commit context + diff.
SYSTEM_FILE=$(mktemp)
USER_FILE=$(mktemp)
trap 'wait 2>/dev/null; rm -f "${SYSTEM_FILE}" "${USER_FILE}" "${OPENAI_OUT:-}" "${GOOGLE_OUT:-}" "${LOCAL_OUT:-}"' EXIT

printf '%s\n' "${SYSTEM_PROMPT}" > "${SYSTEM_FILE}"

{
  if [[ -n "${COMMIT_SUMMARY}" ]]; then
    echo "=== COMMITS ==="
    echo "${COMMIT_SUMMARY}"
    echo ""
  fi
  echo "=== DIFF ==="
  echo "${DIFF}"
} > "${USER_FILE}"

# --- Cost calculation ---

_calc() {
  if command -v bc >/dev/null 2>&1; then
    echo "$1" | bc -l
  else
    echo "?"
  fi
}

# --- Provider: OpenAI ---

call_openai() {
  local model="${OPENAI_MODEL:-o3}"
  local effort="${OPENAI_EFFORT:-high}"
  local api_key="${OPENAI_API_KEY}"

  local body_file
  body_file=$(mktemp)
  jq -n \
    --arg model "${model}" \
    --arg effort "${effort}" \
    --rawfile system "${SYSTEM_FILE}" \
    --rawfile user "${USER_FILE}" \
    '{
      model: $model,
      reasoning: { effort: $effort },
      input: [
        { role: "developer", type: "message", content: $system },
        { role: "user", type: "message", content: $user }
      ]
    }' > "${body_file}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    --max-time "${TIMEOUT}" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "@${body_file}" \
    "https://api.openai.com/v1/responses" 2>/dev/null) || {
    rm -f "${body_file}"
    echo "[openai] API call failed (network error), skipping" >&2
    return 0
  }
  rm -f "${body_file}"

  local http_code body
  http_code=$(echo "${response}" | tail -1)
  body=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" != "200" ]]; then
    local error_msg
    error_msg=$(echo "${body}" | jq -r '.error.message // "unknown error"' 2>/dev/null || echo "HTTP ${http_code}")
    echo "[openai] API error: ${error_msg}, skipping" >&2
    return 0
  fi

  local output_text
  output_text=$(echo "${body}" | jq -r '.output[] | select(.type == "message") | .content[] | select(.type == "output_text") | .text' 2>/dev/null || true)

  if [[ -z "${output_text}" ]]; then
    echo "[openai] Empty response, skipping" >&2
    return 0
  fi

  # Cost logging
  local input_tokens output_tokens reasoning_tokens
  input_tokens=$(echo "${body}" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
  output_tokens=$(echo "${body}" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
  reasoning_tokens=$(echo "${body}" | jq -r '.usage.output_tokens_details.reasoning_tokens // 0' 2>/dev/null)

  local cost="?"
  case "${model}" in
    o3)         cost=$(_calc "scale=4; (${input_tokens} * 2 + (${output_tokens} + ${reasoning_tokens}) * 8) / 1000000") ;;
    o4-mini|o3-mini) cost=$(_calc "scale=4; (${input_tokens} * 1.10 + (${output_tokens} + ${reasoning_tokens}) * 4.40) / 1000000") ;;
    *)          cost=$(_calc "scale=4; (${input_tokens} * 2 + (${output_tokens} + ${reasoning_tokens}) * 8) / 1000000") ;;
  esac
  echo "[openai] ${model} (${effort}) -- ${input_tokens} in / ${output_tokens} out / ${reasoning_tokens} reasoning -- ~\$${cost}" >&2

  # Tag findings with provider
  echo "${output_text}" | while IFS= read -r line; do
    if [[ "${line}" =~ ^\[(BLOCK|WARN|NOTE)\] ]]; then
      echo "${line}" | sed -E 's/^\[([A-Z]+)\]/[\1] (openai)/'
    elif [[ "${line}" == "No issues found." ]]; then
      echo "[openai] No issues found." >&2
    fi
  done
}

# --- Provider: Google ---

call_google() {
  local model="${GEMINI_MODEL:-gemini-2.5-pro}"
  local thinking_budget="${GEMINI_EFFORT:-32768}"
  local api_key="${GEMINI_API_KEY}"

  if ! [[ "${thinking_budget}" =~ ^[0-9]+$ ]]; then
    echo "[google] GEMINI_EFFORT='${thinking_budget}' is not a valid number, skipping" >&2
    return 0
  fi

  local body_file
  body_file=$(mktemp)
  jq -n \
    --rawfile system "${SYSTEM_FILE}" \
    --rawfile user "${USER_FILE}" \
    --argjson budget "${thinking_budget}" \
    '{
      systemInstruction: {
        parts: [{ text: $system }]
      },
      contents: [{
        parts: [{ text: $user }]
      }],
      generationConfig: {
        thinkingConfig: {
          thinkingBudget: $budget
        }
      }
    }' > "${body_file}"

  local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    --max-time "${TIMEOUT}" \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: ${api_key}" \
    -d "@${body_file}" \
    "${url}" 2>/dev/null) || {
    rm -f "${body_file}"
    echo "[google] API call failed (network error), skipping" >&2
    return 0
  }
  rm -f "${body_file}"

  local http_code body
  http_code=$(echo "${response}" | tail -1)
  body=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" != "200" ]]; then
    local error_msg
    error_msg=$(echo "${body}" | jq -r '.error.message // "unknown error"' 2>/dev/null || echo "HTTP ${http_code}")
    echo "[google] API error: ${error_msg}, skipping" >&2
    return 0
  fi

  local output_text
  output_text=$(echo "${body}" | jq -r '
    .candidates[0].content.parts[]
    | select(.thought != true)
    | .text // empty
  ' 2>/dev/null || true)

  if [[ -z "${output_text}" ]]; then
    echo "[google] Empty response, skipping" >&2
    return 0
  fi

  # Cost logging
  local input_tokens output_tokens thinking_tokens
  input_tokens=$(echo "${body}" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
  output_tokens=$(echo "${body}" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)
  thinking_tokens=$(echo "${body}" | jq -r '.usageMetadata.thoughtsTokenCount // 0' 2>/dev/null)

  local cost="?"
  case "${model}" in
    gemini-2.5-pro*)  cost=$(_calc "scale=4; (${input_tokens} * 1.25 + (${output_tokens} + ${thinking_tokens}) * 10) / 1000000") ;;
    gemini-2.5-flash*) cost=$(_calc "scale=4; (${input_tokens} * 0.15 + ${output_tokens} * 0.60 + ${thinking_tokens} * 3.50) / 1000000") ;;
    *)                cost=$(_calc "scale=4; (${input_tokens} * 1.25 + (${output_tokens} + ${thinking_tokens}) * 10) / 1000000") ;;
  esac
  echo "[google] ${model} (budget: ${thinking_budget}) -- ${input_tokens} in / ${output_tokens} out / ${thinking_tokens} thinking -- ~\$${cost}" >&2

  # Tag findings with provider
  echo "${output_text}" | while IFS= read -r line; do
    if [[ "${line}" =~ ^\[(BLOCK|WARN|NOTE)\] ]]; then
      echo "${line}" | sed -E 's/^\[([A-Z]+)\]/[\1] (google)/'
    elif [[ "${line}" == "No issues found." ]]; then
      echo "[google] No issues found." >&2
    fi
  done
}

# --- Provider: Local (qwen) ---

call_local() {
  local script="${LOCAL_REVIEW_SCRIPT}"
  local venv="${LOCAL_REVIEW_VENV}"
  local python="${venv}/bin/python3"
  if [[ ! -x "${python}" ]]; then
    echo "[qwen] venv python not found at ${python}, skipping" >&2
    return 0
  fi

  local stderr_file
  stderr_file=$(mktemp)

  local output
  output=$(timeout "${TIMEOUT}" "${python}" "${script}" \
    --system "${SYSTEM_FILE}" \
    --input "${USER_FILE}" \
    2>"${stderr_file}") || {
    local exit_code=$?
    local stderr_content
    stderr_content=$(cat "${stderr_file}")
    rm -f "${stderr_file}"
    if [[ ${exit_code} -eq 124 ]]; then
      echo "[qwen] Timed out after ${TIMEOUT}s, skipping" >&2
    elif [[ ${exit_code} -eq 137 ]]; then
      echo "[qwen] Killed by OOM killer (exit 137), skipping" >&2
    else
      echo "[qwen] Script failed (exit ${exit_code}), skipping" >&2
    fi
    [[ -n "${stderr_content}" ]] && echo "${stderr_content}" >&2
    return 0
  }

  # Forward stderr (timing/status info)
  local stderr_content
  stderr_content=$(cat "${stderr_file}")
  rm -f "${stderr_file}"
  [[ -n "${stderr_content}" ]] && echo "${stderr_content}" >&2

  # Emit a status line only if review.py didn't produce its own.
  if [[ "${stderr_content}" != *"[qwen]"* ]]; then
    local model_name="${LOCAL_MODEL:-Qwen2.5-Coder-14B-Instruct-AWQ}"
    echo "[qwen] ${model_name} -- local inference -- \$0.00" >&2
  fi

  if [[ -z "${output}" ]]; then
    echo "[qwen] Empty response, skipping" >&2
    return 0
  fi

  # Tag findings with provider
  echo "${output}" | while IFS= read -r line; do
    if [[ "${line}" =~ ^\[(BLOCK|WARN|NOTE)\] ]]; then
      echo "${line}" | sed -E 's/^\[([A-Z]+)\]/[\1] (qwen)/'
    elif [[ "${line}" == "No issues found." ]]; then
      echo "[qwen] No issues found." >&2
    fi
  done
}

# --- Main: run configured providers in parallel ---

OPENAI_OUT=$(mktemp)
GOOGLE_OUT=$(mktemp)
LOCAL_OUT=$(mktemp)
OPENAI_PID=""
GOOGLE_PID=""
LOCAL_PID=""

if ${HAS_OPENAI}; then
  call_openai > "${OPENAI_OUT}" 2>&1 &
  OPENAI_PID=$!
fi

if ${HAS_GOOGLE}; then
  call_google > "${GOOGLE_OUT}" 2>&1 &
  GOOGLE_PID=$!
fi

if ${HAS_LOCAL}; then
  call_local > "${LOCAL_OUT}" 2>&1 &
  LOCAL_PID=$!
fi

[[ -n "${OPENAI_PID}" ]] && wait "${OPENAI_PID}" || true
[[ -n "${GOOGLE_PID}" ]] && wait "${GOOGLE_PID}" || true
[[ -n "${LOCAL_PID}" ]] && wait "${LOCAL_PID}" || true

# Separate findings (stdout) from status/cost (stderr).
# Provider functions write findings to stdout and cost to stderr, but since
# we captured both with 2>&1 for background jobs, they are mixed.
for outfile in "${OPENAI_OUT}" "${GOOGLE_OUT}" "${LOCAL_OUT}"; do
  if [[ -s "${outfile}" ]]; then
    while IFS= read -r line; do
      if [[ "${line}" =~ ^\[(BLOCK|WARN|NOTE)\] ]]; then
        echo "${line}"          # findings -> stdout
      elif [[ -n "${line}" ]]; then
        echo "${line}" >&2      # cost/status -> stderr
      fi
    done < "${outfile}"
  fi
done
