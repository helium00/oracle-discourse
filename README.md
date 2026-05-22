# discourse-docker-community

Production-oriented Docker Compose deployment for a self-hosted
[Discourse](https://www.discourse.org/) community platform.

Designed for a single Ubuntu host with a pre-existing Cloudflare Tunnel.
The application binds **only** to the private IP `10.0.1.204:8090` — no
ports are exposed on public interfaces.

---

## Architecture

```
Internet → Cloudflare Edge (HTTPS) → Cloudflare Tunnel → 10.0.1.204:8090
                                                                  ↓
                                                         discourse-app (Puma + Sidekiq)
                                                         ↙                     ↘
                                              discourse-db:5432        discourse-redis:6379
```

All three containers run on an isolated `discourse-network` bridge network.
See [docs/architecture.md](docs/architecture.md) for the full topology diagram.

---

## Quick Start

```bash
git clone <GITHUB_REPOSITORY_URL> discourse-docker-community
cd discourse-docker-community
make install   # generates passwords, opens editor, sets permissions, starts stack
```

`setup.sh` auto-generates `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, and `DISCOURSE_ADMIN_PASSWORD`.
You only need to fill in hostname, admin email, and SMTP credentials. First boot takes 5–15 minutes.

```bash
make health    # verify everything is up
make logs      # follow all logs
make logs SERVICE=discourse   # follow only Discourse
make backup    # create a backup
make help      # list all available targets
```

---

## Prerequisites

- Ubuntu server with Docker and Docker Compose installed
- Cloudflare Tunnel configured and operational (managed externally)
- Private IP `10.0.1.204` accessible from the Cloudflare Tunnel
- A domain name managed by Cloudflare
- A [Brevo](https://app.brevo.com) account for outbound email

---

## Installation

### 1. Clone the repository

```bash
git clone <GITHUB_REPOSITORY_URL> discourse-docker-community
cd discourse-docker-community
```

### 2. Run the installer

```bash
make install
```

`scripts/setup.sh` runs automatically and:

1. Generates random passwords for `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `DISCOURSE_ADMIN_PASSWORD` via `openssl rand`
2. Detects system timezone from `/etc/timezone` (fallback: `Europe/Madrid`)
3. Shows a summary of the generated values
4. Opens `.env` in your editor for the remaining required fields
5. Validates after you save — warns if any placeholder is still unfilled

Fields you must fill manually in the editor:

| Variable | What to set |
|---|---|
| `DISCOURSE_HOSTNAME` | Your public domain, e.g. `community.example.com` |
| `DISCOURSE_ADMIN_EMAIL` | Your admin email address |
| `DISCOURSE_DEVELOPER_EMAILS` | Same as admin email |
| `DISCOURSE_SMTP_USER_NAME` | Your Brevo login email |
| `DISCOURSE_SMTP_PASSWORD` | Your Brevo SMTP API key (not your account password) |

Fields auto-filled by `setup.sh` (no manual action needed):

| Variable | How it's set |
|---|---|
| `POSTGRES_PASSWORD` | `openssl rand -hex 24` |
| `REDIS_PASSWORD` | `openssl rand -hex 24` |
| `DISCOURSE_ADMIN_PASSWORD` | `openssl rand -hex 12` — change after first login |
| `TIMEZONE` | Detected from `/etc/timezone` |

#### Without Make

```bash
./scripts/setup.sh   # generates passwords, opens editor, validates
./scripts/permissions.sh
./scripts/start.sh
```

---

## Startup Procedure

After `./scripts/start.sh`, Discourse bootstraps on first run:

1. PostgreSQL and Redis start and pass their health checks.
2. The `discourse-app` container starts and runs database migrations.
3. The admin account defined in `.env` is created.

First boot takes **5–15 minutes**. Monitor progress:

```bash
make logs SERVICE=discourse
# or: ./scripts/logs.sh discourse
```

Wait for `Puma starting in production` in the log output before testing access.

---

## Configuration Reference

All configuration is in `.env`. See `.env.example` for full documentation.

| Variable | Default | Description |
|---|---|---|
| `APP_PORT` | `8090` | Internal port Discourse listens on |
| `DISCOURSE_HOSTNAME` | — | Public domain, required |
| `DISCOURSE_SITE_NAME` | `My Community` | Display name in UI |
| `TIMEZONE` | `Europe/Madrid` | Container timezone |
| `DISCOURSE_ADMIN_USERNAME` | `admin` | Initial admin username |
| `DISCOURSE_ADMIN_EMAIL` | — | Initial admin email, required |
| `DISCOURSE_ADMIN_PASSWORD` | — | Initial admin password, required |
| `DISCOURSE_DEVELOPER_EMAILS` | — | Admin email list, required |
| `POSTGRES_USER` | `discourse` | Database user |
| `POSTGRES_DB` | `discourse` | Database name |
| `POSTGRES_PASSWORD` | — | Database password, required |
| `REDIS_PASSWORD` | — | Redis password, required |
| `DISCOURSE_SMTP_ADDRESS` | `smtp-relay.brevo.com` | SMTP host |
| `DISCOURSE_SMTP_PORT` | `587` | SMTP port |
| `DISCOURSE_SMTP_USER_NAME` | — | Brevo login email, required |
| `DISCOURSE_SMTP_PASSWORD` | — | Brevo SMTP API key, required |
| `DISCOURSE_SMTP_ENABLE_START_TLS` | `true` | Enable STARTTLS |

---

## Validation

### Check container status

```bash
docker compose ps
```

All three containers (`discourse-db`, `discourse-redis`, `discourse-app`)
should show `running` status.

### Run full health check

```bash
make health
# or: ./scripts/healthcheck.sh
```

### Test HTTP access from the host

```bash
curl -I http://10.0.1.204:8090
```

Expected: `HTTP/1.1 200 OK` or a redirect response.

### Test HTTP access with curl verbose

```bash
curl -v http://10.0.1.204:8090 2>&1 | head -30
```

### Test via Cloudflare Tunnel (from external network)

```bash
curl -I https://community.example.com
```

Expected: `HTTP/2 200` or a redirect to the login page.

---

## SMTP Setup

See [docs/smtp-brevo.md](docs/smtp-brevo.md) for complete instructions:
- Creating Brevo SMTP credentials
- SPF, DKIM, and DMARC DNS configuration
- Testing email delivery

---

## Backup and Restore

### Create a backup

```bash
make backup
# or: ./scripts/backup.sh
```

Backups are saved to `./backups/` (excluded from git). Each run creates:
- `discourse_backup_TIMESTAMP_db.sql.gz` — PostgreSQL dump
- `discourse_backup_TIMESTAMP_uploads.tar.gz` — Discourse uploads

### Restore from backup

```bash
make restore TIMESTAMP=20240815_143000
# or: ./scripts/restore.sh 20240815_143000
```

### Automate daily backups

```bash
crontab -e
# Add:
0 2 * * * cd /path/to/discourse-docker-community && make backup >> /var/log/discourse-backup.log 2>&1
```

See [docs/backup-restore.md](docs/backup-restore.md) for full details and
disaster recovery instructions.

---

## Updates

```bash
make update
# or: ./scripts/update.sh
```

Pulls updated images, creates a pre-update backup, restarts the stack, and
runs a health check automatically.

See [docs/operations.md](docs/operations.md) for maintenance window procedures.

---

## Container Management

```bash
# Show running containers
docker compose ps

# Follow all logs
make logs
make logs SERVICE=discourse        # only Discourse
make logs SERVICE=discourse LINES=500

# Start / stop / restart
make start
make stop
make restart

# Restart a single container
docker compose restart discourse

# Open a shell inside the Discourse container
docker compose exec discourse bash

# Open the PostgreSQL REPL
docker compose exec postgresql psql -U discourse discourse

# Check Redis
docker compose exec redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping
```

---

## Cloudflare Tunnel

The Cloudflare Tunnel is **managed externally** — no `cloudflared` container
is part of this stack. Configure the tunnel's public hostname to proxy to:

```
http://10.0.1.204:8090
```

See [docs/cloudflare-tunnel.md](docs/cloudflare-tunnel.md) for full details.

---

## Security Recommendations

- Use strong, unique passwords for `POSTGRES_PASSWORD`, `REDIS_PASSWORD`,
  and `DISCOURSE_ADMIN_PASSWORD` (at least 32 random characters).
- Never commit `.env` to version control — it is excluded by `.gitignore`.
- Restrict SSH access to the host: key-based authentication only, disable password auth.
- Keep Docker images updated regularly with `make update`.
- Store offsite backups (S3, Backblaze B2, or equivalent).
- Enable 2FA on your Cloudflare account.
- Enable 2FA on your Brevo account.
- After first login, change `DISCOURSE_ADMIN_PASSWORD` in the Discourse UI
  and update the value in `.env`.
- Keep the GitHub repository **private** if it contains any configuration
  specific to your deployment.

---

## Operational Best Practices

- Run `make backup` before every `make update`.
- Monitor disk usage weekly: `docker system df`.
- Clean old backups monthly: `find backups/ -name "discourse_backup_*" -mtime +30 -delete`.
- Test your restore procedure periodically — an untested backup is not a backup.
- Check Discourse admin email logs after SMTP configuration changes.
- Review Discourse's built-in admin dashboard regularly for plugin and security updates.

---

## Publishing to GitHub

See [docs/github-publishing.md](docs/github-publishing.md) for exact commands
and branch strategy recommendations.

---

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for solutions to:
- Container restart loops
- SMTP failures
- Permission errors
- Volume loss
- Cloudflare connectivity issues

---

## Documentation Index

| Document | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Service topology, networking, traffic flow |
| [docs/cloudflare-tunnel.md](docs/cloudflare-tunnel.md) | Tunnel integration and configuration |
| [docs/smtp-brevo.md](docs/smtp-brevo.md) | SMTP setup, SPF, DKIM, DMARC |
| [docs/backup-restore.md](docs/backup-restore.md) | Backup procedures and disaster recovery |
| [docs/operations.md](docs/operations.md) | Daily ops, updates, monitoring |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common issues and fixes |
| [docs/github-publishing.md](docs/github-publishing.md) | Publishing to GitHub |
