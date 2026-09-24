"""Stockage des fichiers mis en ligne.

- `LocalFileStore` : disque + SQLite, pour le développement et les tests.
- `R2FileStore` : Cloudflare R2, durable, pour la production. Les
  métadonnées (nom, type) sont stockées avec l'objet : aucune base de
  données n'est nécessaire.
"""

import secrets
import shutil
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator, Optional, Protocol
from urllib.parse import quote, unquote

from .config import Settings

CHUNK_SIZE = 64 * 1024


@dataclass(frozen=True)
class StoredFile:
    id: str
    kind: str
    filename: str
    content_type: str
    size: int


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

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self._db_path)

    def _path(self, file_id: str) -> Path:
        return self._files_dir / file_id

    def save(self, file: StoredFile, source: Path) -> None:
        shutil.move(str(source), self._path(file.id))
        with self._connect() as db:
            db.execute(
                "INSERT INTO files VALUES (?, ?, ?, ?, ?, ?)",
                (
                    file.id,
                    file.kind,
                    file.filename,
                    file.content_type,
                    file.size,
                    time.time(),
                ),
            )

    def get(self, file_id: str, kind: str) -> Optional[StoredFile]:
        with self._connect() as db:
            row = db.execute(
                "SELECT id, kind, filename, content_type, size FROM files"
                " WHERE id = ? AND kind = ?",
                (file_id, kind),
            ).fetchone()
        return StoredFile(*row) if row else None

    def open(self, file: StoredFile) -> Iterator[bytes]:
        with self._path(file.id).open("rb") as source:
            while chunk := source.read(CHUNK_SIZE):
                yield chunk


class R2FileStore:
    """Objets rangés sous `<kind>/<id>`, avec type et nom d'origine."""

    def __init__(self, client: Any, bucket: str) -> None:
        self._client = client
        self._bucket = bucket

    @staticmethod
    def _key(file_id: str, kind: str) -> str:
        return f"{kind}/{file_id}"

    def save(self, file: StoredFile, source: Path) -> None:
        self._client.upload_file(
            str(source),
            self._bucket,
            self._key(file.id, file.kind),
            ExtraArgs={
                "ContentType": file.content_type,
                # Les métadonnées S3 n'acceptent que l'ASCII : nom encodé.
                "Metadata": {"filename": quote(file.filename)},
            },
        )

    def get(self, file_id: str, kind: str) -> Optional[StoredFile]:
        from botocore.exceptions import ClientError

        try:
            head = self._client.head_object(
                Bucket=self._bucket, Key=self._key(file_id, kind)
            )
        except ClientError as error:
            code = error.response.get("Error", {}).get("Code")
            if code in ("404", "NoSuchKey", "NotFound"):
                return None
            raise
        return StoredFile(
            id=file_id,
            kind=kind,
            filename=unquote(head.get("Metadata", {}).get("filename", file_id)),
            content_type=head["ContentType"],
            size=head["ContentLength"],
        )

    def open(self, file: StoredFile) -> Iterator[bytes]:
        body = self._client.get_object(
            Bucket=self._bucket, Key=self._key(file.id, file.kind)
        )["Body"]
        try:
            yield from body.iter_chunks(CHUNK_SIZE)
        finally:
            body.close()


def create_store(settings: Settings) -> FileStore:
    if settings.r2 is None:
        return LocalFileStore(settings.data_dir)

    import boto3

    client = boto3.client(
        "s3",
        endpoint_url=settings.r2.endpoint_url,
        aws_access_key_id=settings.r2.access_key_id,
        aws_secret_access_key=settings.r2.secret_access_key,
        region_name="auto",
    )
    return R2FileStore(client, settings.r2.bucket)
