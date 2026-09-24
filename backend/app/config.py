"""Configuration du serveur, lue depuis les variables d'environnement."""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

_MB = 1024 * 1024


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

        public_url = (
            env.get("QR_STUDIO_PUBLIC_URL")
            # Fournie automatiquement par Render (https://<service>.onrender.com).
            or env.get("RENDER_EXTERNAL_URL")
            or "http://localhost:8000"
        )
        return cls(
            public_url=public_url.rstrip("/"),
            data_dir=Path(env.get("QR_STUDIO_DATA_DIR", "data")),
            database_url=database_url,
            max_storage_bytes=int(env.get("QR_STUDIO_MAX_STORAGE_MB", "400")) * _MB,
        )
