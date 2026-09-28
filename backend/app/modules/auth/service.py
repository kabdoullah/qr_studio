import uuid
from dataclasses import dataclass
from datetime import timedelta
from typing import Optional

from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import Settings
from ...core.database import utc_now
from ...core.security import (
    create_access_token,
    hash_installation_id,
    hash_password,
    hash_refresh_token,
    new_refresh_token,
    verify_password,
)
from .models import AuthIdentity, RefreshToken, User
from .repository import IdentityRepository, RefreshTokenRepository, UserRepository
from .schemas import AuthOut, LoginIn, RegisterIn, TokenPairOut, UserOut
from .social import SocialAuthError, SocialAuthProvider, SocialAuthUnavailable, SocialUser

_EMAIL_TAKEN = "Un compte existe déjà avec cette adresse email."
# Email déjà utilisé par un autre compte, sans preuve suffisante pour lier.
_LINK_REQUIRED = (
    "Un compte existe déjà avec cette adresse. Connectez-vous avec votre "
    "méthode habituelle puis liez {provider} depuis votre compte."
)
_IDENTITY_TAKEN = "Ce compte {provider} est déjà lié à un autre compte QR Studio."
_INVALID_REFRESH = "Session expirée ou invalide. Veuillez vous reconnecter."
_DISABLED = "Ce compte est désactivé."
_RETRY = "Une erreur est survenue. Veuillez réessayer."
_ANONYMOUS_LINK = (
    "Créez d'abord votre compte : choisissez « Continuer avec {provider} »."
)
_PROVIDER_NAMES = {"google": "Google", "facebook": "Facebook"}


@dataclass(frozen=True)
class ClientInfo:
    """Appareil à l'origine d'une connexion (informatif)."""

    user_agent: Optional[str] = None
    ip_address: Optional[str] = None


