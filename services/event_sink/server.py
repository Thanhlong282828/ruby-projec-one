"""Internal signed event receiver. SQLite unique IDs make at-least-once delivery safe."""
import hashlib
import hmac
import json
import os
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = os.environ.get("EVENT_DB", "/data/events.sqlite3")
SECRET = os.environ["EVENT_SECRET"].encode()
with sqlite3.connect(DB) as connection:
    connection.execute("CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, event_type TEXT NOT NULL, payload TEXT NOT NULL, received_at TEXT DEFAULT CURRENT_TIMESTAMP)")

    columns = {row[1] for row in connection.execute("PRAGMA table_info(events)")}
    if "body_digest" not in columns:
        connection.execute("ALTER TABLE events ADD COLUMN body_digest TEXT")

class Handler(BaseHTTPRequestHandler):
    # Restrict slow clients and avoid persisting raw bodies/signatures in logs.
    timeout = 5

    def do_GET(self):
        self.send_response(200 if self.path == "/health" else 404)
        self.end_headers()

    def do_POST(self):
        if self.path != "/events":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 65536:
                self.send_error(413)
                return
            if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
                self.send_error(415)
                return
            timestamp = self.headers.get("X-Event-Timestamp", "")
            if not timestamp.isascii() or not timestamp.isdecimal() or len(timestamp) > 12 or abs(time.time() - int(timestamp)) > 300:
                self.send_error(401)
                return
            body = self.rfile.read(length)
            if len(body) != length:
                self.send_error(400)
                return
            expected = hmac.new(SECRET, timestamp.encode() + b"." + body, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(expected, self.headers.get("X-Event-Signature", "")):
                self.send_error(401)
                return
            event = json.loads(body)
            if (
                not isinstance(event, dict)
                or type(event.get("id")) is not int
                or not 0 < event["id"] <= 9223372036854775807
                or type(event.get("company_id")) is not int
                or not 0 < event["company_id"] <= 9223372036854775807
                or not isinstance(event.get("type"), str)
                or not 0 < len(event["type"]) <= 100
                or not isinstance(event.get("payload"), dict)
            ):
                raise ValueError("invalid event schema")
            with sqlite3.connect(DB, timeout=10) as connection:
                digest = hashlib.sha256(json.dumps(event, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
                connection.execute("INSERT OR IGNORE INTO events(id,event_type,payload,body_digest) VALUES(?,?,?,?)", (event["id"], event["type"], json.dumps(event["payload"]), digest))
                stored = connection.execute("SELECT body_digest FROM events WHERE id=?", (event["id"],)).fetchone()[0]
                if stored != digest:
                    self.send_error(409)
                    return
            self.send_response(202)
            self.end_headers()
        except (ValueError, KeyError, TypeError, UnicodeError, json.JSONDecodeError):
            self.send_error(400)

ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
