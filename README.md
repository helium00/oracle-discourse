# discourse-docker-community

Production-oriented deployment for a self-hosted
[Discourse](https://www.discourse.org/) community platform.

Uses the official [discourse/discourse_docker](https://github.com/discourse/discourse_docker)
launcher. Designed for a single Ubuntu host with a pre-existing Cloudflare Tunnel.
The application binds **only** to the private IP `10.0.1.204:8090` — no ports are
exposed on public interfaces.

---

## Architecture

```
Internet → Cloudflare Edge (HTTPS) → Cloudflare Tunnel → 10.0.1.204:8090
                                                                  ↓
                                                    container 'app' (all-in-one)
                                                  Puma + Sidekiq + PostgreSQL + Redis
```

All services run inside a single container managed by the official launcher.
See [docs/architecture.md](docs/architecture.md) for the full topology diagram.

---

## Quick Start

```bash
git clone https://github.com/helium00/oracle-discourse.git discourse-docker-community
cd discourse-docker-community
make install   # setup → bootstrap (10-20 min) → start
```

`make install` runs:
1. `scripts/setup.sh` — generates `.env` (editor opens for required fields) and `containers/app.yml`
2. `scripts/bootstrap.sh` — clones `discourse_docker` to `/var/discourse` and builds the container
3. `scripts/start.sh` — starts the container

```bash
make health    # verify it's up
make logs      # follow logs
make backup    # create a backup
make help      # list all targets
```

---

## Prerequisites

- Ubuntu server with Docker installed
- `git`, `curl`, `sudo` access
- Cloudflare Tunnel configured and operational (managed externally)
- Private IP `10.0.1.204` reachable from the Cloudflare Tunnel
- A domain name managed by Cloudflare
- A [Brevo](https://app.brevo.com) account for outbound email

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/helium00/oracle-discourse.git discourse-docker-community
cd discourse-docker-community
```

### 2. Run the installer

```bash
make install
```

`scripts/setup.sh` opens your editor with `.env`. Fill in:

| Variable | What to set |
|---|---|
| `DISCOURSE_HOSTNAME` | Your public domain, e.g. `community.example.com` |
| `DISCOURSE_DEVELOPER_EMAILS` | Admin email address |
| `DISCOURSE_SMTP_USER_NAME` | Brevo login email |
| `DISCOURSE_SMTP_PASSWORD` | Brevo SMTP API key (not your account password) |

After saving, `bootstrap.sh` clones `discourse_docker` (if not at `/var/discourse`) and
builds the container. **This takes 10–20 minutes.**

#### Step-by-step (without Make)

```bash
./scripts/setup.sh          # generate .env and containers/app.yml
./scripts/permissions.sh
./scripts/bootstrap.sh      # build container (10-20 min)
./scripts/start.sh
```

---

## First Login — Admin Setup

After first start:

1. Visit `https://your-domain.com` (via Cloudflare Tunnel)
2. Click **Sign Up**
3. Register with the email you set in `DISCOURSE_DEVELOPER_EMAILS`
4. Discourse sends you a confirmation email (via Brevo)
5. After confirming, your account is automatically granted admin rights

---

## Configuration Reference

All configuration is in `.env`. See `.env.example` for full documentation.

| Variable | Default | Description |
|---|---|---|
| `APP_PORT` | `8090` | Internal port Discourse listens on |
| `APP_IP` | `10.0.1.204` | IP to bind to (private, Cloudflare-facing) |
| `DISCOURSE_HOSTNAME` | — | Public domain, required |
| `DISCOURSE_SITE_NAME` | `My Community` | Display name in UI |
| `DISCOURSE_DEVELOPER_EMAILS` | — | Admin email(s), required |
| `DISCOURSE_DOCKER_DIR` | `/var/discourse` | Where launcher is installed |
| `DISCOURSE_SMTP_ADDRESS` | `smtp-relay.brevo.com` | SMTP host |
| `DISCOURSE_SMTP_PORT` | `587` | SMTP port |
| `DISCOURSE_SMTP_USER_NAME` | — | Brevo login email, required |
| `DISCOURSE_SMTP_PASSWORD` | — | Brevo SMTP API key, required |

---

## Validation

### Check container status

```bash
docker ps | grep app
```

### Run full health check

```bash
make health
```

### Test HTTP access from the host

```bash
curl -I http://10.0.1.204:8090
```

Expected: `HTTP/1.1 200 OK` or a redirect response.

### Test via Cloudflare Tunnel (from external network)

```bash
curl -I https://community.example.com
```

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
```

Saves to `./backups/`:
- `discourse_backup_TIMESTAMP_db.sql.gz` — PostgreSQL dump
- `discourse_backup_TIMESTAMP_uploads.tar.gz` — Discourse uploads

### Restore from backup

```bash
make restore TIMESTAMP=20240815_143000
```

### Automate daily backups

```bash
crontab -e
# Add:
0 2 * * * cd /path/to/discourse-docker-community && make backup >> /var/log/discourse-backup.log 2>&1
```

---

## Updates

```bash
make update
```

Creates a pre-update backup, then rebuilds the container with the latest Discourse image.

---

## Container Management

```bash
# Start / stop / restart
make start
make stop
make restart

# Follow logs
make logs
make logs LINES=500

# Open a shell inside the container
docker exec -it app /bin/bash

# Access PostgreSQL inside the container
docker exec -it app psql -U discourse discourse
```

---

## Cloudflare Tunnel

The Cloudflare Tunnel is **managed externally** — no `cloudflared` container is part
of this stack. Configure the tunnel's public hostname to proxy to:

```
http://10.0.1.204:8090
```

See [docs/cloudflare-tunnel.md](docs/cloudflare-tunnel.md) for full details.

---

## Security Recommendations

- Never commit `.env` or `containers/app.yml` to version control — both are gitignored.
- Restrict SSH access to the host: key-based authentication only.
- Keep the container updated regularly with `make update`.
- Store offsite backups (S3, Backblaze B2, or equivalent).
- Enable 2FA on your Cloudflare account.
- Enable 2FA on your Brevo account.
- Keep the GitHub repository **private** if it contains any deployment-specific configuration.

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
