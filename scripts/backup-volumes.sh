#!/bin/bash
set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================="
echo "Print Vault: Backup Docker Volumes"
echo "=========================================="
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Backing up volumes to: $BACKUP_DIR"
echo ""

# Backup media volume
echo "Backing up media files..."
docker run --rm \
    -v print-vault_media_volume:/data:ro \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/media_${TIMESTAMP}.tar.gz" -C /data .
echo "  ✓ media_${TIMESTAMP}.tar.gz"

# Backup postgres volume
echo "Backing up postgres data..."
docker run --rm \
    -v print-vault_postgres_volume:/data:ro \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/postgres_${TIMESTAMP}.tar.gz" -C /data .
echo "  ✓ postgres_${TIMESTAMP}.tar.gz"

echo ""
echo "=========================================="
echo "Backup complete!"
echo "=========================================="
echo ""
echo "Backup files created in: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}.tar.gz 2>/dev/null || echo "Backup files created"
