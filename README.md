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

## OpenClaw — AI Gateway Setup

[OpenClaw](https://openclaw.ai) is an AI agent gateway. This machine runs it as a local server with Telegram as the messaging channel.

### Running as a Systemd Service

OpenClaw has a built-in command to install itself as a systemd user service (auto-starts on login):

```bash
openclaw daemon install
openclaw daemon start
```

Manage the service:

```bash
openclaw daemon start      # start
openclaw daemon stop       # stop
openclaw daemon restart    # restart
openclaw daemon status     # check status + probe gateway
```

Service file is installed at `~/.config/systemd/user/openclaw-gateway.service`.

> **Note:** If you need the gateway to start at boot without login, enable systemd user lingering:
> ```bash
> sudo loginctl enable-linger $USER
> ```

See [issue #2](https://github.com/dfpalhano/rocky-linux-setup/issues/2) for full setup notes.

---

### Telegram Channel Configuration

After setting up OpenClaw and configuring a Telegram bot, apply this fix **before starting the gateway** to avoid network issues on Rocky Linux 10.1.

**Problem:** On Rocky Linux 10.1 with Node.js 22, the Telegram channel fails on startup with repeated errors:

```
telegram deleteWebhook failed: Network request for 'deleteWebhook' failed!
telegram setMyCommands failed: Network request for 'setMyCommands' failed!
```

**Cause:** Node.js 22 enables "Happy Eyeballs" (`autoSelectFamily=true`) — it tries IPv4 and IPv6 simultaneously. Rocky Linux 10.1 typically has IPv6 link-local addresses but no global IPv6 routing, so both attempts time out together (`AggregateError [ETIMEDOUT]`).

**Fix:**

```bash
openclaw config set channels.telegram.network.autoSelectFamily false
openclaw gateway --force
```

The gateway log will confirm it's applied:
```
autoSelectFamily=false (config)
```

See [issue #1](https://github.com/dfpalhano/rocky-linux-setup/issues/1) for full diagnosis.

---

## Contributing

If you have additional packages or tips for Rocky Linux 10.1 server setups, feel free to open an issue or PR.
