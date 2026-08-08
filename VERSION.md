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

Beszel: -
Gatus: -
WUD: -