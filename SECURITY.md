# Security Policy

## Supported Versions

This project is pre-1.0 and under active development.

## Reporting a Vulnerability

- Do not open public issues for sensitive vulnerabilities.
- Send a private report to the maintainer with:
  - impact
  - reproduction steps
  - affected version/commit
  - suggested fix (if available)

## Baseline Security Requirements

- Never trust Telegram usernames for auth; use numeric IDs.
- Never commit bot tokens or wake secrets.
- Never log raw secrets.
- Keep gateway bind on loopback for local deployments.
- Enforce rate limiting and lockouts on wake attempts.

