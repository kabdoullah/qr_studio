import re
import uuid
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, Path, Response
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import Settings
from ...core.database import get_session
from ...core.dependencies import get_current_active_user, get_file_store, get_settings
from ...storage import FileStore
from ..auth.models import User
from .public_page import not_found_html, public_html
from .schemas import QrCodeIn, QrCodeList, QrCodeOut
from .service import QrCodeService

_SLUG = r"^[A-Za-z0-9_-]{12}$"

router = APIRouter(prefix="/api/v1/qr-codes", tags=["qr-codes"])
public_router = APIRouter(tags=["public"])


def _service(
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
    store: FileStore = Depends(get_file_store),
) -> QrCodeService:
    return QrCodeService(session, settings, store)


@router.get("", response_model=QrCodeList)
async def list_qr_codes(
    user: User = Depends(get_current_active_user),
    service: QrCodeService = Depends(_service),
) -> Dict[str, Any]:
    return {"items": await service.list(user)}


@router.post("", status_code=201, response_model=QrCodeOut)
async def create_qr_code(
    data: QrCodeIn,
    user: User = Depends(get_current_active_user),
    service: QrCodeService = Depends(_service),
) -> QrCodeOut:
    return service.to_out(await service.create(user, data))


@router.get("/{qr_id}", response_model=QrCodeOut)
async def get_qr_code(
    qr_id: uuid.UUID,
    user: User = Depends(get_current_active_user),
    service: QrCodeService = Depends(_service),
) -> QrCodeOut:
    return service.to_out(await service.get(user, qr_id))


@router.put("/{qr_id}", response_model=QrCodeOut)
async def update_qr_code(
    qr_id: uuid.UUID,
    data: QrCodeIn,
    user: User = Depends(get_current_active_user),
    service: QrCodeService = Depends(_service),
) -> QrCodeOut:
    return service.to_out(await service.update(user, qr_id, data))


@router.delete("/{qr_id}", status_code=204)
async def delete_qr_code(
    qr_id: uuid.UUID,
    user: User = Depends(get_current_active_user),
    service: QrCodeService = Depends(_service),
) -> Response:
    await service.delete(user, qr_id)
    return Response(status_code=204)


# --- Accès public, sans compte : ce que voit la personne qui scanne ---


@public_router.get("/api/v1/public/q/{slug}")
async def get_public_qr_code(
    slug: str = Path(pattern=_SLUG), service: QrCodeService = Depends(_service)
) -> Dict[str, Any]:
    content = await service.find_public(slug)
    if content is None:
        raise HTTPException(404, "QR Code introuvable.")
    return content


@public_router.get("/q/{slug}", response_class=HTMLResponse)
async def show_public_qr_code(
    slug: str, service: QrCodeService = Depends(_service)
) -> HTMLResponse:
    content = await service.find_public(slug) if re.match(_SLUG, slug) else None
    return not_found_html() if content is None else public_html(content)
