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

    def post(self, body, signature=None, timestamp=None, content_type="application/json"):
        timestamp = str(int(time.time())) if timestamp is None else timestamp
        signature = self.sign(body, timestamp) if signature is None else signature
        request = urllib.request.Request(self.url + '/events', data=body, headers={'Content-Type': content_type, 'X-Event-Signature': signature, 'X-Event-Timestamp': timestamp})
        try:
            return urllib.request.urlopen(request, timeout=3).status
        except urllib.error.HTTPError as error:
            code = error.code
            error.close()
            return code

    def sign(self, body, timestamp):
        return hmac.new(b'test-secret', timestamp.encode() + b'.' + body, hashlib.sha256).hexdigest()

    def test_rejects_expired_signature_and_future_timestamp(self):
        for offset in (-600, 600):
            self.assertEqual(401, self.post(b'{}', timestamp=str(int(time.time()) + offset)))

    def test_rejects_wrong_content_type_and_oversized_body(self):
        self.assertEqual(415, self.post(b'{}', content_type='text/plain'))
        self.assertEqual(413, self.post(b'x' * 65537))

    def test_rejects_changed_payload_for_existing_event(self):
        event = {'id': 43, 'company_id': 1, 'type': 'employee.created', 'payload': {'record_id': 3}}
        self.assertEqual(202, self.post(json.dumps(event).encode()))
        event['company_id'] = 2
        self.assertEqual(409, self.post(json.dumps(event).encode()))

    def test_body_tampering_invalidates_signature(self):
        original = b'{"id":10,"company_id":1,"type":"employee.created","payload":{}}'
        timestamp = str(int(time.time()))
        self.assertEqual(401, self.post(original.replace(b'"company_id":1', b'"company_id":2'), self.sign(original, timestamp), timestamp))

    def test_boolean_and_out_of_range_event_ids_are_rejected(self):
        for event_id in (True, 2 ** 70):
            body = json.dumps({'id': event_id, 'company_id': 1, 'type': 'employee.created', 'payload': {}}).encode()
            self.assertEqual(400, self.post(body))

    def test_rejects_unsigned_event(self):
        self.assertEqual(401, self.post(b'{}', 'invalid'))

    def test_signed_delivery_is_idempotent(self):
        body = json.dumps({'id': 42, 'company_id': 1, 'type': 'employee.created', 'payload': {'record_id': 3}}).encode()
        self.assertEqual(202, self.post(body))
        self.assertEqual(202, self.post(body))
        with sqlite3.connect(self.db) as connection:
            self.assertEqual(1, connection.execute('SELECT count(*) FROM events WHERE id=42').fetchone()[0])

    def test_rejects_invalid_schema(self):
        body = b'{"id":"bad"}'
        self.assertEqual(400, self.post(body))

if __name__ == '__main__':
    unittest.main()
