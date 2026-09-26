"""Règles métier des QR Codes : propriété, contenu, fichiers et slug."""

import secrets
import uuid
from typing import Any, Dict, List, Optional

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from ...config import Settings
from ...storage import FileStore
from ..auth.models import User
from .contents import CONTENTS, StoredFiles, file_ids
from .models import QrCode
from .repository import QrCodeRepository
from .schemas import QrCodeOut, QrType

_NOT_FOUND = "QR Code introuvable."


def new_slug() -> str:
    # 72 bits aléatoires (12 caractères) : une adresse `/q/…` ne se devine
    # pas.
    return secrets.token_urlsafe(9)


def public_url(settings: Settings, slug: str) -> str:
    return f"{settings.public_url}/q/{slug}"


class QrCodeService:
    def __init__(
        self, session: AsyncSession, settings: Settings, store: FileStore
    ) -> None:
        self._session = session
        self._settings = settings
        self._store = store
        self._qr_codes = QrCodeRepository(session)

    async def list(self, user: User) -> List[QrCodeOut]:
        return [self.to_out(qr) for qr in await self._qr_codes.list_for_user(user.id)]

    async def get(self, user: User, qr_id: uuid.UUID) -> QrCode:
        qr = await self._qr_codes.get_for_user(qr_id, user.id)
        if qr is None:
            raise HTTPException(404, _NOT_FOUND)
        return qr

    async def create(self, user: User, data: Any) -> QrCode:
        files = await self._owned_files(user, data, None)
        qr = QrCode(user_id=user.id, type=data.type.value, slug=new_slug())
        self._fill(qr, data, files)
        await self._qr_codes.add(qr)
        await self._session.commit()
        return qr

    async def update(self, user: User, qr_id: uuid.UUID, data: Any) -> QrCode:
        """Modifie le contenu en gardant le slug : un QR imprimé reste valide."""
        qr = await self.get(user, qr_id)
        if data.type.value != qr.type:
            raise HTTPException(422, "Le type d'un QR Code ne peut pas changer.")
        files = await self._owned_files(user, data, qr.id)
        previous_files = file_ids(qr)
        self._fill(qr, data, files)
        await self._session.commit()
        await self._delete_files(set(previous_files) - set(file_ids(qr)))
        return qr

    async def delete(self, user: User, qr_id: uuid.UUID) -> None:
        # Suppression réelle : le contenu (mots de passe Wi-Fi compris) et
        # les fichiers disparaissent, et l'adresse publique renvoie 404.
        qr = await self.get(user, qr_id)
        files = file_ids(qr)
        await self._qr_codes.delete(qr)
        await self._session.commit()
        await self._delete_files(files)

    async def find_public(self, slug: str) -> Optional[Dict[str, Any]]:
        """Contenu public d'un QR Code actif, ou `None` (supprimé, inconnu)."""
        qr = await self._qr_codes.get_active_by_slug(slug)
        if qr is None:
            return None
        content = CONTENTS[QrType(qr.type)].public(qr, self._settings.public_url)
        return {"type": qr.type, "title": qr.title, **content}

    def to_out(self, qr: QrCode) -> QrCodeOut:
        return QrCodeOut(
            id=qr.id,
            type=QrType(qr.type),
            slug=qr.slug,
            title=qr.title,
            is_active=qr.is_active,
            created_at=qr.created_at,
            updated_at=qr.updated_at,
            public_url=public_url(self._settings, qr.slug),
            content=CONTENTS[QrType(qr.type)].private(qr, self._settings.public_url),
        )

    def _fill(self, qr: QrCode, data: Any, files: StoredFiles) -> None:
        if data.type == QrType.WEBSITE and not self._settings.is_development:
            if not data.content.url.startswith("https://"):
                raise HTTPException(422, "L'adresse du site doit commencer par https://.")
        qr.title = data.title
        CONTENTS[data.type].apply(qr, data.content, files)

    async def _owned_files(
        self, user: User, data: Any, qr_id: Optional[uuid.UUID]
    ) -> StoredFiles:
        """Fichiers utilisés par la saisie : ils doivent appartenir au compte
        et ne servir à aucun autre QR Code (supprimer l'un effacerait le
        fichier de l'autre)."""
        files: StoredFiles = {}
        for kind, file_id in CONTENTS[data.type].files(data.content):
            stored = await run_in_threadpool(self._store.get, file_id, kind)
            if (
                stored is None
                or stored.owner_id != str(user.id)
                or await self._qr_codes.file_in_use(file_id, qr_id)
            ):
                raise HTTPException(422, "Fichier introuvable. Envoyez-le à nouveau.")
            files[file_id] = stored
        return files

    async def _delete_files(self, ids: Any) -> None:
        for file_id in ids:
            await run_in_threadpool(self._store.delete, file_id)
