# Raspberry Pi Initial Setup

This guide prepares a fresh Raspberry Pi OS Lite (64-bit) installation for the homelab.
Only run bootstrap-fresh-pi.sh on a freshly installed Raspberry Pi OS.

---

# 1. Update Raspberry Pi OS

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

---

# 2. Clone this repository

```bash
git clone https://github.com/Ereperez/raspberry-pi-docker.git

cd RASPBERRY-PI-DOCKER
```

---

# 3. Run bootstrap-fresh-pi

```bash
chmod +x scripts/bootstrap-fresh-pi.sh

./scripts/bootstrap-fresh-pi.sh
```

The script installs:

- Docker
- Docker Compose
- Git
- curl
- wget
- vim
- nano
- htop
- btop
- dnsutils
- unattended-upgrades
- needrestart

It also:

- enables Docker
- adds the current user to the docker group

---

# 4. Reboot

```bash
sudo reboot
```

---

# 5. Verify Docker

```bash
docker --version

docker compose version
```

---

# 6. Configure DNS stack

Navigate to the DNS folder.

```bash
cd ~/RASPBERRY-PI-DOCKER/dns
```

Copy the example environment file.

```bash
cp .env.example .env
```

Edit it.

```bash
nano .env
```

Example:

```dotenv
TZ=Europe/Stockholm
PIHOLE_PASSWORD=ChooseAStrongPassword
```

---

# 7. Deploy Pi-hole & Unbound

```bash
docker compose pull

docker compose up -d
```

Check that both containers are running.

```bash
docker compose ps
```

View logs.

```bash
docker compose logs -f
```

Check that any Portainer/Dockge container is also running.

```bash
docker ps
```

---

# 8. Configure the router

On the UniFi Express 7:

- Leave DHCP enabled.
- Set the Raspberry Pi IP as the primary DNS server.

Example:

```
Router IP:        192.168.1.1
Raspberry Pi:     192.168.1.10

DNS Server:
192.168.1.10
```

---

# 9. Configure Pi-hole

Open:

```
http://<raspberry-pi-ip>/admin
```

Log in using the password from `.env`.

Verify:

- Upstream DNS → Unbound
- DNSSEC enabled
- No public DNS providers enabled

---

# 10. Add blocklists

Recommended:

Currently in use:

```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
```

```
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/popupads.txt
```

```
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/native.lgwebos.txt
```

```
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/native.xiaomi.txt
```

```
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt
```

```
https://big.oisd.nl
```

```
https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt
```

```
https://gist.github.com/mcrumm/972070dfe67d44ed61c4247563cbf07c
```

```
https://badblock.celenity.dev/abp/lg.txt
```

General

- OISD (Small)
- HaGeZi Multi Light (or Normal)

Update Gravity afterwards.

---

# 11. Verify DNS

Run:

```bash
dig google.com @127.0.0.1
```

or

```bash
dig google.com @<raspberry-pi-ip>
```

You should receive a valid response.

---

# 12. Commit future changes

Make configuration changes on your PC.

```bash
git add .
git commit -m "Describe changes"

git push
```

On the Raspberry Pi:

```bash
git pull
```

Redeploy if required.

```bash
cd dns

docker compose pull

docker compose up -d
```
