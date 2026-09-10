#!/usr/bin/env bash
#
# KidSafe VPS setup — READY TO RUN (keys already baked in).
# This matches the kidsafe-phone.conf that was generated alongside it.
#
# On the VPS, as root:
#     sudo bash vps_setup_ready.sh
#
# It installs WireGuard + dnsmasq, forces the phone's traffic + DNS through this
# box, and blocks the domains in /etc/dnsmasq.d/denylist.conf (edit with nano).
# Re-running is safe.

set -euo pipefail

WG_IF=wg0
WG_PORT=51820
SERVER_IP=10.7.0.1
CLIENT_IP=10.7.0.2
DENYLIST=/etc/dnsmasq.d/denylist.conf

# --- Baked-in keys (must match kidsafe-phone.conf) ---
SERVER_PRIV='MJ5No67A20oa6bGRUQEkDwA2dw0aRmRuL1LM5vdElnU='
CLIENT_PUB='Lmx+/Rb1gM4IpeyVAS9qb3PpXN0yBe1K2ljJEbOAEVM='
ENDPOINT_IP='162.35.122.89'

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo bash $0" >&2
  exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Debian/Ubuntu (apt). Adapt the install step for your distro." >&2
  exit 1
fi

echo "==> Installing packages (wireguard, dnsmasq, iptables)…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq wireguard dnsmasq iptables >/dev/null

WAN_IF=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
echo "==> WAN interface: ${WAN_IF:-unknown}"

echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-kidsafe.conf
sysctl -q -w net.ipv4.ip_forward=1

umask 077
mkdir -p /etc/wireguard
cat >/etc/wireguard/${WG_IF}.conf <<EOF
[Interface]
Address = ${SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE

# The child's phone:
[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}/32
EOF
echo "==> Wrote /etc/wireguard/${WG_IF}.conf"

echo "==> Configuring dnsmasq…"
cat >/etc/dnsmasq.d/kidsafe.conf <<EOF
interface=${WG_IF}
bind-dynamic
listen-address=${SERVER_IP}
no-resolv
server=1.1.1.1
server=1.0.0.1
# --- Traffic tracking: log every domain the phone asks for ---
log-queries
log-facility=/var/log/dnsmasq.log
EOF

# Rotate the query log so it can't fill the disk.
cat >/etc/logrotate.d/dnsmasq-kidsafe <<'EOF'
/var/log/dnsmasq.log {
  daily
  rotate 7
  missingok
  notifempty
  compress
  postrotate
    systemctl kill -s HUP dnsmasq 2>/dev/null || true
  endscript
}
EOF

if [[ ! -f "$DENYLIST" ]]; then
  cat >"$DENYLIST" <<'EOF'
# ============================================================================
#  KidSafe deny list  —  "address=/example.com/0.0.0.0" blocks it + subdomains.
#  Edit:  sudo nano /etc/dnsmasq.d/denylist.conf   then  sudo systemctl restart dnsmasq
#  Or:    kidsafe-block <domain> / kidsafe-unblock <domain> / kidsafe-list
# ============================================================================

# ---- WhatsApp ----
address=/whatsapp.com/0.0.0.0
address=/whatsapp.net/0.0.0.0
address=/wa.me/0.0.0.0

# ---- YouTube (all the domains the app and website use) ----
address=/youtube.com/0.0.0.0
address=/youtu.be/0.0.0.0
address=/googlevideo.com/0.0.0.0
address=/ytimg.com/0.0.0.0
address=/youtubei.googleapis.com/0.0.0.0
address=/youtube-nocookie.com/0.0.0.0
address=/youtubekids.com/0.0.0.0
address=/yt3.ggpht.com/0.0.0.0
address=/ggpht.com/0.0.0.0
EOF
  echo "==> Wrote starter deny list: $DENYLIST"
else
  echo "==> $DENYLIST already exists — leaving your edits untouched."
fi

cat >/usr/local/bin/kidsafe-block <<'EOF'
#!/usr/bin/env bash
[[ -z "${1:-}" ]] && { echo "usage: kidsafe-block <domain>"; exit 1; }
L=/etc/dnsmasq.d/denylist.conf
grep -q "address=/$1/0.0.0.0" "$L" || echo "address=/$1/0.0.0.0" >>"$L"
systemctl restart dnsmasq && echo "Blocked: $1"
EOF
cat >/usr/local/bin/kidsafe-unblock <<'EOF'
#!/usr/bin/env bash
[[ -z "${1:-}" ]] && { echo "usage: kidsafe-unblock <domain>"; exit 1; }
L=/etc/dnsmasq.d/denylist.conf
sed -i "\#address=/$1/0.0.0.0#d" "$L"
systemctl restart dnsmasq && echo "Unblocked: $1"
EOF
cat >/usr/local/bin/kidsafe-list <<'EOF'
#!/usr/bin/env bash
grep -oP 'address=/\K[^/]+' /etc/dnsmasq.d/denylist.conf 2>/dev/null | sort || true
EOF
# Live feed of every domain the phone requests (BLOCKED lines = deny-list hits).
cat >/usr/local/bin/kidsafe-watch <<'EOF'
#!/usr/bin/env bash
LOG=/var/log/dnsmasq.log
echo "Live DNS from the kid's phone (Ctrl+C to stop)."
echo "  'query[...]' = a request;  'config ... is 0.0.0.0' = BLOCKED."
echo "--------------------------------------------------------------"
tail -n 30 -F "$LOG" 2>/dev/null | grep --line-buffered -E 'query\[|is 0\.0\.0\.0'
EOF
# Summary: which blocked domains were hit most (whole log).
cat >/usr/local/bin/kidsafe-log <<'EOF'
#!/usr/bin/env bash
echo "Top BLOCKED domains the phone tried to reach:"
grep -hoP 'config \K[^ ]+(?= is 0\.0\.0\.0)' /var/log/dnsmasq.log* 2>/dev/null | sort | uniq -c | sort -rn | head -25
echo
echo "Most requested domains overall:"
grep -hoP 'query\[[A-Z]+\] \K[^ ]+' /var/log/dnsmasq.log* 2>/dev/null | sort | uniq -c | sort -rn | head -25
EOF
chmod +x /usr/local/bin/kidsafe-block /usr/local/bin/kidsafe-unblock /usr/local/bin/kidsafe-list \
         /usr/local/bin/kidsafe-watch /usr/local/bin/kidsafe-log

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow ${WG_PORT}/udp >/dev/null || true
  echo "==> Opened UDP ${WG_PORT} in ufw."
fi

echo "==> Starting services…"
systemctl enable --now "wg-quick@${WG_IF}" >/dev/null 2>&1 || systemctl restart "wg-quick@${WG_IF}"
systemctl restart dnsmasq
systemctl enable dnsmasq >/dev/null 2>&1 || true

echo
echo "============================================================"
echo " DONE. Install the KidSafe APK on the phone (config is baked in)."
echo " Endpoint the phone connects to: ${ENDPOINT_IP}:${WG_PORT}"
echo
echo " Check the phone is connected (look for a recent handshake):"
echo "   sudo wg show"
echo
echo " TRACK what the phone is doing:"
echo "   kidsafe-watch    # live feed of every domain requested (BLOCKED = denied)"
echo "   kidsafe-log      # top blocked + most-requested domains so far"
echo
echo " Manage blocking:"
echo "   kidsafe-list ; kidsafe-block tiktok.com ; kidsafe-unblock youtube.com"
echo "   sudo nano /etc/dnsmasq.d/denylist.conf  &&  sudo systemctl restart dnsmasq"
echo "============================================================"
