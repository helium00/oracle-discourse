# Backup and Restore

## What Gets Backed Up

| Component | Method | Output file |
|---|---|---|
| PostgreSQL database | `pg_dump` piped through gzip | `discourse_backup_TIMESTAMP_db.sql.gz` |
| Discourse uploads | Docker volume tar archive | `discourse_backup_TIMESTAMP_uploads.tar.gz` |

Backups are stored in `./backups/` which is excluded from git via `.gitignore`.

---

## Manual Backup

```bash
./scripts/backup.sh
```

Output example:
```
[2024-08-15 14:30:00] Starting backup (20240815_143000)...
[2024-08-15 14:30:01] Dumping PostgreSQL database...
[2024-08-15 14:30:03] Archiving Discourse uploads volume...
[2024-08-15 14:30:10] Backup complete:
  DB:      ./backups/discourse_backup_20240815_143000_db.sql.gz
  Uploads: ./backups/discourse_backup_20240815_143000_uploads.tar.gz
```

---

## List Available Backups

```bash
ls -lh backups/
```

---

## Restore from Backup

```bash
# Show available timestamps
./scripts/restore.sh

# Restore a specific backup
./scripts/restore.sh 20240815_143000
```

**What happens during restore:**
1. The `discourse-app` container is stopped (database and Redis stay running).
2. The PostgreSQL public schema is dropped and recreated (ensures clean restore).
3. The database is restored from the SQL dump.
4. The uploads volume is cleared, then restored from the tar archive.
5. The `discourse-app` container is restarted.

**Note:** The restore script requires the `discourse-db` container to be running.
Do not stop the full stack before restoring.

---

## Automate Backups with cron

Add a crontab entry on the host for daily backups at 02:00:

```bash
crontab -e
```

Add:
```
0 2 * * * /path/to/discourse-docker-community/scripts/backup.sh >> /var/log/discourse-backup.log 2>&1
```

---

## Offsite Backup Recommendations

Keeping backups only on the host is a single point of failure. Recommended options:

- **AWS S3**: `aws s3 cp backups/ s3://your-bucket/discourse/ --recursive`
- **rclone**: supports S3, Backblaze B2, Google Drive, and others
- **rsync**: `rsync -avz backups/ user@backup-server:/backups/discourse/`

Example S3 sync added to the end of a crontab entry:
```bash
0 2 * * * /path/to/discourse-docker-community/scripts/backup.sh && \
  aws s3 sync /path/to/discourse-docker-community/backups/ s3://your-bucket/discourse/ \
  >> /var/log/discourse-backup.log 2>&1
```

---

## Disaster Recovery (new host)

Full recovery on a new host:

1. Install Docker and Docker Compose on the new host.
2. Clone this repository.
3. Copy `.env.example` to `.env` and fill in the same values as the original.
4. Copy backup files to `./backups/`.
5. Start the stack: `./scripts/start.sh`
6. Wait for Discourse to initialize (~10 minutes on first run).
7. Restore: `./scripts/restore.sh <TIMESTAMP>`
8. Verify: `./scripts/healthcheck.sh`

---

## Database Backup Considerations

- `pg_dump` creates a consistent snapshot even with Discourse running.
- The SQL dump is plain SQL — compatible with any PostgreSQL version ≥ 14.
- The restore script drops and recreates the `public` schema before loading
  the dump, ensuring no conflicts with existing data.
- Do not run a backup while a restore is in progress.
