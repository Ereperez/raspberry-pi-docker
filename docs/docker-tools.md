## You can choose to either install both or one of them

It makes sense to install them before Pi-hole and unbound if not running bootstrap. Do this after installing Docker.

---

# Portainer

**Use for:**

- View containers
- View logs
- Networks
- Volumes
- Resource usage

**Avoid:**

- Editing Compose stacks

---

# Dockge

**Use for:**

- Viewing Compose stacks
- Starting/stopping stacks
- Restarting services
- Viewing logs

**Avoid:**

- Treating it as the source of truth

---

# Installation

## 1. Download and install Docker

```bash
curl -sSL https://get.docker.com | sh
```

## 2. Add your current user to the Docker group

(so you don't need `sudo` for docker commands)

```bash
sudo usermod -aG docker $USER
```

## 3. Apply the new group permissions

```bash
newgrp docker
```

## 4. Prevent port 53 conflict (might not be running)

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

---

# Install Portainer

```bash
docker volume create portainer_data

docker run -d \
  -p 9000:9000 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

> **Now open your web browser** and go to `http://<PI-IP-ADDRESS>:9000` to set up your administrator account!

---

# Install Dockge

## 1. Create the stack storage directory and Dockge installation folder

```bash
mkdir -p /opt/stacks /opt/dockge
```

## 2. Change into the Dockge directory

```bash
cd /opt/dockge
```

## 3. Download the official compose file

```bash
curl https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output compose.yaml
```

## 4. Start Dockge

```bash
docker compose up -d
```

> **Once started**, open your browser and navigate to `http://<YOUR-PI-IP>:5001` to set up your admin account.

## Check that things are up and running
```bash
docker compose ps
```

```bash
docker ps
```