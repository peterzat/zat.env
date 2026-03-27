#!/usr/bin/env bash
# bootstrap-GEX44.sh — Hetzner GEX44 machine provisioning
#
# Turns a bare Ubuntu 22.04.2 LTS install into a usable dev box.
# Safe to run multiple times (idempotent).
#
# After this script: reboot (required for NVIDIA driver), then re-run to
# complete CUDA + container toolkit setup.
#
# After second run: clone zat.env and run zat.env-install.sh to finish setup.
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as your normal user, not root."
  exit 1
fi

USER_NAME="${USER}"
HOME_DIR="${HOME}"
BIN_DIR="${HOME_DIR}/bin"
SRC_DIR="${HOME_DIR}/src"
DATA_DIR="${HOME_DIR}/data"
LOCAL_BIN="${HOME_DIR}/.local/bin"

mkdir -p "${BIN_DIR}" "${SRC_DIR}" "${DATA_DIR}" "${LOCAL_BIN}"

echo "==> Installing base packages"
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  git \
  git-lfs \
  gnupg \
  jq \
  make \
  build-essential \
  ripgrep \
  fd-find \
  tmux \
  unzip \
  zip \
  htop \
  tree \
  emacs \
  python3 \
  python3-pip \
  python3-venv \
  openssh-client \
  software-properties-common \
  ubuntu-drivers-common

git lfs install || true

echo "==> Installing NVIDIA driver"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "Installing recommended NVIDIA driver via ubuntu-drivers..."
  sudo ubuntu-drivers autoinstall
  echo
  echo "*** REBOOT REQUIRED ***"
  echo "NVIDIA driver installed. Please reboot and re-run this script to"
  echo "complete CUDA toolkit and NVIDIA Container Toolkit setup."
  echo
  echo "  sudo reboot"
  echo
  exit 0
else
  echo "NVIDIA driver already installed:"
  nvidia-smi || true
fi

echo "==> Installing CUDA toolkit"
if ! command -v nvcc >/dev/null 2>&1; then
  curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    -o /tmp/cuda-keyring.deb
  sudo dpkg -i /tmp/cuda-keyring.deb
  sudo apt-get update
  sudo apt-get install -y cuda-toolkit
  rm -f /tmp/cuda-keyring.deb
else
  echo "CUDA toolkit already installed"
fi

echo "==> Installing Docker (Ubuntu package)"
sudo apt-get install -y docker.io docker-compose-v2 || sudo apt-get install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER_NAME}" || true

echo "==> Installing Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "Tailscale already installed"
fi
sudo systemctl enable --now tailscaled

echo "==> Installing Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "Claude already installed"
fi

echo "==> Installing NVIDIA Container Toolkit"
if ! dpkg -l nvidia-container-toolkit >/dev/null 2>&1; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker

  echo "==> Testing GPU in Docker"
  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi || true
else
  echo "NVIDIA Container Toolkit already installed"
fi

echo "==> Writing tmux config"
cat > "${HOME_DIR}/.tmux.conf" <<'EOF'
set -g mouse on
set -g history-limit 200000
set -g base-index 1
setw -g pane-base-index 1
set -g detach-on-destroy off
set -g renumber-windows on
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"
EOF

echo "==> Writing project launcher scripts"

cat > "${BIN_DIR}/ccproj" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  ccproj <project-name> <git-url> [branch]"
  echo
  echo "Examples:"
  echo "  ccproj ranking git@github.com:me/ranking.git"
  echo "  ccproj ranking https://github.com/me/ranking.git main"
  exit 1
}

