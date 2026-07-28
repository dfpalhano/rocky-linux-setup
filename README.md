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

## Step 3 — LibreOffice (Word, Excel, PowerPoint)

LibreOffice is **not available in dnf repos** for Rocky Linux 10.1 (not in AppStream or EPEL). Install via Flatpak instead:

```bash
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install flathub org.libreoffice.LibreOffice
```

| Package | Version | Source |
|---------|---------|--------|
| LibreOffice | 26.2.0.3 | Flathub (Flatpak) |

### Headless usage (server)

```bash
# Convert Word to text
flatpak run org.libreoffice.LibreOffice --headless --convert-to txt file.docx

# Convert Excel to CSV
flatpak run org.libreoffice.LibreOffice --headless --convert-to csv file.xlsx
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

## Step 4 — Linuxbrew (Homebrew on Linux)

A second package manager covering many CLIs that aren't packaged for Rocky 10.1
or where the dnf version lags. Used as the source-of-truth for `op`, `gh`,
`rclone`, `semgrep`, and friends below.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

| Package | Version | Source |
|---------|---------|--------|
| Homebrew | 5.1.8 | install.sh |

> **Heads-up — Node ABI split:** if you `brew install node`, the brew Node will
> shadow `/usr/bin/node`. Native modules built against one will fail on the
> other (`NODE_MODULE_VERSION` mismatch). Pin scripts that load native modules
> to the Node they were compiled against, e.g. `PATH=/usr/bin:$PATH node …`.

---

## Step 5 — Daily-driver CLIs (via Linuxbrew)

```bash
brew install gh op rclone semgrep
```

| Package | Version | Source | Purpose |
|---------|---------|--------|---------|
| GitHub CLI (`gh`) | 2.87.3 | Linuxbrew | `gh` for repo / PR / issue / API ops |
| 1Password CLI (`op`) | 2.32.1 | Linuxbrew | Secrets manager; `eval $(op signin)` to start a session |
| rclone | 1.73.5 | Linuxbrew | Cloud sync; encrypted backups via `gcrypt` remotes |
| Semgrep | 1.157.0 | Linuxbrew | Static analysis (security + lint patterns) |

### gh first-time login

```bash
gh auth login            # follow prompts (HTTPS, browser, scope)
gh auth status           # confirm
```

### op first-time setup

```bash
op account add --address my.1password.com --email <you>@<host>
eval $(op signin)        # session lasts ~30 minutes by default
op item list             # smoke
```

### rclone gcrypt backup

```bash
rclone config            # add a Google Drive remote, then a "crypt" overlay on it
rclone sync ~/backup-source crypted-remote:bak/<host>
```

---

## Step 6 — Tailscale (mesh VPN / SSH)

Tailscale is published from its own repo; do not rely on EPEL.

```bash
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/10/tailscale.repo
sudo dnf install -y tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up        # opens a browser auth URL
tailscale status
```

| Package | Version | Source |
|---------|---------|--------|
| tailscale | 1.96.4 | Tailscale RPM repo |

Once up, every machine on your tailnet is reachable by hostname or
`100.x.y.z` IP. Use it for SSH between machines without exposing port 22 to
the public internet.

---

## Step 7 — Obsidian (knowledge vault)

Same Flatpak strategy as LibreOffice — not in dnf repos.

```bash
sudo flatpak install -y flathub md.obsidian.Obsidian
flatpak run md.obsidian.Obsidian
```

| Package | Version | Source |
|---------|---------|--------|
| Obsidian | 1.12.7 | Flathub (Flatpak) |

For multi-machine vault sync use Syncthing over Tailscale; folder paths are
case-sensitive on Linux but not on macOS — pick one canonical case before
syncing or you'll end up with duplicate-but-different folders on the Linux
side.

---

## Step 8 — Zapier + Claude

Two **different, independent** integrations that are easy to confuse. Pick by
which side initiates the call:

| Direction | What it is | Credential | Use when |
|-----------|------------|------------|----------|
| **Claude → Zapier** | Zapier MCP: your Zapier actions become tools Claude can call | MCP server URL | You want Claude to *do* things in your apps, in conversation |
| **Zapier → Claude** | Zapier's "Anthropic (Claude)" app: a Zap step that prompts Claude | Anthropic API key | You want an unattended Zap to classify/summarise/draft |

Setting up one does **not** enable the other, and they bill separately.

---

### 8a. Zapier → Claude (API key)

Zapier's *Anthropic (Claude)* app runs Claude as a step inside a Zap.

1. <https://platform.claude.com/settings/keys> (formerly console.anthropic.com)
   → **Create Key** → copy it. The secret is shown once only.
2. In Zapier: **Apps** → **+ Add connection** → *Anthropic (Claude)* → paste the
   key into the **API Key** field.

> **Billing gotcha:** the Anthropic API is prepaid and entirely separate from a
> Claude Pro/Max subscription — the subscription does **not** cover API calls.
> Load credits (min $5) under Billing in the console or every Zap run fails on
> auth/quota. Credits expire one year after purchase.

Store the key in 1Password rather than only in Zapier, so rotation is possible:

```bash
op item create --category="API Credential" --title="Anthropic API (Zapier)" credential="sk-ant-..."
```

To rotate: create a new key in the console, update the Zapier connection, then
delete the old key. Zaps using the old connection break the moment it's deleted,
so update first.

---

### 8b. Claude → Zapier (MCP)

[Zapier MCP](https://mcp.zapier.com) exposes your Zapier actions as MCP tools, so
Claude can send Gmail, file Jira tickets, append Sheets rows, etc. without you
writing an integration. It is a **remote** MCP server — nothing is installed on
this machine, only a URL + token.

#### Create the server (browser, one time)

1. Go to <https://mcp.zapier.com> and sign in.
2. **+ New MCP Server** → pick the client (**Claude** for claude.ai/Desktop,
   **Claude Code** for the CLI) → name it.
3. Add the actions you want exposed (e.g. *Gmail: Send Email*). **Only the
   actions you add become tools** — an empty server gives Claude nothing.
4. **Connect** tab → copy the generated URL. It looks like
   `https://mcp.zapier.com/api/mcp/s/<token>/mcp`; the token *is* the
   credential, so treat it like a password.

