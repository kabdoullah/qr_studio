from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import Settings
from ...core.database import get_session
from ...core.dependencies import get_current_active_user, get_settings
from .models import User
from .schemas import LoginIn, RegisterIn, TokenOut, UserOut
from .service import AuthService

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _service(
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> AuthService:
    return AuthService(session, settings)


@router.post("/register", status_code=201, response_model=UserOut)
async def register(data: RegisterIn, service: AuthService = Depends(_service)) -> User:
    return await service.register(data)


@router.post("/login", response_model=TokenOut)
async def login(data: LoginIn, service: AuthService = Depends(_service)) -> TokenOut:
    return TokenOut(access_token=await service.login(data))


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_active_user)) -> User:
    return user
