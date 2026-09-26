"""Configuration du serveur, lue depuis les variables d'environnement."""

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

_MB = 1024 * 1024
_DEV_JWT_SECRET = "dev-only-insecure-jwt-secret-change-me"


@dataclass(frozen=True)
class Settings:
    # URL publique du serveur, utilisée pour construire les liens encodés
    # dans les QR Codes. Elle doit être joignable par le téléphone qui scanne.
    public_url: str
    # Stockage local (développement, tests) : fichiers et base SQLite.
    data_dir: Path
    # Base PostgreSQL (ex. Neon) stockant les fichiers ; `None` : stockage
    # local.
    database_url: Optional[str] = None
    # Taille maximale d'un fichier (identique à la limite de l'application).
    max_file_bytes: int = 10 * _MB
    # Espace total utilisable : l'offre gratuite de Neon est limitée à
    # 0,5 GB, marge comprise pour les index et la base elle-même.
    max_storage_bytes: int = 400 * _MB
    # Limites d'envoi par heure : par adresse IP, et pour tout le serveur.
    uploads_per_client_per_hour: int = 20
    uploads_per_hour: int = 300
    # Origines autorisées à appeler l'API depuis un navigateur (CORS), par
    # exemple la PWA. Vide : aucun appel depuis une page web d'un autre
    # domaine (l'application mobile n'est pas concernée).
    cors_origins: Tuple[str, ...] = ()
    # `development` autorise les sites en http et une clé JWT par défaut ;
    # toute autre valeur est traitée comme la production.
    app_env: str = "development"
    # Signature des jetons de session (JWT). La valeur par défaut n'est
    # acceptée qu'en développement.
    jwt_secret_key: str = _DEV_JWT_SECRET
    jwt_algorithm: str = "HS256"
    # Jeton d'accès court ; la session est prolongée par le jeton de
    # renouvellement (opaque, conservé haché en base).
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    # Connexion Google : identifiants client OAuth acceptés comme audience
    # (`aud`) des ID tokens (client web, utilisé aussi comme
    # `serverClientId` sur Android). Vide : connexion Google indisponible.
    google_client_ids: Tuple[str, ...] = ()
    # Connexion Facebook : application Meta. Le secret ne quitte jamais le
    # serveur. Vides : connexion Facebook indisponible.
    facebook_app_id: Optional[str] = None
    facebook_app_secret: Optional[str] = None
    # Tentatives de connexion et d'inscription par heure (force brute).
    auth_attempts_per_client_per_hour: int = 30
    auth_attempts_per_hour: int = 1000
    # Crée les tables SQLAlchemy au démarrage (tests). En production, le
    # schéma est géré par Alembic (`alembic upgrade head`).
    auto_create_schema: bool = False

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    @classmethod
    def from_env(cls) -> "Settings":
        env = os.environ
        database_url = env.get("DATABASE_URL") or None

        # Sur Render, le disque est effacé à chaque déploiement : sans base
        # de données, les fichiers (et les QR Codes qui y pointent) seraient
        # perdus.
        if env.get("RENDER") and database_url is None:
            raise RuntimeError(
                "Base de données requise sur Render : définissez DATABASE_URL "
                "(chaîne de connexion Neon)."
            )

        # Render est toujours la production, sauf indication contraire.
        app_env = env.get("APP_ENV") or (
            "production" if env.get("RENDER") else "development"
        )
        jwt_secret_key = env.get("JWT_SECRET_KEY") or None
        if jwt_secret_key is None and app_env != "development":
            raise RuntimeError(
                "Clé de signature requise en production : définissez "
                "JWT_SECRET_KEY (au moins 32 caractères aléatoires)."
            )

        public_url = (
            env.get("PUBLIC_BASE_URL")
            or env.get("QR_STUDIO_PUBLIC_URL")
            # Fournie automatiquement par Render (https://<service>.onrender.com).
            or env.get("RENDER_EXTERNAL_URL")
            or "http://localhost:8000"
        )
        return cls(
            public_url=public_url.rstrip("/"),
            data_dir=Path(env.get("QR_STUDIO_DATA_DIR", "data")),
            database_url=database_url,
            max_storage_bytes=int(env.get("QR_STUDIO_MAX_STORAGE_MB", "400")) * _MB,
            cors_origins=tuple(
                origin.rstrip("/")
                for origin in _split(env.get("QR_STUDIO_CORS_ORIGINS", ""))
            ),
            app_env=app_env,
            jwt_secret_key=jwt_secret_key or _DEV_JWT_SECRET,
            jwt_algorithm=env.get("JWT_ALGORITHM", "HS256"),
            access_token_expire_minutes=int(
                env.get("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
            ),
            refresh_token_expire_days=int(env.get("REFRESH_TOKEN_EXPIRE_DAYS", "30")),
            google_client_ids=_split(env.get("GOOGLE_CLIENT_ID", "")),
            facebook_app_id=env.get("FACEBOOK_APP_ID") or None,
            facebook_app_secret=env.get("FACEBOOK_APP_SECRET") or None,
        )


def _split(value: str) -> Tuple[str, ...]:
    """Liste séparée par des virgules, sans éléments vides."""
    return tuple(item.strip() for item in value.split(",") if item.strip())


def psycopg_url(database_url: str) -> str:
    """Chaîne de connexion pour psycopg (fichiers, cartes et pages publiées).

    `DATABASE_URL` peut désigner le pilote async (`postgresql+asyncpg://`),
    utilisé par SQLAlchemy pour les comptes et les QR Codes.
    """
    return re.sub(r"^postgres(ql)?\+asyncpg://", "postgresql://", database_url)
