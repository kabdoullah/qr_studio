"""Réseaux sociaux reconnus : domaines acceptés et présentation.

Ajouter un réseau (Threads, Pinterest, Discord…) revient à ajouter une
entrée ici ; la validation et les pages publiques s'appuient sur ce
registre.
"""

import re
from dataclasses import dataclass
from typing import Dict, Optional, Tuple
from urllib.parse import urlsplit


@dataclass(frozen=True)
class SocialNetwork:
    label: str
    # Domaines acceptés (sous-domaines compris) : un bouton « Instagram » ne
    # peut mener qu'à Instagram. `None` : tout domaine (site web).
    domains: Optional[Tuple[str, ...]]
    # Pastille de la page publique : fond, texte et sigle.
    background: str
    foreground: str
    mark: str

    def accepts_host(self, host: str) -> bool:
        return self.domains is None or any(
            host == domain or host.endswith("." + domain) for domain in self.domains
        )


NETWORKS: Dict[str, SocialNetwork] = {
    "instagram": SocialNetwork(
        "Instagram", ("instagram.com",), "#d62976", "#ffffff", "IG"
    ),
    "facebook": SocialNetwork(
        "Facebook", ("facebook.com", "fb.com"), "#1877f2", "#ffffff", "f"
    ),
    "linkedin": SocialNetwork("LinkedIn", ("linkedin.com",), "#0a66c2", "#ffffff", "in"),
    "twitter": SocialNetwork(
        "X (Twitter)", ("x.com", "twitter.com"), "#111111", "#ffffff", "X"
    ),
    # Ancien nom de Twitter, utilisé par les pages `/s/` déjà publiées.
    "x": SocialNetwork("X", ("x.com", "twitter.com"), "#111111", "#ffffff", "X"),
    "youtube": SocialNetwork(
        "YouTube", ("youtube.com", "youtu.be"), "#e62117", "#ffffff", "YT"
    ),
    "tiktok": SocialNetwork("TikTok", ("tiktok.com",), "#111111", "#ffffff", "TT"),
    "whatsapp": SocialNetwork("WhatsApp", ("wa.me",), "#1faa53", "#ffffff", "WA"),
    "telegram": SocialNetwork("Telegram", ("t.me",), "#229ed9", "#ffffff", "TG"),
    # Texte sombre sur le jaune de Snapchat, pour rester lisible.
    "snapchat": SocialNetwork(
        "Snapchat", ("snapchat.com",), "#f7c600", "#111111", "SC"
    ),
    "github": SocialNetwork("GitHub", ("github.com",), "#24292f", "#ffffff", "GH"),
    "website": SocialNetwork("Site web", None, "#5b5bd6", "#ffffff", "www"),
}

# Réseaux proposés pour les nouveaux profils (`x` est remplacé par
# `twitter`).
PROFILE_PLATFORMS: Tuple[str, ...] = tuple(name for name in NETWORKS if name != "x")


def check_url(
    url: str, network: Optional[SocialNetwork] = None, allow_http: bool = False
) -> str:
    """Vérifie une adresse web publique, et son domaine pour un réseau.

    Seules des adresses https (http en développement) sans identifiants ni
    caractères de contrôle sont acceptées : pas de `javascript:`, `data:`…
    """
    if re.search(r"[\s\x00-\x1f\x7f]", url):
        raise ValueError("Adresse invalide.")
    parts = urlsplit(url)
    host = (parts.hostname or "").lower()
    schemes = ("https", "http") if allow_http else ("https",)
    if parts.scheme not in schemes or not host or "." not in host:
        raise ValueError("L'adresse doit commencer par https://.")
    if parts.username is not None or parts.password is not None:
        raise ValueError("Adresse invalide.")
    if network is not None and not network.accepts_host(host):
        raise ValueError("L'adresse ne correspond pas au réseau choisi.")
    return url
