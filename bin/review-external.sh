#!/usr/bin/env bash
set -euo pipefail

# External code reviewer: reads a unified diff from stdin, sends it to
# configured LLM providers, and writes findings to stdout. Cost and status
# information goes to stderr. Exits 0 in all cases (fail-open).
#
# Usage:
#   git diff origin/main | review-external.sh                    # default: review the piped diff
#   git diff v1.3..HEAD  | review-external.sh --range v1.3..HEAD # match COMMITS context to range
#   review-external.sh --check                                   # report configured providers
#
# --check: does not read stdin. Loads config and prints one stderr line per
# configured provider (model + effort/budget). Exits 0 if any provider is
# configured, exit 1 with a pointer to the env file if none are. Used by
# /codereview external as a pre-flight gate so an explicit invocation fails
# loudly when nothing is configured. The default no-flag path keeps its
# silent-exit-0 fallback so /codereview Step 5.5 stays fail-open.
#
# --range <git-range>: use the given range for the COMMITS context block
# prepended to the user message. When absent, the script falls back to
# @{upstream}..HEAD (matches /codereview Step 5.5). /codereview external
# passes --range so the COMMITS framing matches the user-supplied range
# rather than the branch's upstream.
#
# Config: ~/.config/claude-reviewers/.env
#   OPENAI_API_KEY, OPENAI_MODEL (default: gpt-6.1-sol), OPENAI_EFFORT (default: high)
#   GEMINI_API_KEY, GEMINI_MODEL (default: gemini-3.1-pro-preview),
#     GEMINI_EFFORT (default: high; a level low|medium|high is sent as thinkingLevel,
#     a number as thinkingBudget; a pinned gemini-2.5 model defaults to budget 32768)
#   LOCAL_REVIEW_SCRIPT, LOCAL_REVIEW_VENV, LOCAL_MODEL (optional local GPU reviewer)
#   REVIEW_TIMEOUT (default: 300, per-provider seconds)
#
# Output (stdout): [SEVERITY] (provider) file:line -- description
# Output (stderr): cost logs, status messages
#
# If no providers are configured, exits 0 with no stdout output (default path)
# or exits 1 with a pointer message on stderr (--check path).
# If a provider fails, that provider is skipped (warning on stderr).

# --- Argument parsing ---

