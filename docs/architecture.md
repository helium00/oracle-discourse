# Architecture

## Service Overview

The stack runs three Docker containers on a single host, connected via an
internal bridge network (`discourse-network`). No container is exposed on
a public network interface.

```
┌─────────────────────────────────────────────────────────┐
│                     Docker Host                         │
│                   10.0.1.204                            │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │             discourse-network (bridge)           │   │
│  │                                                  │   │
│  │  ┌──────────────┐   ┌──────────────┐            │   │
│  │  │ discourse-db │   │discourse-    │            │   │
│  │  │ (postgresql) │   │redis         │            │   │
│  │  │ :5432        │   │:6379         │            │   │
│  │  └──────┬───────┘   └──────┬───────┘            │   │
│  │         │                  │                    │   │
│  │  ┌──────▼──────────────────▼───────┐            │   │
│  │  │        discourse-app            │            │   │
│  │  │    (bitnami/discourse:3)        │            │   │
│  │  │    Puma (web) + Sidekiq (jobs)  │            │   │
│  │  │    internal port :3000          │            │   │
│  │  └──────────────────┬─────────────┘            │   │
│  └─────────────────────│──────────────────────────┘   │
│                         │ port binding                  │
│             10.0.1.204:8090 → container:3000            │
│                         │                               │
└─────────────────────────┼───────────────────────────────┘
                          │ private network
              ┌───────────▼───────────┐
              │   Cloudflare Tunnel   │
              │  (managed externally) │
              └───────────┬───────────┘
                          │ encrypted tunnel
              ┌───────────▼───────────┐
              │  Cloudflare Edge      │
              │  https://community.   │
              │  example.com          │
              └───────────────────────┘
```

## Docker Networking

- All three containers join `discourse-network`, a Docker bridge network.
- Containers address each other by service name:
  - Discourse → PostgreSQL: hostname `postgresql`, port `5432`
  - Discourse → Redis: hostname `redis`, port `6379`
- Only the `discourse-app` container has a host port binding.
- The port binding is restricted to `10.0.1.204` — never `0.0.0.0`.
- Other services running on this host (n8n, strapi, elearning, pgadmin) are
  on separate networks and have no connectivity to `discourse-network`.

## Volume Persistence

| Volume Name              | Mounted in container at | Purpose |
|--------------------------|-------------------------|---------|
| `discourse-postgres-data` | `/bitnami/postgresql`  | Database files |
| `discourse-redis-data`    | `/data`                 | Redis AOF persistence |
| `discourse-app-data`      | `/bitnami/discourse`    | Uploads, assets, plugins |

Volumes survive container restarts and image upgrades. They are managed by
Docker and stored in `/var/lib/docker/volumes/` by default.

## Internal Traffic Flow

1. Browser → Cloudflare Edge (HTTPS, port 443)
2. Cloudflare Edge → Cloudflare Tunnel (encrypted tunnel)
3. Cloudflare Tunnel → `http://10.0.1.204:8090` (plain HTTP on private network)
4. Host port binding → `discourse-app` container port 3000
5. `discourse-app` → `discourse-db` (SQL queries over `discourse-network`)
6. `discourse-app` → `discourse-redis` (cache reads/writes, Sidekiq job queue)

## Restart Policy

All containers use `restart: unless-stopped`. They will:
- Automatically restart on crash.
- Automatically restart on host reboot (when Docker daemon starts).
- NOT restart if explicitly stopped with `docker compose stop` or `./scripts/stop.sh`.

## Initialization Sequence

On first start, `discourse-app` waits for PostgreSQL and Redis health checks
before starting (see `depends_on` with `condition: service_healthy`). The
bitnami/discourse bootstrap runs database migrations and creates the initial
admin account defined in `.env`.

Bootstrap only runs once — when the `discourse-app-data` volume is empty.
Subsequent starts skip bootstrap and go straight to serving requests.

First boot typically takes **5–15 minutes**. Monitor with:

```bash
./scripts/logs.sh discourse
```

Wait for `Puma starting in production` in the log output.
