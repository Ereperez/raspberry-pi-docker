# Backups: Restic + Backrest + Google Drive (rclone)

This guide covers setting up encrypted, deduplicated backups for the homelab
using [restic](https://restic.net/) as the backup engine and
[Backrest](https://github.com/garethgeorge/backrest) as the web UI/orchestrator
on top of it. Backups are stored on Google Drive via `rclone`.

**Scope:** this backs up configs, databases, and other irreplaceable state
(e.g. `RASPBERRY-PI-DOCKER/` — Pi-hole DB, Unbound config, app configs).
It does **not** back up media libraries (Jellyfin/Plex) or anything
re-downloadable/re-rippable — that's out of scope for this job by design,
to keep the repo small relative to available Drive storage.

---

## Prerequisites

- Docker and Docker Compose already running on the Pi (see manual install /
  bootstrap guides)
- A Google account with Drive storage available
- SSH access to the Pi (for the one-time headless rclone OAuth step)

---

## 1. Install rclone on the host

Backrest uses rclone under the hood to talk to Google Drive. Install rclone
on the Pi itself first, so we can complete the OAuth flow — the resulting
config file is then mounted into the Backrest container.

```bash
curl https://rclone.org/install.sh | sudo bash
```

## 2. Configure the Google Drive remote

Run the interactive config:

```bash
rclone config
```

Walk through the prompts:

- `n` for new remote
- Name it `gdrive`
- Storage type: search for and select `drive` (Google Drive)
- Leave `client_id` and `client_secret` blank (use rclone's defaults) unless
  you've created your own Google Cloud OAuth app
- Scope: `drive` (full access) or `drive.file` (only files created by
  rclone) — `drive.file` is more restrictive and a bit safer, since rclone
  can only see/touch files it created itself, not your whole Drive
- Leave `root_folder_id` and `service_account_file` blank
- Edit advanced config: `n`
- **Auto config: `n`** — since the Pi is headless, you can't open a browser
  on it directly

Since auto config is `n`, rclone will print a command to run **on a machine
that does have a browser** (your PC):

```bash
rclone authorize "drive"
```

Run that command on your PC (rclone must be installed there too, or use
`npx`/download the binary temporarily). It opens a browser, you log in and
authorize, and it prints back a token. Paste that token into the prompt
back on the Pi's `rclone config` session.

Confirm the remote works:

```bash
rclone lsd gdrive:
```

This should list folders in your Drive (or show empty output if the root is
empty) without erroring.

## 3. Move the rclone config into the Backrest folder

Backrest needs its own copy of the rclone config, mounted at
`/root/.config/rclone` inside the container.

```bash
mkdir -p ~/RASPBERRY-PI-DOCKER/backrest/rclone
cp ~/.config/rclone/rclone.conf ~/RASPBERRY-PI-DOCKER/backrest/rclone/
```

## 4. Add the Backrest service

Create `backrest/docker-compose.yml` in the repo:

```yaml
services:
  backrest:
    image: garethgeorge/backrest:v1.12.1
    container_name: backrest
    hostname: backrest
    restart: unless-stopped
    volumes:
      - ./data:/data
      - ./config:/config
      - ./cache:/cache
      - ./tmp:/tmp
      - ./rclone:/root/.config/rclone
      - /home/pi/RASPBERRY-PI-DOCKER:/userdata:ro
    environment:
      - BACKREST_DATA=/data
      - BACKREST_CONFIG=/config/config.json
      - XDG_CACHE_HOME=/cache
      - TMPDIR=/tmp
      - TZ=${TZ}
    ports:
      - '9898:9898'
    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

Notes on this file, consistent with the rest of the repo's conventions:

- **Pinned version** (`v1.12.1`), not `latest` — matches the
  pin-infrastructure strategy used for Pi-hole/Unbound. Bump deliberately.
- `/userdata` is mounted **read-only** — Backrest only needs to read this
  directory to back it up, never write to it.
- `TZ` comes from the repo's shared `.env` file (same pattern as the DNS
  stack).

Bring it up:

```bash
cd ~/RASPBERRY-PI-DOCKER/backrest
docker compose up -d
```

Access the web UI at `http://<pi-ip>:9898` and set a login password on
first visit.

## 5. Create the restic repository in Backrest

In the Backrest UI:

1. **Add Repo**
2. URI: `rclone:gdrive:restic-backups` (rclone will create the
   `restic-backups` folder in Drive automatically on first backup)
3. Set a **strong repository password** and store it somewhere durable
   *outside* the Pi (password manager, written down, etc.) — if you lose
   this password, the backups are unrecoverable, encryption included.
4. Save — Backrest will initialize the repo (`restic init` under the hood)

## 6. Create the backup plan

1. **Add Plan**
2. Repo: the one created above
3. Paths: `/userdata` (this maps to `RASPBERRY-PI-DOCKER` on the host, via
   the read-only mount)
4. Excludes: add anything noisy/large you don't want versioned — e.g.
   `.git` directories, `*.log` if not already log-rotated
5. **Schedule**: daily is a reasonable default for a homelab config backup
6. **Retention policy**: something like keep 7 daily, 4 weekly, 6 monthly —
   generous enough to recover from "I broke something 3 weeks ago and
   didn't notice," lean enough that repo size stays small
7. **Notifications** (optional but recommended): configure Discord/Slack/
   webhook so a silently failing backup doesn't go unnoticed — a backup you
   don't know is broken is worse than no backup, since it gives false
   confidence

## 7. Run a backup and verify

Trigger a manual backup from the UI (don't wait for the schedule the first
time). Once it completes, browse the snapshot in the Backrest UI to confirm
the expected files are present.

## 8. Test a restore — do this now, not during an emergency

This step is the one people skip and regret. From the Backrest UI, pick the
snapshot and restore a file (or the whole thing) to a scratch location, e.g.
`/tmp/restore-test`, and confirm the contents are intact and readable.

```bash
docker exec backrest ls -la /tmp/restore-test
```

If this works, you have a real, verified backup — not just a job that
*appears* to run successfully.

---

## Future backend migration (Google Drive → elsewhere)

Because restic runs through rclone as an abstraction layer, switching
backends later (e.g. to Backblaze B2) doesn't require redoing this setup:

1. Configure a new rclone remote (e.g. `b2`) alongside the existing `gdrive`
   one
2. Either `rclone sync` the old repo to the new remote, or simply start a
   fresh restic repo pointed at the new remote and let old Google Drive
   snapshots age out naturally
3. Update the repo URI in Backrest to point at the new remote
4. Nothing about the Docker setup, backup plan, or restore process changes

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `rclone lsd gdrive:` fails with auth error | Token expired or revoked — rerun `rclone config reconnect gdrive:` |
| Backrest can't see the rclone remote | Config wasn't copied into `backrest/rclone/rclone.conf`, or container needs a restart to pick up a new mount |
| Backup runs but repo size is much larger than expected | Check excludes — likely picking up something noisy like logs or `.git` history |
| Restore test comes back empty/incomplete | Don't proceed further — treat this as a broken backup and debug before relying on it |