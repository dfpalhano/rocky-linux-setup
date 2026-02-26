# Rocky Linux 10.1 — Starter Setup

Personal notes and package list for a fresh Rocky Linux 10.1 (Red Quartz) installation.
Machine role: AI server.

---

## System Info

| Field | Value |
|-------|-------|
| OS | Rocky Linux 10.1 (Red Quartz) |
| Kernel | 6.12.0-124.38.1.el10_1.x86_64 |
| Shell | bash |
| Package manager | dnf |

---

## Step 1 — Enable EPEL

```bash
sudo dnf install -y epel-release
sudo dnf update -y
```

---

## Step 2 — Essential Packages

```bash
sudo dnf install -y \
    tmux \
    kernel-devel-matched \
    NetworkManager-wifi \
    linux-firmware \
    dkms
```

| Package | Version | Source | Purpose |
|---------|---------|--------|---------|
| epel-release | 10-7.el10_1 | extras | Enables EPEL repository |
| kernel-devel-matched | 6.12.0-124.38.1.el10_1 | appstream | Kernel headers for building modules |
| NetworkManager-wifi | 1.54.0-2.el10_1 | baseos | WiFi support |
| linux-firmware | 20260107-19.2.el10_1 | baseos | Firmware blobs for hardware |
| dkms | 3.3.0-1.el10_1 | EPEL | Auto-rebuild kernel modules on updates |
| tmux | latest | baseos/epel | Terminal multiplexer |

---

## Notes

- **WiFi (Realtek RTW8852AE):** out-of-tree driver available at [lwfinger/rtw89](https://github.com/lwfinger/rtw89) but did not work reliably on Rocky Linux 10.1. Ethernet recommended for server use.
- **DKMS:** installed and available but not actively used. Useful if you register out-of-tree kernel modules so they auto-rebuild after kernel updates.
- **kernel-devel-matched:** make sure to install the `matched` variant so it aligns with your running kernel version.

---

## Useful Commands

```bash
# Check running kernel
uname -r

# List installed kernels
rpm -q kernel kernel-devel

# Check NetworkManager device status
nmcli device status

# Check DKMS modules
dkms status
```

---

## Known Issues & Fixes

### OpenClaw — Telegram channel failing with ETIMEDOUT on startup

**Symptom:** Telegram channel repeatedly fails with `Network request failed` errors despite valid credentials and working internet.

**Cause:** Node.js 22 uses "Happy Eyeballs" (`autoSelectFamily=true`) — tries IPv4 and IPv6 simultaneously. Rocky Linux 10.1 has IPv6 link-local addresses but no global IPv6 routing, so both attempts time out together.

**Fix:**
```bash
openclaw config set channels.telegram.network.autoSelectFamily false
openclaw gateway --force
```

See [issue #1](https://github.com/dfpalhano/rocky-linux-setup/issues/1) for full diagnosis.

---

## Contributing

If you have additional packages or tips for Rocky Linux 10.1 server setups, feel free to open an issue or PR.
