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

Homepage: v1.13.2 *(not yet deployed)*
Socket Proxy (wollomatic/socket-proxy, Homepage's dockerproxy): 1 *(not yet deployed)*

## Monitoring

Beszel: -
Gatus: -
WUD: -