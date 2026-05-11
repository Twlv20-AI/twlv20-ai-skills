# Postgres backups runbook

Weekly encrypted logical snapshots of the production `twlv20` Postgres database are uploaded to Backblaze B2.

## Production location

- Droplet: `twlv20-prod`
- Database: `twlv20`
- Backup script: `/usr/local/sbin/twlv20-postgres-backup`
- B2 helper: `/usr/local/sbin/twlv20-pg-b2.py`
- systemd service: `twlv20-postgres-backup.service`
- systemd timer: `twlv20-postgres-backup.timer`
- Schedule: Sundays at `02:00 UTC`
- Local log: `/var/log/twlv20/postgres-backup.log`

## Secret locations

Secrets are stored only on the droplet as root-only interim files:

- B2 key/env file: `/root/.secrets/b2-backup.env`
- GPG symmetric encryption passphrase: `/root/.secrets/pg-backup-gpg.pass`

Do not paste these values into chat, ClickUp, docs, or git. Migrate them to Infisical when the Infisical task is complete.

## B2 layout and retention

- Bucket: `twlv20-postgres-backups`
- Object prefix: `postgres/weekly/`
- Filename format: `postgres/weekly/YYYY-MM-DD/weekly-postgres-YYYY-MM-DD-HHMMUTC.sql.gz.gpg`
- Retention: backup script keeps the newest 8 `.sql.gz.gpg` weekly objects and deletes older objects under the prefix.

## Manual snapshot

SSH to the droplet, then run:

```bash
sudo /usr/local/sbin/twlv20-postgres-backup
```

Check the local log:

```bash
sudo tail -n 50 /var/log/twlv20/postgres-backup.log
```

## Restore drill / restore steps

This restores the latest encrypted B2 object into a throwaway DB, verifies basic table/extension presence, then drops it.

```bash
sudo -i
set -euo pipefail
set -a
source /root/.secrets/b2-backup.env
set +a

WORK=$(mktemp -d /var/backups/twlv20-postgres/restore-test.XXXXXX)
trap 'sudo -u postgres dropdb --if-exists twlv20_restore_test >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

OBJ=$(/usr/local/sbin/twlv20-pg-b2.py latest "$B2_OBJECT_PREFIX/")
/usr/local/sbin/twlv20-pg-b2.py download "$OBJ" "$WORK/snapshot.sql.gz.gpg"
gpg --batch --yes --decrypt \
  --pinentry-mode loopback \
  --passphrase-file /root/.secrets/pg-backup-gpg.pass \
  --output "$WORK/snapshot.sql.gz" \
  "$WORK/snapshot.sql.gz.gpg"
gunzip "$WORK/snapshot.sql.gz"

sudo -u postgres dropdb --if-exists twlv20_restore_test
sudo -u postgres createdb twlv20_restore_test
cat "$WORK/snapshot.sql" | sudo -u postgres psql -v ON_ERROR_STOP=1 -d twlv20_restore_test
sudo -u postgres psql -At -d twlv20_restore_test -c "select count(*) from tenants; select count(*) from runs; select extname from pg_extension where extname in ('pgcrypto','vector') order by extname;"
sudo -u postgres dropdb twlv20_restore_test
```

A successful test should show tenant count, run count, `pgcrypto`, `vector`, and no psql errors.

## Rotate the B2 key

1. In Backblaze, create a new application key scoped to bucket `twlv20-postgres-backups` with read/write access.
2. SSH to the droplet.
3. Edit `/root/.secrets/b2-backup.env` and replace only the key ID/application key values.
4. Keep permissions root-only:

```bash
sudo chmod 600 /root/.secrets/b2-backup.env
sudo chown root:root /root/.secrets/b2-backup.env
```

5. Run a manual snapshot and restore drill before deleting the old key.
6. Delete/revoke the old Backblaze application key.

## Failure alerts

The backup service has `OnFailure=twlv20-postgres-backup-alert@%n.service`.

The alert script is `/usr/local/sbin/twlv20-postgres-backup-alert` and sends to `ai@twlv20.com` using local mail/sendmail. Postfix and `bsd-mailx` are installed on the droplet. If mail delivery is suspected to be blocked by the provider, check:

```bash
sudo journalctl -u postfix -n 100 --no-pager
sudo mailq
sudo journalctl -u 'twlv20-postgres-backup-alert@*' -n 100 --no-pager
```
