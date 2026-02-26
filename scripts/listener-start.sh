#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/config.toml"
PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"
RUN_LOG="${HOME}/.openclaw/logs/bob-hibernate-wake-listener.log"
PLIST="${HOME}/Library/LaunchAgents/ai.bob.hibernatewake.listener.plist"
LABEL="ai.bob.hibernatewake.listener"
RUNTIME_DIR="${HOME}/.openclaw/plugins/bob-hibernate-wake-runtime"
RUNTIME_CONFIG="${RUNTIME_DIR}/config/config.toml"
RUNTIME_ROOT="${RUNTIME_DIR}"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "Missing config: ${CONFIG_FILE}"
  echo "Create it from: ${ROOT_DIR}/config/config.example.toml"
  exit 1
fi

if [[ -z "${TG_BOT_TOKEN:-}" ]]; then
  echo "Missing TG_BOT_TOKEN in ${ROOT_DIR}/.env"
  exit 1
fi

mkdir -p "$(dirname "${PID_FILE}")" "$(dirname "${RUN_LOG}")"
mkdir -p "$(dirname "${PLIST}")"
rm -rf "${RUNTIME_DIR}"
mkdir -p "${RUNTIME_DIR}"
cp -R "${ROOT_DIR}/bin" "${RUNTIME_DIR}/"
cp -R "${ROOT_DIR}/scripts" "${RUNTIME_DIR}/"
cp -R "${ROOT_DIR}/src" "${RUNTIME_DIR}/"
mkdir -p "${RUNTIME_DIR}/config"
cp "${CONFIG_FILE}" "${RUNTIME_CONFIG}"

cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>${RUNTIME_DIR}/src/listener.py</string>
    <string>--root</string>
    <string>${RUNTIME_ROOT}</string>
    <string>--config</string>
    <string>${RUNTIME_CONFIG}</string>
    <string>--pid-file</string>
    <string>${PID_FILE}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>TG_BOT_TOKEN</key>
    <string>${TG_BOT_TOKEN}</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${RUN_LOG}</string>
  <key>StandardErrorPath</key>
  <string>${RUN_LOG}</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "${PLIST}"

sleep 1
if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
  echo "Listener LaunchAgent started (${LABEL})"
  echo "Run log: ${RUN_LOG}"
else
  echo "Listener failed to start. Check: ${RUN_LOG}"
  exit 1
fi
