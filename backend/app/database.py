"""Accès SQL partagé par les cartes de visite et les pages de réseaux.

Même SQL pour SQLite (développement, tests) et PostgreSQL (production) :
les requêtes sont écrites avec `%s`, remplacé par `?` pour SQLite.
"""

import sqlite3
from pathlib import Path
from typing import Any, Callable, Tuple

from .config import Settings


class Database:
    def __init__(self, connect: Callable[[], Any], placeholder: str) -> None:
        self._connect = connect
        self._placeholder = placeholder

    def execute(self, sql: str, params: Tuple = (), fetch: bool = False):
        sql = sql.replace("%s", self._placeholder)
        with self._connect() as db:
            cursor = db.execute(sql, params)
            return cursor.fetchall() if fetch else None


def create_database(settings: Settings) -> Database:
    if settings.database_url is None:
        path = Path(settings.data_dir)
        path.mkdir(parents=True, exist_ok=True)
        return Database(lambda: _sqlite(path / "qr_studio.sqlite3"), placeholder="?")

    import psycopg

    url = settings.database_url
    # Une connexion par opération, sans requêtes préparées (pooler de Neon).
    return Database(
        lambda: psycopg.connect(url, prepare_threshold=None), placeholder="%s"
    )


class _sqlite:
    """Connexion SQLite fermée en fin de bloc (et validée si succès)."""

    def __init__(self, path: Path) -> None:
        self._db = sqlite3.connect(path)

    def __enter__(self) -> sqlite3.Connection:
        return self._db

    def __exit__(self, exc_type, *_) -> None:
        if exc_type is None:
            self._db.commit()
        self._db.close()
