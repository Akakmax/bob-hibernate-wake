#!/usr/bin/env bash
set -euo pipefail

LABEL="ai.openclaw.gateway"
UID_NUM="$(id -u)"

echo "Waking Bob..."
launchctl enable "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${UID_NUM}" "${HOME}/Library/LaunchAgents/${LABEL}.plist" >/dev/null 2>&1 || true
openclaw gateway restart >/dev/null 2>&1 || openclaw gateway start >/dev/null 2>&1 || true

echo "Current status:"
openclaw gateway status || true

