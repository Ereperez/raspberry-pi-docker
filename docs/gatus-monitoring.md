# Gatus — Endpoint Monitoring & Status Page

[Gatus](https://github.com/TwiN/gatus) checks a list of endpoints on a
schedule, evaluates conditions against each response (status code,
response time, DNS record, TLS cert expiry, etc.), and shows the result on
a status dashboard. This setup monitors every currently-live service in
the homelab and alerts to Healthchecks.io on failure/recovery.

---

## 1. Folder structure

```
gatus/
├── docker-compose.yml
├── .env
├── .env.example
├── config/
│   └── config.yaml
└── data/          (SQLite history -- created on first run)
```

## 2. `docker-compose.yml`

```yaml
services:
  gatus:
    image: ghcr.io/twin/gatus:v5.35.0
    container_name: gatus
    hostname: gatus
    restart: unless-stopped

    # Published on 8081 (not 8080) to match the tile already set up in
    # Homepage's services.yaml.
    ports:
      - '8081:8080'

    environment:
      TZ: ${TZ}
      HEALTHCHECKS_UUID: ${HEALTHCHECKS_UUID}

    volumes:
      - ./config/config.yaml:/config/config.yaml:ro
      - ./data:/data

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

Note: unlike Homepage, **Gatus's own `${VAR}` substitution works directly
in its config file** — no `HOMEPAGE_VAR_`-style prefix needed here. Don't
assume this carries over to other tools; check each tool's own docs.

## 3. `.env.example`

```bash
# No quotes around values. Escape literal $ as $$. Save as LF line endings, not CRLF.

TZ=
# From healthchecks.io -- create a check, copy the UUID portion of its
# Ping URL (https://hc-ping.com/<UUID>), paste just the UUID here.
HEALTHCHECKS_UUID=
```

## 4. `config/config.yaml`

```yaml
storage:
  type: sqlite
  path: /data/data.db

alerting:
  custom:
    url: "https://hc-ping.com/${HEALTHCHECKS_UUID}[ALERT_TRIGGERED_OR_RESOLVED]"
    method: POST
    placeholders:
      ALERT_TRIGGERED_OR_RESOLVED:
        TRIGGERED: "/fail"
        RESOLVED: ""
    body: |
      {
        "endpoint": "[ENDPOINT_NAME]",
        "description": "[ALERT_DESCRIPTION]",
        "status": "[ALERT_TRIGGERED_OR_RESOLVED]"
      }
    default-alert:
      failure-threshold: 2
      success-threshold: 1
      send-on-resolved: true

web:
  port: 8080

ui:
  title: Homelab Status
  header: Homelab Status

endpoints:
  - name: Pi-hole
    group: DNS
    url: "http://192.168.1.79/admin/login"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 1000"
    alerts:
      - type: custom
        description: "Pi-hole is down"

  - name: Unbound
    group: DNS
    url: "192.168.1.79"
    dns:
      query-name: "dnssec.works"
      query-type: "A"
    interval: 60s
    conditions:
      - "[DNS_RCODE] == NOERROR"
    alerts:
      - type: custom
        description: "Unbound DNS resolution failing"

  - name: Homepage
    group: Dashboard
    url: "http://192.168.1.79:3000"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: custom
        description: "Homepage is down"

  - name: Backrest
    group: Backup
    url: "http://192.168.1.79:9898"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: custom
        description: "Backrest is down"

  - name: Portainer
    group: Docker Tools
    url: "http://192.168.1.79:9000"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: custom
        description: "Portainer is down"

  - name: Beszel Hub
    group: Monitoring
    url: "http://192.168.1.79:8090"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: custom
        description: "Beszel Hub is down"
```

### DNS check syntax — a gotcha worth flagging

Gatus's official examples use a **bare IP** for DNS endpoints:
```yaml
url: "192.168.1.79"
```
Not `dns://192.168.1.79` and not an explicit `:53` port. Either of those
additions causes the check to error out entirely — shows `N/A` response
time on the dashboard rather than a normal pass/fail, which looks like a
connectivity problem but is actually just a URL-format mismatch.

### Alerting — shared check, not per-endpoint

Gatus only supports **one global `custom` provider config**, so all six
endpoints' alerts route through the same Healthchecks check. This means:

- Healthchecks' up/down state tells you *something* is failing, not
  *which* service specifically
- The endpoint name and description are included in the ping's request
  body — visible in Healthchecks' own ping log (click into the check →
  ping history) if you need to know which one triggered it
- If per-service granularity becomes worth the setup later, this would
  need splitting into separate Healthchecks checks with per-endpoint
  `alerts:` overrides (Gatus supports per-endpoint alert config, just not
  distinct global provider instances) — not done here to keep the first
  pass simple

---

## 5. Set up Healthchecks.io

Same account already used for Backrest:

1. Create a new check, name it something like "Gatus — Homelab endpoints"
2. Schedule doesn't matter much here since pings are state-change-driven,
   not fixed-interval — a generous Period (e.g. 1 hour) as a fallback
   safety net is fine
3. Copy just the UUID portion of the Ping URL
   (`https://hc-ping.com/`**`this-part`**)

## 6. Deploy

```bash
cd ~/RASPBERRY-PI-DOCKER/gatus
cp .env.example .env
nano .env   # TZ, HEALTHCHECKS_UUID
docker compose up -d
docker compose logs -f gatus
```

Visit `http://192.168.1.79:8081` — should show all six endpoints, each
flipping Healthy within one check interval.

## 7. Verify alerting actually fires

Temporarily stop one monitored container (e.g. `docker stop backrest`)
and watch:
- Gatus's own dashboard flips that endpoint to Unhealthy after
  `failure-threshold` consecutive failed checks (2 × 60s interval here)
- Healthchecks flips to "Down" at the same time (the `/fail` ping)
- Restart the container, confirm both flip back within one more interval
  (the `send-on-resolved` ping)

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| An endpoint shows `N/A` response time instead of pass/fail | URL format issue, not a real connectivity problem — check DNS endpoint syntax section above |
| Config changes don't take effect | `docker compose restart gatus` reloads the mounted config file; no `--force-recreate` needed unless the image or environment changed |
| Alerts never fire even when an endpoint is clearly down | Confirm `HEALTHCHECKS_UUID` is set in `.env` and the container actually has it (`docker exec gatus env \| grep HEALTHCHECKS`) |
| Healthchecks shows "Down" but you can't tell which service | Expected with the current shared-check setup — check the ping's request body in Healthchecks' ping log for the endpoint name |