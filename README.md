# Raspberry Pi Docker Homelab

Docker services running on Raspberry Pi.

## Current services

| Service | Purpose |
|---|---|
| Pi-hole | Network-wide DNS filtering |
| Unbound | Recursive DNS resolver |
| Beszel | System monitoring |
| Gatus | Service monitoring |
| Homepage | Dashboard |
| WUD | Docker update notifications |
| Tailscale | Remote access |

---

# DNS Stack

## Architecture

Devices
|
|
Router
|
| DNS
|
Raspberry Pi
|
+-- Pi-hole :53
|
|
+-- Unbound
|
|
Internet DNS root servers

---

# Initial setup
## Install Docker

*bash*
"curl -fsSL https://get.docker.com | sh"

### Add user to docker group:
sudo usermod -aG docker $USER

### Log out and back in.
*Verify:*
docker --version
docker compose version

### Go to DNS folder:
cd ~/RASPBERRY-PI-DOCKER/dns

### Create environment file:
nano .env

*Example:*
TZ=Europe/Stockholm
PIHOLE_PASSWORD=change_this_password

### Start services:
docker compose up -d

#### Check status:
docker compose ps

#### View logs:
docker compose logs -f

## Pi-hole configuration

### Log in to Pihole as admin:
http://raspberrypi/admin or in PS: ssh USERNAME@IPADDRESS and then enter password

*Configure:*
DNS upstream
*Use:*
unbound
#### Disable other upstream DNS providers.

### Blocklists
*Add:*
### LG TV:
https://badblock.celenity.dev/abp/lg.txt
https://gist.githubusercontent.com/mcrumm/972070dfe67d44ed61c4247563cbf07c/raw
### Alt:
General smart TV block:
https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt

Samsung block:
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/native.samsung.txt

### Update gravity:
Tools -> Update Gravity


## Updating DNS stack

#### Check image updates:
docker compose pull

#### Review changes.
docker compose up -d

#### Remove unused images:
docker image prune

## Backup

*Run:*
./backup-docker.sh
#### Backups are stored locally.

### Security note
.env is excluded.
That means your passwords are not backed up.
You could back up .env separately encrypted and store the encrypted file somewhere safe:
gpg -c dns/.env

## Restore

### Extract backup archive.
*Restore folders:*
dns/pihole
dns/unbound
#### Start:
docker compose up -d

## Maintenance

#### Check containers:
docker ps
#### Check resource usage:
docker stats
#### Restart DNS:
docker compose restart

--- 
## Git workflow

### Commit configuration changes:
git add .
git commit -m "Update DNS configuration"
#### Do not commit: .env files, passwords, databases, backups
### scripts/backup-docker.sh 
*Make executable:*
chmod +x scripts/backup-docker.sh

### scripts/update-dns.sh
*Make executable:*
chmod +x scripts/update-dns.sh

## Fresh RaspberryPi install
### Run the bootstrap-fresh-pi.sh file
chmod +x scripts/bootstrap-fresh-pi.sh
#### Only run bootstrap-fresh-pi.sh on a freshly installed Raspberry Pi OS.