from typing import Dict

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import Settings
from ...core.database import get_session
from ...core.dependencies import get_current_active_user, get_settings
from .models import User
from .schemas import (
    AuthOut,
    FacebookIn,
    GoogleIn,
    LoginIn,
    RefreshIn,
    RegisterIn,
    TokenPairOut,
    UserOut,
)
from .service import AuthService, ClientInfo
from .social import SocialAuthProvider

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _service(
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> AuthService:
    return AuthService(session, settings)


def _client(request: Request) -> ClientInfo:
    return ClientInfo(
        user_agent=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None,
    )


def _providers(request: Request) -> Dict[str, SocialAuthProvider]:
    return request.app.state.social_providers


@router.post("/register", status_code=201, response_model=AuthOut)
async def register(
    data: RegisterIn,
    client: ClientInfo = Depends(_client),
    service: AuthService = Depends(_service),
) -> AuthOut:
    return await service.register(data, client)


@router.post("/login", response_model=AuthOut)
async def login(
    data: LoginIn,
    client: ClientInfo = Depends(_client),
    service: AuthService = Depends(_service),
) -> AuthOut:
    return await service.login(data, client)


@router.post("/social/google", response_model=AuthOut)
async def google(
    data: GoogleIn,
    client: ClientInfo = Depends(_client),
    providers: Dict[str, SocialAuthProvider] = Depends(_providers),
    service: AuthService = Depends(_service),
) -> AuthOut:
    return await service.social_login(providers["google"], data.id_token, client)


@router.post("/social/facebook", response_model=AuthOut)
async def facebook(
    data: FacebookIn,
    client: ClientInfo = Depends(_client),
    providers: Dict[str, SocialAuthProvider] = Depends(_providers),
    service: AuthService = Depends(_service),
) -> AuthOut:
    return await service.social_login(providers["facebook"], data.access_token, client)


@router.post("/social/google/link", response_model=UserOut)
async def link_google(
    data: GoogleIn,
    user: User = Depends(get_current_active_user),
    providers: Dict[str, SocialAuthProvider] = Depends(_providers),
    service: AuthService = Depends(_service),
) -> UserOut:
    return await service.link(user, providers["google"], data.id_token)


@router.post("/social/facebook/link", response_model=UserOut)
async def link_facebook(
    data: FacebookIn,
    user: User = Depends(get_current_active_user),
    providers: Dict[str, SocialAuthProvider] = Depends(_providers),
    service: AuthService = Depends(_service),
) -> UserOut:
    return await service.link(user, providers["facebook"], data.access_token)


@router.post("/refresh", response_model=TokenPairOut)
async def refresh(
    data: RefreshIn,
    client: ClientInfo = Depends(_client),
    service: AuthService = Depends(_service),
) -> TokenPairOut:
    return await service.refresh(data.refresh_token, client)


@router.post("/logout", status_code=204)
async def logout(data: RefreshIn, service: AuthService = Depends(_service)) -> Response:
    # Pas de jeton d'accès requis : il peut avoir expiré.
    await service.logout(data.refresh_token)
    return Response(status_code=204)


@router.post("/logout-all", status_code=204)
async def logout_all(
    user: User = Depends(get_current_active_user),
    service: AuthService = Depends(_service),
) -> Response:
    await service.logout_all(user)
    return Response(status_code=204)


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_active_user)) -> User:
    return user
