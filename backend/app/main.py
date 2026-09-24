"""API de QR Studio : mise en ligne des CV et des images de carte de visite.

Le QR Code généré par l'application contient l'URL renvoyée ici ; la
personne qui le scanne ouvre directement le fichier dans son navigateur.
"""

import os
import re
import tempfile
import unicodedata
from pathlib import Path as FilePath
from typing import Callable, Dict, Optional
from urllib.parse import quote

from fastapi import FastAPI, HTTPException, Path, Request, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel

from .cards import CardStore, create_card_store, create_cards_router
from .config import Settings
from .rate_limit import UploadRateLimiter
from .storage import CHUNK_SIZE, FileStore, StoredFile, create_store, new_file_id
# Marge pour l'enveloppe multipart (en-têtes, séparateurs).
_MULTIPART_OVERHEAD = 64 * 1024
_ID_PATTERN = r"^[A-Za-z0-9_-]{16}$"


def _sniff_pdf(head: bytes) -> Optional[str]:
    return "application/pdf" if head.startswith(b"%PDF-") else None


def _sniff_image(head: bytes) -> Optional[str]:
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    return None


# Types de fichiers acceptés : le contenu réel est vérifié (signature),
# jamais l'extension ni le type annoncé par le client.
_KINDS: Dict[str, Callable[[bytes], Optional[str]]] = {
    "cv": _sniff_pdf,
    "card": _sniff_image,
}
_WRONG_FORMAT = {
    "cv": "Le fichier doit être un PDF.",
    "card": "L'image doit être au format JPEG, PNG ou WebP.",
}


class UploadResponse(BaseModel):
    id: str
    url: str


def _safe_filename(name: Optional[str], fallback: str) -> str:
    """Nom d'origine nettoyé, utilisé seulement pour l'affichage."""
    name = unicodedata.normalize("NFC", (name or "").split("/")[-1])
    name = re.sub(r"[\x00-\x1f\x7f\\]", "", name).strip()[:200]
    return name or fallback


def create_app(
    settings: Optional[Settings] = None,
    store: Optional[FileStore] = None,
    card_store: Optional[CardStore] = None,
) -> FastAPI:
    settings = settings or Settings.from_env()
    store = store or create_store(settings)
    card_store = card_store or create_card_store(settings)
    limiter = UploadRateLimiter(
        per_client=settings.uploads_per_client_per_hour,
        total=settings.uploads_per_hour,
    )
    app = FastAPI(title="QR Studio API", version="1.0.0")

    @app.middleware("http")
    async def limit_upload_size(request: Request, call_next):
        # Refuse les envois trop volumineux avant de lire le corps, pour ne
        # pas remplir le disque avec des fichiers qui seront rejetés.
        if request.method == "POST":
            length = request.headers.get("content-length")
            if length is None or not length.isdigit():
                return JSONResponse(
                    {"detail": "En-tête Content-Length requis."}, status_code=411
                )
            if int(length) > settings.max_file_bytes + _MULTIPART_OVERHEAD:
                return _too_large(settings)
            # Adresse fournie par le proxy de l'hébergeur. Elle peut être
            # falsifiée : la limite globale reste la vraie protection.
            client = request.client.host if request.client else "inconnu"
            if not limiter.allow(client):
                return JSONResponse(
                    {"detail": "Trop d'envois. Réessayez plus tard."},
                    status_code=429,
                )
        return await call_next(request)

    async def _store_upload(upload: UploadFile, kind: str) -> UploadResponse:
        file_id = new_file_id()
        # Fichier temporaire hors du stockage : un envoi refusé ne laisse
        # aucune trace.
        handle, temp_name = tempfile.mkstemp(prefix="qr_studio_")
        temp_path = FilePath(temp_name)
        size = 0
        content_type: Optional[str] = None
        try:
            with os.fdopen(handle, "wb") as out:
                while chunk := await upload.read(CHUNK_SIZE):
                    if content_type is None:
                        content_type = _KINDS[kind](chunk)
                        if content_type is None:
                            raise HTTPException(415, _WRONG_FORMAT[kind])
                    size += len(chunk)
                    if size > settings.max_file_bytes:
                        raise HTTPException(413, _too_large_message(settings))
                    out.write(chunk)
            if content_type is None:
                raise HTTPException(400, "Le fichier est vide.")
            if store.total_bytes() + size > settings.max_storage_bytes:
                raise HTTPException(
                    507, "L'espace de stockage est plein. Réessayez plus tard."
                )
            store.save(
                StoredFile(
                    id=file_id,
                    kind=kind,
                    filename=_safe_filename(upload.filename, f"{kind}-{file_id}"),
                    content_type=content_type,
                    size=size,
                ),
                temp_path,
            )
        finally:
            temp_path.unlink(missing_ok=True)
            await upload.close()
        return UploadResponse(id=file_id, url=f"{settings.public_url}/{kind}/{file_id}")

    def _serve(file_id: str, kind: str) -> StreamingResponse:
        stored = store.get(file_id, kind)
        if stored is None:
            raise HTTPException(404, "Fichier introuvable.")
        return StreamingResponse(
            store.open(stored),
            media_type=stored.content_type,
            headers={
                "Content-Length": str(stored.size),
                "Content-Disposition": (
                    f"inline; filename*=utf-8''{quote(stored.filename)}"
                ),
                "X-Content-Type-Options": "nosniff",
                # Les fichiers ne changent jamais une fois mis en ligne.
                "Cache-Control": "public, max-age=86400, immutable",
            },
        )

    app.include_router(create_cards_router(card_store))

    @app.get("/health")
    def health() -> Dict[str, str]:
        return {"status": "ok"}

    @app.post("/api/v1/cvs", status_code=201, response_model=UploadResponse)
    async def upload_cv(file: UploadFile) -> UploadResponse:
        return await _store_upload(file, "cv")

    @app.post("/api/v1/cards", status_code=201, response_model=UploadResponse)
    async def upload_card(file: UploadFile) -> UploadResponse:
        return await _store_upload(file, "card")

    @app.get("/cv/{file_id}")
    def get_cv(file_id: str = Path(pattern=_ID_PATTERN)) -> StreamingResponse:
        return _serve(file_id, "cv")

    @app.get("/card/{file_id}")
    def get_card(file_id: str = Path(pattern=_ID_PATTERN)) -> StreamingResponse:
        return _serve(file_id, "card")

    return app


def _too_large_message(settings: Settings) -> str:
    return (
        "Le fichier est trop volumineux "
        f"(maximum {settings.max_file_bytes // (1024 * 1024)} MB)."
    )


def _too_large(settings: Settings) -> JSONResponse:
    return JSONResponse({"detail": _too_large_message(settings)}, status_code=413)

