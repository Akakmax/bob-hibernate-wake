#!/usr/bin/env python3
import argparse
import json
import os
import signal
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


def parse_value(raw):
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw.startswith("'") and raw.endswith("'"):
        return raw[1:-1]
    if raw in ("true", "false"):
        return raw == "true"
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        out = []
        for part in inner.split(","):
            p = part.strip()
            if p.startswith('"') and p.endswith('"'):
                out.append(p[1:-1])
            elif p.startswith("'") and p.endswith("'"):
                out.append(p[1:-1])
            else:
                try:
                    out.append(int(p))
                except ValueError:
                    out.append(p)
        return out
    try:
        return int(raw)
    except ValueError:
        return raw


def parse_toml_minimal(path):
    data = {}
    section = None
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            data.setdefault(section, {})
            continue
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if "#" in val:
            # Strip trailing comments for simple scalar forms.
            maybe = val.split("#", 1)[0].strip()
            if maybe:
                val = maybe
        parsed = parse_value(val)
        if section:
            data.setdefault(section, {})[key] = parsed
        else:
            data[key] = parsed
    return data


def ensure_parent(path):
    Path(path).expanduser().parent.mkdir(parents=True, exist_ok=True)


def read_json(path, default):
    p = Path(path).expanduser()
    if not p.exists():
        return default
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json(path, payload):
    p = Path(path).expanduser()
    ensure_parent(p)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    tmp.replace(p)


def now_ts():
    return int(time.time())


