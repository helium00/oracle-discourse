# Cloudflare Tunnel Integration

## Overview

The Cloudflare Tunnel for this deployment is **managed externally** — no
`cloudflared` container runs inside this repository. This design keeps the
Discourse stack independent of the tunnel configuration and reduces coupling.

The Discourse stack only needs to know its internal binding address:

```
http://10.0.1.204:8090
```

The Cloudflare Tunnel proxy is configured separately to forward traffic
arriving at your public domain to this internal address.

## How It Works

```
Internet user
     │
     ▼  HTTPS (port 443)
Cloudflare Edge
     │
     ▼  Encrypted Cloudflare Tunnel
cloudflared daemon (running separately on this host or in the private network)
     │
     ▼  HTTP (plain, private network only — 10.0.1.204)
http://10.0.1.204:8090
     │
     ▼
discourse-app container (Puma on port 3000)
```

All TLS termination happens at the Cloudflare Edge. Traffic between
Cloudflare and the host travels through the encrypted tunnel — not over
raw TCP — so plain HTTP on the private IP is acceptable and intentional.

## Cloudflare Tunnel Public Hostname Configuration

In the Cloudflare Zero Trust dashboard, configure the public hostname for
your tunnel as follows:

| Field | Value |
|---|---|
| **Subdomain** | `community` (or your chosen prefix) |
| **Domain** | `example.com` |
| **Type** | `HTTP` |
| **URL** | `10.0.1.204:8090` |

Leave "TLS" origin settings at default — no origin TLS certificate is needed
because the tunnel handles encryption end-to-end.

If you change `APP_PORT` in your `.env`, update the tunnel URL accordingly.

## What This Repository Does NOT Do

- Does not install or configure `cloudflared`.
- Does not create or manage Cloudflare Tunnel credentials.
- Does not manage DNS records.

These are managed externally as stated in the environment context.

## Verifying Connectivity

After the Discourse stack is running, verify the tunnel is working:

```bash
# From the host — direct internal access
curl -I http://10.0.1.204:8090

# From outside — through Cloudflare Tunnel
curl -I https://community.example.com
```

Both should return HTTP `200` or a Discourse redirect (`301`/`302`).

## Changing the Port

If `APP_PORT` must change from `8090`:

1. Edit `.env`: `APP_PORT=<new_port>`
2. Restart the stack: `./scripts/restart.sh`
3. Update the Cloudflare Tunnel public hostname URL to `10.0.1.204:<new_port>`
