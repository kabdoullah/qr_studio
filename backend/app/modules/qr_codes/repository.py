import uuid
from typing import List, Optional

from sqlalchemy import exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import BusinessCardProfile, CvDocument, QrCode


class QrCodeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_for_user(self, user_id: uuid.UUID) -> List[QrCode]:
        result = await self._session.execute(
            select(QrCode)
            .where(QrCode.user_id == user_id)
            .order_by(QrCode.created_at.desc())
        )
        return list(result.scalars())

    async def get_for_user(
        self, qr_id: uuid.UUID, user_id: uuid.UUID
    ) -> Optional[QrCode]:
        # Le propriétaire fait partie de la requête : le QR Code d'un autre
        # compte est introuvable, comme un QR Code inexistant.
        result = await self._session.execute(
            select(QrCode).where(QrCode.id == qr_id, QrCode.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_active_by_slug(self, slug: str) -> Optional[QrCode]:
        result = await self._session.execute(
            select(QrCode).where(QrCode.slug == slug, QrCode.is_active.is_(True))
        )
        return result.scalar_one_or_none()

    async def add(self, qr: QrCode) -> None:
        self._session.add(qr)
        await self._session.flush()

    async def delete(self, qr: QrCode) -> None:
        await self._session.delete(qr)

    async def file_in_use(
        self, file_id: str, except_qr_id: Optional[uuid.UUID]
    ) -> bool:
        """Le fichier est-il déjà utilisé par un autre QR Code ?"""
        uses = or_(
            exists().where(
                CvDocument.file_id == file_id, CvDocument.qr_code_id != except_qr_id
            ),
            exists().where(
                BusinessCardProfile.file_id == file_id,
                BusinessCardProfile.qr_code_id != except_qr_id,
            ),
        )
        return bool(await self._session.scalar(select(uses)))
