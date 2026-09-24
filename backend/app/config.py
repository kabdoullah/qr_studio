"""Configuration du serveur, lue depuis les variables d'environnement."""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True)
class R2Settings:
    """Accès à Cloudflare R2 (API compatible S3)."""

    account_id: str
    access_key_id: str
    secret_access_key: str
    bucket: str

    @property
    def endpoint_url(self) -> str:
        return f"https://{self.account_id}.r2.cloudflarestorage.com"


@dataclass(frozen=True)
class Settings:
    # URL publique du serveur, utilisée pour construire les liens encodés
    # dans les QR Codes. Elle doit être joignable par le téléphone qui scanne.
    public_url: str
    # Stockage local (développement, tests) : fichiers et base SQLite.
    data_dir: Path
    # Stockage durable en production ; `None` : stockage local.
    r2: Optional[R2Settings] = None
    # Taille maximale d'un fichier (identique à la limite de l'application).
    max_file_bytes: int = 10 * 1024 * 1024
    # Limites d'envoi par heure : par adresse IP, et pour tout le serveur
    # (protège le quota gratuit du stockage).
    uploads_per_client_per_hour: int = 20
    uploads_per_hour: int = 300

    @classmethod
    def from_env(cls) -> "Settings":
        env = os.environ
        r2_keys = (
            "R2_ACCOUNT_ID",
            "R2_ACCESS_KEY_ID",
            "R2_SECRET_ACCESS_KEY",
            "R2_BUCKET",
        )
        present = [key for key in r2_keys if env.get(key)]
        if present and len(present) != len(r2_keys):
            missing = sorted(set(r2_keys) - set(present))
            raise RuntimeError(f"Configuration R2 incomplète : {missing}")
        r2 = R2Settings(*(env[key] for key in r2_keys)) if present else None

        # Sur Render, le disque est effacé à chaque déploiement : sans R2,
        # les fichiers (et les QR Codes qui y pointent) seraient perdus.
        if env.get("RENDER") and r2 is None:
            raise RuntimeError(
                "Stockage R2 requis sur Render : définissez R2_ACCOUNT_ID, "
                "R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY et R2_BUCKET."
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
            r2=r2,
        )
