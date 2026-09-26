"""Contenu propre à chaque type de QR Code.

Chaque type décrit comment enregistrer sa saisie, ce que voit son
propriétaire, ce que voit le public (`/q/{slug}`) et les fichiers qu'il
utilise. Ajouter un type revient à ajouter une entrée à `CONTENTS`.
"""

from typing import Any, Callable, Dict, List, NamedTuple, Tuple

from ...cards import FIELDS as CARD_FIELDS
from ...social_networks import NETWORKS
from ...storage import StoredFile
from .models import (
    BusinessCardProfile,
    CvDocument,
    QrCode,
    SocialMediaLink,
    SocialMediaProfile,
    TextContent,
    Website,
    WifiProfile,
)
from .schemas import (
    BusinessCardIn,
    CvIn,
    QrType,
    SocialMediaIn,
    TextIn,
    WebsiteIn,
    WifiIn,
)

# Fichier utilisé par un QR Code : (type de fichier, identifiant).
FileRef = Tuple[str, str]
StoredFiles = Dict[str, StoredFile]


class Content(NamedTuple):
    # Enregistre la saisie sur le QR Code (création ou remplacement), avec
    # les fichiers qu'elle utilise, déjà vérifiés.
    apply: Callable[[QrCode, Any, "StoredFiles"], None]
    # Contenu complet, pour le propriétaire.
    private: Callable[[QrCode, str], Dict[str, Any]]
    # Contenu public, sans donnée inutile au scan.
    public: Callable[[QrCode, str], Dict[str, Any]]
    files: Callable[[Any], List[FileRef]] = lambda _: []


def _file_url(base_url: str, kind: str, file_id: str) -> str:
    return f"{base_url}/{kind}/{file_id}"


# --- Texte ---


def _apply_text(qr: QrCode, data: TextIn, _: StoredFiles) -> None:
    if qr.text is None:
        qr.text = TextContent(content=data.text)
    else:
        qr.text.content = data.text


def _text(qr: QrCode, _: str) -> Dict[str, Any]:
    return {"text": qr.text.content}


# --- Site web ---


def _apply_website(qr: QrCode, data: WebsiteIn, _: StoredFiles) -> None:
    if qr.website is None:
        qr.website = Website(url=data.url)
    else:
        qr.website.url = data.url


def _website(qr: QrCode, _: str) -> Dict[str, Any]:
    return {"url": qr.website.url}


# --- Wi-Fi ---


def _apply_wifi(qr: QrCode, data: WifiIn, _: StoredFiles) -> None:
    values = data.model_dump()
    if qr.wifi is None:
        qr.wifi = WifiProfile(**values)
    else:
        for name, value in values.items():
            setattr(qr.wifi, name, value)


def _wifi_private(qr: QrCode, _: str) -> Dict[str, Any]:
    wifi = qr.wifi
    return {
        "ssid": wifi.ssid,
        "security": wifi.security,
        "password": wifi.password,
        "hidden": wifi.hidden,
    }


def _wifi_public(qr: QrCode, _: str) -> Dict[str, Any]:
    # Jamais le mot de passe : il n'est utile que dans le QR Code lui-même.
    return {"ssid": qr.wifi.ssid, "security": qr.wifi.security}


# --- CV ---


def _apply_cv(qr: QrCode, data: CvIn, files: StoredFiles) -> None:
    filename = files[data.file_id].filename
    if qr.cv is None:
        qr.cv = CvDocument(file_id=data.file_id, filename=filename)
    else:
        qr.cv.file_id = data.file_id
        qr.cv.filename = filename


def _cv_private(qr: QrCode, base_url: str) -> Dict[str, Any]:
    return {**_cv_public(qr, base_url), "file_id": qr.cv.file_id}


def _cv_public(qr: QrCode, base_url: str) -> Dict[str, Any]:
    return {
        "filename": qr.cv.filename,
        "url": _file_url(base_url, "cv", qr.cv.file_id),
    }


# --- Carte de visite ---


def _apply_business_card(qr: QrCode, data: BusinessCardIn, _: StoredFiles) -> None:
    card = qr.business_card
    if card is None:
        card = qr.business_card = BusinessCardProfile(mode=data.mode)
    card.mode = data.mode
    card.file_id = data.file_id if data.mode == "image" else None
    details = data.details if data.mode == "details" else None
    for name in CARD_FIELDS:
        setattr(card, name, getattr(details, name) if details else "")


def _business_card(qr: QrCode, base_url: str) -> Dict[str, Any]:
    card = qr.business_card
    if card.mode == "image":
        return {
            "mode": "image",
            "image_url": _file_url(base_url, "card", card.file_id),
        }
    return {
        "mode": "details",
        "details": {name: getattr(card, name) for name in CARD_FIELDS},
    }


def _business_card_private(qr: QrCode, base_url: str) -> Dict[str, Any]:
    content = _business_card(qr, base_url)
    if qr.business_card.mode == "image":
        content["file_id"] = qr.business_card.file_id
    return content


def _business_card_files(data: BusinessCardIn) -> List[FileRef]:
    return [("card", data.file_id)] if data.mode == "image" else []


# --- Réseaux sociaux ---


def _apply_social_media(qr: QrCode, data: SocialMediaIn, _: StoredFiles) -> None:
    profile = qr.social_media
    if profile is None:
        profile = qr.social_media = SocialMediaProfile()
    profile.description = data.description
    # Les liens sont remplacés : leur ordre est celui de la saisie.
    profile.links = [
        SocialMediaLink(
            platform=link.platform,
            url=link.url,
            label=link.label,
            display_order=index,
            is_visible=link.is_visible,
        )
        for index, link in enumerate(data.links)
    ]


def _social_media_private(qr: QrCode, _: str) -> Dict[str, Any]:
    return {
        "description": qr.social_media.description,
        "links": [
            {
                "platform": link.platform,
                "url": link.url,
                "label": link.label,
                "is_visible": link.is_visible,
            }
            for link in qr.social_media.links
        ],
    }


def _social_media_public(qr: QrCode, _: str) -> Dict[str, Any]:
    return {
        "description": qr.social_media.description,
        "links": [
            {
                "platform": link.platform,
                "label": link.label or NETWORKS[link.platform].label,
                "url": link.url,
            }
            for link in qr.social_media.links
            if link.is_visible
        ],
    }


CONTENTS: Dict[QrType, Content] = {
    QrType.TEXT: Content(_apply_text, _text, _text),
    QrType.WEBSITE: Content(_apply_website, _website, _website),
    QrType.WIFI: Content(_apply_wifi, _wifi_private, _wifi_public),
    QrType.CV: Content(
        _apply_cv,
        _cv_private,
        _cv_public,
        files=lambda data: [("cv", data.file_id)],
    ),
    QrType.BUSINESS_CARD: Content(
        _apply_business_card,
        _business_card_private,
        _business_card,
        files=_business_card_files,
    ),
    QrType.SOCIAL_MEDIA: Content(
        _apply_social_media, _social_media_private, _social_media_public
    ),
}


def file_ids(qr: QrCode) -> List[str]:
    """Fichiers actuellement utilisés par le QR Code."""
    if qr.cv is not None:
        return [qr.cv.file_id]
    if qr.business_card is not None and qr.business_card.file_id:
        return [qr.business_card.file_id]
    return []
