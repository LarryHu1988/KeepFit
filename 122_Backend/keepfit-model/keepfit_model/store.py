"""Local SQLite store: owner isolation, atomic writes and request replay."""
import hashlib
import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from threading import RLock

from .providers import ServiceError


class Store:
    def __init__(self, directory: Path):
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path = directory / "keepfit.sqlite3"
        self.lock = RLock()
        with self.transaction() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS objects (
                    owner TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL, body TEXT NOT NULL,
                    PRIMARY KEY (owner, kind, id));
                CREATE TABLE IF NOT EXISTS replays (
                    owner TEXT NOT NULL, scope TEXT NOT NULL, key TEXT NOT NULL,
                    digest TEXT NOT NULL, body TEXT NOT NULL,
                    PRIMARY KEY (owner, scope, key));
            """)
        os.chmod(self.path, 0o600)

    @contextmanager
    def transaction(self):
        with self.lock:
            db = sqlite3.connect(self.path, timeout=10)
            try:
                db.execute("BEGIN IMMEDIATE")
                yield db
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    @staticmethod
    def get(db, owner, kind, id):
        row = db.execute("SELECT body FROM objects WHERE owner=? AND kind=? AND id=?", (owner, kind, id)).fetchone()
        if row is None:
            raise ServiceError("not_found", "记录不存在。", 404)
        return json.loads(row[0])

    @staticmethod
    def put(db, owner, kind, obj):
        db.execute("INSERT OR REPLACE INTO objects VALUES (?,?,?,?)", (owner, kind, obj["id"], json.dumps(obj, ensure_ascii=False)))

    @staticmethod
    def digest(payload):
        return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()

    @classmethod
    def replay(cls, db, owner, scope, key, payload):
        row = db.execute("SELECT digest, body FROM replays WHERE owner=? AND scope=? AND key=?", (owner, scope, key)).fetchone()
        if row:
            if row[0] != cls.digest(payload):
                raise ServiceError("idempotency_conflict", "同一 Idempotency-Key 不能用于不同请求内容。", 409)
            return json.loads(row[1])
        return None

    @classmethod
    def remember(cls, db, owner, scope, key, payload, body):
        db.execute("INSERT INTO replays VALUES (?,?,?,?,?)", (owner, scope, key, cls.digest(payload), json.dumps(body, ensure_ascii=False)))
