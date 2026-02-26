#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"
PLIST="${HOME}/Library/LaunchAgents/ai.bob.hibernatewake.listener.plist"
LABEL="ai.bob.hibernatewake.listener"

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
rm -f "${PID_FILE}" "${PLIST}"
echo "Listener stopped (${LABEL})."
