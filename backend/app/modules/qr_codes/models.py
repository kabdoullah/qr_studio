"""QR Code central et contenu propre à chaque type (une table par type)."""

import uuid
from typing import List, Optional

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ...core.database import Base, TimestampMixin, new_uuid


class QrCode(TimestampMixin, Base):
    __tablename__ = "qr_codes"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # Valeur de `QrType` (voir `schemas.py`).
    type: Mapped[str] = mapped_column(String(20))
    # Identifiant public, non devinable, de l'adresse `/q/{slug}`. Il ne
    # change jamais : un QR imprimé reste valide après modification.
    slug: Mapped[str] = mapped_column(String(32), unique=True)
    title: Mapped[str] = mapped_column(String(100))
    # Prévu pour une désactivation sans suppression (offres, expiration).
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Contenu : une seule de ces relations est renseignée, selon `type`.
    text: Mapped[Optional["TextContent"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    website: Mapped[Optional["Website"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    wifi: Mapped[Optional["WifiProfile"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    cv: Mapped[Optional["CvDocument"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    business_card: Mapped[Optional["BusinessCardProfile"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    social_media: Mapped[Optional["SocialMediaProfile"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )


def _qr_code_id() -> Mapped[uuid.UUID]:
    return mapped_column(
        ForeignKey("qr_codes.id", ondelete="CASCADE"), primary_key=True
    )


class TextContent(Base):
    __tablename__ = "texts"

    qr_code_id: Mapped[uuid.UUID] = _qr_code_id()
    content: Mapped[str] = mapped_column(Text)


class Website(Base):
    __tablename__ = "websites"

    qr_code_id: Mapped[uuid.UUID] = _qr_code_id()
    url: Mapped[str] = mapped_column(String(500))


class WifiProfile(Base):
    __tablename__ = "wifi_profiles"

    qr_code_id: Mapped[uuid.UUID] = _qr_code_id()
    ssid: Mapped[str] = mapped_column(String(64))
    # Donnée sensible : jamais journalisée ni exposée publiquement.
    password: Mapped[str] = mapped_column(String(128))
    security: Mapped[str] = mapped_column(String(8))
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)


class CvDocument(Base):
    __tablename__ = "cv_documents"

    qr_code_id: Mapped[uuid.UUID] = _qr_code_id()
    # Fichier de la table `files` (voir `app/storage.py`).
    file_id: Mapped[str] = mapped_column(String(32))
    filename: Mapped[str] = mapped_column(String(200))


# Nom distinct de `business_cards`, l'annuaire public des cartes publiées.
class BusinessCardProfile(Base):
    __tablename__ = "business_card_profiles"

    qr_code_id: Mapped[uuid.UUID] = _qr_code_id()
    # `details` (coordonnées, encodées en vCard) ou `image` (lien vers
    # l'image de la carte).
    mode: Mapped[str] = mapped_column(String(10))
    file_id: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    first_name: Mapped[str] = mapped_column(String(200), default="")
    last_name: Mapped[str] = mapped_column(String(200), default="")
    job_title: Mapped[str] = mapped_column(String(200), default="")
    company: Mapped[str] = mapped_column(String(200), default="")
    phone: Mapped[str] = mapped_column(String(200), default="")
    email: Mapped[str] = mapped_column(String(200), default="")
    website: Mapped[str] = mapped_column(String(200), default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    city: Mapped[str] = mapped_column(String(200), default="")
    country: Mapped[str] = mapped_column(String(200), default="")
    linkedin: Mapped[str] = mapped_column(String(200), default="")
    instagram: Mapped[str] = mapped_column(String(200), default="")
    whatsapp: Mapped[str] = mapped_column(String(200), default="")


class SocialMediaProfile(TimestampMixin, Base):
    __tablename__ = "social_media_profiles"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    qr_code_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("qr_codes.id", ondelete="CASCADE"), unique=True
    )
    # Le titre de la page est celui du QR Code (`qr_codes.title`).
    description: Mapped[str] = mapped_column(String(300), default="")
    links: Mapped[List["SocialMediaLink"]] = relationship(
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="SocialMediaLink.display_order",
    )


class SocialMediaLink(TimestampMixin, Base):
    __tablename__ = "social_media_links"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    profile_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("social_media_profiles.id", ondelete="CASCADE"), index=True
    )
    # Clé du registre `app/social_networks.py`.
    platform: Mapped[str] = mapped_column(String(32))
    url: Mapped[str] = mapped_column(String(500))
    label: Mapped[str] = mapped_column(String(50), default="")
    display_order: Mapped[int] = mapped_column(Integer)
    is_visible: Mapped[bool] = mapped_column(Boolean, default=True)
