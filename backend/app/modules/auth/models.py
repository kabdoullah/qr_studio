import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    ForeignKey,
    String,
    UniqueConstraint,
    Uuid,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column

from ...core.database import Base, TimestampMixin, UtcDateTime, new_uuid, utc_now


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    # Toujours en minuscules (voir `schemas.normalize_email`). `None` pour
    # un compte Facebook sans adresse email.
    email: Mapped[Optional[str]] = mapped_column(String(254), unique=True)
    # `None` pour un compte créé uniquement via Google ou Facebook.
    password_hash: Mapped[Optional[str]] = mapped_column(String(255))
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # Adresse confirmée par un fournisseur de confiance (Google). Les
    # inscriptions par mot de passe ne sont pas encore vérifiées.
    email_verified: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=false()
    )


class AuthIdentity(TimestampMixin, Base):
    """Compte externe (Google, Facebook…) rattaché à un utilisateur.

    Le mot de passe reste dans `User.password_hash` : une identité n'existe
    que pour un fournisseur externe.
    """

    __tablename__ = "auth_identities"
    __table_args__ = (UniqueConstraint("provider", "provider_user_id"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    provider: Mapped[str] = mapped_column(String(20), nullable=False)
    # Identifiant stable chez le fournisseur (`sub` Google, id Facebook).
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)


class RefreshToken(Base):
    """Jeton de renouvellement, conservé uniquement sous forme d'empreinte.

    Tous les jetons issus d'une même connexion (un appareil) partagent un
    `session_id` : la réutilisation d'un jeton déjà remplacé révoque toute
    la session.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    session_id: Mapped[uuid.UUID] = mapped_column(Uuid, index=True, nullable=False)
    # SHA-256 hexadécimal du jeton (jamais le jeton lui-même).
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(UtcDateTime)
    replaced_by_token_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("refresh_tokens.id", ondelete="SET NULL")
    )
    # Informations sur l'appareil, pour une future liste « Mes appareils ».
    user_agent: Mapped[Optional[str]] = mapped_column(String(255))
    ip_address: Mapped[Optional[str]] = mapped_column(String(45))
