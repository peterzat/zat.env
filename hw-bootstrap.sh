#!/usr/bin/env bash
# hw-bootstrap.sh — Hetzner GEX44 machine provisioning
#
# Turns a bare Ubuntu 22.04.2 LTS install into a usable dev box.
# Safe to run multiple times (idempotent).
#
# Run 1: installs base packages, then stops at NVIDIA driver with
#   instructions for manual install. Install the driver, validate
#   with modprobe, then reboot.
# Run 2: installs CUDA toolkit, Docker, Tailscale, Claude Code,
#   NVIDIA Container Toolkit, tmux config, helper scripts, and
#   shell environment.
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
  shellcheck \
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

echo "==> Checking NVIDIA driver"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo
  echo "No NVIDIA driver detected. This script does NOT auto-install NVIDIA"
  echo "drivers. The wrong driver can brick a remote headless box with no"
  echo "recovery path short of an OS reinstall."
  echo
  echo "You are responsible for choosing and installing the correct driver."
  echo
  echo "Available server/compute (GPGPU) drivers for this machine:"
  echo "------------------------------------------------------------"
  sudo ubuntu-drivers list --gpgpu 2>/dev/null || echo "  (ubuntu-drivers list --gpgpu returned no results)"
  echo "------------------------------------------------------------"
  echo
  echo "For the GEX44 (RTX 4000 SFF Ada, Ubuntu 22.04), install the"
  echo "server driver with the proprietary kernel module. Pick the highest"
  echo "-server (non-open) branch from the list above. Do NOT use -open"
  echo "or headless variants."
  echo
  echo "Install kernel headers first so DKMS can build the module:"
  echo
  echo "  sudo apt-get install -y linux-headers-\$(uname -r)"
  echo
  echo "Then install the driver. Replace 590 with whichever server branch"
  echo "number appeared highest in the list above:"
  echo
  echo "  sudo apt-get install -y \\"
  echo "    linux-modules-nvidia-590-server-\$(uname -r) \\"
  echo "    nvidia-driver-590-server \\"
  echo "    nvidia-utils-590-server"
  echo
  echo "The linux-modules-nvidia package provides pre-built kernel modules."
  echo "If it is not available for your running kernel, the DKMS fallback"
  echo "builds from source (requires the headers installed above)."
  echo
  echo "Validate BEFORE rebooting:"
  echo
  echo "  sudo modprobe nvidia && nvidia-smi"
  echo
  echo "If modprobe succeeds and nvidia-smi shows the GPU, reboot is safe."
  echo "If nvidia-smi fails but modprobe succeeded, verify that"
  echo "linux-headers-\$(uname -r) is installed and re-run the driver"
  echo "install to trigger the DKMS build."
  echo "If modprobe itself fails, check dmesg and do NOT reboot."
  echo
  echo "  sudo reboot"
  echo
  echo "Then re-run this script to complete CUDA toolkit and container"
  echo "toolkit setup."
  echo
  echo "RESCUE: If the machine does not come back after reboot, activate"
  echo "Hetzner rescue mode via the Robot panel, then:"
  echo
  echo "  mount /dev/sda2 /mnt        # adjust device as needed"
  echo "  mount -t proc none /mnt/proc"
  echo "  mount -o bind /dev /mnt/dev"
  echo "  mount -o bind /sys /mnt/sys"
  echo "  chroot /mnt /bin/bash"
  echo "  apt-get purge 'nvidia-*'"
  echo "  update-initramfs -u"
  echo "  exit"
  echo "  umount -R /mnt"
  echo "  reboot"
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
set -g window-size latest
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"
EOF

echo "==> Helper scripts (zatmux, etc.) are installed by zat.env-install.sh"

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
echo "  3. Set up GitHub access (SSH key + gh CLI — see README Phase 6)"
echo "  4. Install zat.env config (repo should already be cloned at ~/src/zat.env):"
echo "       ~/src/zat.env/zat.env-install.sh"
echo "  5. Authenticate Claude Code:"
echo "       claude"
echo "  6. Start working on a project:"
echo "       cd ~/src/myrepo && zatmux"
echo
echo "GPU notes:"
echo "  - Docker GPU runs: docker run --rm --gpus all --shm-size=8g <image>"
echo "  - PyTorch DataLoader in Docker needs --shm-size=8g or --ipc=host"
echo "  - Verify GPU: nvidia-smi"
