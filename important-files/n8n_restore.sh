#!/bin/bash

# --- CONFIGURATION ---
BACKUP_REPO="/home/{your-username}/backups"
COMPOSE_DIR="/home/{your-username}"
export PGPASSWORD="{your-n8n-PG-password}"

echo "--- Restore Session Started: $(date) ---"

# 1. Get Latest Backup
echo "[STEP 1/7] Updating backup repository and finding latest backup..."
cd "$BACKUP_REPO" || { echo "ERROR: Backup directory not found!"; exit 1; }
git pull origin main || { echo "ERROR: Git pull failed!"; exit 1; }

# Latest backup by actual modification time (new + old filename dono support karega)
LATEST=$(ls -t n8n-backup_*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST" ]; then
    echo "ERROR: No backup files found in $BACKUP_REPO"
    exit 1
fi
echo "Found latest backup: $LATEST"

# 2. Extracting Backup
echo "[STEP 2/7] Extracting backup files..."
TEMP_RESTORE=$(mktemp -d)
trap 'rm -rf "$TEMP_RESTORE"' EXIT

tar -xzf "$BACKUP_REPO/$LATEST" -C "$TEMP_RESTORE" || { echo "ERROR: Extraction failed!"; exit 1; }

# 3. Stop n8n Stack
echo "[STEP 3/7] Stopping n8n containers and cleaning old volumes..."
cd "$COMPOSE_DIR" || { echo "ERROR: Compose directory not found!"; exit 1; }
docker compose down -v || { echo "ERROR: Could not stop containers!"; exit 1; }

# 4. Recreate & Restore Volumes
echo "[STEP 4/7] Recreating volumes and restoring files..."
docker volume create n8n_data >/dev/null 2>&1
docker volume create n8n_db_data >/dev/null 2>&1

# n8n_data volume restore
docker run --rm \
  -v n8n_data:/data \
  -v "$TEMP_RESTORE/n8n_data":/backup \
  busybox sh -c "cp -rp /backup/. /data/" || { echo "ERROR: Volume file restore failed!"; exit 1; }

# 5. Start Database Only
echo "[STEP 5/7] Starting database container..."
docker compose up -d n8n-db || { echo "ERROR: Failed to start n8n-db!"; exit 1; }
echo "Waiting 25 seconds for PostgreSQL to initialize..."
sleep 25

# 6. Restore Database Dump
echo "[STEP 6/7] Restoring database dump..."
if [ -f "$TEMP_RESTORE/n8n_db.dump" ]; then
    cat "$TEMP_RESTORE/n8n_db.dump" | docker exec -i n8n-db pg_restore -U n8n -d n8n --no-owner -Fc || { echo "ERROR: DB restore failed!"; exit 1; }
else
    echo "ERROR: n8n_db.dump not found in backup!"
    exit 1
fi

# 7. Start Full Stack
echo "[STEP 7/7] Starting all n8n services..."
docker compose up -d || { echo "ERROR: Final stack start failed!"; exit 1; }

echo "--- Restore Successfully Completed! ---"
echo "Restored from: $LATEST"
echo "Check your n8n instance at your local IP/domain."
echo "Login credentials and workflows are now restored."