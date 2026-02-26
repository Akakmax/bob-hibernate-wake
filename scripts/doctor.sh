#!/usr/bin/env bash
set -euo pipefail

echo "Doctor checks:"

if command -v openclaw >/dev/null 2>&1; then
  echo "- openclaw: ok"
else
  echo "- openclaw: missing"
fi

if command -v launchctl >/dev/null 2>&1; then
  echo "- launchctl: ok"
else
  echo "- launchctl: missing"
fi

if command -v rg >/dev/null 2>&1; then
  echo "- rg: ok"
else
  echo "- rg: missing (optional)"
fi

if command -v python3 >/dev/null 2>&1; then
  echo "- python3: ok ($(python3 --version 2>/dev/null))"
else
  echo "- python3: missing"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "- config template: ${ROOT_DIR}/config/config.example.toml"
if [[ -f "${ROOT_DIR}/config/config.toml" ]]; then
  echo "- config active: ${ROOT_DIR}/config/config.toml"
else
  echo "- config active: missing (copy from template)"
fi

if [[ -f "${ROOT_DIR}/.env" ]]; then
  echo "- env file: ${ROOT_DIR}/.env"
else
  echo "- env file: missing (copy from .env.example)"
fi
