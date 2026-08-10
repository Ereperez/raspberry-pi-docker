# Nginx Proxy Manager — Internal Reverse Proxy with Trusted Local HTTPS

[Nginx Proxy Manager](https://nginxproxymanager.com) (NPM) gives every
service a clean internal hostname (e.g. `homepage.home.arpa`) instead of
`192.168.1.79:3000`, with a trusted HTTPS certificate — no browser
warnings, no public exposure.

**Deliberately internal-only.** With Tailscale already providing secure
remote access to every device, there's no real benefit to exposing
anything to the public internet — that would only matter for services
meant for people outside your own devices, which nothing in this stack
is. No ports are forwarded on the router; NPM sits on the LAN/tailnet only.

**No domain purchased.** Since nobody outside your own devices will ever
visit these hostnames, a globally-trusted public certificate (Let's
Encrypt) isn't actually solving a problem you have. Instead, this uses
[`mkcert`](https://github.com/FiloSottile/mkcert) — a locally-trusted
certificate authority you install once on each of your own devices, after
which certificates it issues are trusted by that device with no warnings.
No recurring cost, no domain to renew, no third-party dependency.

**Domain suffix: `.home.arpa`** — the actual IANA-reserved special-use
domain for exactly this purpose ([RFC 8375](https://www.rfc-editor.org/rfc/rfc8375.html)),
rather than an arbitrary made-up suffix that could theoretically collide
with a real TLD later, or `.local`, which is already claimed by
mDNS/Bonjour and causes real conflicts if reused for this.

---

## Architecture

```
Device on LAN/tailnet
        |
        | homepage.home.arpa (resolved by Pi-hole's Local DNS Records)
        v
   192.168.1.79 (the Pi)
        |
        | :443, mkcert-issued cert, SNI routing by hostname
        v
      NPM
        |
        | forwards to the real internal port
        v
  homepage:3000 / pihole:80 / portainer:9000 / etc.
```

---

## Part 1: Generate certificates with `mkcert` (on your PC, not the Pi)

`mkcert` needs to run somewhere with a real trust store and browser to
install its root CA into — that's your PC, not the headless Pi.

### Install mkcert

**Windows:**
```powershell
choco install mkcert
```
(or download the binary directly from the
[mkcert releases page](https://github.com/FiloSottile/mkcert/releases)
if you don't use Chocolatey)

### Install the local CA into your PC's trust store

```powershell
mkcert -install
```

This creates a root certificate and installs it into Windows' trust
store (and Firefox's, if present) — this is the one-time step that makes
everything issued by `mkcert` afterward trusted **on this specific
device**.

### Generate a wildcard certificate

```powershell
mkcert "*.home.arpa"
```

This produces two files (`_wildcard.home.arpa.pem` and
`_wildcard.home.arpa-key.pem`) covering every hostname under
`.home.arpa` — one certificate for the whole internal setup, not one per
service.

### Extend trust to your other devices (phone, tablet, other PCs)

Each device needs the **root CA** installed to trust these certs — the
wildcard cert itself doesn't need to go anywhere else, just the CA that
signed it.

```powershell
mkcert -CAROOT
```

This prints the folder containing `rootCA.pem`. Transfer that one file
to each other device and install it into that device's trust store
(varies by OS — Android/iOS: install as a trusted root certificate via
Settings; check current OS-specific steps if unfamiliar, since exact menus
shift between OS versions).

---

## Part 2: Deploy NPM

## 1. Folder structure

```
npm/
├── docker-compose.yml
├── .env
├── .env.example
├── data/          (created on first run)
└── letsencrypt/   (created on first run, unused but expected by NPM)
```

## 2. `docker-compose.yml`

```yaml
services:
  npm:
    image: jc21/nginx-proxy-manager:2.15.1
    container_name: nginx-proxy-manager
    hostname: npm
    restart: unless-stopped

    ports:
      - '80:80'
      - '443:443'
      - '81:81'

    environment:
      TZ: ${TZ}
      DISABLE_IPV6: 'true'

    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt

    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
```

`DISABLE_IPV6: true` avoids startup errors — this network has no IPv6
configured (confirmed via UniFi: Interface Type set to None).

## 3. `.env`

```bash
cp .env.example .env
nano .env   # TZ
docker compose up -d
```

## 4. First login

Visit `http://192.168.1.79:81`. **Default credentials must be changed
immediately** on first login:
- Email: `admin@example.com`
- Password: `changeme`

---

## Part 3: Upload the mkcert certificate into NPM

1. **SSL Certificates → Add SSL Certificate → Custom**
2. Name it something like `home.arpa wildcard`
3. Upload `_wildcard.home.arpa.pem` as the **Certificate**
4. Upload `_wildcard.home.arpa-key.pem` as the **Certificate Key**
5. Save

---

## Part 4: Add Local DNS Records in Pi-hole

Each internal hostname needs to actually resolve to the Pi's IP. Pi-hole
already handles DNS for the whole network, so this is the natural place
for it rather than editing `/etc/hosts` on every device individually.

Pi-hole admin → **Settings → Local DNS Records** (or similar — check
current UI wording, this has moved between Pi-hole versions):

Add one A record per service, e.g.:
```
homepage.home.arpa   -> 192.168.1.79
pihole.home.arpa      -> 192.168.1.79
portainer.home.arpa   -> 192.168.1.79
backrest.home.arpa    -> 192.168.1.79
beszel.home.arpa      -> 192.168.1.79
gatus.home.arpa       -> 192.168.1.79
wud.home.arpa         -> 192.168.1.79
```

All pointing at the same IP (the Pi) — NPM is what actually routes each
hostname to the correct internal port based on the `Host` header, not DNS.

---

## Part 5: Create a Proxy Host per service

Repeat for each service. **Proxy Hosts → Add Proxy Host**:

| Field | Value |
|---|---|
| Domain Names | `homepage.home.arpa` (etc., one per service) |
| Scheme | `http` |
| Forward Hostname / IP | `192.168.1.79` |
| Forward Port | the service's actual port (`3000` for Homepage, `9000` for Portainer, etc.) |
| Block Common Exploits | on |

**SSL tab:**
- Certificate: the `home.arpa wildcard` cert uploaded in Part 3
- Force SSL: on
- HTTP/2 Support: on

Save. Repeat for each service:

| Service | Port |
|---|---|
| Pi-hole | 80 |
| Homepage | 3000 |
| Portainer | 9000 |
| Backrest | 9898 |
| Beszel | 8090 |
| Gatus | 8081 |
| WUD | 3001 |

---

## Verify

From a device that has the mkcert root CA installed, visit
`https://homepage.home.arpa` — should load with a valid, non-warning
HTTPS padlock, proxied through to Homepage on port 3000.

From a device *without* the root CA installed, the same URL will show a
certificate warning — expected, that's exactly what installing the CA
prevents, and confirms the cert is genuinely doing its job rather than
being silently trusted everywhere.

---

## What NOT to change later

- **Homepage widget `url:` fields calling other services' APIs** (Pi-hole,
  Portainer, etc.) should stay pointed at the internal IP, not the new
  `.home.arpa` hostnames — that's server-to-server traffic with no benefit
  from going through the proxy, and adds an unnecessary dependency on NPM
  being healthy for Homepage's own widgets to function. Only update the
  **`href:`** fields (the human-facing links) to the new hostnames.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Certificate warning on every device | Root CA (`rootCA.pem`) not installed on that specific device — the wildcard cert alone doesn't establish trust |
| Hostname doesn't resolve at all | Local DNS Record missing in Pi-hole, or client's DNS cache needs flushing after adding it |
| NPM shows "502 Bad Gateway" | Forward Hostname/IP or Forward Port wrong for that service — double check against the port table above |
| Works on PC (ran mkcert there) but not phone | Root CA never transferred/installed on the phone — see Part 1's "extend trust" step |
| NPM's own admin UI (port 81) unreachable from LAN | Confirm the port is actually published (not restricted to `127.0.0.1` — this compose file intentionally doesn't restrict it, since managing NPM from your PC over the LAN is the whole point) |