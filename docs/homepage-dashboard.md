# Homepage Dashboard (with locked-down Docker socket access)

This guide covers setting up [Homepage](https://gethomepage.dev/) as the
central dashboard for the homelab, with Docker container visibility provided
through [wollomatic/socket-proxy](https://github.com/wollomatic/socket-proxy)
instead of mounting `/var/run/docker.sock` directly into the Homepage
container.

**Why not mount the socket directly?** Any container with the raw Docker
socket implicitly has the full authority of the Docker API — there's no
built-in way to scope that down. Docker can't tell the difference between a
container listing running services and a container creating a new
privileged one that mounts the host filesystem. Since Homepage is a
browser-facing app (broader attack surface than a single-purpose tool), it
gets a filtered, read-only view through a small dedicated proxy instead —
so a compromise of Homepage doesn't hand over the keys to the whole Pi.

---

## Architecture

```
                 ┌─────────────────┐
   port 3000 ──▶ │     homepage     │
                 └────────┬─────────┘
                           │ docker-proxynet (internal network)
                 ┌────────▼─────────┐
                 │   dockerproxy    │  (wollomatic/socket-proxy)
                 │  read-only, GET  │
                 │  containers only │
                 └────────┬─────────┘
                           │ /var/run/docker.sock (ro)
                 ┌────────▼─────────┐
                 │   Docker daemon   │
                 └───────────────────┘
```

- `dockerproxy` is the only container with the real socket mounted.
- `docker-proxynet` is marked `internal: true` — not reachable from outside
  the Docker host, only from containers explicitly attached to it.
- `dockerproxy` is configured with `-allowfrom=homepage`, so even another
  container on the same host couldn't use it without being named exactly
  `homepage`.
- Only `GET` requests to container listing/inspection endpoints are
  allowed — no create, start/stop, exec, volumes, or networks access.

---

## Prerequisites

- Docker and Docker Compose running on the Pi
- The GID of the host's `docker` group:
  ```bash
  getent group docker
  ```
  This prints something like `docker:x:999:pi` — the number (`999` here) is
  needed for the proxy container's `user:` setting, so it can read the
  socket without running as root.

---

## 1. Folder structure

Following the repo's one-folder-per-service convention:

```
homepage/
├── docker-compose.yml
├── .env
├── .env.example
└── config/
    ├── settings.yaml
    ├── services.yaml
    ├── widgets.yaml
    ├── bookmarks.yaml
    └── docker.yaml
```

## 2. `.env`

```bash
cp .env.example .env
```

Fill in:

```bash
TZ=Europe/Stockholm
# Must include every host:port combination used to access Homepage
HOMEPAGE_ALLOWED_HOSTS=192.168.1.79:3000
PUID=1000
PGID=1000
# From `getent group docker` above
DOCKER_GID=999
```

`HOMEPAGE_ALLOWED_HOSTS` is required — Homepage refuses to load if the host
you're browsing from isn't in this list. Add more entries (comma-separated)
later if you reverse-proxy Homepage through Nginx Proxy Manager or access it
over Tailscale.

## 3. `docker-compose.yml`

```yaml
services:
  dockerproxy:
    image: wollomatic/socket-proxy:1
    container_name: homepage-dockerproxy
    hostname: dockerproxy
    restart: unless-stopped

    read_only: true
    mem_limit: 64M
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges
    user: '65534:${DOCKER_GID}'

    command:
      - '-loglevel=info'
      - '-listenip=0.0.0.0'
      - '-listenport=2375'
      - '-allowfrom=homepage'
      - '-allowGET=/v1\..{1,2}/(containers.*|version|info)'
      - '-allowHEAD=/_ping'
      - '-watchdoginterval=3600'
      - '-stoponwatchdog'
      - '-shutdowngracetime=10'

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

    networks:
      - docker-proxynet

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'

  homepage:
    image: ghcr.io/gethomepage/homepage:v1.13.2
    container_name: homepage
    hostname: homepage
    restart: unless-stopped

    depends_on:
      - dockerproxy

    ports:
      - '3000:3000'

    environment:
      TZ: ${TZ}
      HOMEPAGE_ALLOWED_HOSTS: ${HOMEPAGE_ALLOWED_HOSTS}
      PUID: ${PUID}
      PGID: ${PGID}

    volumes:
      - ./config:/app/config
      - ./images:/app/public/images

    networks:
      - default
      - docker-proxynet

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'

networks:
  docker-proxynet:
    name: homepage-dockerproxynet
    internal: true
```

Notes, consistent with the rest of the repo's conventions:

- **Pinned versions** for both images (`v1.13.2`, `wollomatic/socket-proxy:1`
  tracks the latest 1.x without breaking changes — pin to an exact patch
  version like `1.11.4` instead if you want fully static behavior).
- `homepage` never sees `/var/run/docker.sock` directly, only `dockerproxy`
  does, and that mount is read-only.
- `docker-proxynet` is `internal: true` so nothing outside the Docker host
  can reach the proxy, even if its port were somehow exposed.

## 4. Config files

### `config/docker.yaml`

Tells Homepage where to find the proxy for any live container status
widgets:

```yaml
---
my-docker:
  host: dockerproxy
  port: 2375
```

### `config/settings.yaml`

```yaml
---
title: Homelab
theme: dark
color: slate

layout:
  DNS:
    style: row
    columns: 2
  Homelab Tools:
    style: row
    columns: 3
```

### `config/services.yaml`

Starter tiles for what's already deployed, plus placeholders for what's
coming next:

```yaml
---
- DNS:
    - Pi-hole:
        icon: pi-hole.png
        href: http://192.168.1.79/admin
        description: DNS filtering
        widget:
          type: pihole
          url: http://pihole
          key: ${PIHOLE_API_KEY}

    - Backrest:
        icon: restic.png
        href: http://192.168.1.79:9898
        description: Backup status

- Homelab Tools:
    - Dozzle:
        icon: dozzle.png
        href: http://192.168.1.79:8080
        description: Container logs

    - Beszel:
        icon: beszel.png
        href: http://192.168.1.79:8090
        description: System monitoring

    - Gatus:
        icon: gatus.png
        href: http://192.168.1.79:8081
        description: Uptime checks
```

`PIHOLE_API_KEY` needs adding to `homepage/.env` — generate it from the
Pi-hole admin UI under Settings → API.

### `config/widgets.yaml`

Top-of-page info widgets:

```yaml
---
- resources:
    label: Pi
    cpu: true
    memory: true
    disk: /

- datetime:
    text_size: xl
    format:
      timeStyle: short
      dateStyle: short
```

### `config/bookmarks.yaml`

Empty scaffold, ready to fill in later:

```yaml
---
# - Group Name:
#     - Bookmark Name:
#         - abbr: BN
#           href: https://example.com
```

## 5. Bring it up

```bash
cd ~/RASPBERRY-PI-DOCKER/homepage
docker compose up -d
docker compose logs dockerproxy
```

Confirm `dockerproxy` starts cleanly with no permission errors in its logs
before checking Homepage itself. A permission error here almost always
means `DOCKER_GID` in `.env` doesn't match the real `docker` group GID on
the Pi.

Visit `http://192.168.1.79:3000`.

---

## Extending later

- **Adding a new service tile:** add an entry under the relevant group in
  `services.yaml`. To show live container status (not just a link), add
  `server: my-docker` and `container: <container_name>` to that entry —
  this is what `config/docker.yaml` enables.
- **Reusing the proxy for Dozzle:** `dockerproxy`'s `-allowfrom` is
  currently scoped to just `homepage`. When Dozzle is deployed, either add
  a second `-allowfrom` entry (comma-separated, if supported by the version
  in use — check current docs) or stand up a second, separately-scoped
  proxy dedicated to Dozzle. Prefer the second approach if in doubt — one
  proxy per consumer keeps the allowlists simple and avoids accidentally
  widening scope for both services at once.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Homepage shows a blank page / refused to load | `HOMEPAGE_ALLOWED_HOSTS` doesn't include the host:port you're browsing from |
| `dockerproxy` container exits immediately | `DOCKER_GID` in `.env` doesn't match `getent group docker` on the host |
| Homepage can't reach Docker status widgets | Confirm `homepage` container is on both `default` and `docker-proxynet`; confirm `docker.yaml` points at `dockerproxy:2375`, not `localhost` or the raw socket |
| Pi-hole widget shows an error | `PIHOLE_API_KEY` missing/incorrect in `homepage/.env`, or key was regenerated in Pi-hole since |
| Proxy logs show `403` on a request Homepage makes | The requested API path isn't covered by `-allowGET` — widen the regex deliberately rather than switching to a broad `.*` allow |