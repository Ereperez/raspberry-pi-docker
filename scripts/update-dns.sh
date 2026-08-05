#!/bin/bash

set -e

DNS_DIR="$HOME/RASPBERRY-PI-DOCKER/dns"

cd "$DNS_DIR"

echo "Checking DNS container updates..."

docker compose pull

echo
echo "Applying updates..."

docker compose up -d

echo
echo "Cleaning unused images..."

docker image prune -f

echo
echo "DNS update complete."

docker compose ps