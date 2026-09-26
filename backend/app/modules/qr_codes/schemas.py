"""Données échangées avec l'application, validées côté serveur."""

import uuid
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, Field, field_validator, model_validator
from typing_extensions import Annotated

from ...cards import BusinessCardIn as BusinessCardDetails
from ...social_networks import NETWORKS, PROFILE_PLATFORMS, check_url

_FILE_ID = r"^[A-Za-z0-9_-]{16}$"


class QrType(str, Enum):
    BUSINESS_CARD = "business_card"
    CV = "cv"
    TEXT = "text"
    SOCIAL_MEDIA = "social_media"
    WEBSITE = "website"
    WIFI = "wifi"


def _strip(value: Any) -> Any:
    return value.strip() if isinstance(value, str) else value


# --- Contenu de chaque type ---


class TextIn(BaseModel):
    # Le texte est conservé tel quel (espaces et retours à la ligne compris).
    text: str = Field(min_length=1, max_length=1000)

    @field_validator("text")
    @classmethod
    def _not_blank(cls, text: str) -> str:
        if not text.strip():
            raise ValueError("Le texte est vide.")
        return text


class WebsiteIn(BaseModel):
    url: str = Field(min_length=1, max_length=500)

    _strip_url = field_validator("url", mode="before")(_strip)

    # http est vérifié par le service : accepté en développement seulement.
    @field_validator("url")
    @classmethod
    def _check(cls, url: str) -> str:
        return check_url(url, allow_http=True)


WifiSecurity = Literal["none", "WEP", "WPA", "WPA2", "WPA3"]


class WifiIn(BaseModel):
    ssid: str = Field(min_length=1, max_length=32)
    security: WifiSecurity = "WPA2"
    password: str = Field("", max_length=63)
    hidden: bool = False

    @model_validator(mode="after")
    def _check_password(self) -> "WifiIn":
        if self.security == "none":
            # Un réseau ouvert n'a pas de mot de passe : rien n'est conservé.
            self.password = ""
        elif self.security == "WEP" and not self.password:
            raise ValueError("Mot de passe requis pour un réseau WEP.")
        elif self.security != "WEP" and len(self.password) < 8:
            raise ValueError("Le mot de passe WPA doit contenir 8 à 63 caractères.")
        return self


class CvIn(BaseModel):
    # Fichier mis en ligne par `POST /api/v1/cvs`.
    file_id: str = Field(pattern=_FILE_ID)


class BusinessCardIn(BaseModel):
    mode: Literal["details", "image"] = "details"
    details: Optional[BusinessCardDetails] = None
    # Image mise en ligne par `POST /api/v1/cards` (mode `image`).
    file_id: Optional[str] = Field(None, pattern=_FILE_ID)

    @model_validator(mode="after")
    def _check_mode(self) -> "BusinessCardIn":
        if self.mode == "details" and self.details is None:
            raise ValueError("Coordonnées requises.")
        if self.mode == "image" and self.file_id is None:
            raise ValueError("Image de la carte requise.")
        return self


class SocialLinkIn(BaseModel):
    platform: str
    url: str = Field(min_length=1, max_length=500)
    label: str = Field("", max_length=50)
    is_visible: bool = True

    _strip_text = field_validator("url", "label", mode="before")(_strip)

    @field_validator("platform")
    @classmethod
    def _known_platform(cls, platform: str) -> str:
        if platform not in PROFILE_PLATFORMS:
            raise ValueError("Réseau non pris en charge.")
        return platform

    @field_validator("url")
    @classmethod
    def _check_url(cls, url: str, info) -> str:
        return check_url(url, NETWORKS.get(info.data.get("platform", "")))


class SocialMediaIn(BaseModel):
    description: str = Field("", max_length=300)
    links: List[SocialLinkIn] = Field(min_length=1, max_length=15)

    _strip_text = field_validator("description", mode="before")(_strip)


# --- QR Code complet (création et modification) ---


class _QrIn(BaseModel):
    title: str = Field(min_length=1, max_length=100)

    _strip_title = field_validator("title", mode="before")(_strip)


class TextQrIn(_QrIn):
    type: Literal[QrType.TEXT]
    content: TextIn


class WebsiteQrIn(_QrIn):
    type: Literal[QrType.WEBSITE]
    content: WebsiteIn


class WifiQrIn(_QrIn):
    type: Literal[QrType.WIFI]
    content: WifiIn


class CvQrIn(_QrIn):
    type: Literal[QrType.CV]
    content: CvIn


class BusinessCardQrIn(_QrIn):
    type: Literal[QrType.BUSINESS_CARD]
    content: BusinessCardIn


class SocialMediaQrIn(_QrIn):
    type: Literal[QrType.SOCIAL_MEDIA]
    content: SocialMediaIn


QrCodeIn = Annotated[
    Union[
        TextQrIn, WebsiteQrIn, WifiQrIn, CvQrIn, BusinessCardQrIn, SocialMediaQrIn
    ],
    Field(discriminator="type"),
]


class QrCodeOut(BaseModel):
    id: uuid.UUID
    type: QrType
    slug: str
    title: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    # Adresse `/q/{slug}` encodée dans les QR Codes dynamiques.
    public_url: str
    # Contenu complet, réservé au propriétaire (mot de passe Wi-Fi compris).
    content: Dict[str, Any]


class QrCodeList(BaseModel):
    items: List[QrCodeOut]
