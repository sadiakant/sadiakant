#!/bin/bash
LOG="/home/{your-username}/logs/ubuntu_update.log"

# Purana log delete karke naya fresh log shuru karo
> "$LOG"

echo -e "\n=== Ubuntu System Update Started: $(date) ===" >> "$LOG"
echo "→ Running apt-get update..." | tee -a "$LOG"
apt-get update 2>&1 | tee -a "$LOG"

echo -e "\n→ Checking dpkg Errors..." | tee -a "$LOG"
dpkg --configure -a 2>&1 | tee -a "$LOG"

echo -e "\n→ Fixing Broken dpkg..." | tee -a "$LOG"
apt --fix-broken install -y 2>&1 | tee -a "$LOG"

echo -e "\n→ Running apt-get upgrade..." | tee -a "$LOG"
apt-get upgrade -y 2>&1 | tee -a "$LOG"

echo -e "\n→ Running apt-get autoremove..." | tee -a "$LOG"
apt-get autoremove -y 2>&1 | tee -a "$LOG"

echo -e "=== Ubuntu System Update Finished: $(date) ===\n" >> "$LOG"
