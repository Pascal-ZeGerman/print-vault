#!/bin/bash
set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"

echo "=========================================="
echo "Print Vault: Restore Docker Volumes"
echo "=========================================="
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# List available backups
echo "Available backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
    echo "No backup files found!"
    exit 1
}
echo ""

# Prompt for backup timestamp
read -p "Enter timestamp to restore (YYYYMMDD_HHMMSS): " TIMESTAMP

if [ ! -f "$BACKUP_DIR/media_${TIMESTAMP}.tar.gz" ]; then
    echo "ERROR: Media backup not found: media_${TIMESTAMP}.tar.gz"
    exit 1
fi

if [ ! -f "$BACKUP_DIR/postgres_${TIMESTAMP}.tar.gz" ]; then
    echo "ERROR: Postgres backup not found: postgres_${TIMESTAMP}.tar.gz"
    exit 1
fi

# Warning
echo ""
echo "WARNING: This will REPLACE all current data with the backup!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "Stopping containers..."
docker compose down

echo ""
echo "Restoring media files..."
docker run --rm \
    -v print-vault_media_volume:/data \
    -v "$(pwd)/$BACKUP_DIR:/backup:ro" \
    alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null || true && tar xzf /backup/media_${TIMESTAMP}.tar.gz -C /data"
echo "  ✓ Media restored"

echo ""
echo "Restoring postgres data..."
docker run --rm \
    -v print-vault_postgres_volume:/data \
    -v "$(pwd)/$BACKUP_DIR:/backup:ro" \
    alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null || true && tar xzf /backup/postgres_${TIMESTAMP}.tar.gz -C /data"
echo "  ✓ Postgres restored"

echo ""
echo "Starting containers..."
docker compose up -d

echo ""
echo "=========================================="
echo "Restore complete!"
echo "=========================================="
