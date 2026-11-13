# Networking Reference

Machine-specific values. Update these if the machine, domain, or tailnet changes.

- **Public DNS**: `dev.agent-hypervisor.ai` (A record pointing to Hetzner public IP)
- **Tailscale hostname**: `dev` (short) / `dev.emperor-exponential.ts.net` (FQDN)
- **Tailnet**: `emperor-exponential.ts.net`

**Default access model: Tailscale.** All routine access (SSH, web UIs, APIs) goes through the Tailscale mesh. From a Mac or iPad, connect to `dev:PORT` or `dev.emperor-exponential.ts.net:PORT`. Public DNS is reserved for webhook callbacks, external demos, or anything that must be reachable from the open internet.

**Binding addresses for services:**

- Bind to the Tailscale address, not `0.0.0.0`. Take the address once and check it: `TS_IP="$(tailscale ip -4)"`, then `--host "${TS_IP:?Tailscale is not up}"` or the framework's equivalent. Tailnet clients reach it at `dev:PORT`, and nothing reaches it from the public IP, whether or not the firewall is up.
- An empty address must stop the command, never fall back. When Tailscale is stopped, logged out, or still starting, `$(tailscale ip -4)` expands to an empty string, and an empty host binds every interface (Python, uvicorn, and Docker all read it as `0.0.0.0`). The `${TS_IP:?...}` form aborts instead.
- Docker containers: `-p "${TS_IP:?Tailscale is not up}:PORT:PORT"`. A bare `-p PORT:PORT` binds `0.0.0.0`, and Docker's own iptables rules are not filtered by UFW, so that port is public.
- `127.0.0.1` for anything only this machine uses.
- To check a service from this machine, use `dev.emperor-exponential.ts.net:PORT`. On the box itself, `localhost` does not answer a Tailscale-bound service, and the short name `dev` resolves to the public IPv6 address.
- Combine with `--gpus all --shm-size=8g` for GPU workloads (see ml-gpu.md).

**Public DNS (`dev.agent-hypervisor.ai`) use cases:**

- Webhook callbacks from external services (GitHub, Stripe, etc.)
- Temporary demos for external collaborators
- For deliberate public exposure, bind `0.0.0.0` (Docker: `-p PORT:PORT`) for the duration. A service outside Docker also needs a UFW allow rule, which is an operator action.
- Keep public exposure brief. Stop or rebind the service when done.

**Firewall (UFW):** active, set up outside zat.env (`hw-bootstrap.sh` does not configure it). Default policy: deny incoming, allow outgoing. Allowed inbound: SSH (22/tcp), all traffic on `tailscale0`. Docker-published ports are not filtered by these rules. Hetzner may apply additional network-level rules (check Robot panel).

**No reverse proxy.** Services bind directly to ports. If Caddy or nginx is added later, update this section.
