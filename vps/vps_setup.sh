#!/usr/bin/env bash
#
# KidSafe VPS setup — force a child's phone through this server and filter it
# with a nano-editable deny list.
#
#   Architecture:
#     Phone (WireGuard app)  ──encrypted tunnel──►  VPS (this box)
#                                                     ├─ WireGuard  : all phone traffic enters here
#                                                     ├─ dnsmasq    : resolves DNS, blackholes blocked domains
#                                                     └─ NAT        : forwards allowed traffic to the internet
#
#   Because AllowedIPs on the phone is 0.0.0.0/0 and DNS is forced to this box,
#   the child cannot bypass the filter by changing the phone's DNS or Wi-Fi.
#
#   Blocking is DNS-based: a blocked domain resolves to 0.0.0.0, so apps that
#   rely on it (WhatsApp, YouTube, ...) cannot connect. Edit the list any time:
#     sudo nano /etc/dnsmasq.d/denylist.conf   &&   sudo systemctl restart dnsmasq
#   or use the helper commands this script installs: kidsafe-block / kidsafe-unblock / kidsafe-list
#
# Run on the VPS as root:   sudo bash vps_setup.sh
# Re-running is safe: it will NOT regenerate keys if wg0 already exists.

set -euo pipefail

WG_DIR=/etc/wireguard
WG_IF=wg0
WG_PORT=51820
WG_NET=10.7.0
SERVER_IP=${WG_NET}.1
CLIENT_IP=${WG_NET}.2
CLIENT_CONF=/root/kidsafe-phone.conf
CLIENT_PNG=/root/kidsafe-phone.png
DENYLIST=/etc/dnsmasq.d/denylist.conf

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo bash $0" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Debian/Ubuntu (apt). Adapt the install step for your distro." >&2
  exit 1
fi

echo "==> Installing packages (wireguard, dnsmasq, qrencode, iptables)…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq wireguard dnsmasq qrencode iptables curl >/dev/null

