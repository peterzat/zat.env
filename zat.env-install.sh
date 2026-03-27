#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as your normal user, not root."
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

echo "==> zat.env-install: wiring repo config into the live system"
echo "    Repo: ${REPO_DIR}"

# --- git config ---
echo "==> Configuring git globals"
git config --global init.defaultBranch main
git config --global user.name "peterzat"
git config --global user.email "peter@zatloukal.com"
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

echo "==> Done"
echo
echo "Verify:"
echo "  git st                          # should work (alias from gitconfig)"
echo "  ls -la ~/.claude/CLAUDE.md     # should be a symlink"
