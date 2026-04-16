# Hardware Setup: Hetzner GEX44

Full provisioning walkthrough for the Hetzner GEX44 dedicated server used for development. See the [README](../README.md#current-hardware) for machine specs and the agentic framework documentation.

The agentic workflow itself runs on any Linux machine with git, jq, and Claude Code. This guide covers the specific bare-metal setup, including NVIDIA driver installation, CUDA toolkit, Docker GPU access, and Tailscale networking. Nothing here is GEX44-specific except the NVIDIA driver version selection in Phase 3; `hw-bootstrap.sh` works on any Ubuntu box with a supported GPU.

---

## Setup From Scratch

Starting from a bare Hetzner Ubuntu 22.04.2 LTS install with root SSH access. These steps reflect the actual setup of this machine (March 2026, driver 590-server, CUDA 13.1).

**Phase 1: Create user (as root)**

SSH in as root using the IP from the Hetzner Robot panel:

```bash
ssh root@<public-ip>
```

Create a sudo-enabled user and copy the SSH authorized keys:

```bash
adduser peter
usermod -aG sudo peter
mkdir -p /home/peter/.ssh
cp /root/.ssh/authorized_keys /home/peter/.ssh/authorized_keys
chown -R peter:peter /home/peter/.ssh
chmod 700 /home/peter/.ssh
chmod 600 /home/peter/.ssh/authorized_keys
exit
```

`adduser` prompts for a password and full name ("Peter Zatloukal"). The rest can be left blank.

**Phase 2: First bootstrap run (as peter)**

SSH back in as peter and run the bootstrap script:

```bash
ssh peter@<public-ip>
sudo -v
```

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/peterzat/zat.env.git ~/src/zat.env
cd ~/src/zat.env
bash hw-bootstrap.sh
```

The script installs base packages (build-essential, emacs, ripgrep, Python 3, etc.), then stops at the NVIDIA driver section. It prints a list of available GPGPU drivers from `ubuntu-drivers list --gpgpu` and exits with instructions. Do not reboot yet.

**Phase 3: NVIDIA driver (manual)**

From the list the script printed, pick the highest `-server` (non-open) branch. In March 2026 that was `590-server`. Do not use `-open` or headless variants.

Install kernel headers first so DKMS can build the module, then install the driver:

```bash
sudo apt-get install -y linux-headers-$(uname -r)
sudo apt-get install -y \
  linux-modules-nvidia-590-server-$(uname -r) \
  nvidia-driver-590-server \
  nvidia-utils-590-server
```

The `linux-modules-nvidia` package provides pre-built kernel modules for your running kernel. The `linux-headers` package enables DKMS to rebuild them if needed (e.g., after a kernel update).

Validate before rebooting:

```bash
sudo modprobe nvidia && nvidia-smi
```

You should see the RTX 4000 SFF Ada with 20475 MiB memory and driver version 590.48.01. If `nvidia-smi` fails but `modprobe` succeeded, verify that the headers package matches your running kernel (`uname -r`) and re-run the driver install to trigger the DKMS build. If `modprobe` itself fails, check `dmesg` and do NOT reboot.

Once `nvidia-smi` shows the GPU:

```bash
sudo reboot
```

**Phase 4: Second bootstrap run**

SSH back in (allow ~60 seconds for reboot):

```bash
ssh peter@<public-ip>
```

Verify the driver survived the reboot:

```bash
nvidia-smi
```

Run the bootstrap script again to complete CUDA toolkit, Docker, Tailscale, Claude Code, and NVIDIA Container Toolkit:

```bash
cd ~/src/zat.env
bash hw-bootstrap.sh
```

The Docker GPU test at the end may fail with a "permission denied" error. This is expected because your user is not yet in the `docker` group (the script added you, but it takes effect on next login). Log out and back in:

```bash
exit
```

```bash
ssh peter@<public-ip>
```

Verify Docker GPU access:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

**Phase 5: Tailscale, hostname, system updates**

Authenticate Tailscale:

```bash
sudo tailscale up --ssh
```

This prints a one-time auth URL (`https://login.tailscale.com/a/<xxx>`). Open it in a browser to authenticate. On success, `tailscale status` shows your machine and any other devices on your tailnet.

Fix the Hetzner default hostname (`Ubuntu-2204-jammy-amd64-base`):

```bash
sudo hostnamectl set-hostname dev
sudo sed -i 's/Ubuntu-2204-jammy-amd64-base/dev/g' /etc/hosts
sudo tailscale up --ssh --hostname=dev
```

Verify:

```bash
hostname -f
tailscale status
```

`hostname -f` should return `dev`. `tailscale status` should show `dev` as the machine name with your tailnet identity (`peterzat@`).

**Networking identity (machine-specific):**

The hostname (`dev`), tailnet (`emperor-exponential.ts.net`), and any public DNS record (`dev.agent-hypervisor.ai`) are configured at this point. If you are setting up a different machine, substitute your own values. These values are referenced in `claude/references/networking.md` and should be updated there if they change.

Apply pending system updates (this typically pulls a new kernel):

```bash
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo reboot
```

DKMS automatically rebuilds the NVIDIA module for the new kernel during `dist-upgrade`. You will see "Autoinstall on 5.15.0-NNN-generic succeeded for module(s) nvidia-srv" in the output.

After reboot, connect via Tailscale SSH from your client machine:

```bash
ssh peter@<tailscale-ip>
```

The first Tailscale SSH connection prompts for browser-based authentication. After that, `ssh peter@dev` works if your client resolves Tailscale MagicDNS names (e.g., from a Mac on the same tailnet).

Verify the hostname stuck. Hetzner's installimage puts the old hostname on the public IP lines in `/etc/hosts`, and a kernel update may regenerate those entries. If `hostname -f` still returns `dev`, you're fine. If the IP lines reverted, fix them:

```bash
cat /etc/hosts
# If the public IP lines still say Ubuntu-2204-jammy-amd64-base:
sudo sed -i 's/Ubuntu-2204-jammy-amd64-base/dev/g' /etc/hosts
```

Final sanity check:

```bash
hostname -f
nvidia-smi
tailscale status
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

**Phase 6: zat.env config and Claude Code**

From here on, connect via Tailscale SSH (`ssh peter@dev` or `ssh peter@dev.emperor-exponential.ts.net`).

Generate an SSH key for GitHub:

```bash
ssh-keygen -t ed25519 -C "peterzat"
cat ~/.ssh/id_ed25519.pub
```

Add the public key at https://github.com/settings/keys, then verify access:

```bash
ssh -T git@github.com
```

You should see "Hi peterzat! You've successfully authenticated". Then install the GitHub CLI (`gh` is not in Ubuntu 22.04's default repos, so the fallback adds GitHub's APT repository):

```bash
sudo apt-get update -qq && sudo apt-get install -y gh || {
  sudo sh -c 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /usr/share/keyrings/githubcli-archive-keyring.gpg &&
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list &&
  apt-get update -qq && apt-get install -y gh'
}
gh auth login
```

Install the zat.env config:

```bash
~/src/zat.env/zat.env-install.sh
```

The install script prompts for git `user.name` and `user.email` on first run, then symlinks skills, hooks, and conventions into place.

Authenticate Claude Code:

```bash
claude
```

Follow the browser-based auth flow. Once authenticated, exit and start a new session to pick up the installed skills:

```bash
mkdir -p ~/src/scratchpad && cd ~/src/scratchpad && zatmux
```
