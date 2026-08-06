bootstrap fresh pi:
	./scripts/bootstrap-fresh-pi.sh

dns-up:
	cd dns && docker compose up -d

dns-down:
	cd dns && docker compose down

dns-update:
	cd dns && docker compose pull && docker compose up -d

backup:
	./scripts/backup-docker.sh