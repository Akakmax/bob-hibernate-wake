#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${HOME}/.openclaw/plugins/bob-hibernate-wake/listener.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "Listener is not running."
  exit 0
fi

PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
if [[ -z "${PID}" ]]; then
  rm -f "${PID_FILE}"
  echo "Listener pid file was empty. Cleaned."
  exit 0
fi

if kill -0 "${PID}" 2>/dev/null; then
  kill "${PID}" 2>/dev/null || true
  for _ in {1..20}; do
    if ! kill -0 "${PID}" 2>/dev/null; then
      break
    fi
    sleep 0.2
  done
  if kill -0 "${PID}" 2>/dev/null; then
    kill -9 "${PID}" 2>/dev/null || true
  fi
fi

rm -f "${PID_FILE}"
echo "Listener stopped."
