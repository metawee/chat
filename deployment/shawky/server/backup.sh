#!/bin/bash
# Daily PostgreSQL backup for Shawky WhatsApp. Run from aaPanel → Cron (Shell script), e.g. every day at 03:17:
#   bash /www/wwwroot/web.shawkygroup.com/chat/deployment/shawky/server/backup.sh
# Keeps KEEP_DAYS days of dumps in BACKUP_DIR. Attachments live in Cloudflare R2 (or the "storage" volume when
# ACTIVE_STORAGE_SERVICE=local, which is archived too).
set -euo pipefail
cd "$(dirname "$0")"

BACKUP_DIR="${BACKUP_DIR:-/www/backup/shawky}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M)"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Custom-format dump: compressed, restorable table by table with pg_restore.
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > "$BACKUP_DIR/db-$STAMP.dump.partial"
mv "$BACKUP_DIR/db-$STAMP.dump.partial" "$BACKUP_DIR/db-$STAMP.dump"

if grep -q '^ACTIVE_STORAGE_SERVICE=local' .env; then
  docker compose exec -T rails tar -C /app/storage -czf - . > "$BACKUP_DIR/storage-$STAMP.tar.gz"
fi

find "$BACKUP_DIR" -maxdepth 1 -type f \( -name 'db-*.dump' -o -name 'storage-*.tar.gz' -o -name '*.partial' \) -mtime +"$KEEP_DAYS" -delete
echo "Backup done: $BACKUP_DIR/db-$STAMP.dump ($(du -h "$BACKUP_DIR/db-$STAMP.dump" | cut -f1))"
