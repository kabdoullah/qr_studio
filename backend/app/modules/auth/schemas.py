import re
import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_email(value: Any) -> Any:
    if not isinstance(value, str):
        return value
    email = value.strip().lower()
    if len(email) > 254 or not _EMAIL.match(email):
        raise ValueError("Adresse email invalide.")
    return email


def _strip(value: Any) -> Any:
    return value.strip() if isinstance(value, str) else value


class RegisterIn(BaseModel):
    email: str
    # Borne haute : le hachage d'un texte énorme coûterait cher.
    password: str = Field(min_length=8, max_length=128)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)

    _email = field_validator("email", mode="before")(normalize_email)
    _names = field_validator("first_name", "last_name", mode="before")(_strip)


class LoginIn(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(min_length=1, max_length=128)

    # Pas de validation de format : un email mal saisi reçoit la même
    # réponse qu'un mauvais mot de passe.
    _email = field_validator("email", mode="before")(
        lambda v: v.strip().lower() if isinstance(v, str) else v
    )


class RefreshIn(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=200)


class GoogleIn(BaseModel):
    id_token: str = Field(min_length=1, max_length=4096)


class FacebookIn(BaseModel):
    access_token: str = Field(min_length=1, max_length=4096)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: Optional[str]
    first_name: str
    last_name: str
    avatar_url: Optional[str]
    email_verified: bool
    is_active: bool
    created_at: datetime


class TokenPairOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthOut(TokenPairOut):
    user: UserOut
