# KidSafe

Self-hosted, network-level parental controls for a child's phone.

A single sideloaded Android app builds a WireGuard tunnel to **your own server**, where a
DNS deny list decides what the phone can reach. Nothing is blocked on the device itself —
all filtering happens on the server, so it works across Wi-Fi and mobile data, and it can't
be defeated by uninstalling a "blocker" app.

> **Use this only on a device you own and administer** (e.g. your own child's phone).
> Routing someone else's traffic through your server without their knowledge is not what
> this is for.

---

## How it works

```
   Child's phone                          Your VPS
┌──────────────────┐                ┌──────────────────────────────┐
│  KidSafe APK     │                │  WireGuard  (wg0, 10.7.0.1)  │
│  (WireGuard      │───encrypted───▶│      │                       │
│   client, config │    tunnel      │      ▼                       │
│   baked in)      │                │  dnsmasq  ── deny list       │
│                  │                │      │      (blocked → 0.0.0.0)
│  all traffic ────┼───────────────▶│      ▼                       │
└──────────────────┘                │  NAT ──▶ internet            │
                                    └──────────────────────────────┘
```

1. The app tunnels **all** phone traffic (`AllowedIPs = 0.0.0.0/0`) to your server.
2. The phone's DNS is forced to the server; a firewall rule redirects *any* DNS attempt
   back to the server's resolver, so the deny list can't be side-stepped.
3. `dnsmasq` answers blocked domains with `0.0.0.0` and forwards everything else normally.
4. Every lookup is logged, so you can see what the phone is reaching.

## Features

- **One APK, no Play Store** — sideload it; the tunnel config is compiled in.
- **Opens, connects, closes itself** — no Disconnect button for the child to press.
- **Server-side filtering** — change what's blocked without touching the phone.
- **Traffic visibility** — live feed and reports of every domain requested.
- **Blocks by domain + subdomains** — one line blocks `youtube.com` and all of its hosts.

## Repository layout

```
lib/                                   Flutter UI (status screen, auto-connect + self-exit)
android/app/src/main/kotlin/…/MainActivity.kt    WireGuard control via method channel
android/app/src/main/res/raw/wg_tunnel.conf      tunnel config (NOT committed — see below)
vps/                                   server setup script + deny list reference
```

## Requirements

- A VPS (tested on **Ubuntu 22.04**) with a public IP and root/sudo.
- **UDP 51820** open in the provider's firewall / security group.
- Flutter 3.x + Android SDK to build the APK.
- An Android phone (**arm64**, Android 8.0+).

---

# Part 1 — Server setup

Run everything below on the VPS. Replace `<WAN_IF>` with your internet interface
(find it with `ip route get 1.1.1.1 | grep -oP 'dev \K\S+'` — often `eth0` or `ens3`).

### 1. Install

```bash
sudo apt-get update
sudo apt-get install -y wireguard dnsmasq iptables dnsutils
```

### 2. Generate keys

```bash
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee client.key | wg pubkey > client.pub
cat server.key server.pub client.key client.pub
```

Keep these four values; you'll paste them below and into the app.

### 3. Enable forwarding

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-kidsafe.conf
sudo sysctl -w net.ipv4.ip_forward=1
```

### 4. WireGuard server

```bash
sudo tee /etc/wireguard/wg0.conf >/dev/null <<'EOF'
[Interface]
Address = 10.7.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
PostUp   = iptables -I INPUT -i %i -j ACCEPT; iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o <WAN_IF> -j MASQUERADE
PostDown = iptables -D INPUT -i %i -j ACCEPT; iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o <WAN_IF> -j MASQUERADE

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.7.0.2/32
EOF

sudo systemctl enable --now wg-quick@wg0
```

> **The `-I INPUT -i %i -j ACCEPT` part is essential.** Without it the kernel drops DNS
> packets aimed at the server itself and the tunnel connects but nothing resolves.
> See [Troubleshooting](#troubleshooting).

### 5. DNS filter

```bash
sudo tee /etc/dnsmasq.d/kidsafe.conf >/dev/null <<'EOF'
interface=wg0
bind-dynamic
no-resolv
server=8.8.8.8
server=8.8.4.4
log-queries
log-facility=/var/log/dnsmasq.log
EOF

sudo tee /etc/dnsmasq.d/denylist.conf >/dev/null <<'EOF'
# One line per service. Blocks the domain AND every subdomain.
address=/whatsapp.com/0.0.0.0
address=/whatsapp.net/0.0.0.0
address=/wa.me/0.0.0.0

address=/youtube.com/0.0.0.0
address=/youtu.be/0.0.0.0
address=/googlevideo.com/0.0.0.0
address=/ytimg.com/0.0.0.0
address=/youtubei.googleapis.com/0.0.0.0
address=/youtube-nocookie.com/0.0.0.0
address=/youtubekids.com/0.0.0.0
address=/ggpht.com/0.0.0.0
EOF

sudo systemctl restart dnsmasq
```

### 6. Force all DNS through the filter

Stops the phone from using `8.8.8.8` (or anything else) to bypass the deny list:

```bash
sudo iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j DNAT --to-destination 10.7.0.1
sudo iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 53 -j DNAT --to-destination 10.7.0.1
```

### 7. Verify

```bash
dig @10.7.0.1 youtube.com +short     # → 0.0.0.0        (blocked)
dig @10.7.0.1 google.com  +short     # → a real IP      (allowed)
sudo wg show                          # peer + handshake once the phone connects
```

### 8. Persist firewall rules across reboots

```bash
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

---

# Part 2 — Phone app

### 1. Add your tunnel config

Create `android/app/src/main/res/raw/wg_tunnel.conf`:

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.7.0.2/32
DNS = 10.7.0.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### 2. Build

```bash
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~18 MB).
For a universal build (all CPU architectures, ~50 MB) use `flutter build apk --release`.

### 3. Install

1. Copy the APK to the phone and open it → allow **install from unknown sources**.
2. Play Protect will warn about a sideloaded app → **Install anyway**.
3. Open **KidSafe** → approve the one-time **VPN connection request**.
4. The app shows *Protected* for a second, then closes itself. The 🔑 icon stays in the
   status bar — the tunnel is running.

### 4. Prevent it being switched off

**Settings → Network & internet → VPN → KidSafe ⚙️** → enable
**Always-on VPN** and **Block connections without VPN**.

---

## Managing blocked sites

```bash
sudo kidsafe-block tiktok.com       # block domain + all subdomains
sudo kidsafe-unblock tiktok.com     # remove a block
kidsafe-list                        # show everything blocked
```

Or edit by hand:

```bash
sudo nano /etc/dnsmasq.d/denylist.conf
sudo systemctl restart dnsmasq      # required after manual edits
```

Block a batch in one go:

```bash
for d in tiktok.com instagram.com snapchat.com roblox.com; do
  echo "address=/$d/0.0.0.0"
done | sudo tee -a /etc/dnsmasq.d/denylist.conf
sudo systemctl restart dnsmasq
```

Always confirm with `dig @10.7.0.1 <domain> +short` → `0.0.0.0`.

## Monitoring traffic

```bash
sudo kidsafe-watch                  # live feed of every domain requested
sudo kidsafe-log                    # report: top blocked + most visited
sudo kidsafe-search youtube         # search history for a site
sudo wg show                        # connection status + data used
sudo tcpdump -ni wg0 udp port 53    # raw packet view
```

Reading the log:

```
query[A] www.tiktok.com from 10.7.0.2    ← the phone asked for this
config www.tiktok.com is 0.0.0.0         ← BLOCKED
reply www.google.com is 142.250.x.x      ← allowed
```

The helper commands live in `vps/`. Install them with the snippet in
[`vps/README.md`](vps/README.md).

## Preventing bypass

Modern browsers can use **DNS-over-HTTPS**, which skips your resolver entirely:

```bash
for d in dns.google cloudflare-dns.com mozilla.cloudflare-dns.com dns.quad9.net doh.opendns.com; do
  echo "address=/$d/0.0.0.0"
done | sudo tee -a /etc/dnsmasq.d/denylist.conf
sudo systemctl restart dnsmasq
```

On the phone: **Private DNS → Off** (Settings → Network), and in Chrome
**Settings → Privacy → Use secure DNS → Off**.

---

## Troubleshooting

**Tunnel connects (handshake OK) but nothing resolves.**
Almost always the firewall's INPUT chain. Forwarded traffic has a rule, but a DNS query to
`10.7.0.1` is addressed *to the server itself* and hits INPUT:

```bash
sudo iptables -I INPUT -i wg0 -j ACCEPT
```

Diagnose it: if `tcpdump -ni wg0 udp port 53` shows queries arriving but
`/var/log/dnsmasq.log` records none, the kernel is dropping them before dnsmasq
(tcpdump taps the device *before* the firewall).

**`dig @10.7.0.1` works on the server but the phone gets nothing.**
Same cause as above.

**Sites don't load but DNS resolves.**
Forwarding or NAT is missing:

```bash
cat /proc/sys/net/ipv4/ip_forward                 # must be 1
sudo iptables -t nat -S POSTROUTING | grep MASQ   # must have a MASQUERADE rule
```

**`wg show` never shows a handshake.**
UDP 51820 isn't open in the cloud provider's firewall (separate from the OS firewall).

**dnsmasq won't start.**
Port 53 conflict with `systemd-resolved`. Keep `interface=wg0` + `bind-dynamic` so dnsmasq
binds only the tunnel address, or disable the stub listener
(`DNSStubListener=no` in `/etc/systemd/resolved.conf.d/`).

**YouTube still loads.**
The app uses more domains than the site — make sure `googlevideo.com` and `ggpht.com` are
in the deny list, and check the DoH bypass section above.

---

## Security notes

- **Never commit your keys.** `wg_tunnel.conf`, `*.key` and any generated setup script hold
  private keys. See [`.gitignore`](.gitignore).
- The APK embeds the client private key — anyone with the file can join your tunnel. Don't
  publish built APKs.
- `dnsmasq` binds only to `wg0`, so it isn't a public open resolver. If you ever bind it to
  `0.0.0.0`, block port 53 on your public interface.
- The release build is signed with Flutter's debug key. Generate a real keystore before
  distributing anything.

## Limitations

- **Domain-based filtering.** An app talking to hard-coded IPs won't be stopped by the deny
  list; you'd need IP/CIDR rules for that.
- Logs show **domains requested** — not page content, and not message contents.
- A determined teenager could uninstall the APK unless the device is managed (MDM /
  device owner). Always-on VPN + not granting them admin raises the bar considerably.
- **iOS** isn't supported by this app, but the same server works with the official
  WireGuard app and a config profile.

## Credits

Uses the official [WireGuard Android tunnel library](https://git.zx2c4.com/wireguard-android/)
and [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html).

## License

MIT — see [`LICENSE`](LICENSE).
