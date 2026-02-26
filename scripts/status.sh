#!/usr/bin/env bash
set -euo pipefail

LABEL="ai.openclaw.gateway"
UID_NUM="$(id -u)"
PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"

echo "Plugin root: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Wake listener:"
if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    echo "  running (pid ${PID})"
  else
    echo "  stale pid file (${PID_FILE})"
  fi
else
  echo "  stopped"
fi
echo
echo "LaunchAgent disabled state:"
launchctl print-disabled "gui/${UID_NUM}" | rg "${LABEL}" || true
echo
echo "Gateway status:"
openclaw gateway status || true
