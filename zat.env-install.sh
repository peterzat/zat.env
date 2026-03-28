#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as your normal user, not root."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: sudo apt install jq"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

echo "==> zat.env-install: wiring repo config into the live system"
echo "    Repo: ${REPO_DIR}"

# --- git config ---
echo "==> Configuring git globals"
git config --global init.defaultBranch main

GIT_NAME="${GIT_NAME:-$(git config --global user.name 2>/dev/null || true)}"
if [[ -z "${GIT_NAME}" ]]; then
  read -rp "Git user.name: " GIT_NAME
fi
git config --global user.name "${GIT_NAME}"

GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
if [[ -z "${GIT_EMAIL}" ]]; then
  read -rp "Git user.email: " GIT_EMAIL
fi
git config --global user.email "${GIT_EMAIL}"
git config --global core.excludesfile "${REPO_DIR}/gitconfig/ignore-global"

# include.path supports multiple values; only add if not already present
if ! git config --global --get-all include.path | grep -qF "${REPO_DIR}/gitconfig/aliases.gitconfig"; then
  git config --global --add include.path "${REPO_DIR}/gitconfig/aliases.gitconfig"
fi

# --- ~/.claude/CLAUDE.md symlink ---
echo "==> Symlinking ~/.claude/CLAUDE.md -> ${REPO_DIR}/claude/global-claude.md"
mkdir -p "${CLAUDE_DIR}"
if [[ -L "${CLAUDE_DIR}/CLAUDE.md" ]]; then
  rm "${CLAUDE_DIR}/CLAUDE.md"
elif [[ -f "${CLAUDE_DIR}/CLAUDE.md" ]]; then
  echo "    WARNING: ${CLAUDE_DIR}/CLAUDE.md exists and is not a symlink — moving to CLAUDE.md.bak"
  mv "${CLAUDE_DIR}/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md.bak"
fi
ln -s "${REPO_DIR}/claude/global-claude.md" "${CLAUDE_DIR}/CLAUDE.md"

# --- ~/.claude/skills/ symlinks ---
echo "==> Symlinking skills into ${CLAUDE_DIR}/skills/"
mkdir -p "${CLAUDE_DIR}/skills"

for skill_dir in "${REPO_DIR}/claude/skills"/*/; do
  skill_name="$(basename "${skill_dir}")"
  target="${CLAUDE_DIR}/skills/${skill_name}"

  if [[ -L "${target}" ]]; then
    rm "${target}"
  elif [[ -d "${target}" ]]; then
    echo "    WARNING: ${target} exists and is not a symlink — skipping ${skill_name}"
    continue
  fi

  ln -s "${skill_dir}" "${target}"
  echo "    ${skill_name} -> ${skill_dir}"
done

# --- merge pre-push hook into ~/.claude/settings.json ---
echo "==> Merging pre-push hook into ${CLAUDE_DIR}/settings.json"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

if [[ ! -f "${SETTINGS_FILE}" ]]; then
  echo '{}' > "${SETTINGS_FILE}"
fi

# Only add if no existing entry already references our hook script
if jq -e '.hooks.PreToolUse // [] | map(select(.hooks[]?.command // "" | test("pre-push-codereview"))) | length > 0' \
    "${SETTINGS_FILE}" > /dev/null 2>&1; then
  echo "    Hook already present — skipping"
else
  HOOK_COMMAND="bash ${REPO_DIR}/hooks/pre-push-codereview.sh"
  jq --arg cmd "${HOOK_COMMAND}" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse += [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": $cmd,
        "timeout": 10
      }]
    }]
  ' "${SETTINGS_FILE}" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "${SETTINGS_FILE}"
  echo "    Added pre-push hook"
fi

echo "==> Done"
echo
echo "Verify:"
echo "  git st                                    # should work (alias from gitconfig)"
echo "  ls -la ~/.claude/CLAUDE.md               # should be a symlink"
echo "  ls -la ~/.claude/skills/                 # should show codereview, security, architect, tester"
echo "  cat ~/.claude/skills/codereview/SKILL.md # should resolve through symlink"
echo "  jq .hooks ~/.claude/settings.json        # should show pre-push hook"
