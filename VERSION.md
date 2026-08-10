# Infrastructure Versions

## DNS

Pi-hole: 2026.07.2
Unbound: v1.25.2

## Management

Portainer: 2.39.5
Dockge: not planned

## Backup

Backrest: v1.12.1
Restic: managed by Backrest, no separate pin
rclone: latest (installed via official install script, not version-pinned)

**Backup destination:** Google Drive, via rclone (`drive.file` scope —
isolated to files rclone creates itself). Own Google Cloud OAuth client in
use (shared rclone client_id being retired during 2026).

**Schedule:** daily. **Retention:** 14 daily / 8 weekly / 12 monthly.
**Monitoring:** Healthchecks.io dead-man's-switch hook
(`CONDITION_SNAPSHOT_SUCCESS` + `CONDITION_ANY_ERROR`).

**Restore tested:** 2026-08-07 — restored `VERSION.md` from snapshot
`aca1515f`, content verified byte-for-byte.

## Dashboard

Homepage: v1.13.2
Socket Proxy (wollomatic/socket-proxy, Homepage's dockerproxy): 1

**Docker visibility:** wollomatic/socket-proxy, dedicated to Homepage only
(`-allowfrom=homepage`, GET-only on containers/version/info paths).
Dozzle will get its own separate proxy instance when deployed — one
proxy per consumer, not shared.

**Live widgets:** Pi-hole, Backrest, Portainer. All three authenticate via
Homepage's `HOMEPAGE_VAR_*` env var substitution (`{{HOMEPAGE_VAR_X}}` in
YAML — this is Homepage's own substitution system, distinct from Docker
Compose's `${VAR}` syntax; using the wrong one silently sends the literal
`${VAR}` string as the credential rather than failing loudly).

**Portainer widget note:** Portainer CE has no scoped read-only role
(Business Edition only). The `homepage` Portainer user is Standard role
with per-resource **Restricted** ownership granted explicitly on each
container it needs to see — kept off the Administrators-only default and
off Public. New containers default to Administrators-only ownership and
need this set manually each time.

## Monitoring

Beszel Hub: 0.18.7
Beszel Agent: 0.18.7
Gatus: v5.35.0

**Gatus alerting:** custom webhook to Healthchecks.io, sharing the same
account used for Backrest. All six monitored endpoints (Pi-hole, Unbound,
Homepage, Backrest, Portainer, Beszel Hub) share **one** Healthchecks
check — Gatus only supports a single global custom-provider config, so the
check's up/down state reflects "something is failing," not which service
specifically (endpoint name is in the ping body if detail is needed).
Split into per-endpoint checks later if that granularity matters.

**DNS check syntax gotcha:** Gatus's `dns://` endpoints want a bare IP
(`url: "192.168.1.79"`), not a `dns://` scheme prefix or an explicit
`:53` port — either of those causes the check to error out entirely
(shows `N/A` response time, not just a failed condition).

**Beszel connection method:** agent-initiated WebSocket (`HUB_URL` +
`TOKEN` + hub's public `KEY`), not the unix-socket method — matches what
the hub UI generates by default for local systems. Token confirmed
reusable across agent restarts, not single-use.

**Docker socket:** mounted directly into the agent, read-only, not routed
through a socket-proxy like Homepage's setup — Beszel needs broader
per-container stats access than a simple GET-only proxy scopes cleanly.
Pinned version (0.18.7) already includes fixes for both known advisories
affecting this access pattern (GHSA-phwh-4f42-gwf3, Docker API path
traversal, fixed 0.18.4; GHSA-5f5r-95pg-xrpm, IDOR, fixed 0.18.7).

## Updates

WUD: 8.3.1

**Mode:** notify-only, no auto-update triggers configured (deliberate
choice over Watchtower). Nothing is monitored by default -- containers
must be labeled `wud.watch=true` individually to appear in WUD.

**Docker socket:** mounted directly into WUD, read-only -- same trade-off
reasoning as Beszel's agent (needs image/registry inspection access
broader than a simple container-list proxy scopes cleanly).

**Auth:** basic auth via `WUD_AUTH_BASIC_*` env vars. APR1 hash contains
multiple `$` segments -- every one needs doubling to `$$` in `.env` or
Compose silently empties the value (hit this exact bug on first deploy).

## Remote Access

Tailscale: stable (deliberate exception to pin-everything -- Tailscale's
own docs recommend against fixed-version pinning so the VPN client always
gets security patches on redeploy)

**Mode:** subnet router, advertising `192.168.1.0/24`. Auto-approved via
`tag:homelab` + `autoApprovers` in the tailnet ACL policy -- no manual
click needed in the Machines list after (re)connect. Node key expiry also
disabled for tagged devices.

**Auth key:** reusable, pre-approved, 90-day expiry -- needs manual
regeneration when it expires (flagged in `.env.example`). An OAuth client
setup would remove this maintenance item if it becomes worth the added
complexity later.

**DNS override:** enabled. Pi-hole (`192.168.1.79`) set as tailnet global
nameserver with Override DNS on -- gives ad/tracker blocking on cellular
data for all tailnet devices, at the cost of making general web browsing
(not device-to-device access, which is unaffected either way) dependent on
Pi-hole/Unbound uptime even away from home. Toggle off anytime via Admin
Console -> DNS -> Nameservers if this trade-off stops being worth it.

**Reachability confirmed:** subnet route and DNS override both tested from
cellular-only (WiFi off), verified via Pi-hole query log showing the
phone's Tailscale IP.