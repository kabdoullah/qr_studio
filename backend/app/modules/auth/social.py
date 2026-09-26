"""Vérification des identités Google et Facebook côté serveur.

Chaque fournisseur vérifie un credential fourni par l'application et en
extrait un `SocialUser`. Seul ce qui provient du credential vérifié est
utilisé : jamais un identifiant ou un email envoyé seul par le client.
"""

import hashlib
import hmac
from dataclasses import dataclass
from typing import Any, Callable, Dict, Optional, Protocol, Sequence

import httpx
import jwt
from starlette.concurrency import run_in_threadpool

from ...config import Settings


@dataclass(frozen=True)
class SocialUser:
    provider: str
    provider_user_id: str
    email: Optional[str]
    email_verified: bool
    first_name: str
    last_name: str
    avatar_url: Optional[str]


class SocialAuthError(Exception):
    """Credential refusé (invalide, expiré, destiné à une autre application)."""


class SocialAuthUnavailable(Exception):
    """Fournisseur non configuré ou injoignable."""


class SocialAuthProvider(Protocol):
    name: str

    async def verify(self, credential: str) -> SocialUser: ...


def _clip(value: Any, length: int) -> str:
    return value.strip()[:length] if isinstance(value, str) else ""


def _email(value: Any) -> Optional[str]:
    email = value.strip().lower() if isinstance(value, str) else ""
    return email if email and len(email) <= 254 and "@" in email else None


def _url(value: Any) -> Optional[str]:
    return value if isinstance(value, str) and value.startswith("https://") and len(value) <= 500 else None


class GoogleAuthProvider:
    """ID token Google (JWT RS256) : signature par les clés publiques de
    Google, émetteur, audience (nos identifiants client) et expiration."""

    name = "google"
    CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
    ISSUERS = ("accounts.google.com", "https://accounts.google.com")

    def __init__(
        self,
        client_ids: Sequence[str],
        signing_key: Optional[Callable[[str], Any]] = None,
    ) -> None:
        self._client_ids = list(client_ids)
        if signing_key is None:
            # Clés mises en cache ; rechargées quand Google en change.
            jwks = jwt.PyJWKClient(self.CERTS_URL, cache_keys=True, timeout=10)
            signing_key = lambda token: jwks.get_signing_key_from_jwt(token).key  # noqa: E731
        self._signing_key = signing_key

    async def verify(self, credential: str) -> SocialUser:
        if not self._client_ids:
            raise SocialAuthUnavailable()
        try:
            # Téléchargement éventuel des clés : hors de la boucle async.
            key = await run_in_threadpool(self._signing_key, credential)
            claims = jwt.decode(
                credential,
                key,
                algorithms=["RS256"],
                audience=self._client_ids,
                issuer=self.ISSUERS,
                options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            )
        except jwt.PyJWKClientConnectionError as error:
            raise SocialAuthUnavailable() from error
        except jwt.PyJWTError as error:
            raise SocialAuthError() from error
        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject:
            raise SocialAuthError()
        verified = claims.get("email_verified")
        return SocialUser(
            provider=self.name,
            provider_user_id=subject,
            email=_email(claims.get("email")),
            email_verified=verified is True or verified == "true",
            first_name=_clip(claims.get("given_name"), 100),
            last_name=_clip(claims.get("family_name"), 100),
            avatar_url=_url(claims.get("picture")),
        )


class FacebookAuthProvider:
    """Jeton d'accès Facebook : `debug_token` (validité, application) puis
    `/me` avec `appsecret_proof`."""

    name = "facebook"
    GRAPH_URL = "https://graph.facebook.com/v21.0"

    def __init__(
        self,
        app_id: Optional[str],
        app_secret: Optional[str],
        transport: Optional[httpx.AsyncBaseTransport] = None,
    ) -> None:
        self._app_id = app_id
        self._app_secret = app_secret
        self._transport = transport

    async def verify(self, credential: str) -> SocialUser:
        if not self._app_id or not self._app_secret:
            raise SocialAuthUnavailable()
        try:
            async with httpx.AsyncClient(
                base_url=self.GRAPH_URL, transport=self._transport, timeout=10
            ) as client:
                debug = await client.get(
                    "/debug_token",
                    params={"input_token": credential},
                    headers={"Authorization": f"OAuth {self._app_id}|{self._app_secret}"},
                )
                data = self._json(debug).get("data")
                if not (
                    isinstance(data, dict)
                    and data.get("is_valid") is True
                    and str(data.get("app_id")) == self._app_id
                    and data.get("user_id")
                ):
                    raise SocialAuthError()
                proof = hmac.new(
                    self._app_secret.encode(), credential.encode(), hashlib.sha256
                ).hexdigest()
                me = self._json(
                    await client.get(
                        "/me",
                        params={
                            "fields": "id,first_name,last_name,email,picture.type(large)",
                            "appsecret_proof": proof,
                        },
                        headers={"Authorization": f"Bearer {credential}"},
                    )
                )
        except httpx.HTTPError as error:
            raise SocialAuthUnavailable() from error
        if str(me.get("id")) != str(data["user_id"]):
            raise SocialAuthError()
        picture = me.get("picture")
        picture_data = picture.get("data") if isinstance(picture, dict) else None
        return SocialUser(
            provider=self.name,
            provider_user_id=str(me["id"]),
            # Facebook ne fournit pas toujours d'email (compte créé avec un
            # numéro de téléphone, permission refusée).
            email=_email(me.get("email")),
            # Pas de garantie documentée : l'email n'est jamais considéré
            # comme vérifié, donc jamais utilisé pour lier des comptes.
            email_verified=False,
            first_name=_clip(me.get("first_name"), 100),
            last_name=_clip(me.get("last_name"), 100),
            avatar_url=_url(
                picture_data.get("url")
                if isinstance(picture_data, dict) and not picture_data.get("is_silhouette")
                else None
            ),
        )

    @staticmethod
    def _json(response: httpx.Response) -> Dict[str, Any]:
        # 4xx : jeton refusé par Facebook ; 5xx : service indisponible.
        if response.status_code >= 500:
            raise SocialAuthUnavailable()
        try:
            body = response.json()
        except ValueError:
            raise SocialAuthUnavailable() from None
        if response.status_code >= 400 or not isinstance(body, dict):
            raise SocialAuthError()
        return body


def create_providers(settings: Settings) -> Dict[str, SocialAuthProvider]:
    return {
        "google": GoogleAuthProvider(settings.google_client_ids),
        "facebook": FacebookAuthProvider(
            settings.facebook_app_id, settings.facebook_app_secret
        ),
    }
