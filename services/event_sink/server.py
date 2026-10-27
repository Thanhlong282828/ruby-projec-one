"""Internal signed event receiver. SQLite unique IDs make at-least-once delivery safe."""
import hashlib
import hmac
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = os.environ.get("EVENT_DB", "/data/events.sqlite3")
SECRET = os.environ["EVENT_SECRET"].encode()
with sqlite3.connect(DB) as connection:
    connection.execute("CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, event_type TEXT NOT NULL, payload TEXT NOT NULL, received_at TEXT DEFAULT CURRENT_TIMESTAMP)")

class Handler(BaseHTTPRequestHandler):
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
            body = self.rfile.read(length)
            expected = hmac.new(SECRET, body, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(expected, self.headers.get("X-Event-Signature", "")):
                self.send_error(401)
                return
            event = json.loads(body)
            if not isinstance(event["id"], int) or not isinstance(event["type"], str) or not isinstance(event["payload"], dict):
                raise ValueError("invalid event schema")
            with sqlite3.connect(DB, timeout=10) as connection:
                connection.execute("INSERT OR IGNORE INTO events(id,event_type,payload) VALUES(?,?,?)", (event["id"], event["type"], json.dumps(event["payload"])))
            self.send_response(202)
            self.end_headers()
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            self.send_error(400)

ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
