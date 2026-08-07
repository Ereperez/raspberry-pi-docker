# Raspberry Pi Docker Homelab

Docker services running on Raspberry Pi 4 - 4GB. Written with help of Gemini, ChatGPT and Claude.

## Current services

| Service | Purpose | Status |
|---|---|---|
| Pi-hole | Network-wide DNS filtering | Live |
| Unbound | Recursive DNS resolver | Live |
| Portainer | Visual Docker monitor | Live |
| Dockge | Compose management | Not planned |
| Backrest | Encrypted backups (restic) | Live |
| Homepage | Dashboard | Planned — see [docs/homepage-dashboard.md](docs/homepage-dashboard.md) |
| Beszel | System monitoring | Planned |
| Gatus | Service monitoring | Planned |
| WUD | Docker update notifications | Planned |
| Tailscale | Remote access | Planned |

> Update this table's Status column as each service goes live — see
> `docs/CHANGELOG.md` and `docs/VERSION.md` for the running history.

## Documentation

- [docs/manual-installation.md](docs/manual-installation.md) — manual Pi setup
- [docs/raspberry-pi-setup.md](docs/raspberry-pi-setup.md) — fresh Pi bootstrap
- [docs/docker-tools.md](docs/docker-tools.md) — Portainer + Dockge
- [docs/backup-restic-backrest.md](docs/backup-restic-backrest.md) — Restic + Backrest backup setup
- [docs/homepage-dashboard.md](docs/homepage-dashboard.md) — Homepage dashboard + socket-proxy setup
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — dated history of changes
- [docs/VERSION.md](docs/VERSION.md) — pinned versions per service

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

> **Note:** the section below describes the original local backup script,
> now superseded by Restic + Backrest (encrypted, off-site, verified
> restore). See [docs/backup-restic-backrest.md](docs/backup-restic-backrest.md)
> for the current setup. Kept here for reference until the old script and
> local backup folders are formally retired.

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