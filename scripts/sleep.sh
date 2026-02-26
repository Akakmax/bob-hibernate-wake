#!/usr/bin/env bash
set -euo pipefail

LABEL="ai.openclaw.gateway"
UID_NUM="$(id -u)"

echo "Putting Bob to sleep..."
openclaw gateway stop >/dev/null 2>&1 || true
launchctl disable "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootout "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
echo "Bob sleep mode is set."

