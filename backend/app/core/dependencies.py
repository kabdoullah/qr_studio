"""Dépendances FastAPI partagées : session SQL et compte connecté."""

import uuid
from typing import Optional

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import Settings
from ..modules.auth.models import User
from ..modules.auth.repository import UserRepository
from ..storage import FileStore
from .database import get_session
from .security import decode_access_token

_bearer = HTTPBearer(auto_error=False)


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_file_store(request: Request) -> FileStore:
    return request.app.state.file_store


def _unauthorized() -> HTTPException:
    return HTTPException(
        401,
        "Session expirée ou invalide. Veuillez vous reconnecter.",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> User:
    if credentials is None:
        raise _unauthorized()
    subject = decode_access_token(credentials.credentials, settings)
    try:
        user_id = uuid.UUID(subject) if subject else None
    except ValueError:
        user_id = None
    user = await UserRepository(session).get(user_id) if user_id else None
    if user is None:
        raise _unauthorized()
    return user


async def get_current_active_user(user: User = Depends(get_current_user)) -> User:
    if not user.is_active:
        raise HTTPException(403, "Ce compte est désactivé.")
    return user