# --- Detect the internet-facing interface and public IP ---
WAN_IF=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
PUB_IP=$(curl -4 -s --max-time 8 https://api.ipify.org || true)
[[ -z "$PUB_IP" ]] && PUB_IP=$(ip -4 addr show "$WAN_IF" | grep -oP 'inet \K[\d.]+' | head -1)
echo "==> WAN interface: ${WAN_IF:-unknown}   Public IP: ${PUB_IP:-unknown}"

# --- Enable IP forwarding (persistently) ---
echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-kidsafe.conf
sysctl -q -w net.ipv4.ip_forward=1

# --- WireGuard keys + server config (only if not already set up) ---
umask 077
mkdir -p "$WG_DIR"
if [[ ! -f "$WG_DIR/${WG_IF}.conf" ]]; then
  echo "==> Generating WireGuard keys…"
  wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey >"$WG_DIR/server_public.key"
  wg genkey | tee "$WG_DIR/client_private.key" | wg pubkey >"$WG_DIR/client_public.key"

  SERVER_PRIV=$(cat "$WG_DIR/server_private.key")
  CLIENT_PUB=$(cat "$WG_DIR/client_public.key")

  cat >"$WG_DIR/${WG_IF}.conf" <<EOF
[Interface]
Address = ${SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
# NAT + forwarding so allowed traffic reaches the internet:
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE

# The child's phone:
[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}/32
EOF
  echo "==> Wrote $WG_DIR/${WG_IF}.conf"
else
  echo "==> $WG_DIR/${WG_IF}.conf already exists — keeping existing keys."
fi

# --- dnsmasq: DNS server on the tunnel with the deny list ---
echo "==> Configuring dnsmasq…"
cat >/etc/dnsmasq.d/kidsafe.conf <<EOF
# KidSafe DNS — only listens on the WireGuard tunnel, forwards to Cloudflare.
interface=${WG_IF}
bind-dynamic
listen-address=${SERVER_IP}
no-resolv
server=1.1.1.1
server=1.0.0.1
# Blocked domains live in denylist.conf (auto-included from this directory).
EOF

# Seed the deny list (do not overwrite if the parent already customised it).
if [[ ! -f "$DENYLIST" ]]; then
  cat >"$DENYLIST" <<'EOF'
# ============================================================================
#  KidSafe deny list  —  one blocked service per section.
#  A line "address=/example.com/0.0.0.0" blocks example.com AND every subdomain.
#
#  To change what is blocked:
#     sudo nano /etc/dnsmasq.d/denylist.conf
#     sudo systemctl restart dnsmasq
#  (or use: kidsafe-block <domain> / kidsafe-unblock <domain> / kidsafe-list)
# ============================================================================

# ---- WhatsApp ----
address=/whatsapp.com/0.0.0.0
address=/whatsapp.net/0.0.0.0
address=/wa.me/0.0.0.0

# ---- YouTube ----
address=/youtube.com/0.0.0.0
address=/youtu.be/0.0.0.0
address=/googlevideo.com/0.0.0.0
address=/ytimg.com/0.0.0.0
address=/youtubei.googleapis.com/0.0.0.0
EOF
  echo "==> Wrote starter deny list: $DENYLIST"
else
  echo "==> $DENYLIST already exists — leaving your edits untouched."
fi

# --- Helper commands for managing the deny list ---
cat >/usr/local/bin/kidsafe-block <<'EOF'
#!/usr/bin/env bash
# Block a domain (and all its subdomains). Usage: kidsafe-block youtube.com
[[ -z "${1:-}" ]] && { echo "usage: kidsafe-block <domain>"; exit 1; }
L=/etc/dnsmasq.d/denylist.conf
grep -q "address=/$1/0.0.0.0" "$L" || echo "address=/$1/0.0.0.0" >>"$L"
systemctl restart dnsmasq && echo "Blocked: $1"
EOF
cat >/usr/local/bin/kidsafe-unblock <<'EOF'
#!/usr/bin/env bash
# Unblock a domain. Usage: kidsafe-unblock youtube.com
[[ -z "${1:-}" ]] && { echo "usage: kidsafe-unblock <domain>"; exit 1; }
L=/etc/dnsmasq.d/denylist.conf
sed -i "\#address=/$1/0.0.0.0#d" "$L"
systemctl restart dnsmasq && echo "Unblocked: $1"
EOF
cat >/usr/local/bin/kidsafe-list <<'EOF'
#!/usr/bin/env bash
# Show currently blocked domains.
grep -oP 'address=/\K[^/]+' /etc/dnsmasq.d/denylist.conf 2>/dev/null | sort || true
EOF
chmod +x /usr/local/bin/kidsafe-block /usr/local/bin/kidsafe-unblock /usr/local/bin/kidsafe-list

# --- Open the WireGuard port if ufw is active ---
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow ${WG_PORT}/udp >/dev/null || true
  echo "==> Opened UDP ${WG_PORT} in ufw."
fi

# --- Start everything ---
echo "==> Starting services…"
systemctl enable --now "wg-quick@${WG_IF}" >/dev/null 2>&1 || systemctl restart "wg-quick@${WG_IF}"
systemctl restart dnsmasq
systemctl enable dnsmasq >/dev/null 2>&1 || true

# --- Build the phone's config (idempotent) ---
CLIENT_PRIV=$(cat "$WG_DIR/client_private.key")
SERVER_PUB=$(cat "$WG_DIR/server_public.key")
cat >"$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}/32
DNS = ${SERVER_IP}

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${PUB_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_CONF"
qrencode -o "$CLIENT_PNG" < "$CLIENT_CONF" 2>/dev/null || true

echo
echo "============================================================"
echo " DONE. Scan this QR with the WireGuard app on the kid's phone"
echo " (WireGuard app  ▸  +  ▸  Scan from QR code):"
echo "============================================================"
qrencode -t ansiutf8 < "$CLIENT_CONF"
echo
echo "Config file (if you prefer to import a file): $CLIENT_CONF"
echo "QR image saved to:                            $CLIENT_PNG"
echo
echo "Manage blocking anytime:"
echo "  kidsafe-list                 # show blocked domains"
echo "  kidsafe-block  tiktok.com    # add a block"
echo "  kidsafe-unblock youtube.com  # remove a block"
echo "  sudo nano /etc/dnsmasq.d/denylist.conf   # edit by hand, then: sudo systemctl restart dnsmasq"
echo "============================================================"
