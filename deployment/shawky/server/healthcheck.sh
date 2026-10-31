#!/bin/bash
# Health check for Shawky WhatsApp. Run from aaPanel → Cron every 5 minutes:
#   bash /www/wwwroot/web.shawkygroup.com/chat/deployment/shawky/server/healthcheck.sh
# Prints problems and exits 1 when something is wrong. If SHAWKY_ALERT_WEBHOOK_URL is set in .env
# (an n8n webhook), the problems are POSTed there so n8n can alert the administrators.
set -uo pipefail
cd "$(dirname "$0")"

BACKUP_DIR="${BACKUP_DIR:-/www/backup/shawky}"
RAILS_PORT="$(grep -E '^RAILS_PORT=' .env | cut -d= -f2)"
ALERT_URL="$(grep -E '^SHAWKY_ALERT_WEBHOOK_URL=' .env | cut -d= -f2-)"
problems=()

for service in rails sidekiq postgres redis; do
  [ -n "$(docker compose ps --status running -q "$service")" ] || problems+=("$service is not running")
done

curl -fsS -m 10 -H 'X-Forwarded-Proto: https' "http://127.0.0.1:${RAILS_PORT:-3000}/health" >/dev/null || problems+=("web app does not answer /health")

disk_used="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
[ "$disk_used" -lt 85 ] || problems+=("disk is ${disk_used}% full")

latest_backup="$(find "$BACKUP_DIR" -maxdepth 1 -name 'db-*.dump' -mmin -1560 2>/dev/null | head -1)"
[ -n "$latest_backup" ] || problems+=("no database backup in the last 26 hours")

if [ ${#problems[@]} -eq 0 ]; then
  echo "OK $(date -Is)"
  exit 0
fi

printf '%s\n' "${problems[@]}"
if [ -n "$ALERT_URL" ]; then
  message="$(printf '%s; ' "${problems[@]}")"
  curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
    -d "{\"source\":\"shawky-healthcheck\",\"host\":\"$(hostname)\",\"problems\":\"${message//\"/}\"}" "$ALERT_URL" >/dev/null || true
fi
exit 1
