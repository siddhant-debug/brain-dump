#!/bin/bash

# Configuration
PROJECT_ROOT="/home/sidtom/application/projects/brain-dump/backend"
ENV_FILE="$PROJECT_ROOT/.env"
BACKUP_DIR="/backups/braindump"
LOG_FILE="/var/log/braindump_backup.log"
EMAIL="siddhanttomar@hotmail.com"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/braindump_$TIMESTAMP.sql.gz"

# Ensure log file exists and is writable
touch "$LOG_FILE" 2>/dev/null

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    # Filter only relevant variables to avoid issues with special characters
    export $(grep -E "^DATABASE_URL=" "$ENV_FILE" | xargs)
else
    log "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

if [ -z "$DATABASE_URL" ]; then
    log "ERROR: DATABASE_URL not found in $ENV_FILE"
    exit 1
fi

# Parse DATABASE_URL for pg_dump
# Format: postgresql+psycopg://user:password@host:port/dbname
# Remove the +psycopg part if it exists
CLEAN_URL=$(echo $DATABASE_URL | sed 's/postgresql+psycopg/postgresql/')

log "Starting backup to $BACKUP_FILE"

# Run pg_dump and compress
if pg_dump "$CLEAN_URL" | gzip > "$BACKUP_FILE"; then
    log "SUCCESS: Backup created at $BACKUP_FILE"
    
    # Auto-delete backups older than 7 days
    find "$BACKUP_DIR" -type f -name "braindump_*.sql.gz" -mtime +7 -delete
    log "Old backups (7+ days) cleaned up"

    # Send success email
    SUBJECT="✅ BrainDump Backup Success — $(date +'%Y-%m-%d')"
    BODY="Timestamp: $(date)\nBackup file: $BACKUP_FILE"
    echo -e "Subject: $SUBJECT\n\n$BODY" | sendmail "$EMAIL"
else
    log "ERROR: Backup failed for $BACKUP_FILE"
    
    # Send failure email
    SUBJECT="❌ BrainDump Backup Failed — $(date +'%Y-%m-%d')"
    BODY="Timestamp: $(date)\nError: pg_dump failed. Check $LOG_FILE for details."
    echo -e "Subject: $SUBJECT\n\n$BODY" | sendmail "$EMAIL"
    exit 1
fi
