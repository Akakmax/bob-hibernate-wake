#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/config.toml"
PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"
RUN_LOG="${HOME}/.openclaw/logs/bob-hibernate-wake-listener.log"

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

if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    echo "Listener already running (pid ${PID})."
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

mkdir -p "$(dirname "${PID_FILE}")" "$(dirname "${RUN_LOG}")"
nohup python3 "${ROOT_DIR}/src/listener.py" \
  --root "${ROOT_DIR}" \
  --config "${CONFIG_FILE}" \
  --pid-file "${PID_FILE}" \
  >>"${RUN_LOG}" 2>&1 &

sleep 1
PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
if [[ -z "${PID}" ]] || ! kill -0 "${PID}" 2>/dev/null; then
  echo "Listener failed to start. Check: ${RUN_LOG}"
  exit 1
fi

echo "Listener started (pid ${PID})"
echo "Run log: ${RUN_LOG}"
