#!/bin/bash
# --- CONFIGURATION ---
BACKUP_REPO="/home/{your-username}/backups"
BACKUP_FILE="n8n-backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
export PGPASSWORD="{your-n8n-PG-password}"
DB_USER="n8n"
DB_NAME="n8n"

echo "--- Backup Session Started: $(date) ---"

# 1. Update Repo (FUTURE-PROOFED)
echo "[STEP 1/6] Cleaning and updating local repository from GitHub..."
cd "$BACKUP_REPO" || { echo "ERROR: Could not find backup directory!"; exit 1; }

# --- FIX START ---
git reset --hard HEAD > /dev/null 2>&1
git clean -fd > /dev/null 2>&1
# --- FIX END ---

git pull origin main --rebase || { echo "ERROR: Git pull failed!"; exit 1; }

# 2. Temp Directory setup
echo "[STEP 2/6] Creating temporary workspace..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# 3. DB Dump
echo "[STEP 3/6] Exporting database (pg_dump)..."
docker exec n8n-db pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner -Fc > "$TEMP_DIR/n8n_db.dump" || { echo "ERROR: Database export failed!"; exit 1; }

# 4. Copy n8n volume
echo "[STEP 4/6] Copying n8n data volume..."
docker run --rm \
  -v n8n_data:/data \
  -v "$TEMP_DIR":/backup \
  busybox cp -r /data /backup/n8n_data || { echo "ERROR: Volume copy failed!"; exit 1; }

# 5. Compress
echo "[STEP 5/6] Compressing files..."
tar -czf "$BACKUP_REPO/$BACKUP_FILE" --warning=no-file-changed -C "$TEMP_DIR" . || { echo "ERROR: Compression failed!"; exit 1; }

# 6. Git Operations
echo "[STEP 6/6] Finalizing Git operations..."
cd "$BACKUP_REPO"

# Ownership fix
chown -R root:root "$BACKUP_REPO"
git add "$BACKUP_FILE"

# === IMPROVED RETENTION POLICY (Keeping latest 5) ===
echo "Checking retention policy (Keeping latest 5)..."
git ls-files "n8n-backup_*.tar.gz" |
  xargs -r -I{} sh -c 'stat -c "%Y {}" "{}" 2>/dev/null' |
  sort -nr |
  cut -d' ' -f2- |
  tail -n +6 |
  while read -r file_to_delete; do
      if [ -n "$file_to_delete" ]; then
          echo "Removing old backup: $file_to_delete"
          git rm -f "$file_to_delete"
      fi
  done

echo "Committing and pushing to GitHub..."
git commit -m "Automated Backup: $(date +%d-%m-%Y_%H-%M-%S)" || echo "Note: No changes to commit"
git push origin main || { echo "ERROR: Git push failed!"; exit 1; }

echo "--- Backup Successfully Completed: $BACKUP_FILE ---"