class AuthService:
    def __init__(self, session: AsyncSession, settings: Settings) -> None:
        self._session = session
        self._settings = settings
        self._users = UserRepository(session)
        self._identities = IdentityRepository(session)
        self._tokens = RefreshTokenRepository(session)

    # --- Utilisateur anonyme ---

    async def anonymous(self, installation_id: uuid.UUID, client: ClientInfo) -> AuthOut:
        """Session de l'utilisateur anonyme de cette installation, créé au
        premier appel. Idempotent : la même installation retrouve toujours
        le même compte, tant qu'il n'a pas été converti.

        L'identifiant d'installation sert uniquement à ouvrir la session ;
        les requêtes sont ensuite authentifiées par les jetons, comme pour
        un compte enregistré.
        """
        installation_hash = hash_installation_id(installation_id)
        user = await self._users.get_by_installation(installation_hash)
        if user is None:
            try:
                user = await self._users.add(
                    User(is_anonymous=True, installation_hash=installation_hash)
                )
            except IntegrityError:
                # Premier lancement envoyé deux fois en même temps : le
                # compte créé par l'autre requête est réutilisé.
                await self._session.rollback()
                user = await self._users.get_by_installation(installation_hash)
                if user is None:
                    raise HTTPException(409, _RETRY) from None
        if not user.is_active:
            raise HTTPException(403, _DISABLED)
        return await self._open_session(user, client)

    # --- Email et mot de passe ---

    async def register(
        self, data: RegisterIn, client: ClientInfo, current: Optional[User] = None
    ) -> AuthOut:
        """Crée un compte, ou convertit l'utilisateur anonyme de la session
        (`current`) : même `id`, ses QR Codes et fichiers restent à lui."""
        if await self._users.get_by_email(data.email) is not None:
            raise HTTPException(409, _EMAIL_TAKEN)
        # Argon2 est volontairement lent : hors de la boucle async.
        password_hash = await run_in_threadpool(hash_password, data.password)
        anonymous = _anonymous(current)
        user = anonymous or User()
        user.email = data.email
        user.password_hash = password_hash
        user.first_name = data.first_name
        user.last_name = data.last_name
        try:
            if anonymous is None:
                await self._users.add(user)
            else:
                await self._claim(user)
            auth = await self._open_session(user, client)
        except IntegrityError:
            # Inscription simultanée avec le même email.
            await self._session.rollback()
            raise HTTPException(409, _EMAIL_TAKEN) from None
        return auth

    async def login(self, data: LoginIn, client: ClientInfo) -> AuthOut:
        user = await self._users.get_by_email(data.email)
        # Un compte sans mot de passe (Google, Facebook) passe aussi par la
        # vérification factice : même durée de réponse.
        valid = await run_in_threadpool(
            verify_password, data.password, user.password_hash if user else None
        )
        if user is None or not valid:
            raise HTTPException(401, "Email ou mot de passe incorrect.")
        if not user.is_active:
            raise HTTPException(403, _DISABLED)
        return await self._open_session(user, client)

    # --- Google, Facebook ---

    async def social_login(
        self,
        provider: SocialAuthProvider,
        credential: str,
        client: ClientInfo,
        current: Optional[User] = None,
    ) -> AuthOut:
        """Connexion Google/Facebook.

        Compte externe déjà connu (ou email vérifié d'un compte existant) :
        connexion à ce compte, sans fusion avec l'utilisateur anonyme de la
        session, dont les QR Codes restent attachés à l'installation.
        Sinon, l'utilisateur anonyme (`current`) devient ce compte (même
        `id`) ; sans session anonyme, un compte est créé.
        """
        social = await self._verify(provider, credential)
        identity = await self._identities.get(social.provider, social.provider_user_id)
        if identity is not None:
            user = await self._users.get(identity.user_id)
            assert user is not None  # Suppression en cascade.
            if not user.is_active:
                raise HTTPException(403, _DISABLED)
            return await self._open_session(user, client)

        user = await self._users.get_by_email(social.email) if social.email else None
        if user is not None:
            # Liaison automatique seulement si les deux côtés prouvent la
            # possession de l'adresse ; sinon l'utilisateur doit se
            # connecter puis lier le compte (`link`).
            if not (social.email_verified and user.email_verified):
                raise HTTPException(
                    409, _LINK_REQUIRED.format(provider=_PROVIDER_NAMES[social.provider])
                )
            if not user.is_active:
                raise HTTPException(403, _DISABLED)
        else:
            anonymous = _anonymous(current)
            user = anonymous or User()
            user.email = social.email
            user.first_name = social.first_name
            user.last_name = social.last_name
            user.avatar_url = social.avatar_url
            user.email_verified = social.email is not None and social.email_verified
            if anonymous is None:
                await self._users.add(user)
            else:
                await self._claim(user)
        try:
            await self._add_identity(user, social)
            return await self._open_session(user, client)
        except IntegrityError:
            # Même compte externe connecté deux fois en même temps, ou email
            # pris entre-temps : l'utilisateur peut simplement réessayer.
            await self._session.rollback()
            raise HTTPException(409, _EMAIL_TAKEN) from None

    async def link(
        self, user: User, provider: SocialAuthProvider, credential: str
    ) -> UserOut:
        """Rattache un compte Google/Facebook au compte connecté."""
        if user.is_anonymous:
            # La conversion passe par `social_login`, qui complète le profil.
            raise HTTPException(
                400, _ANONYMOUS_LINK.format(provider=_PROVIDER_NAMES[provider.name])
            )
        social = await self._verify(provider, credential)
        identity = await self._identities.get(social.provider, social.provider_user_id)
        if identity is not None and identity.user_id != user.id:
            raise HTTPException(
                409, _IDENTITY_TAKEN.format(provider=_PROVIDER_NAMES[social.provider])
            )
        if identity is None:
            try:
                await self._add_identity(user, social)
                await self._session.commit()
            except IntegrityError:
                await self._session.rollback()
                raise HTTPException(
                    409, _IDENTITY_TAKEN.format(provider=_PROVIDER_NAMES[social.provider])
                ) from None
        return UserOut.model_validate(user)

    async def _verify(self, provider: SocialAuthProvider, credential: str) -> SocialUser:
        name = _PROVIDER_NAMES[provider.name]
        try:
            return await provider.verify(credential)
        except SocialAuthUnavailable:
            raise HTTPException(
                503, f"La connexion avec {name} est indisponible pour le moment."
            ) from None
        except SocialAuthError:
            # 400 et non 401 : la requête peut porter la session d'un
            # utilisateur anonyme, et un 401 signifierait que cette session
            # est invalide (l'application la terminerait).
            raise HTTPException(
                400, f"La connexion avec {name} a échoué. Veuillez réessayer."
            ) from None

    async def _claim(self, user: User) -> None:
        """Convertit l'utilisateur anonyme en compte enregistré (même `id`).

        L'installation ne donne plus accès au compte, et ses sessions
        anonymes sont terminées : la conversion en ouvre une nouvelle.
        """
        user.is_anonymous = False
        user.installation_hash = None
        await self._tokens.revoke_all(user.id, utc_now())

    async def _add_identity(self, user: User, social: SocialUser) -> None:
        await self._identities.add(
            AuthIdentity(
                user_id=user.id,
                provider=social.provider,
                provider_user_id=social.provider_user_id,
            )
        )

    # --- Jetons ---

    async def refresh(self, refresh_token: str, client: ClientInfo) -> TokenPairOut:
        """Rotation : le jeton présenté est révoqué et remplacé.

        Un jeton déjà révoqué qui revient signale un vol probable (il a été
        copié avant d'être remplacé) : toute la session est révoquée.
        """
        now = utc_now()
        current = await self._tokens.get_by_hash(hash_refresh_token(refresh_token))
        if current is None or current.expires_at <= now:
            raise HTTPException(401, _INVALID_REFRESH)
        if current.revoked_at is not None:
            await self._revoke_session(current.session_id)
            raise HTTPException(401, _INVALID_REFRESH)
        user = await self._users.get(current.user_id)
        if user is None or not user.is_active:
            await self._revoke_session(current.session_id)
            raise HTTPException(403 if user else 401, _DISABLED if user else _INVALID_REFRESH)

        token, row = self._new_refresh_token(user, current.session_id, client)
        await self._tokens.add(row)
        if not await self._tokens.revoke(current.id, now, replaced_by=row.id):
            # Renouvellement concurrent avec le même jeton : même traitement
            # qu'une réutilisation.
            await self._session.rollback()
            await self._revoke_session(current.session_id)
            raise HTTPException(401, _INVALID_REFRESH)
        await self._session.commit()
        return TokenPairOut(
            access_token=create_access_token(str(user.id), self._settings),
            refresh_token=token,
        )

    async def logout(self, refresh_token: str) -> None:
        """Termine la session (l'appareil) du jeton ; inconnu : sans effet."""
        current = await self._tokens.get_by_hash(hash_refresh_token(refresh_token))
        if current is not None:
            await self._revoke_session(current.session_id)

    async def logout_all(self, user: User) -> None:
        await self._tokens.revoke_all(user.id, utc_now())
        await self._session.commit()

    async def _revoke_session(self, session_id: uuid.UUID) -> None:
        await self._tokens.revoke_session(session_id, utc_now())
        await self._session.commit()

    async def _open_session(self, user: User, client: ClientInfo) -> AuthOut:
        """Nouvelle session (appareil) : jeton d'accès et de renouvellement."""
        await self._tokens.delete_expired(user.id, utc_now())
        token, row = self._new_refresh_token(user, uuid.uuid4(), client)
        await self._tokens.add(row)
        await self._session.commit()
        return AuthOut(
            user=UserOut.model_validate(user),
            access_token=create_access_token(str(user.id), self._settings),
            refresh_token=token,
        )

    def _new_refresh_token(
        self, user: User, session_id: uuid.UUID, client: ClientInfo
    ) -> "tuple[str, RefreshToken]":
        token, token_hash = new_refresh_token()
        row = RefreshToken(
            id=uuid.uuid4(),
            user_id=user.id,
            session_id=session_id,
            token_hash=token_hash,
            expires_at=utc_now() + timedelta(days=self._settings.refresh_token_expire_days),
            user_agent=(client.user_agent or None) and client.user_agent[:255],
            ip_address=(client.ip_address or None) and client.ip_address[:45],
        )
        return token, row


def _anonymous(current: Optional[User]) -> Optional[User]:
    """Utilisateur anonyme de la session à convertir, sinon `None` (sans
    session, ou session d'un compte déjà enregistré)."""
    if current is None or not current.is_anonymous:
        return None
    if not current.is_active:
        raise HTTPException(403, _DISABLED)
    return current