#### Wire it into Claude Code (this machine)

```bash
# --scope user = available in every project on this box (default is per-project)
claude mcp add --transport http --scope user zapier "<YOUR_GENERATED_URL>"

claude mcp list          # confirm it registered
```

Then inside Claude Code run `/mcp` to check the connection and list the tools.

#### Wire it into claude.ai / Claude Desktop

Settings → **Connectors** → **Add custom connector** → paste the same URL.
Zapier is also in the connector directory, which does the same thing over OAuth
instead of a URL token.

| Detail | Value |
|--------|-------|
| Transport | Streamable HTTP (legacy SSE is no longer supported) |
| Auth | Bearer token embedded in the server URL |
| Install footprint | None — remote server, no local daemon |

### Notes

- **Store the URL in 1Password**, not in `~/.claude.json` in a synced/backed-up
  folder — `op` is already installed above:
  ```bash
  op item create --category="API Credential" --title="Zapier MCP" credential="<URL>"
  claude mcp add --transport http --scope user zapier "$(op read 'op://Private/Zapier MCP/credential')"
  ```
- Each action you expose is a live write to a real account. Keep the action list
  minimal and re-read Claude's tool-call arguments before approving the first
  run of anything that sends or deletes.
- Rotating: delete and recreate the server in the Zapier dashboard, then
  `claude mcp remove zapier` and re-add with the new URL.
- Headless/systemd contexts (like the OpenClaw gateway above) don't share the
  Claude Code MCP config — configure that separately if you want the same tools
  there.

---

## Contributing

If you have additional packages or tips for Rocky Linux 10.1 server setups, feel free to open an issue or PR.
