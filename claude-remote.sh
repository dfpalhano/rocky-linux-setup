#!/usr/bin/env bash
#
# claude-remote.sh — launch Claude Code in Remote Control mode on this machine.
#
# Remote Control keeps Claude Code running locally (full filesystem, MCP servers,
# project config) while letting you steer it from a browser at claude.ai/code or
# the Claude mobile app. Nothing moves to the cloud — the web/mobile UI is just a
# window into this local session.
#
# Usage:
#   ./claude-remote.sh [project-dir] [session-name]
#
#   project-dir   Directory to run in. Defaults to the current directory.
#   session-name  Title shown in the session list. Defaults to "<hostname>-server".
#
# Examples:
#   ./claude-remote.sh                      # current dir, default name
#   ./claude-remote.sh ~/code/myproject     # named after the host
#   ./claude-remote.sh ~/code/myproject "My Project"
#
set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
SESSION_NAME="${2:-$(hostname -s)-server}"

# Remote Control talks directly to api.anthropic.com and needs a full claude.ai
# login. An API key or a custom base URL in the environment disables it, so drop
# them for this process only (your shell config is untouched).
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "note: unsetting ANTHROPIC_API_KEY for this session (Remote Control needs claude.ai login)"
    unset ANTHROPIC_API_KEY
fi
if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    echo "note: unsetting ANTHROPIC_BASE_URL for this session (Remote Control needs api.anthropic.com)"
    unset ANTHROPIC_BASE_URL
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "error: 'claude' (Claude Code CLI) not found on PATH." >&2
    echo "       Install it, then run 'claude' once and '/login' with your claude.ai account." >&2
    exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "error: project dir not found: $PROJECT_DIR" >&2
    exit 1
fi

cd "$PROJECT_DIR"

echo "Starting Claude Code Remote Control"
echo "  dir:  $PROJECT_DIR"
echo "  name: $SESSION_NAME"
echo "  -> a session URL prints below; press spacebar for a QR code."
echo "  -> keep this process running; close it and the remote session ends."
echo

# Server mode: stays running and waits for remote connections from any device.
exec claude remote-control --name "$SESSION_NAME"
