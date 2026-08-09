# WUD (What's Up Docker) — Update Notifications

[WUD](https://getwud.github.io/wud/) watches Docker container images and
reports when a newer version is available. Chosen over Watchtower
specifically because Watchtower auto-updates by default; WUD is
notify-only unless explicitly configured otherwise — matches the
preference for reviewing updates rather than having them applied
automatically.

---

## Watch mode — notify only, opt-in per container

**Nothing is monitored by default**, even with the Docker socket mounted.
A container must be explicitly labeled to appear in WUD:

```yaml
services:
  some-service:
    image: some/image:1.2.3
    labels:
      - wud.watch=true
```

No update-trigger environment variables (`WUD_TRIGGER_*`) are configured
in this setup — WUD reports what it finds, nothing is applied
automatically. Adding an update trigger later is possible but is a
deliberate escalation from "tells me" to "does it for me" and should be a
conscious choice per-container, not a default.

## Docker socket access — same trade-off as Beszel

The socket is mounted directly into WUD, read-only, rather than through a
filtered `socket-proxy` like Homepage's setup. WUD needs to inspect image
digests and registry metadata across every container it watches — broader
access than a simple container-list proxy scopes cleanly, same reasoning
as Beszel's agent (see `beszel-monitoring.md`). Read-only mount + no
trigger env vars configured means WUD has no actual path to modify or
recreate any container even via its own UI, regardless of what's clicked
in the web interface.

---

## 1. Folder structure

```
wud/
├── docker-compose.yml
├── .env
└── .env.example
```

(WUD's own state — `wud.json` — persists in `./data`, created on first run.)

## 2. `docker-compose.yml`

```yaml
services:
  wud:
    image: ghcr.io/getwud/wud:8.3.1
    container_name: wud
    hostname: wud
    restart: unless-stopped

    read_only: true
    security_opt:
      - no-new-privileges

    # Published on 3001 -- 3000 is already taken by Homepage.
    ports:
      - '3001:3000'

    environment:
      TZ: ${TZ}
      WUD_WATCHER_LOCAL_CRON: '0 0 * * *'
      WUD_AUTH_BASIC_HOMELAB_USER: ${WUD_ADMIN_USER}
      WUD_AUTH_BASIC_HOMELAB_HASH: ${WUD_ADMIN_PASSWORD_HASH}

    volumes:
      - ./data:/store
      - /var/run/docker.sock:/var/run/docker.sock:ro

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

## 3. Generate the basic-auth password hash

Needs `apache2-utils` (provides `htpasswd`) — a small, single-purpose
package, safe to remove afterward if preferred:

```bash
sudo apt update
sudo apt install apache2-utils

htpasswd -nb 'yourusername' 'yourpassword' | cut -d: -f2
```

This prints an **Apache-style APR1 (MD5) hash** — not bcrypt, despite that
being a more common default elsewhere. It looks like:
```
$apr1$xxxxxxxx$yyyyyyyyyyyyyyyyyyyyyy
```

### Critical: escape every `$` before saving to `.env`

An APR1 hash always contains multiple `$`-delimited segments. Docker
Compose treats `$` as the start of a variable reference **even inside
`.env` files**, and silently substitutes an empty string for anything it
doesn't recognize as a defined variable — no error, just a quietly broken
value. This bit both Backrest's password and this hash during initial
setup; the tell-tale sign is
`WARN "some_fragment" variable is not set. Defaulting to a blank string`
in `docker compose` output.

Every `$` in the hash needs doubling to `$$`:
```
$apr1$xxxxxxxx$yyyyyyyyyyyyyyyyyyyyyy
```
becomes, in `.env`:
```
WUD_ADMIN_PASSWORD_HASH=$$apr1$$xxxxxxxx$$yyyyyyyyyyyyyyyyyyyyyy
```

## 4. `.env`

```bash
cp .env.example .env
nano .env
```

```bash
TZ=Europe/Stockholm
WUD_ADMIN_USER=yourusername
WUD_ADMIN_PASSWORD_HASH=$$apr1$$xxxxxxxx$$yyyyyyyyyyyyyyyyyyyyyy
```

## 5. Deploy

```bash
docker compose up -d
docker compose logs -f wud
```

Look for `Some authentications failed to register` in the logs — if
present, the hash didn't come through correctly (almost always the `$$`
escaping above). A clean start shows auth registering without that
warning.

Visit `http://192.168.1.79:3001` — should prompt for the username/password
set above, not show a blank page. A blank white box with no input fields
is the visible symptom of the empty-hash bug.

## 6. Opt a container in for watching

Add the label to any service in its own `docker-compose.yml`:
```yaml
labels:
  - wud.watch=true
```
Then `docker compose up -d` that service (recreate, not just restart, for
the label to register). It should appear in WUD's dashboard within the
next scan (or immediately on next manual refresh in the UI).

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Blank white page at the WUD URL, no login fields | Basic auth hash arrived empty — check logs for `WARN "..." variable is not set` and `"hash" is not allowed to be empty`, fix `$` escaping in `.env` |
| A container never shows up in WUD | Missing `wud.watch=true` label, or the container wasn't recreated after adding it |
| WUD shows a container as up-to-date when it isn't (or vice versa) | Tag-matching heuristics can be imprecise for non-semver tags (e.g. `latest`, date-based tags) — check WUD's own docs on `wud.tag.include`/`wud.tag.transform` labels for that specific image's tagging scheme |