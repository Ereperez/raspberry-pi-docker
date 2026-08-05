# Manual Raspberry Pi Setup

This guide assumes Raspberry Pi OS Lite 64-bit and performs the installation manually rather than using `scripts/bootstrap.sh`.

---

# 1. Update the OS

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

---

# 2. Install common utilities

```bash
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
```

---

# 3. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
```

Add your user to the Docker group:

```bash
sudo usermod -aG docker $USER
```

Enable and start Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Reboot:

```bash
sudo reboot
```

---

# 4. Verify Docker

```bash
docker --version
docker compose version
docker ps
```

---

# 5. Clone the repository

```bash
git clone git@github.com:<username>/RASPBERRY-PI-DOCKER.git
cd RASPBERRY-PI-DOCKER
```

---

# 6. (Optional) Install Portainer

Create a Docker volume:

```bash
docker volume create portainer_data
```

Run Portainer CE:

```bash
docker run -d \
  --name portainer \
  --restart unless-stopped \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

Access:

```
https://<raspberry-pi-ip>:9443
```

Use Portainer for:

- Viewing containers
- Viewing logs
- Inspecting networks and volumes

Avoid editing Compose stacks from the UI if Git is your source of truth.

---

# 7. (Optional) Install Dockge

Create the required directories:

```bash
mkdir -p ~/dockge/data
mkdir -p ~/stacks
```

Create a `compose.yaml` for Dockge (or use the official example from the project), then start it with:

```bash
docker compose up -d
```

Access:

```
http://<raspberry-pi-ip>:5001
```

Use Dockge to:

- View Compose stacks
- Restart stacks
- View logs

Continue editing Compose files in Git and deploying with `git pull` and `docker compose up -d`.

---

# 8. Deploy the DNS stack

```bash
cd ~/RASPBERRY-PI-DOCKER/dns
cp .env.example .env
nano .env
```

Example:

```dotenv
TZ=Europe/Stockholm
PIHOLE_PASSWORD=ChangeMe
```

Download images:

```bash
docker compose pull
```

Start the stack:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
docker compose logs
```

Open:

```
http://<raspberry-pi-ip>/admin
```

---

# 9. Configure the router

Set the Raspberry Pi as the DNS server in UniFi.

Leave DHCP on the router.

---

# 10. Configure Pi-hole

- Verify Unbound is the upstream resolver.
- Enable DNSSEC (if not already handled by your chosen configuration).
- Add your preferred blocklists.
- Run **Update Gravity**.

---

# 11. Workflow

Development:

```
VS Code
↓
git commit
↓
git push
```

Deployment:

```bash
git pull
cd dns
docker compose pull
docker compose up -d
```