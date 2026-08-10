# Tailscale — Remote Access & Subnet Routing

[Tailscale](https://tailscale.com) provides a mesh VPN (built on
WireGuard) letting your own devices reach each other securely from
anywhere, without exposing anything to the public internet. This setup
runs Tailscale on the Pi as a **subnet router**, giving every device on
your tailnet access to the whole home LAN, plus optional DNS-level
ad/tracker blocking via Pi-hole while away from home.

---

## Two independent systems — worth understanding clearly

This setup actually does two separate things, and they don't depend on
each other:

**1. Reaching home devices (PC, Pi, anything on `192.168.1.0/24`)**
Handled entirely by Tailscale's own addressing (`100.x.x.x` IPs /
MagicDNS). This works regardless of whether Pi-hole/Unbound are healthy,
broken, or offline. If DNS-specific issues happen at home, subnet
routing and device access are unaffected.

**2. General web browsing DNS on tailnet devices**
Only relevant if **DNS override** is enabled (see below). This is the
*only* thing that depends on Pi-hole being up, and only affects general
internet browsing — not reaching your own devices.

Keeping these separate matters when troubleshooting: if you can't reach a
home device, that's a routing/approval issue. If browsing is broken on a
tailnet device away from home, that's a DNS override / Pi-hole issue.

---

## `stable` tag — a deliberate exception to pin-everything

Every other service in this repo pins an exact version. Tailscale is the
one deliberate exception: their own documentation recommends the
`stable` tag specifically because containers are meant to be redeployed
and pick up security patches automatically, rather than silently running
an aging VPN client. Don't "fix" this to a pinned version without
reconsidering that trade-off first.

## Kernel networking, not userspace

`network_mode: host` + `TS_USERSPACE: false` + `NET_ADMIN`/`NET_RAW`
capabilities + `/dev/net/tun` device — this combination is required for
subnet routing to actually forward LAN traffic correctly. Host networking
also avoids Docker's own NAT interfering with the tailnet interface.

## Host-level IP forwarding — required, not optional

Because this runs in `network_mode: host`, Compose's `sysctls:` directive
doesn't apply the way it would under bridge networking — it has to be set
directly on the host:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Without this, the Pi will connect to the tailnet fine but subnet routing
won't actually forward traffic to other LAN devices.

---

## 1. Folder structure

```
tailscale/
├── docker-compose.yml
├── .env
└── .env.example
```

