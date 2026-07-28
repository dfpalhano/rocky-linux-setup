#!/usr/bin/env bash
#
# Register the Zapier MCP server with Claude Code on this machine.
#
#   ./setup-zapier-mcp.sh 'https://mcp.zapier.com/api/mcp/s/<token>/mcp'
#   ./setup-zapier-mcp.sh          # re-reads the URL back out of 1Password
#
# The URL embeds a bearer token, so it is treated as a secret: stashed in
# 1Password on first run and never echoed. Idempotent — safe to re-run.
#
# Getting the URL is the one manual part: https://mcp.zapier.com
#   + New MCP Server -> client "Claude Code" -> add the actions you want
#   exposed -> Connect tab -> copy the URL.
#
set -euo pipefail

OP_ITEM="Zapier MCP"
OP_VAULT="${OP_VAULT:-Private}"
SERVER_NAME="zapier"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[34m==>\033[0m %s\n' "$*"; }

command -v claude >/dev/null || die "claude CLI not found in PATH"

url="${1:-}"

# No URL given: pull the one we stored last time.
if [[ -z "$url" ]]; then
    command -v op >/dev/null || die "no URL argument and 1Password CLI (op) not installed"
    info "No URL given — reading it from 1Password item '$OP_ITEM'"
    url="$(op read "op://${OP_VAULT}/${OP_ITEM}/credential" 2>/dev/null)" \
        || die "couldn't read '$OP_ITEM' from vault '$OP_VAULT'. Run 'eval \$(op signin)' first, or pass the URL as an argument."
fi

[[ "$url" == https://mcp.zapier.com/* ]] \
    || die "that doesn't look like a Zapier MCP URL (expected it to start with https://mcp.zapier.com/)"

# Stash it, so future runs need no argument. Non-fatal: the registration below
# is what actually matters.
if command -v op >/dev/null && [[ -n "${1:-}" ]]; then
    if op item get "$OP_ITEM" --vault "$OP_VAULT" >/dev/null 2>&1; then
        info "Updating 1Password item '$OP_ITEM'"
        op item edit "$OP_ITEM" --vault "$OP_VAULT" "credential=$url" >/dev/null \
            || info "warning: couldn't update 1Password item (continuing)"
    else
        info "Saving URL to 1Password item '$OP_ITEM'"
        op item create --category="API Credential" --vault "$OP_VAULT" \
            --title="$OP_ITEM" "credential=$url" >/dev/null \
            || info "warning: couldn't save to 1Password (continuing)"
    fi
fi

# --scope user so it's available in every project, not just this directory.
# Re-adding an existing name errors, so drop it first.
if claude mcp list 2>/dev/null | grep -q "^${SERVER_NAME}\b"; then
    info "Replacing existing '$SERVER_NAME' server registration"
    claude mcp remove --scope user "$SERVER_NAME" >/dev/null 2>&1 || true
fi

info "Registering '$SERVER_NAME' with Claude Code (user scope)"
claude mcp add --transport http --scope user "$SERVER_NAME" "$url"

info "Done. Verifying:"
claude mcp list | sed -n "1p;/^${SERVER_NAME}\b/p"

cat <<'EOF'

Next: start Claude Code and run /mcp to confirm the connection and see which
tools came through. If the list is empty, the server has no actions attached —
add them at https://mcp.zapier.com and re-run /mcp.
EOF
