#!/usr/bin/env bash
set -euo pipefail

LABEL="ai.openclaw.gateway"
UID_NUM="$(id -u)"
PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"
LABEL="ai.bob.hibernatewake.listener"

echo "Plugin root: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Wake listener:"
if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
  echo "  running (${LABEL})"
elif [[ -f "${PID_FILE}" ]]; then
  echo "  stopped (stale pid file present)"
else
  echo "  stopped"
fi
echo
echo "LaunchAgent disabled state:"
launchctl print-disabled "gui/${UID_NUM}" | rg "${LABEL}" || true
echo
echo "Gateway status:"
openclaw gateway status || true
