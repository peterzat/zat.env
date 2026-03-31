# Networking Reference

Machine-specific values. Update these if the machine, domain, or tailnet changes.

- **Public DNS**: `dev.agent-hypervisor.ai` (A record pointing to Hetzner public IP)
- **Tailscale hostname**: `dev` (short) / `dev.emperor-exponential.ts.net` (FQDN)
- **Tailnet**: `emperor-exponential.ts.net`

**Default access model: Tailscale.** All routine access (SSH, web UIs, APIs) goes through the Tailscale mesh. From a Mac or iPad, connect to `dev:PORT` or `dev.emperor-exponential.ts.net:PORT`. Public DNS is reserved for webhook callbacks, external demos, or anything that must be reachable from the open internet.

**Binding addresses for services:**

- Local dev server (no Docker): bind `0.0.0.0` so Tailscale clients can reach it. `127.0.0.1` is local-only.
- Docker containers: `-p PORT:PORT` (binds `0.0.0.0`). Never `-p 127.0.0.1:PORT:PORT` unless the service must be unreachable from Tailscale.
- Combine with `--gpus all --shm-size=8g` for GPU workloads (see ml-gpu.md).

**Public DNS (`dev.agent-hypervisor.ai`) use cases:**

- Webhook callbacks from external services (GitHub, Stripe, etc.)
- Temporary demos for external collaborators
- Keep public exposure brief. Stop or rebind the service when done.

**Firewall (UFW):** active. Default policy: deny incoming, allow outgoing. Allowed inbound: SSH (22/tcp), all traffic on `tailscale0`. Hetzner may apply additional network-level rules (check Robot panel).

**No reverse proxy.** Services bind directly to ports. If Caddy or nginx is added later, update this section.
