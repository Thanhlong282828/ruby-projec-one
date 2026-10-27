import hashlib
import hmac
import json
import os
import socket
import sqlite3
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

class EventSinkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.db = str(Path(cls.directory.name) / 'events.sqlite3')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            cls.port = sock.getsockname()[1]
        cls.process = subprocess.Popen(['python3', str(Path(__file__).with_name('server.py'))], env={**os.environ, 'PORT': str(cls.port), 'EVENT_DB': cls.db, 'EVENT_SECRET': 'test-secret'}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cls.url = f'http://127.0.0.1:{cls.port}'
        for attempt in range(50):
            try:
                urllib.request.urlopen(cls.url + '/health', timeout=1)
                return
            except OSError:
                time.sleep(0.05)
        raise RuntimeError('Receiver failed to start')

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        cls.process.wait(timeout=5)
        cls.directory.cleanup()

    def post(self, body, signature):
        request = urllib.request.Request(self.url + '/events', data=body, headers={'Content-Type': 'application/json', 'X-Event-Signature': signature})
        try:
            return urllib.request.urlopen(request, timeout=3).status
        except urllib.error.HTTPError as error:
            code = error.code
            error.close()
            return code

    def test_rejects_unsigned_event(self):
        self.assertEqual(401, self.post(b'{}', 'invalid'))

    def test_signed_delivery_is_idempotent(self):
        body = json.dumps({'id': 42, 'type': 'employee.created', 'payload': {'record_id': 3}}).encode()
        signature = hmac.new(b'test-secret', body, hashlib.sha256).hexdigest()
        self.assertEqual(202, self.post(body, signature))
        self.assertEqual(202, self.post(body, signature))
        with sqlite3.connect(self.db) as connection:
            self.assertEqual(1, connection.execute('SELECT count(*) FROM events WHERE id=42').fetchone()[0])

    def test_rejects_invalid_schema(self):
        body = b'{"id":"bad"}'
        signature = hmac.new(b'test-secret', body, hashlib.sha256).hexdigest()
        self.assertEqual(400, self.post(body, signature))

if __name__ == '__main__':
    unittest.main()