(Tailscale's own state persists in `./state`, created on first run.)

## 2. `docker-compose.yml`

```yaml
services:
  tailscale:
    image: tailscale/tailscale:stable
    container_name: tailscale
    hostname: rpi4-homelab
    restart: unless-stopped
    network_mode: host

    environment:
      TS_AUTHKEY: ${TS_AUTHKEY}
      TS_STATE_DIR: /var/lib/tailscale
      TS_USERSPACE: 'false'
      TS_EXTRA_ARGS: --advertise-routes=192.168.1.0/24
      TS_ACCEPT_DNS: 'false'

    volumes:
      - ./state:/var/lib/tailscale

    devices:
      - /dev/net/tun:/dev/net/tun

    cap_add:
      - NET_ADMIN
      - NET_RAW

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

`TS_ACCEPT_DNS: false` stops Tailscale from overriding the *Pi's own*
DNS resolution — it already has Unbound/Pi-hole configured and shouldn't
have that silently replaced. This is unrelated to the tailnet-wide DNS
override setting below, which is configured in the admin console, not
here.

## 3. Tailnet ACL policy — tags and route auto-approval

Tailscale's newer policy format uses `grants` rather than the older
`acls` array. Two additions needed beyond the default policy, under
**Access controls → Policies** in the admin console:

```json
"tagOwners": {
    "tag:homelab": ["autogroup:admin"],
},
"autoApprovers": {
    "routes": {
        "192.168.1.0/24": ["tag:homelab"],
    },
},
```

- `tagOwners` makes `tag:homelab` assignable (empty `[]` means nobody can
  assign it — a common first-attempt mistake)
- `autoApprovers` is what actually skips the manual "approve this route"
  click after connecting — tags alone don't do this
- Tagging a device also **disables node key expiry** for it, avoiding a
  recurring manual re-authentication step

## 4. Generate the auth key

Admin console → **Settings → Keys → Generate auth key**:
- **Reusable**: on
- **Expiration**: 90 days (default) — will need regenerating when it
  expires; an OAuth client setup removes this if it becomes worth the
  added complexity later
- **Ephemeral**: **off** — this device should persist across reboots, not
  get removed from the tailnet every time it goes offline
- **Tags**: on, select `tag:homelab` (requires step 3 to already be done)

## 5. `.env`

```bash
# No quotes around values. Escape literal $ as $$. Save as LF line endings, not CRLF.

TS_AUTHKEY=
```

## 6. Deploy

```bash
cd ~/RASPBERRY-PI-DOCKER/tailscale   # after git pull
cp .env.example .env
nano .env   # paste the auth key
docker compose up -d
docker compose logs -f tailscale
```

Confirm the machine (`rpi4-homelab`) appears in the admin console's
Machines list, connected, with the advertised route already showing
approved (no manual click needed, assuming step 3 was done correctly
before generating the key).

---

## 7. Optional: DNS override

**What it does:** sets Pi-hole as the tailnet's global nameserver with
Override DNS enabled, so every tailnet device (not just ones at home) uses
Pi-hole for general web browsing DNS — ad/tracker blocking on cellular
data, hotel wifi, anywhere.

**What it costs:** general browsing on tailnet devices becomes dependent
on Pi-hole/Unbound uptime, even far from home. Reaching home devices via
Tailscale is unaffected either way (see the two-systems note above) — this
only risks *browsing*, not device access.

**Enabled here**, given:
- Already have Mullvad for actual untrusted-network protection (full
  traffic tunnel) — DNS override isn't standing in for that, it's a
  lighter-weight, always-on ad-blocking layer for the common case
- Latency cost is negligible — DNS lookups are cached per-domain by the
  OS/browser, so this is a one-time small round-trip per new domain, not
  a tax on every request (unlike a full VPN tunnel)
- Reachability tested and confirmed working from cellular-only before
  committing to this

**To enable:** Admin console → **DNS** → **Nameservers** → Add Nameserver
→ `192.168.1.79` → enable **Override DNS**.

**To disable** (if the trade-off stops being worth it — e.g. Pi-hole
proves unreliable, or travel to a country with poor connectivity back
home makes the latency more noticeable): same page, toggle off. Takes
effect within moments; toggle Tailscale off/on on a client if it doesn't
seem to pick up the change immediately.

---

## Testing — verify both systems independently

**1. Subnet routing** (unrelated to DNS, test this first):
- Phone: WiFi off, cellular only
- Confirm Tailscale app shows connected
- Try reaching a home service directly, e.g. `http://192.168.1.79:3000`
  (Homepage), or SSH into the Pi

**2. DNS override** (only if enabled):
- Still cellular-only, browse to an ordinary website
- Check Pi-hole's query log for entries from the phone's Tailscale IP
  (`100.x.x.x`) — confirms DNS is actually routing home, not using
  carrier DNS
- Visit an ad-heavy site and confirm blocking is actually happening

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Container connects, but other tailnet devices can't reach the LAN | Route not approved — check Machines list for an unapproved route, or check `autoApprovers` policy syntax if it should've been automatic |
| Route approved, but traffic still doesn't reach LAN devices | Host-level `net.ipv4.ip_forward` not set — see step above, this is easy to miss since it's outside the compose file |
| Auth key rejected on deploy | Key expired (90-day default) — regenerate in admin console |
| Device shows in Machines list but keeps needing manual re-approval after restarts | Tag wasn't actually applied — confirm `tagOwners` includes your account and the key generation dialog had Tags enabled |
| Browsing broken on a tailnet device away from home | If DNS override is enabled, check Pi-hole/Unbound health first — this is the expected trade-off, not a bug |
| Can't reach home devices, but DNS override still seems to work | These are independent systems — this combination shouldn't happen; check subnet route approval, not DNS settings |