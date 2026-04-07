#!/bin/bash
set -euo pipefail

BACKUP_DIR="/root/paperclip/backups"
DATE=$(date +%F_%H-%M-%S)

DB_CONTAINER="paperclip_paperclip-db_1"
DB_NAME="paperclip"
DB_USER="paperclip"
PAPERCLIP_VOLUME="paperclip_paperclip_data"

mkdir -p "$BACKUP_DIR"

echo "=== Starting Paperclip backup at $DATE ==="

# Paperclip data (config, secrets, logs, storage)
docker run --rm \
  -v "$PAPERCLIP_VOLUME":/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/paperclip_data_$DATE.tar.gz" /data

# Safe logical DB dump
TMP_SQL="$BACKUP_DIR/.paperclip_postgres_$DATE.tmp.sql"

docker exec "$DB_CONTAINER" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" > "$TMP_SQL"

# Validate dump header
if ! head -n 2 "$TMP_SQL" | grep -q "PostgreSQL database dump"; then
  echo "Invalid SQL dump created — aborting"
  rm -f "$TMP_SQL"
  exit 1
fi

mv "$TMP_SQL" "$BACKUP_DIR/paperclip_postgres_$DATE.sql"

# Retention (7 days)
find "$BACKUP_DIR" -type f -mtime +7 -delete

echo "Paperclip backup finished successfully at $(date +%F_%H-%M-%S)"