[[ $# -lt 2 ]] && usage

PROJECT_NAME="$1"
GIT_URL="$2"
BRANCH="${3:-}"
PROJECT_ROOT="${HOME}/src/${PROJECT_NAME}"

mkdir -p "${HOME}/src"

if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
  echo "Cloning ${GIT_URL} into ${PROJECT_ROOT}"
  if [[ -n "${BRANCH}" ]]; then
    git clone --branch "${BRANCH}" "${GIT_URL}" "${PROJECT_ROOT}"
  else
    git clone "${GIT_URL}" "${PROJECT_ROOT}"
  fi
else
  echo "Repo already exists at ${PROJECT_ROOT}"
fi

if tmux has-session -t "${PROJECT_NAME}" 2>/dev/null; then
  exec tmux attach -t "${PROJECT_NAME}"
else
  exec tmux new-session -s "${PROJECT_NAME}" -c "${PROJECT_ROOT}" "claude"
fi
EOF

cat > "${BIN_DIR}/newproj" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  newproj <project-name>"
  echo
  echo "Example:"
  echo "  newproj eval-sandbox"
  exit 1
}

[[ $# -ne 1 ]] && usage

PROJECT_NAME="$1"
PROJECT_ROOT="${HOME}/src/${PROJECT_NAME}"

mkdir -p "${PROJECT_ROOT}"
cd "${PROJECT_ROOT}"

if [[ ! -d .git ]]; then
  git init -b main
fi

if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<'GITEOF'
.env
.venv/
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
node_modules/
dist/
build/
.DS_Store
GITEOF
fi

if [[ ! -f README.md ]]; then
  cat > README.md <<MDEOF
# ${PROJECT_NAME}
MDEOF
fi

if [[ ! -d .venv ]]; then
  echo "Creating .venv..."
  python3 -m venv .venv
fi

if tmux has-session -t "${PROJECT_NAME}" 2>/dev/null; then
  exec tmux attach -t "${PROJECT_NAME}"
else
  exec tmux new-session -s "${PROJECT_NAME}" -c "${PROJECT_ROOT}" "claude"
fi
EOF

cat > "${BIN_DIR}/projattach" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $# -ne 1 ]] && { echo "Usage: projattach <project-name>"; exit 1; }
exec tmux attach -t "$1"
EOF

cat > "${BIN_DIR}/projls" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tmux list-sessions 2>/dev/null || echo "No tmux sessions"
EOF

chmod +x "${BIN_DIR}/ccproj" "${BIN_DIR}/newproj" "${BIN_DIR}/projattach" "${BIN_DIR}/projls"

echo "==> Configuring shell environment"
if ! grep -q 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' "${HOME_DIR}/.bashrc"; then
  echo 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' >> "${HOME_DIR}/.bashrc"
fi

if ! grep -q 'CUDA_HOME' "${HOME_DIR}/.bashrc"; then
  echo 'export CUDA_HOME=/usr/local/cuda' >> "${HOME_DIR}/.bashrc"
  echo 'export PATH="${CUDA_HOME}/bin:${PATH}"' >> "${HOME_DIR}/.bashrc"
fi

if ! grep -q 'PIP_REQUIRE_VIRTUALENV' "${HOME_DIR}/.bashrc"; then
  echo 'export PIP_REQUIRE_VIRTUALENV=true' >> "${HOME_DIR}/.bashrc"
fi

echo "==> Done"
echo
echo "Next steps:"
echo "  1. Log out and back in (docker group membership + updated PATH/env vars)"
echo "  2. Authenticate Tailscale:"
echo "       sudo tailscale up --ssh"
echo "     or, with an auth key:"
echo "       sudo tailscale up --ssh --authkey=tskey-xxxxx"
echo "  3. Set up SSH key for GitHub, then clone and install zat.env:"
echo "       git clone git@github.com:peterzat/zat.env.git ~/src/zat.env"
echo "       ~/src/zat.env/zat.env-install.sh"
echo "  4. Authenticate Claude Code:"
echo "       claude"
echo "  5. Start a new project:"
echo "       newproj scratchpad"
echo "  6. Clone/open an existing repo:"
echo "       ccproj myrepo git@github.com:peterzat/myrepo.git"
echo
echo "GPU notes:"
echo "  - Docker GPU runs: docker run --rm --gpus all --shm-size=8g <image>"
echo "  - PyTorch DataLoader in Docker needs --shm-size=8g or --ipc=host"
echo "  - Verify GPU: nvidia-smi"
