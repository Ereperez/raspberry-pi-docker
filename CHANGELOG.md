# Changelog

## 2026-08-07
- Resolved UniFi AdBlock conflict causing DNSSEC bogus/SERVFAIL responses on Pi-hole/Unbound
- Added zone-based firewall rule for cross-VLAN DNS access (IoT → Pi-hole), corrected rule priority
- Scaffolded Backrest (restic + web UI) backup solution — compose file and docs added, not yet deployed
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