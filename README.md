# bob-hibernate-wake

Secure sleep/wake plugin scaffold for Bob (OpenClaw).

This folder is intentionally isolated from existing runtime scripts/config so you can build and test safely.

## Scope

- Separate plugin code and docs
- Sleep/wake CLI for OpenClaw gateway lifecycle
- Real Telegram wake listener daemon (non-LLM polling)
- Sender allowlist + secret phrase + lockout controls
- Security and open-source starter docs

No runtime behavior changes happen unless you explicitly run plugin commands.

## Quick Start

1. Copy env file:
   - `cp .env.example .env`
2. Copy config template:
   - `cp config/config.example.toml config/config.toml`
3. Edit:
   - `.env` with `TG_BOT_TOKEN`
   - `config/config.toml` with `allowed_user_ids`, `allowed_chat_ids`, `secret_phrase`
4. Start listener:
   - `./bin/bob-hibernate listener-start`
5. Put Bob to sleep:
   - `./bin/bob-hibernate sleep`
6. Send secure command from authorized Telegram account/chat:
   - `/wakeup<secret>` or `/wakeup <secret>`
   - `/sleep<secret>` or `/sleep <secret>`
7. Check status:
   - `./bin/bob-hibernate status`

## Commands

- `./bin/bob-hibernate sleep`
- `./bin/bob-hibernate wake`
- `./bin/bob-hibernate status`
- `./bin/bob-hibernate listener-start`
- `./bin/bob-hibernate listener-stop`
- `./bin/bob-hibernate doctor`

## Security Notes

- Use Telegram numeric IDs, not usernames.
- Keep `.env` and `config/config.toml` private.
- Keep `wake.secret_phrase` high entropy.
- Recommended: set `dm_only = true`.
- Wrong secrets trigger rate-limit and lockout controls.
- Success reply texts:
  - sleep success -> `go to sleep bob!`
  - wake success -> `wake up Boby!`
