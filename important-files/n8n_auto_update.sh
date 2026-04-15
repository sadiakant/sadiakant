#!/bin/bash
LOG="/home/{your-username}/logs/n8n_update.log"

# Purana log delete karke naya fresh log shuru karo
> "$LOG"

echo -e "\n=== n8n Update Check Started: $(date) ===" >> "$LOG"
cd /home/{your-username}

echo "→ Pulling latest images..." | tee -a "$LOG"
 /usr/bin/docker compose pull 2>&1 | tee -a "$LOG"

if grep -qE "(Downloaded newer image|Pull complete)" "$LOG"; then
    echo -e "\n→ New update found! Restarting containers..." | tee -a "$LOG"
    /usr/bin/docker compose up -d --force-recreate 2>&1 | tee -a "$LOG"
    echo -e "\n→ Pruning old images..." | tee -a "$LOG"
    /usr/bin/docker image prune -f 2>&1 | tee -a "$LOG"
else
    echo -e "\n→ No new update available. Already up to date." | tee -a "$LOG"
fi

echo -e "=== n8n Update Finished: $(date) ===\n" >> "$LOG"