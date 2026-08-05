#!/bin/bash

set -e

BACKUP_DIR="$HOME/docker-backups"
DATE=$(date +"%Y-%m-%d_%H-%M")

SOURCE="$HOME/RASPBERRY-PI-DOCKER"

mkdir -p "$BACKUP_DIR"

echo "Creating Docker backup..."

tar \
  --exclude=".git" \
  --exclude=".env" \
  -czf \
  "$BACKUP_DIR/docker-backup-$DATE.tar.gz" \
  "$SOURCE"

echo "Backup complete:"
echo "$BACKUP_DIR/docker-backup-$DATE.tar.gz"