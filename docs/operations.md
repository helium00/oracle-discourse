# Operations Guide

## Daily Operations

### Check Stack Status

```bash
docker compose ps
# or
./scripts/healthcheck.sh
```

### View Logs

```bash
# All services, last 100 lines, follow
./scripts/logs.sh

# Only Discourse app logs
./scripts/logs.sh discourse

# Only database logs
./scripts/logs.sh postgresql

# Last 500 lines of Discourse logs
./scripts/logs.sh discourse 500
```

### Start / Stop / Restart

```bash
./scripts/start.sh    # Start all containers
./scripts/stop.sh     # Stop all containers gracefully
./scripts/restart.sh  # Restart all containers
```

---

## Image Updates

To pull new image versions and restart the stack:

```bash
./scripts/update.sh
```

This script:
1. Pulls updated images (`docker compose pull`).
2. Creates a backup (`./scripts/backup.sh`).
3. Restarts with new images (`docker compose up -d --remove-orphans`).
4. Waits 60 seconds, then runs `./scripts/healthcheck.sh`.

**Note on Discourse versions**: `bitnami/discourse:3` tracks the latest
Discourse 3.x patch release. To pin to a specific version, change the image
tag in `docker-compose.yml` before running the update.

---

## Maintenance Windows

For tasks that require downtime (major version upgrades, schema migrations):

```bash
# 1. Notify users via the Discourse admin panel banner

# 2. Create a backup
./scripts/backup.sh

# 3. Stop the stack
./scripts/stop.sh

# 4. Perform maintenance (edit docker-compose.yml, etc.)

# 5. Restart
./scripts/start.sh

# 6. Verify
./scripts/healthcheck.sh
```

---

## Monitoring

No monitoring agent is included in this stack. Recommended additions:

- **Uptime monitoring**: [Uptime Kuma](https://github.com/louislam/uptime-kuma) — monitor `http://10.0.1.204:8090`
- **Metrics**: Prometheus + Grafana (add containers to `docker-compose.yml`)
- **Log forwarding**: configure the Docker logging driver to forward to a central system

Quick availability check from the host:
```bash
curl -sf http://10.0.1.204:8090 -o /dev/null && echo "UP" || echo "DOWN"
```

---

## Health Checks

```bash
./scripts/healthcheck.sh
```

Checks performed:
1. `docker compose ps` — container running state
2. `curl` to `http://10.0.1.204:8090` — HTTP availability
3. `pg_isready` inside `discourse-db` — database readiness
4. `redis-cli ping` inside `discourse-redis` — Redis responsiveness

---

## Disk Space Management

Check volume sizes:
```bash
docker system df -v
```

The uploads volume (`discourse-app-data`) grows over time as users attach files
and images. Monitor disk usage and clean old backups periodically:

```bash
# Remove backups older than 30 days
find backups/ -name "discourse_backup_*" -mtime +30 -delete
```

---

## Container Resource Limits (optional)

To prevent runaway resource usage, add to the `discourse` service in
`docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: "2"
```

A small Discourse community typically requires 1–2 GB RAM.

---

## SSL / TLS

TLS is handled entirely by Cloudflare. The `discourse-app` container serves
plain HTTP on `10.0.1.204:8090` — this is by design. Do not add an nginx
TLS layer in this stack unless you remove Cloudflare Tunnel from the
architecture.
