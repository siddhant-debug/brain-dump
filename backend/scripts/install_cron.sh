#!/bin/bash

# Configuration
PROJECT_ROOT="/home/sidtom/application/projects/brain-dump/backend"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup_db.sh"
BACKUP_DIR="/backups/braindump"
LOG_FILE="/var/log/braindump_backup.log"
USER_NAME="sidtom"
CRON_TIME="0 22 * * *"
CRON_COMMENT="# 3:30 AM IST (22:00 UTC)"

echo "--- PostgreSQL Backup Setup ---"

# 1. Make script executable
if [ -f "$BACKUP_SCRIPT" ]; then
    chmod +x "$BACKUP_SCRIPT"
    echo "✅ Made $BACKUP_SCRIPT executable"
else
    echo "❌ ERROR: $BACKUP_SCRIPT not found!"
    exit 1
fi

# 2. Check for msmtp/sendmail
if ! command -v msmtp &> /dev/null && ! command -v sendmail &> /dev/null; then
    echo "Installing msmtp for email notifications..."
    sudo apt-get update && sudo apt-get install -y msmtp msmtp-mta
    echo "✅ Installed msmtp"
else
    echo "✅ Mail utility found"
fi

# 3. Create backup directory and log file with correct permissions (One-time sudo step)
echo "Setting up directories and permissions..."
sudo mkdir -p "$BACKUP_DIR"
sudo touch "$LOG_FILE"
sudo chown -R "$USER_NAME:$USER_NAME" "$BACKUP_DIR"
sudo chown "$USER_NAME:$USER_NAME" "$LOG_FILE"
sudo chmod 750 "$BACKUP_DIR"
echo "✅ Directory and log file ready (owned by $USER_NAME)"

# 4. Add cron job
# Check if entry already exists
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "ℹ️ Cron entry already exists, updating..."
    (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_TIME $BACKUP_SCRIPT $CRON_COMMENT") | crontab -
else
    echo "Registering cron job..."
    (crontab -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_TIME $BACKUP_SCRIPT") | crontab -
fi
echo "✅ Cron job registered"

# 5. Confirm registration
echo "--- Current Crontab ---"
crontab -l
echo "-----------------------"
echo "Setup complete. Please ensure you configure /etc/msmtprc or ~/.msmtprc for emails to work."
