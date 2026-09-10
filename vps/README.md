# KidSafe — VPS network filter (WhatsApp / YouTube blocking)

Force a child's phone through your VPS and block apps at the network level with a
`nano`-editable deny list. Works alongside (or instead of) the on-device Flutter app.

```
Phone (WireGuard app)  ──encrypted tunnel──►  VPS
                                               ├─ WireGuard : all phone traffic enters here
                                               ├─ dnsmasq   : blackholes blocked domains
                                               └─ NAT       : forwards allowed traffic out
```

Because the phone tunnels **all** traffic (`AllowedIPs = 0.0.0.0/0`) and its DNS is
forced to the VPS, the child can't bypass the filter by changing Wi-Fi or DNS.

## 1. Set up the VPS (once)

SSH into your server, then:

```bash
nano vps_setup.sh        # paste the contents of vps/vps_setup.sh, save with Ctrl+O, Ctrl+X
sudo bash vps_setup.sh
```

At the end it prints a **QR code**.

> Make sure UDP port **51820** is open to the server (cloud provider firewall / security group).

## 2. Set up the phone (once)

1. Install the official **WireGuard** app (Play Store / App Store) on the kid's phone.
2. Open it ▸ **＋** ▸ **Scan from QR code** ▸ scan the QR from step 1.
3. Toggle the tunnel **on**. Optionally enable "on-demand" / always-on so it can't be
   left off. On Android you can also set the VPN as **Always-on VPN** with
   **Block connections without VPN** in Settings ▸ Network ▸ VPN.

WhatsApp and YouTube are now blocked. Everything else works normally.

## 3. Change what's blocked (anytime)

On the VPS:

```bash
kidsafe-list                 # show blocked domains
kidsafe-block  tiktok.com    # add a block (all subdomains too)
kidsafe-unblock youtube.com  # remove a block
```

or edit the file directly — exactly the "nano deny list" workflow:

```bash
sudo nano /etc/dnsmasq.d/denylist.conf
sudo systemctl restart dnsmasq
```

## How solid is the block, honestly

- **DNS-based blocking** stops apps that resolve a name — very effective for WhatsApp
  and YouTube in day-to-day use.
- A determined teenager *could* try to defeat it by installing another VPN on the phone
  (which tunnels around yours) or by using an app that talks to hardcoded IPs. To harden:
  - Set the WireGuard tunnel as **Always-on + Block connections without VPN** (Android).
  - Also add IP-level blocks on the VPS if needed (ask and I'll add `iptables`/`ipset` rules).
  - Combine with the on-device Flutter app in this repo, which blocks the WhatsApp *app*
    itself even on Wi-Fi with no tunnel.
- This filters a device **you own and administer**. Don't route someone else's traffic
  through it without their knowledge.

## Security

- Your VPS password was pasted in a chat earlier — **rotate it** (`passwd`) and prefer
  SSH keys with password login disabled.
- `client_private.key` / `kidsafe-phone.conf` on the VPS are the phone's identity — keep
  them private; delete `kidsafe-phone.png` after you've scanned it if you like.
