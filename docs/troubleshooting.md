# Troubleshooting

## Container Keeps Restarting

**Symptom:** `docker compose ps` shows a container in `Restarting` state.

**Diagnose:**
```bash
docker compose logs --tail=50 discourse
docker compose logs --tail=50 postgresql
```

**Common causes:**

| Log message | Cause | Fix |
|---|---|---|
| `POSTGRES_PASSWORD must be set` | `.env` missing or var not set | Ensure `.env` exists and `POSTGRES_PASSWORD` is set |
| `could not connect to server: Connection refused` | PostgreSQL not ready yet | Wait — `depends_on` healthcheck should handle this; if it persists, check the `discourse-db` container logs |
| `Redis connection refused` | Redis not ready | Check `discourse-redis` container logs |

---

## Discourse Shows 502 / Not Reachable

**Check port binding:**
```bash
ss -tlnp | grep 8090
```

Expected: `10.0.1.204:8090` in `LISTEN` state.

If not listed, `discourse-app` is not running. Check:
```bash
docker compose ps discourse
docker compose logs discourse
```

**Check if Discourse finished initializing:**

First boot takes 5–15 minutes. Watch:
```bash
./scripts/logs.sh discourse
```

Wait for `Puma starting in production` in the log. The HTTP endpoint will
not respond until that line appears.

---

## SMTP Failures

**Symptom:** Users do not receive registration or notification emails.

**Check Discourse email log:**

Admin → **Email** → **Sent** — look for failed delivery entries.

**Test SMTP port from the host:**
```bash
nc -vz smtp-relay.brevo.com 587
```

Expected: `Connection succeeded`.

If this fails, outbound TCP 587 is blocked by a firewall:
```bash
sudo ufw allow out 587/tcp
```

**Common SMTP errors:**

| Error | Cause | Fix |
|---|---|---|
| `535 Authentication` | Wrong credentials | Verify `DISCOURSE_SMTP_USER_NAME` (Brevo login) and `DISCOURSE_SMTP_PASSWORD` (SMTP API key, not account password) |
| `Connection timed out` | Port 587 blocked | Open outbound 587 as shown above |
| `TLS handshake failed` | STARTTLS misconfigured | Ensure `DISCOURSE_SMTP_ENABLE_START_TLS=true` in `.env` and restart |

---

## Permission Errors on Volume Files

**Symptom:** Discourse logs show `Permission denied` on file writes.

**Fix:**
```bash
./scripts/permissions.sh

# If the issue is inside the Docker volume
docker compose exec discourse chown -R 1001:1001 /bitnami/discourse
```

---

## Volume Issues

**Symptom:** Data lost after restart, or Discourse re-runs bootstrap on every start.

**Verify volumes exist:**
```bash
docker volume ls | grep discourse
```

Expected output includes:
```
discourse-postgres-data
discourse-redis-data
discourse-app-data
```

If volumes are missing, they were deleted. Restore from backup:
```bash
./scripts/restore.sh <TIMESTAMP>
```

**IMPORTANT:** Never use `docker compose down -v` — the `-v` flag deletes all
named volumes and permanently destroys your data. Use `./scripts/stop.sh` or
`docker compose stop` (without `-v`) instead.

---

## Cloudflare Tunnel Not Routing Traffic

**Symptom:** Public URL returns a Cloudflare error but the internal address works.

**Verify the stack is reachable internally:**
```bash
curl -I http://10.0.1.204:8090
```

If this works, the issue is in the Cloudflare Tunnel configuration (managed
externally). Check:
1. The `cloudflared` daemon is running on the host.
2. The Zero Trust public hostname URL is `http://10.0.1.204:8090`.
3. The `APP_PORT` in the tunnel config matches `APP_PORT` in `.env`.

See [docs/cloudflare-tunnel.md](cloudflare-tunnel.md) for configuration details.

---

## Out of Disk Space

**Symptom:** Containers fail to start or database writes fail.

**Check disk usage:**
```bash
df -h
docker system df
```

**Free space:**
```bash
# Remove unused Docker images
docker image prune -a

# Remove old backups (keep last 7)
ls -t backups/discourse_backup_*_db.sql.gz | tail -n +8 | xargs rm -f
ls -t backups/discourse_backup_*_uploads.tar.gz | tail -n +8 | xargs rm -f
```

---

## Restart Loop After Update

If a new Discourse image causes a restart loop:

1. Check logs: `./scripts/logs.sh discourse`
2. Pin the previous image version in `docker-compose.yml` (change `bitnami/discourse:3` to `bitnami/discourse:3.x.y`).
3. If the database schema was already migrated during the failed update, restore from the pre-update backup: `./scripts/restore.sh <PRE_UPDATE_TIMESTAMP>`
