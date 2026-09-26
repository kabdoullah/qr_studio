"""Mots de passe (Argon2 via pwdlib), jetons d'accès (JWT) et jetons de
renouvellement (opaques)."""

import hashlib
import secrets
from datetime import timedelta
from typing import Optional, Tuple

import jwt
from pwdlib import PasswordHash

from ..config import Settings
from .database import utc_now

_hasher = PasswordHash.recommended()
# Empreinte de référence : vérifiée quand l'email est inconnu, pour que la
# durée de la réponse ne révèle pas si un compte existe.
_DUMMY_HASH = _hasher.hash("qr-studio-dummy-password")


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: Optional[str]) -> bool:
    if password_hash is None:
        _hasher.verify(password, _DUMMY_HASH)
        return False
    return _hasher.verify(password, password_hash)


def create_access_token(
    subject: str, settings: Settings, expires_in: Optional[timedelta] = None
) -> str:
    now = utc_now()
    expires_at = now + (
        expires_in or timedelta(minutes=settings.access_token_expire_minutes)
    )
    payload = {"sub": subject, "iat": now, "exp": expires_at}
    return jwt.encode(payload, settings.jwt_secret_key, settings.jwt_algorithm)


def decode_access_token(token: str, settings: Settings) -> Optional[str]:
    """Identifiant du compte, ou `None` si le jeton est invalide ou expiré."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["sub", "exp"]},
        )
    except jwt.PyJWTError:
        return None
    subject = payload.get("sub")
    return subject if isinstance(subject, str) else None


def new_refresh_token() -> Tuple[str, str]:
    """Nouveau jeton de renouvellement et son empreinte (seule conservée).

    Le jeton est aléatoire (384 bits) : un SHA-256 suffit, sans sel ni
    hachage lent, contrairement à un mot de passe.
    """
    token = secrets.token_urlsafe(48)
    return token, hash_refresh_token(token)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
