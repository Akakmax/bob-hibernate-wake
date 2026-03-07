#!/usr/bin/env bash
# plan-review.sh — Quick validation that a plan file has required sections.
# Usage: ./scripts/plan-review.sh plans/my-plan.md

set -euo pipefail

PLAN="${1:?Usage: plan-review.sh <plan-file>}"

if [[ ! -f "$PLAN" ]]; then
  echo "ERROR: File not found: $PLAN" >&2
  exit 1
fi

REQUIRED_SECTIONS=(
  "## Goal"
  "## Tasks"
  "## Files to Change"
  "## Security Considerations"
  "## Review Checklist"
)

MISSING=0
for section in "${REQUIRED_SECTIONS[@]}"; do
  if ! grep -q "$section" "$PLAN"; then
    echo "MISSING: $section" >&2
    MISSING=$((MISSING + 1))
  fi
done

if [[ "$MISSING" -gt 0 ]]; then
  echo ""
  echo "Plan is missing $MISSING required section(s)." >&2
  echo "See plans/TEMPLATE.md for the expected format." >&2
  exit 1
fi

echo "Plan structure OK: $PLAN"
