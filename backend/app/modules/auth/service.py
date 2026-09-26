from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import Settings
from ...core.security import create_access_token, hash_password, verify_password
from .models import User
from .repository import UserRepository
from .schemas import LoginIn, RegisterIn

_EMAIL_TAKEN = "Un compte existe déjà avec cette adresse email."


class AuthService:
    def __init__(self, session: AsyncSession, settings: Settings) -> None:
        self._session = session
        self._settings = settings
        self._users = UserRepository(session)

    async def register(self, data: RegisterIn) -> User:
        if await self._users.get_by_email(data.email) is not None:
            raise HTTPException(409, _EMAIL_TAKEN)
        user = User(
            email=data.email,
            # Argon2 est volontairement lent : hors de la boucle async.
            password_hash=await run_in_threadpool(hash_password, data.password),
            first_name=data.first_name,
            last_name=data.last_name,
        )
        try:
            await self._users.add(user)
            await self._session.commit()
        except IntegrityError:
            # Inscription simultanée avec le même email.
            await self._session.rollback()
            raise HTTPException(409, _EMAIL_TAKEN) from None
        return user

    async def login(self, data: LoginIn) -> str:
        user = await self._users.get_by_email(data.email)
        valid = await run_in_threadpool(
            verify_password, data.password, user.password_hash if user else None
        )
        if user is None or not valid:
            raise HTTPException(401, "Email ou mot de passe incorrect.")
        if not user.is_active:
            raise HTTPException(403, "Ce compte est désactivé.")
        return create_access_token(str(user.id), self._settings)
