# Changelog

## 2026-08-06
- Deployed Backrest (restic + web UI) — daily backups of homelab repo to Google Drive via rclone
  - Own Google Cloud OAuth client configured (shared rclone client_id being retired during 2026)
  - Retention: 14 daily / 8 weekly / 12 monthly
  - Healthchecks.io dead-man's-switch hook configured (success + any-error conditions)
  - Restore verified: restored `VERSION.md` from a live snapshot, content matched
- Resolved UniFi AdBlock conflict causing DNSSEC bogus/SERVFAIL responses on Pi-hole/Unbound
- Added zone-based firewall rule for cross-VLAN DNS access (IoT → Pi-hole), corrected rule priority
- Scaffolded Homepage dashboard — compose file and docs added, not yet deployed
  - Docker visibility provided via wollomatic/socket-proxy (dedicated proxy per consumer, least-privilege)
- Confirmed Dockge will not be implemented (Portainer covers this need)
- Added docs: `backup-restic-backrest.md`, `homepage-dashboard.md`

## 2026-08-05
- Initial repository created
- Added Pi-hole + Unbound stack
- Added bootstrap script for fresh PI installs
- Added backup script
- Added Dockge+Portainer docs
- Added Version.md