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
while [[ -z "${GIT_NAME}" ]]; do
  read -rp "Git user.name: " GIT_NAME
done
git config --global user.name "${GIT_NAME}"

GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
while [[ -z "${GIT_EMAIL}" ]]; do
  read -rp "Git user.email: " GIT_EMAIL
done
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

# --- ~/bin helper scripts ---
echo "==> Symlinking helper scripts into ~/bin/"
BIN_DIR="${HOME}/bin"
mkdir -p "${BIN_DIR}"

for script in "${REPO_DIR}/bin"/*; do
  script_name="$(basename "${script}")"
  target="${BIN_DIR}/${script_name}"

  if [[ -L "${target}" ]]; then
    rm "${target}"
  elif [[ -f "${target}" ]]; then
    echo "    WARNING: ${target} exists and is not a symlink — replacing with symlink"
    rm "${target}"
  fi

  ln -s "${script}" "${target}"
  echo "    ${script_name} -> ${script}"
done

# --- merge permissions and hooks into ~/.claude/settings.json ---
echo "==> Merging permissions and hooks into ${CLAUDE_DIR}/settings.json"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

if [[ ! -f "${SETTINGS_FILE}" ]]; then
  echo '{}' > "${SETTINGS_FILE}"
fi

# Replace permissions: defaultMode, allow list, deny list.
# Clean slate on each install to prevent session-accumulated cruft.
jq '
  .permissions = {
    "defaultMode": "auto",
    "allow": [
      "Bash(git *)",
      "Bash(gh *)",
      "Bash(python3 *)",
      "Bash(pip *)",
      "Bash(npm *)",
      "Bash(node *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(which *)",
      "Bash(command -v *)",
      "Bash(cat *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(wc *)",
      "Bash(diff *)",
      "Bash(jq *)",
      "Bash(bash -n *)",
      "Bash(make *)",
      "Bash(. .venv/bin/activate && *)",
      "Skill(codereview)",
      "Skill(security)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl * | bash *)",
      "Bash(wget * | bash *)"
    ]
  }
' "${SETTINGS_FILE}" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "${SETTINGS_FILE}"
echo "    Set permissions (defaultMode, allow list, deny list)"

# Remove any existing pre-push-codereview entry (may be old format without "if" field),
# then add the current version. This keeps the hook config up to date on re-runs.
HOOK_COMMAND="bash ${REPO_DIR}/hooks/pre-push-codereview.sh"
jq --arg cmd "${HOOK_COMMAND}" '
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  .hooks.PreToolUse = [.hooks.PreToolUse[] | select(.hooks | map(.command // "" | test("pre-push-codereview")) | any | not)] |
  .hooks.PreToolUse += [{
    "matcher": "Bash",
    "if": "Bash(git push*)",
    "hooks": [{
      "type": "command",
      "command": $cmd,
      "timeout": 10
    }]
  }]
' "${SETTINGS_FILE}" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "${SETTINGS_FILE}"
echo "    Added pre-push hook"

echo "==> Done"
echo
echo "Verify:"
echo "  git st                                    # should work (alias from gitconfig)"
echo "  ls -la ~/.claude/CLAUDE.md               # should be a symlink"
echo "  ls -la ~/.claude/skills/                 # should show spec, codereview, security, architect, tester, pr"
echo "  cat ~/.claude/skills/codereview/SKILL.md # should resolve through symlink"
echo "  ls -la ~/bin/                            # should show symlinks to repo bin/"
echo "  jq .permissions ~/.claude/settings.json   # should show allow/deny lists
  jq .hooks ~/.claude/settings.json        # should show pre-push hook"
