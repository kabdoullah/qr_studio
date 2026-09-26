"""Stockage des fichiers mis en ligne.

- `LocalFileStore` : disque + SQLite, pour le développement et les tests.
- `PostgresFileStore` : fichiers et métadonnées dans PostgreSQL (Neon),
  durable, pour la production.
"""

import secrets
import shutil
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Optional, Protocol

from .config import Settings, psycopg_url

CHUNK_SIZE = 64 * 1024


@dataclass(frozen=True)
class StoredFile:
    id: str
    kind: str
    filename: str
    content_type: str
    size: int
    # Compte qui a mis le fichier en ligne ; `None` pour les fichiers
    # envoyés avant les comptes.
    owner_id: Optional[str] = None


def new_file_id() -> str:
    # 96 bits aléatoires (16 caractères) : les liens ne sont pas
    # devinables, ce qui protège les CV partagés.
    return secrets.token_urlsafe(12)


class FileStore(Protocol):
    def save(self, file: StoredFile, source: Path) -> None:
        """Enregistre le fichier écrit dans `source` (qui peut être déplacé)."""

    def get(self, file_id: str, kind: str) -> Optional[StoredFile]:
        """Métadonnées du fichier, ou `None` s'il n'existe pas."""

    def open(self, file: StoredFile) -> Iterator[bytes]:
        """Contenu du fichier, lu par morceaux."""

    def total_bytes(self) -> int:
        """Espace occupé par l'ensemble des fichiers."""

    def delete(self, file_id: str) -> None:
        """Supprime le fichier (sans erreur s'il n'existe plus)."""


_COLUMNS = "id, kind, filename, content_type, size, owner_id"


class LocalFileStore:
    def __init__(self, data_dir: Path) -> None:
        self._files_dir = data_dir / "files"
        self._files_dir.mkdir(parents=True, exist_ok=True)
        self._db_path = data_dir / "qr_studio.sqlite3"
        with self._connect() as db:
            db.execute(
                """
                CREATE TABLE IF NOT EXISTS files (
                    id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    filename TEXT NOT NULL,
                    content_type TEXT NOT NULL,
                    size INTEGER NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            # Colonne ajoutée avec les comptes (bases existantes).
            columns = [row[1] for row in db.execute("PRAGMA table_info(files)")]
            if "owner_id" not in columns:
                db.execute("ALTER TABLE files ADD COLUMN owner_id TEXT")

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self._db_path)

    def _path(self, file_id: str) -> Path:
        return self._files_dir / file_id

    def save(self, file: StoredFile, source: Path) -> None:
        shutil.move(str(source), self._path(file.id))
        with self._connect() as db:
            db.execute(
                f"INSERT INTO files ({_COLUMNS}, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    file.id,
                    file.kind,
                    file.filename,
                    file.content_type,
                    file.size,
                    file.owner_id,
                    time.time(),
                ),
            )

    def get(self, file_id: str, kind: str) -> Optional[StoredFile]:
        with self._connect() as db:
            row = db.execute(
                f"SELECT {_COLUMNS} FROM files WHERE id = ? AND kind = ?",
                (file_id, kind),
            ).fetchone()
        return StoredFile(*row) if row else None

    def open(self, file: StoredFile) -> Iterator[bytes]:
        with self._path(file.id).open("rb") as source:
            while chunk := source.read(CHUNK_SIZE):
                yield chunk

    def total_bytes(self) -> int:
        with self._connect() as db:
            return db.execute("SELECT COALESCE(SUM(size), 0) FROM files").fetchone()[0]

    def delete(self, file_id: str) -> None:
        with self._connect() as db:
            db.execute("DELETE FROM files WHERE id = ?", (file_id,))
        self._path(file_id).unlink(missing_ok=True)


class PostgresFileStore:
    """Fichiers stockés en `bytea` (10 MB maximum chacun)."""

    def __init__(self, database_url: str) -> None:
        self._database_url = psycopg_url(database_url)
        with self._connect() as db:
            db.execute(
                """
                CREATE TABLE IF NOT EXISTS files (
                    id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    filename TEXT NOT NULL,
                    content_type TEXT NOT NULL,
                    size INTEGER NOT NULL,
                    data BYTEA NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
                """
            )
            # Colonne ajoutée avec les comptes (bases existantes).
            db.execute("ALTER TABLE files ADD COLUMN IF NOT EXISTS owner_id TEXT")

    def _connect(self):
        import psycopg

        # Une connexion par opération : suffisant pour ce trafic, et
        # compatible avec le pooler de Neon (pas de requêtes préparées).
        return psycopg.connect(self._database_url, prepare_threshold=None)

    def save(self, file: StoredFile, source: Path) -> None:
        with self._connect() as db:
            db.execute(
                f"INSERT INTO files ({_COLUMNS}, data)"
                " VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (
                    file.id,
                    file.kind,
                    file.filename,
                    file.content_type,
                    file.size,
                    file.owner_id,
                    source.read_bytes(),
                ),
            )

    def get(self, file_id: str, kind: str) -> Optional[StoredFile]:
        with self._connect() as db:
            row = db.execute(
                f"SELECT {_COLUMNS} FROM files WHERE id = %s AND kind = %s",
                (file_id, kind),
            ).fetchone()
        return StoredFile(*row) if row else None

    def open(self, file: StoredFile) -> Iterator[bytes]:
        with self._connect() as db:
            row = db.execute(
                "SELECT data FROM files WHERE id = %s AND kind = %s",
                (file.id, file.kind),
            ).fetchone()
        data = memoryview(row[0]) if row else memoryview(b"")
        for start in range(0, len(data), CHUNK_SIZE):
            yield bytes(data[start : start + CHUNK_SIZE])

    def total_bytes(self) -> int:
        with self._connect() as db:
            return db.execute("SELECT COALESCE(SUM(size), 0) FROM files").fetchone()[0]

    def delete(self, file_id: str) -> None:
        with self._connect() as db:
            db.execute("DELETE FROM files WHERE id = %s", (file_id,))


def create_store(settings: Settings) -> FileStore:
    if settings.database_url is None:
        return LocalFileStore(settings.data_dir)
    return PostgresFileStore(settings.database_url)
