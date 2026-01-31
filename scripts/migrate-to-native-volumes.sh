#!/bin/bash
set -e  # Exit on any error

echo "=========================================="
echo "Print Vault: Migrate to Native Volumes"
echo "=========================================="
echo ""
echo "This script migrates your data from bind mounts (./data/) to Docker native volumes."
echo ""

# Check if running from correct directory
if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: Must run this script from the print-vault directory"
    exit 1
fi

# Check if old data directories exist
if [ ! -d "./data/media" ] && [ ! -d "./data/postgres" ]; then
    echo "No ./data/ directories found. Either:"
    echo "  1. You're doing a fresh install (no migration needed)"
    echo "  2. You already migrated (check 'docker volume ls')"
    exit 0
fi

echo "Step 1: Checking for existing data..."
if [ -d "./data/media" ]; then
    MEDIA_SIZE=$(du -sh ./data/media 2>/dev/null | cut -f1 || echo "0")
    echo "  ✓ Found media files: $MEDIA_SIZE"
fi
if [ -d "./data/postgres" ]; then
    POSTGRES_SIZE=$(du -sh ./data/postgres 2>/dev/null | cut -f1 || echo "0")
    echo "  ✓ Found postgres data: $POSTGRES_SIZE"
fi
echo ""

# Prompt for confirmation
read -p "Continue with migration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Step 2: Stopping containers..."
docker compose down

echo ""
echo "Step 3: Creating named volumes..."
docker volume create print-vault_media_volume
docker volume create print-vault_postgres_volume

echo ""
echo "Step 4: Migrating media files..."
if [ -d "./data/media" ]; then
    docker run --rm \
        -v "$(pwd)/data/media:/source:ro" \
        -v print-vault_media_volume:/target \
        alpine sh -c "cp -av /source/. /target/"
    echo "  ✓ Media files migrated"
else
    echo "  ⊘ No media directory to migrate"
fi

echo ""
echo "Step 5: Migrating postgres data..."
if [ -d "./data/postgres" ]; then
    docker run --rm \
        -v "$(pwd)/data/postgres:/source:ro" \
        -v print-vault_postgres_volume:/target \
        alpine sh -c "cp -av /source/. /target/"
    echo "  ✓ Postgres data migrated"
else
    echo "  ⊘ No postgres directory to migrate"
fi

echo ""
echo "Step 6: Starting containers with native volumes..."
docker compose up -d

echo ""
echo "Step 7: Verifying migration..."
sleep 5
docker compose ps

echo ""
echo "=========================================="
echo "Migration complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Test your Print Vault installation"
echo "  2. Verify all data is accessible"
echo "  3. If everything works, you can remove ./data/ directories:"
echo "     rm -rf ./data/"
echo ""
echo "To rollback if needed:"
echo "  1. Restore old docker-compose.yml from git"
echo "  2. Run: docker compose down"
echo "  3. Run: docker compose up -d"
echo ""
