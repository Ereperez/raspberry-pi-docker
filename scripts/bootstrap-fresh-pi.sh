#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " Raspberry Pi Docker Bootstrap"
echo "====================================="
echo

# Ensure script isn't run as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as your normal user."
    echo "It will use sudo when required."
    exit 1
fi

echo "Updating Raspberry Pi OS..."
sudo apt update
sudo apt full-upgrade -y

echo
echo "Installing useful packages..."

sudo apt install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    btop \
    unzip \
    dnsutils \
    ca-certificates \
    unattended-upgrades \
    needrestart

echo
echo "Installing Docker..."

curl -fsSL https://get.docker.com | sh

echo
echo "Adding current user to docker group..."

sudo usermod -aG docker "$USER"

echo
echo "Enabling Docker service..."

sudo systemctl enable docker
sudo systemctl start docker

echo
echo "Docker version:"
sudo docker --version

echo
echo "Docker Compose version:"
sudo docker compose version

echo
echo "====================================="
echo " bootstrap-fresh-pi complete!"
echo "====================================="
echo
echo "Next steps:"
echo
echo "1. Reboot:"
echo "      sudo reboot"
echo
echo "2. Clone your repository:"
echo
echo "      git clone <your repository>"
echo
echo "3. Create your .env file:"
echo
echo "      cd RASPBERRY-PI-DOCKER/dns"
echo "      cp .env.example .env"
echo
echo "4. Start Pi-hole:"
echo
echo "      docker compose up -d"
echo
echo "====================================="