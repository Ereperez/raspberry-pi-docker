# Changelog

## 2026-08-09 (later)
- Deployed WUD for Docker update notifications
  - Pinned to 8.3.1, published on 3001 (3000 taken by Homepage)
  - Notify-only, no auto-update triggers -- containers must opt in via
    `wud.watch=true` label; nothing watched by default
  - Basic auth via `WUD_AUTH_BASIC_*` -- hit the same `$` escaping bug as
    Backrest's password (APR1 hashes contain multiple `$` segments, all
    need doubling to `$$` in `.env`)
  - Confirmed working: correctly flagged Gatus's v5.36.0 release on first
    scan
  - Added doc: `wud-updates.md`

## 2026-08-09
- Deployed Gatus for endpoint monitoring — Pi-hole, Unbound, Homepage,
  Backrest, Portainer, and Beszel Hub all checked on 60s intervals
  - Pinned to v5.35.0 (canonical image moved to ghcr.io/twin/gatus)
  - Published on 8081 to match the pre-existing Homepage tile
  - Alerting wired to Healthchecks.io via Gatus's custom webhook provider,
    using `[ALERT_TRIGGERED_OR_RESOLVED]` to hit the base ping URL on
    recovery and `/fail` on failure -- verified end-to-end with a live
    test (stopped a container, watched both Gatus and Healthchecks flip)
  - Fixed DNS check for Unbound: Gatus wants a bare IP for `dns://`
    endpoints, not a scheme prefix or explicit `:53` port
  - Added doc: `gatus-monitoring.md`

## 2026-08-08 (later)
- Deployed Beszel (hub + agent) for system monitoring — CPU, memory, disk,
  network, temperature, load average
  - Pinned to v0.18.7 (patches both known security advisories affecting
    the agent's Docker socket access)
  - Connected via agent-initiated WebSocket (HUB_URL/TOKEN/KEY), matching
    what the hub's "Add System" UI generates for local systems, rather
    than the unix-socket method originally planned
  - Docker socket mounted directly (read-only) into the agent rather than
    via socket-proxy — documented as a deliberate scope trade-off, unlike
    Homepage's narrower proxied access
  - Added doc: `beszel-monitoring.md`

## 2026-08-08
- Deployed Homepage dashboard, live with Pi-hole, Backrest, and Portainer widgets
  - Docker container visibility via dedicated wollomatic/socket-proxy (`-allowfrom=homepage`,
    GET-only, isolated internal network) — real proxy flag is `-proxyport`, not `-listenport`
  - `-allowGET` regex fixed to match Homepage's unversioned Docker API calls
    (`/containers/json`, not `/v1.xx/containers/json`)
  - Root cause of all three widgets returning 401 despite valid, individually-verified
    credentials: Homepage uses its own `{{HOMEPAGE_VAR_X}}` substitution system in config
    files, distinct from Compose's `${VAR}` — using `${VAR}` sends the literal string as
    the credential rather than failing loudly. All service credentials renamed with the
    required `HOMEPAGE_VAR_` prefix.
  - Portainer widget needed per-container "Restricted" resource ownership granted to the
    scoped `homepage` user (CE has no read-only/scoped role short of full Administrator)
  - `.env` CRLF line endings (from Windows editing) and unescaped `$` in generated
    passwords both fixed along the way — `.env` values with `$` need `$$` escaping
- Confirmed Dockge will not be implemented (Portainer covers this need)

## 2026-08-07
- Deployed Backrest (restic + web UI) — daily backups of homelab repo to Google Drive via rclone
  - Own Google Cloud OAuth client configured (shared rclone client_id being retired during 2026)
  - Retention: 14 daily / 8 weekly / 12 monthly
  - Healthchecks.io dead-man's-switch hook configured (success + any-error conditions)
  - Restore verified: restored `VERSION.md` from a live snapshot, content matched
- Resolved UniFi AdBlock conflict causing DNSSEC bogus/SERVFAIL responses on Pi-hole/Unbound
- Added zone-based firewall rule for cross-VLAN DNS access (IoT → Pi-hole), corrected rule priority
- Scaffolded Homepage dashboard — compose file and docs added, not yet deployed
  - Docker visibility provided via wollomatic/socket-proxy (dedicated proxy per consumer, least-privilege)
- Added docs: `backup-restic-backrest.md`, `homepage-dashboard.md`

## 2026-08-05
- Initial repository created
- Added Pi-hole + Unbound stack
- Added bootstrap script for fresh PI installs
- Added backup script
- Added Dockge+Portainer docs
- Added Version.md