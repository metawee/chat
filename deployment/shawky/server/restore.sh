#!/bin/bash
# Restore a dump made by backup.sh. This REPLACES the current database.
#   CONFIRM=yes bash restore.sh /www/backup/shawky/db-20261101-0317.dump
set -euo pipefail
cd "$(dirname "$0")"

DUMP="${1:?usage: CONFIRM=yes bash restore.sh <db-*.dump>}"
[ -f "$DUMP" ] || { echo "No such file: $DUMP"; exit 1; }
[ "${CONFIRM:-}" = "yes" ] || { echo "Refusing: this replaces the live database. Re-run with CONFIRM=yes"; exit 1; }

docker compose stop rails sidekiq
docker compose exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' < "$DUMP"
docker compose up -d rails sidekiq
echo "Restored $DUMP. Open the site and log in to check it."
