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

```
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
```

---

# Initial Setup

## Install Docker

```bash
curl -fsSL https://get.docker.com | sh
```

### Add user to docker group

```bash
sudo usermod -aG docker $USER
```

### Log out and back in

### Verify installation

```bash
docker --version
docker compose version
```

### Go to DNS folder

```bash
cd ~/RASPBERRY-PI-DOCKER/dns
```

### Create environment file

```bash
nano .env
```

**Example `.env` contents:**

```
TZ=Europe/Stockholm
PIHOLE_PASSWORD=change_this_password
```

### Start services

```bash
docker compose up -d
```

### Check status

```bash
docker compose ps
```

### View logs

```bash
docker compose logs -f
```

---

# Pi-hole Configuration

### Log in to Pi-hole as admin

```
http://raspberrypi/admin
```

Or via SSH:

```bash
ssh USERNAME@IPADDRESS
```

### Configure DNS upstream

- Use Unbound
- Disable other upstream DNS providers

### Blocklists

**LG TV:**

- https://badblock.celenity.dev/abp/lg.txt
- https://gist.githubusercontent.com/mcrumm/972070dfe67d44ed61c4247563cbf07c/raw

**Alternative blocklists:**

General smart TV block:
- https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt

Samsung block:
- https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/native.samsung.txt

### Update gravity

Go to **Tools → Update Gravity**

---

# Updating DNS Stack

### Check image updates

```bash
docker compose pull
```

### Review changes and redeploy

```bash
docker compose up -d
```

### Remove unused images

```bash
docker image prune
```

---

# Backup

### Run backup script

```bash
./backup-docker.sh
```

Backups are stored locally.

### Security note

`.env` is excluded from backups. That means your passwords are not backed up.

You could back up `.env` separately encrypted and store the encrypted file somewhere safe:

```bash
gpg -c dns/.env
```

---

# Restore

### Extract backup archive

Restore folders:
- `dns/pihole`
- `dns/unbound`

### Start services

```bash
docker compose up -d
```

---

# Maintenance

### Check containers

```bash
docker ps
```

### Check resource usage

```bash
docker stats
```

### Restart DNS

```bash
docker compose restart
```

---

# Git Workflow

### Commit configuration changes

```bash
git add .
git commit -m "Update DNS configuration"
```

**Do not commit:**
- `.env` files
- Passwords
- Databases
- Backups

### Backup script

Make executable:

```bash
chmod +x scripts/backup-docker.sh
```

### Update script

Make executable:

```bash
chmod +x scripts/update-dns.sh
```

---

# Fresh Raspberry Pi Install

### Run the bootstrap script

```bash
chmod +x scripts/bootstrap-fresh-pi.sh
```

> **⚠️ Important:** Only run `bootstrap-fresh-pi.sh` on a freshly installed Raspberry Pi OS.