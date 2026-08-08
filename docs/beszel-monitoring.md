# Beszel — System Monitoring (Hub + Agent)

[Beszel](https://beszel.dev) provides lightweight system and Docker
container monitoring: CPU, memory, disk, network, temperature, and load
average, with historical data and alerting. It's split into two
components — a **hub** (web UI + API, built on PocketBase) and an
**agent** (runs on each monitored system, reports metrics back to the
hub). This setup runs both on the Pi, monitoring the Pi itself.

---

## Version and security notes

Pinned to **v0.18.7**. This version matters, not just as a version-pin
convention — it patches two real advisories affecting exactly the kind of
access this setup grants the agent:

- **GHSA-phwh-4f42-gwf3** — Docker API path traversal via unsanitized
  container ID (moderate severity), fixed in 0.18.4
- **GHSA-5f5r-95pg-xrpm** — IDOR allowing an authenticated hub user to
  access another user's system/container data by guessing IDs (low
  severity, single-user setups unaffected in practice), fixed in 0.18.7

Don't downgrade below 0.18.7 for this reason. Check
[github.com/henrygd/beszel/releases](https://github.com/henrygd/beszel/releases)
before deploying if it's been a while since this doc was written — bump
deliberately, same as the rest of the stack.

## Docker socket access — a deliberate trade-off, not an oversight

The agent mounts `/var/run/docker.sock` **directly**, read-only — unlike
Homepage's Docker visibility, which goes through a narrowly-scoped
`wollomatic/socket-proxy` instance. This is intentional, not an
inconsistency:

- Homepage only needs to list containers and read basic status — a simple
  GET-only regex allowlist covers that cleanly.
- Beszel needs deeper access: per-container CPU/memory/network stats,
  which means hitting a wider surface of the Docker API. Scoping that
  cleanly through a simple path-regex proxy the way Homepage's is set up
  isn't practical without either breaking functionality or building
  something considerably more complex than the socket-proxy pattern is
  meant to provide.
- The two CVEs above are exactly the kind of risk this access pattern
  carries — which is why staying current on Beszel's version matters more
  here than it does for most other services in this stack.

If this ever feels worth revisiting (e.g. exposing the hub beyond the
LAN), reducing the agent's Docker access scope should be looked at again
at that point — right now it's LAN-only, single-user, and running a
patched version, which keeps the actual risk low.

---

## 1. Folder structure

```
beszel/
├── docker-compose.yml
├── .env
├── .env.example
├── data/          (hub's PocketBase data -- created on first run)
└── agent_data/    (agent's local state -- created on first run)
```

## 2. `docker-compose.yml`

```yaml
services:
  beszel-hub:
    image: henrygd/beszel:0.18.7
    container_name: beszel
    hostname: beszel
    restart: unless-stopped

    ports:
      - '8090:8090'

    environment:
      TZ: ${TZ}

    volumes:
      - ./data:/beszel_data

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'

  beszel-agent:
    image: henrygd/beszel-agent:0.18.7
    container_name: beszel-agent
    hostname: beszel-agent
    restart: unless-stopped

    depends_on:
      - beszel-hub

    # Required for accurate host-level network stats -- without host
    # networking the agent only sees its own isolated container network.
    network_mode: host

    environment:
      TZ: ${TZ}
      LISTEN: ${BESZEL_AGENT_LISTEN}
      # Hub's SSH public key -- verifies the agent is talking to the
      # legitimate hub. Same value for every agent this hub manages.
      KEY: ${BESZEL_HUB_PUBLIC_KEY}
      # Pairing token, generated per-system in the hub's "Add System"
      # dialog. Confirmed reusable across agent restarts (not single-use).
      TOKEN: ${BESZEL_AGENT_TOKEN}
      # Lets the agent connect out to the hub rather than the hub needing
      # to reach the agent directly.
      HUB_URL: http://192.168.1.79:8090

    volumes:
      - ./agent_data:/var/lib/beszel-agent
      - /var/run/docker.sock:/var/run/docker.sock:ro

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

## 3. `.env.example`

```bash
# No quotes around values. Escape literal $ as $$. Save as LF line endings, not CRLF.

TZ=

# Port the agent listens on for the hub's connection.
BESZEL_AGENT_LISTEN=45876

# From the hub's "Add System" dialog -- Public Key field.
BESZEL_HUB_PUBLIC_KEY=

# From the hub's "Add System" dialog -- Token field.
BESZEL_AGENT_TOKEN=
```

## 4. First deploy — chicken-and-egg sequence

`BESZEL_HUB_PUBLIC_KEY` and `BESZEL_AGENT_TOKEN` don't exist until you've
added a system in the hub's UI, which requires the hub to already be
running. So the first startup is agent-then-fix, not one clean pass:

```bash
cd ~/RASPBERRY-PI-DOCKER/beszel
cp .env.example .env
nano .env   # fill in TZ, BESZEL_AGENT_LISTEN=45876, leave the rest blank

docker compose up -d
```

The agent will sit unhealthy/erroring at this point — expected.

1. Visit `http://192.168.1.79:8090`, create the admin account
2. Click **Add System**
3. Name it (e.g. `RPi4`), leave Host/IP and Port as generated
4. Copy the **Public Key** and **Token** shown
5. Click the **Docker** tab / **Copy docker compose** if you want to
   cross-check the exact snippet the hub expects
6. Back in `.env`, fill in `BESZEL_HUB_PUBLIC_KEY` and `BESZEL_AGENT_TOKEN`
7. Recreate the agent:
   ```bash
   docker compose up -d --force-recreate beszel-agent
   docker compose logs -f beszel-agent
   ```

Refresh the hub's Systems view — should flip to connected within seconds,
showing live CPU/memory/disk/network/temp/load.

## 5. Verify

```bash
docker compose ps
```
Both containers should show `Up` (hub) / running (agent — `network_mode:
host` containers don't show published ports the normal way, that's
expected). In the hub UI, confirm the agent version shown matches the
pinned image tag (`0.18.7`) and that stats are actively updating, not
frozen.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Agent won't connect, hub shows system as pending | `BESZEL_HUB_PUBLIC_KEY` or `BESZEL_AGENT_TOKEN` missing/wrong in `.env` — re-copy from the hub's Add System dialog |
| Agent shows no network stats, or wrong host network usage | Confirm `network_mode: host` is actually set — without it the agent reports its own container's isolated network, not the Pi's |
| No Docker/container stats in the hub | Confirm `/var/run/docker.sock` is mounted into the agent; check agent logs for a permission error |
| Agent reconnects fail after a restart | Shouldn't happen — token confirmed reusable in this setup. If it does, check for a newer Beszel version changing this behavior |