class Listener:
    def __init__(self, root_dir, config_path, pid_file):
        self.root_dir = Path(root_dir).expanduser().resolve()
        self.config = parse_toml_minimal(config_path)

        plugin_cfg = self.config.get("plugin", {})
        telegram_cfg = self.config.get("telegram", {})
        auth_cfg = self.config.get("auth", {})
        wake_cfg = self.config.get("wake", {})
        sec_cfg = self.config.get("security", {})

        token_env = telegram_cfg.get("bot_token_env", "TG_BOT_TOKEN")
        self.token = os.environ.get(token_env, "").strip()
        if not self.token:
            raise RuntimeError("Missing Telegram bot token env: %s" % token_env)

        self.poll_interval = int(telegram_cfg.get("poll_interval_seconds", 2))
        self.dm_only = bool(telegram_cfg.get("dm_only", True))

        self.allowed_users = {int(x) for x in auth_cfg.get("allowed_user_ids", [])}
        self.allowed_chats = {int(x) for x in auth_cfg.get("allowed_chat_ids", [])}
        self.secret_phrase = str(wake_cfg.get("secret_phrase", "")).strip()
        if not self.secret_phrase:
            raise RuntimeError("wake.secret_phrase must be set")

        self.max_failures = int(sec_cfg.get("max_failures", 3))
        self.window_seconds = int(sec_cfg.get("window_seconds", 600))
        self.cooldown_seconds = int(sec_cfg.get("cooldown_seconds", 900))

        self.log_file = str(plugin_cfg.get("log_file", str(Path.home() / ".openclaw/logs/bob-hibernate-wake.log")))
        self.state_file = str(plugin_cfg.get("state_file", str(Path.home() / ".openclaw/plugins/bob-hibernate-wake/state.json")))
        self.pid_file = str(Path(pid_file).expanduser())
        self.running = True

        self.state = read_json(
            self.state_file,
            {
                "last_update_id": 0,
                "failures": {},
                "cooldown_until": {},
            },
        )

    def log(self, event, **fields):
        row = {"ts": now_ts(), "event": event}
        row.update(fields)
        ensure_parent(self.log_file)
        with open(Path(self.log_file).expanduser(), "a", encoding="utf-8") as f:
            f.write(json.dumps(row, sort_keys=True) + "\n")

    def save_state(self):
        write_json(self.state_file, self.state)

    def install_signal_handlers(self):
        def _stop(signum, _frame):
            self.log("listener_signal", signal=signum)
            self.running = False

        signal.signal(signal.SIGTERM, _stop)
        signal.signal(signal.SIGINT, _stop)

    def write_pid(self):
        ensure_parent(self.pid_file)
        Path(self.pid_file).write_text(str(os.getpid()), encoding="utf-8")

    def clear_pid(self):
        p = Path(self.pid_file).expanduser()
        if p.exists():
            p.unlink()

    def telegram_get_updates(self):
        base = "https://api.telegram.org/bot%s/getUpdates" % self.token
        params = {
            "timeout": 25,
            "offset": int(self.state.get("last_update_id", 0)),
            "allowed_updates": json.dumps(["message"]),
        }
        url = base + "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=35) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        return payload

    def telegram_send_message(self, chat_id, text):
        base = "https://api.telegram.org/bot%s/sendMessage" % self.token
        body = urllib.parse.urlencode(
            {
                "chat_id": str(chat_id),
                "text": text,
                "disable_notification": "true",
            }
        ).encode("utf-8")
        req = urllib.request.Request(base, data=body, method="POST")
        with urllib.request.urlopen(req, timeout=20) as resp:
            _ = resp.read()

    def is_authorized(self, user_id, chat_id, chat_type):
        if self.dm_only and chat_type != "private":
            return False
        by_user = (not self.allowed_users) or (user_id in self.allowed_users)
        by_chat = (not self.allowed_chats) or (chat_id in self.allowed_chats)
        return by_user and by_chat

    def user_key(self, user_id):
        return str(int(user_id))

    def in_cooldown(self, key):
        until = int(self.state.get("cooldown_until", {}).get(key, 0))
        return until > now_ts(), until

    def register_failure(self, key):
        cur = now_ts()
        fail_map = self.state.setdefault("failures", {})
        entries = [int(x) for x in fail_map.get(key, []) if int(x) >= cur - self.window_seconds]
        entries.append(cur)
        fail_map[key] = entries
        if len(entries) >= self.max_failures:
            cd = self.state.setdefault("cooldown_until", {})
            cd[key] = cur + self.cooldown_seconds
            fail_map[key] = []
            self.save_state()
            return True, cd[key]
        self.save_state()
        return False, 0

    def reset_failures(self, key):
        self.state.setdefault("failures", {}).pop(key, None)
        self.state.setdefault("cooldown_until", {}).pop(key, None)
        self.save_state()

    def run_wake_command(self):
        wake_script = self.root_dir / "scripts" / "wake.sh"
        proc = subprocess.run(
            [str(wake_script)],
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )
        return proc.returncode, proc.stdout[-1200:], proc.stderr[-1200:]

    def run_sleep_command(self):
        sleep_script = self.root_dir / "scripts" / "sleep.sh"
        proc = subprocess.run(
            [str(sleep_script)],
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )
        return proc.returncode, proc.stdout[-1200:], proc.stderr[-1200:]

    def parse_action(self, text):
        t = text.strip()
        if not t:
            return None, None
        low = t.lower()

        # Support compact command style: /sleep<secret> and /wakeup<secret>
        if low.startswith("/sleep"):
            return "sleep", t[len("/sleep") :].strip()
        if low.startswith("/wakeup"):
            return "wakeup", t[len("/wakeup") :].strip()

        # Backward-compatible command forms with separators.
        parts = t.split(maxsplit=1)
        cmd = parts[0].lower()
        arg = parts[1].strip() if len(parts) > 1 else ""
        if cmd in ("/wake", "wake", "wakeup"):
            return "wakeup", arg
        if cmd in ("sleep",):
            return "sleep", arg
        return None, None

    def process_message(self, msg):
        frm = msg.get("from") or {}
        chat = msg.get("chat") or {}
        text = (msg.get("text") or "").strip()
        user_id = int(frm.get("id", 0))
        chat_id = int(chat.get("id", 0))
        chat_type = str(chat.get("type", ""))
        key = self.user_key(user_id)

        if not user_id or not chat_id or not text:
            return

        if not self.is_authorized(user_id, chat_id, chat_type):
            self.log("wake_denied_auth", user_id=user_id, chat_id=chat_id, chat_type=chat_type)
            return

        in_cd, cd_until = self.in_cooldown(key)
        if in_cd:
            self.log("wake_denied_cooldown", user_id=user_id, chat_id=chat_id, cooldown_until=cd_until)
            self.telegram_send_message(chat_id, "Wake locked. Try again later.")
            return

        action, supplied_secret = self.parse_action(text)
        if action is None:
            return

        if supplied_secret != self.secret_phrase:
            locked, until = self.register_failure(key)
            if locked:
                self.log("wake_denied_lockout", user_id=user_id, chat_id=chat_id, cooldown_until=until)
                self.telegram_send_message(chat_id, "Command locked due to failed attempts.")
            else:
                self.log("cmd_denied_phrase", user_id=user_id, chat_id=chat_id, action=action)
                self.telegram_send_message(chat_id, "Command denied.")
            return

        self.reset_failures(key)
        self.log("cmd_attempt", user_id=user_id, chat_id=chat_id, action=action)

        if action == "wakeup":
            code, out, err = self.run_wake_command()
            if code == 0:
                self.log("wake_success", user_id=user_id, chat_id=chat_id)
                self.telegram_send_message(chat_id, "wake up Boby!")
                return
            self.log("wake_failed", user_id=user_id, chat_id=chat_id, code=code, out=out, err=err)
            self.telegram_send_message(chat_id, "Wake failed. Run local doctor.")
            return

        if action == "sleep":
            code, out, err = self.run_sleep_command()
            if code == 0:
                self.log("sleep_success", user_id=user_id, chat_id=chat_id)
                self.telegram_send_message(chat_id, "go to sleep bob!")
                return
            self.log("sleep_failed", user_id=user_id, chat_id=chat_id, code=code, out=out, err=err)
            self.telegram_send_message(chat_id, "Sleep failed. Run local doctor.")
            return

    def loop(self):
        self.log("listener_started", pid=os.getpid(), dm_only=self.dm_only)
        while self.running:
            try:
                payload = self.telegram_get_updates()
                if not payload.get("ok"):
                    self.log("telegram_error", detail=str(payload.get("description", "unknown")))
                    time.sleep(max(self.poll_interval, 2))
                    continue

                updates = payload.get("result", [])
                for item in updates:
                    upd_id = int(item.get("update_id", 0))
                    if upd_id >= int(self.state.get("last_update_id", 0)):
                        self.state["last_update_id"] = upd_id + 1
                    msg = item.get("message")
                    if msg:
                        self.process_message(msg)
                self.save_state()
            except Exception as exc:
                self.log("listener_error", error=str(exc))
                time.sleep(max(self.poll_interval, 2))
        self.log("listener_stopped")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--pid-file", required=True)
    args = parser.parse_args()

    listener = Listener(root_dir=args.root, config_path=args.config, pid_file=args.pid_file)
    listener.install_signal_handlers()
    listener.write_pid()
    try:
        listener.loop()
    finally:
        listener.clear_pid()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("listener failed: %s" % e, file=sys.stderr)
        sys.exit(1)