CHECK_ONLY=false
RANGE=""
case "${1:-}" in
  --check)
    if [[ $# -gt 1 ]]; then
      echo "review-external.sh: --check takes no further arguments" >&2
      echo "Usage: review-external.sh [--check]" >&2
      exit 2
    fi
    CHECK_ONLY=true
    ;;
  --range)
    if [[ $# -lt 2 ]]; then
      echo "review-external.sh: --range requires a git range argument" >&2
      echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
      exit 2
    fi
    if [[ $# -gt 2 ]]; then
      echo "review-external.sh: --range takes one argument" >&2
      echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
      exit 2
    fi
    RANGE="$2"
    if [[ -z "${RANGE}" ]]; then
      echo "review-external.sh: --range requires a non-empty git range argument" >&2
      echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
      exit 2
    fi
    ;;
  --range=*)
    if [[ $# -gt 1 ]]; then
      echo "review-external.sh: --range takes one argument" >&2
      echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
      exit 2
    fi
    RANGE="${1#--range=}"
    if [[ -z "${RANGE}" ]]; then
      echo "review-external.sh: --range requires a git range argument" >&2
      echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
      exit 2
    fi
    ;;
  '')
    : # default: read diff from stdin
    ;;
  *)
    echo "review-external.sh: unknown argument '${1}'" >&2
    echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
    exit 2
    ;;
esac

# A range beginning with `-` is parsed by git as an option, not a revision.
# `git log --oneline --output=<path>` truncates and overwrites that path, so an
# unvalidated leading dash is an arbitrary-file-write primitive rather than a
# mere usage error. Enforce it here: codereview SKILL.md Step E.2 also tells the
# model to validate refs, but that prose is LLM-executed and is not an
# enforcement boundary.
if [[ "${RANGE}" == -* ]]; then
  echo "review-external.sh: --range must not begin with '-' (got '${RANGE}')" >&2
  echo "Usage: review-external.sh [--check] [--range <git-range>]" >&2
  exit 2
fi

# --- Read diff from stdin (default path only) ---

if ! ${CHECK_ONLY}; then
  DIFF=$(cat)
  if [[ -z "${DIFF}" ]]; then
    exit 0
  fi
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

# Model defaults and lifecycle. Check these when a provider retires a model:
#   https://developers.openai.com/api/docs/models
#   https://ai.google.dev/gemini-api/docs/models and .../docs/deprecations
OPENAI_DEFAULT_MODEL="gpt-6.1-sol"
GEMINI_DEFAULT_MODEL="gemini-3.1-pro-preview"

# Resolve the Gemini thinking setting for a model and GEMINI_EFFORT value.
# Prints "level <value>" or "budget <n>"; returns 1 for an invalid value.
# Gemini 3.x takes a thinking level; Gemini 2.5 takes a numeric budget.
gemini_thinking() {
  local model="$1" effort="$2"
  if [[ -z "${effort}" ]]; then
    if [[ "${model}" == gemini-2.5* ]]; then effort=32768; else effort=high; fi
  fi
  if [[ "${effort}" =~ ^[0-9]+$ ]]; then
    echo "budget ${effort}"
  elif [[ "${effort}" =~ ^(minimal|low|medium|high)$ ]]; then
    echo "level ${effort}"
  else
    return 1
  fi
}

# --- --check: report providers and exit (fail-loud if none configured) ---

if ${CHECK_ONLY}; then
  any_configured=false
  if ${HAS_OPENAI}; then
    echo "openai: ${OPENAI_MODEL:-${OPENAI_DEFAULT_MODEL}} (${OPENAI_EFFORT:-high})" >&2
    any_configured=true
  fi
  if ${HAS_GOOGLE}; then
    gm="${GEMINI_MODEL:-${GEMINI_DEFAULT_MODEL}}"
    echo "google: ${gm} (thinking $(gemini_thinking "${gm}" "${GEMINI_EFFORT:-}" || echo "setting '${GEMINI_EFFORT:-}' is invalid"))" >&2
    any_configured=true
  fi
  if ${HAS_LOCAL}; then
    echo "local: ${LOCAL_MODEL:-Qwen2.5-Coder-14B-Instruct-AWQ}" >&2
    any_configured=true
  fi
  if ! ${any_configured}; then
    echo "No external reviewers configured." >&2
    echo "Edit ${REVIEWER_ENV} to set OPENAI_API_KEY, GEMINI_API_KEY, or LOCAL_REVIEW_SCRIPT." >&2
    exit 1
  fi
  exit 0
fi

# --- Default path: silent fail-open if no providers ---

if ! ${HAS_OPENAI} && ! ${HAS_GOOGLE} && ! ${HAS_LOCAL}; then
  exit 0
fi

TIMEOUT="${REVIEW_TIMEOUT:-300}"

# `timeout` is GNU coreutils. It is absent on stock macOS, where Homebrew's
# coreutils package installs it as `gtimeout`. Resolve it once here; if
# neither exists, run the provider unwrapped rather than failing it outright
# (the exit-124 branch in call_local then simply never fires). On Linux
# `timeout` always wins this lookup, so behavior there is unchanged.
TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "${TIMEOUT}")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "${TIMEOUT}")
fi

# --- Commit summary (provides context for the diff) ---
# When --range is supplied, use it directly so the COMMITS block matches the
# diff range piped on stdin. Otherwise fall back to @{upstream}..HEAD so the
# default /codereview Step 5.5 path keeps its existing behavior.

COMMIT_SUMMARY=""
if [[ -n "${RANGE}" ]]; then
  COMMIT_SUMMARY=$(git log --oneline "${RANGE}" 2>/dev/null || true)
else
  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || UPSTREAM="origin/$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || UPSTREAM=""
  if [[ -n "${UPSTREAM}" ]]; then
    COMMIT_SUMMARY=$(git log --oneline "${UPSTREAM}..HEAD" 2>/dev/null || true)
  fi
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
trap 'wait 2>/dev/null; rm -f "${SYSTEM_FILE}" "${USER_FILE}" "${OPENAI_OUT:-}" "${GOOGLE_OUT:-}" "${LOCAL_OUT:-}" "${OPENAI_ERR:-}" "${GOOGLE_ERR:-}" "${LOCAL_ERR:-}"' EXIT

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

# Token counts come from the provider's response and reach bc, so accept only
# plain integers; anything else counts as 0 rather than being evaluated.
_count() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then echo "$1"; else echo 0; fi
}

# Provider error messages can echo a redacted copy of the API key, and these
# lines reach the cost log that /codereview copies into CODEREVIEW.md. Strip
# anything key-shaped before printing.
_redact() {
  sed -E 's/(sk-|AIza)[A-Za-z0-9_*.-]+/\1[REDACTED]/g'
}

# --- Provider: OpenAI ---

call_openai() {
  local model="${OPENAI_MODEL:-${OPENAI_DEFAULT_MODEL}}"
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
    echo "[openai] API error: $(printf '%s' "${error_msg}" | _redact), skipping" >&2
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
  input_tokens=$(_count "$(echo "${body}" | jq -r '.usage.input_tokens // 0' 2>/dev/null)")
  output_tokens=$(_count "$(echo "${body}" | jq -r '.usage.output_tokens // 0' 2>/dev/null)")
  reasoning_tokens=$(_count "$(echo "${body}" | jq -r '.usage.output_tokens_details.reasoning_tokens // 0' 2>/dev/null)")

  # USD per 1M tokens. output_tokens already includes reasoning tokens, which
  # are billed as output, so reasoning_tokens is reported but not added again.
  local price_in="" price_out=""
  case "${model}" in
    gpt-6-astra*)             price_in=10;   price_out=50 ;;
    gpt-6.1-sol*|gpt-6-sol*)  price_in=2;    price_out=10 ;;
    gpt-6-luna*)              price_in=0.1;  price_out=0.5 ;;
    o3)                       price_in=2;    price_out=8 ;;
    o4-mini|o3-mini)          price_in=1.10; price_out=4.40 ;;
  esac
  local cost="?"
  if [[ -n "${price_in}" ]]; then
    cost=$(_calc "scale=4; (${input_tokens} * ${price_in} + ${output_tokens} * ${price_out}) / 1000000")
  fi
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
  local model="${GEMINI_MODEL:-${GEMINI_DEFAULT_MODEL}}"
  local api_key="${GEMINI_API_KEY}"

  local thinking thinking_kind thinking_value
  if ! thinking=$(gemini_thinking "${model}" "${GEMINI_EFFORT:-}"); then
    echo "[google] GEMINI_EFFORT='${GEMINI_EFFORT:-}' is not a valid thinking level (low|medium|high) or budget (a number), skipping" >&2
    return 0
  fi
  thinking_kind="${thinking%% *}"
  thinking_value="${thinking#* }"

  local body_file
  body_file=$(mktemp)
  jq -n \
    --rawfile system "${SYSTEM_FILE}" \
    --rawfile user "${USER_FILE}" \
    --arg kind "${thinking_kind}" \
    --arg value "${thinking_value}" \
    '{
      systemInstruction: {
        parts: [{ text: $system }]
      },
      contents: [{
        parts: [{ text: $user }]
      }],
      generationConfig: {
        thinkingConfig: (if $kind == "budget"
                         then { thinkingBudget: ($value | tonumber) }
                         else { thinkingLevel: $value } end)
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
    echo "[google] API error: $(printf '%s' "${error_msg}" | _redact), skipping" >&2
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
  input_tokens=$(_count "$(echo "${body}" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)")
  output_tokens=$(_count "$(echo "${body}" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)")
  thinking_tokens=$(_count "$(echo "${body}" | jq -r '.usageMetadata.thoughtsTokenCount // 0' 2>/dev/null)")

  # USD per 1M tokens; thinking tokens are billed as output. Pro models charge
  # a higher rate for prompts over 200k tokens.
  local price_in="" price_out="" long=false
  [[ "${input_tokens}" -gt 200000 ]] && long=true
  case "${model}" in
    gemini-3.1-pro*) if ${long}; then price_in=4;    price_out=18; else price_in=2;    price_out=12; fi ;;
    gemini-2.5-pro*) if ${long}; then price_in=2.50; price_out=15; else price_in=1.25; price_out=10; fi ;;
  esac
  local cost="?"
  if [[ -n "${price_in}" ]]; then
    cost=$(_calc "scale=4; (${input_tokens} * ${price_in} + (${output_tokens} + ${thinking_tokens}) * ${price_out}) / 1000000")
  fi
  echo "[google] ${model} (thinking ${thinking}) -- ${input_tokens} in / ${output_tokens} out / ${thinking_tokens} thinking -- ~\$${cost}" >&2

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
  output=$(${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} "${python}" "${script}" \
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

OPENAI_OUT=$(mktemp); OPENAI_ERR=$(mktemp)
GOOGLE_OUT=$(mktemp); GOOGLE_ERR=$(mktemp)
LOCAL_OUT=$(mktemp); LOCAL_ERR=$(mktemp)
OPENAI_PID=""
GOOGLE_PID=""
LOCAL_PID=""

if ${HAS_OPENAI}; then
  call_openai > "${OPENAI_OUT}" 2> "${OPENAI_ERR}" &
  OPENAI_PID=$!
fi

if ${HAS_GOOGLE}; then
  call_google > "${GOOGLE_OUT}" 2> "${GOOGLE_ERR}" &
  GOOGLE_PID=$!
fi

if ${HAS_LOCAL}; then
  call_local > "${LOCAL_OUT}" 2> "${LOCAL_ERR}" &
  LOCAL_PID=$!
fi

[[ -n "${OPENAI_PID}" ]] && wait "${OPENAI_PID}" || true
[[ -n "${GOOGLE_PID}" ]] && wait "${GOOGLE_PID}" || true
[[ -n "${LOCAL_PID}" ]] && wait "${LOCAL_PID}" || true

# Separate findings (stdout) from status/cost (stderr).
# Each provider's stdout and stderr were captured to separate files. Only a
# line on a provider's own stdout that carries that provider's own tag becomes
# a finding; everything on its stderr is status or cost and goes to stderr.
# The findings stream becomes EXTERNAL_FINDINGS -> CODEREVIEW.md -> /codefix,
# which holds Edit, so neither a status line nor a line claiming another
# provider's tag can pose as a finding. Nothing is hidden from the user: lines
# that are not findings still reach stderr.
demux() {
  local tag="$1" out="$2" err="$3" line
  local finding_re="^\[(BLOCK|WARN|NOTE)\] \(${tag}\)"
  [[ -s "${err}" ]] && cat "${err}" >&2
  if [[ -s "${out}" ]]; then
    while IFS= read -r line; do
      if [[ "${line}" =~ ${finding_re} ]]; then
        echo "${line}"          # finding -> stdout
      elif [[ -n "${line}" ]]; then
        echo "${line}" >&2      # anything else -> stderr
      fi
    done < "${out}"
  fi
  return 0
}
demux openai "${OPENAI_OUT}" "${OPENAI_ERR}"
demux google "${GOOGLE_OUT}" "${GOOGLE_ERR}"
demux qwen "${LOCAL_OUT}" "${LOCAL_ERR}"
