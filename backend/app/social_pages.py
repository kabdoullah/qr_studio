"""Pages de réseaux sociaux : une page publique regroupant plusieurs liens.

Le QR Code encode l'adresse `/s/{id}` ; la personne qui scanne ouvre la
page dans son navigateur. Une page n'est listée nulle part (seul son lien
y mène) et ne change plus une fois publiée : la modifier revient à en
publier une nouvelle.
"""

import hashlib
import json
import re
import time
from html import escape
from typing import Any, Dict, List, Literal, Optional, Tuple
from urllib.parse import urlsplit

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field, field_validator

from .database import Database
from .storage import new_file_id

_ID = re.compile(r"^[A-Za-z0-9_-]{16}$")
_MAX_URL_LENGTH = 300

Network = Literal[
    "instagram",
    "tiktok",
    "facebook",
    "x",
    "linkedin",
    "youtube",
    "snapchat",
    "whatsapp",
    "telegram",
    "website",
]

# Domaines acceptés pour chaque réseau : un bouton « Instagram » ne peut
# mener qu'à Instagram. `None` : tout domaine (site web).
_DOMAINS: Dict[str, Optional[Tuple[str, ...]]] = {
    "instagram": ("instagram.com",),
    "tiktok": ("tiktok.com",),
    "facebook": ("facebook.com", "fb.com"),
    "x": ("x.com", "twitter.com"),
    "linkedin": ("linkedin.com",),
    "youtube": ("youtube.com", "youtu.be"),
    "snapchat": ("snapchat.com",),
    "whatsapp": ("wa.me",),
    "telegram": ("t.me",),
    "website": None,
}

# Présentation sur la page : libellé, couleurs de la pastille (fond, texte)
# et sigle.
_STYLES: Dict[str, Tuple[str, str, str, str]] = {
    "instagram": ("Instagram", "#d62976", "#ffffff", "IG"),
    "tiktok": ("TikTok", "#111111", "#ffffff", "TT"),
    "facebook": ("Facebook", "#1877f2", "#ffffff", "f"),
    "x": ("X", "#111111", "#ffffff", "X"),
    "linkedin": ("LinkedIn", "#0a66c2", "#ffffff", "in"),
    "youtube": ("YouTube", "#e62117", "#ffffff", "YT"),
    # Texte sombre sur le jaune de Snapchat, pour rester lisible.
    "snapchat": ("Snapchat", "#f7c600", "#111111", "SC"),
    "whatsapp": ("WhatsApp", "#1faa53", "#ffffff", "WA"),
    "telegram": ("Telegram", "#229ed9", "#ffffff", "TG"),
    "website": ("Site web", "#5b5bd6", "#ffffff", "www"),
}


def _strip(value: Any) -> Any:
    return value.strip() if isinstance(value, str) else value


class SocialLinkIn(BaseModel):
    network: Network
    url: str = Field(min_length=1, max_length=_MAX_URL_LENGTH)

    _strip_url = field_validator("url", mode="before")(_strip)

    @field_validator("url")
    @classmethod
    def _check_url(cls, url: str, info) -> str:
        # Seules des adresses https sans identifiants ni caractères de
        # contrôle sont acceptées (pas de `javascript:`, `data:`, etc.).
        if re.search(r"[\s\x00-\x1f\x7f]", url):
            raise ValueError("Adresse invalide.")
        parts = urlsplit(url)
        host = (parts.hostname or "").lower()
        if parts.scheme != "https" or not host or "." not in host:
            raise ValueError("L'adresse doit commencer par https://.")
        if parts.username is not None or parts.password is not None:
            raise ValueError("Adresse invalide.")
        domains = _DOMAINS.get(info.data.get("network", ""), ())
        if domains is not None and not any(
            host == domain or host.endswith("." + domain) for domain in domains
        ):
            raise ValueError("L'adresse ne correspond pas au réseau choisi.")
        return url


class SocialPageIn(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    bio: str = Field("", max_length=300)
    links: List[SocialLinkIn] = Field(min_length=1, max_length=10)

    _strip_text = field_validator("title", "bio", mode="before")(_strip)


class SocialPageCreated(BaseModel):
    id: str
    url: str


class SocialPageStore:
    def __init__(self, db: Database) -> None:
        self._execute = db.execute
        self._execute(
            "CREATE TABLE IF NOT EXISTS social_pages ("
            " id TEXT PRIMARY KEY,"
            " title TEXT NOT NULL,"
            " bio TEXT NOT NULL,"
            " links TEXT NOT NULL,"
            # Republier le même contenu renvoie la même page.
            " content_hash TEXT NOT NULL UNIQUE,"
            " created_at DOUBLE PRECISION NOT NULL)"
        )

    def add(self, page: SocialPageIn) -> str:
        """Enregistre la page (ou retrouve l'identique) et renvoie son id."""
        links = json.dumps([link.model_dump() for link in page.links])
        content_hash = hashlib.sha256(
            json.dumps([page.title, page.bio, links]).encode()
        ).hexdigest()
        self._execute(
            "INSERT INTO social_pages"
            " (id, title, bio, links, content_hash, created_at)"
            " VALUES (%s, %s, %s, %s, %s, %s)"
            " ON CONFLICT (content_hash) DO NOTHING",
            (new_file_id(), page.title, page.bio, links, content_hash, time.time()),
        )
        rows = self._execute(
            "SELECT id FROM social_pages WHERE content_hash = %s",
            (content_hash,),
            fetch=True,
        )
        return rows[0][0]

    def get(self, page_id: str) -> Optional[SocialPageIn]:
        rows = self._execute(
            "SELECT title, bio, links FROM social_pages WHERE id = %s",
            (page_id,),
            fetch=True,
        )
        if not rows:
            return None
        title, bio, links = rows[0]
        return SocialPageIn(title=title, bio=bio, links=json.loads(links))


def create_social_pages_router(store: SocialPageStore, public_url: str) -> APIRouter:
    router = APIRouter()

    @router.post(
        "/api/v1/social-pages", status_code=201, response_model=SocialPageCreated
    )
    def publish_page(page: SocialPageIn) -> SocialPageCreated:
        page_id = store.add(page)
        return SocialPageCreated(id=page_id, url=f"{public_url}/s/{page_id}")

    @router.get("/s/{page_id}", response_class=HTMLResponse)
    def show_page(page_id: str) -> HTMLResponse:
        page = store.get(page_id) if _ID.match(page_id) else None
        if page is None:
            return _html(_not_found_html(), status_code=404, cache="no-store")
        # Une page publiée ne change jamais.
        return _html(_page_html(page), cache="public, max-age=86400, immutable")

    return router


def _html(body: str, cache: str, status_code: int = 200) -> HTMLResponse:
    return HTMLResponse(
        body,
        status_code=status_code,
        headers={
            # Aucun script, aucune ressource externe : seul le style en ligne
            # est autorisé.
            "Content-Security-Policy": (
                "default-src 'none'; style-src 'unsafe-inline'; "
                "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
            ),
            "X-Content-Type-Options": "nosniff",
            "Referrer-Policy": "no-referrer",
            "Cache-Control": cache,
        },
    )


def _initials(title: str) -> str:
    words = title.split()
    return "".join(word[0] for word in words[:2]).upper() or "?"


def _page_html(page: SocialPageIn) -> str:
    title = escape(page.title)
    bio = escape(page.bio)
    buttons = "\n".join(
        '<a class="link" href="{url}" rel="noopener noreferrer">'
        '<span class="badge" style="background:{background};color:{color}">'
        "{mark}</span><span>{label}</span></a>".format(
            url=escape(link.url),
            label=_STYLES[link.network][0],
            background=_STYLES[link.network][1],
            color=_STYLES[link.network][2],
            mark=_STYLES[link.network][3],
        )
        for link in page.links
    )
    bio_html = f'<p class="bio">{bio}</p>' if bio else ""
    return _layout(
        title=title,
        description=bio,
        body=(
            f'<div class="avatar" aria-hidden="true">{escape(_initials(page.title))}</div>'
            f"<h1>{title}</h1>{bio_html}"
            f'<nav class="links">{buttons}</nav>'
        ),
    )


def _not_found_html() -> str:
    return _layout(
        title="Page introuvable",
        description="",
        body=(
            "<h1>Page introuvable</h1>"
            '<p class="bio">Ce lien ne correspond à aucune page. '
            "Vérifiez le QR Code scanné.</p>"
        ),
    )


# Les valeurs passées ici sont déjà échappées.
def _layout(title: str, description: str, body: str) -> str:
    og_description = (
        f'<meta property="og:description" content="{description}">'
        if description
        else ""
    )
    return f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{title}</title>
<meta property="og:title" content="{title}">
{og_description}
<style>
:root {{
  --bg: #f4f3fb; --card: #ffffff; --text: #1b1a2e; --muted: #5d5b72;
  --border: #e4e2f0; --accent: #5b5bd6;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #121220; --card: #1d1c2e; --text: #f2f1fa; --muted: #a9a7c0;
    --border: #2e2d44; --accent: #8e8cf0;
  }}
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0; min-height: 100vh; background: var(--bg); color: var(--text);
  font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  display: flex; justify-content: center; padding: 40px 16px;
}}
main {{ width: 100%; max-width: 440px; text-align: center; }}
.avatar {{
  width: 88px; height: 88px; margin: 0 auto 16px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  background: var(--accent); color: #fff; font-size: 32px; font-weight: 700;
}}
h1 {{ margin: 0 0 8px; font-size: 26px; line-height: 1.25; word-wrap: break-word; }}
.bio {{ margin: 0 0 28px; color: var(--muted); white-space: pre-line; word-wrap: break-word; }}
.links {{ display: flex; flex-direction: column; gap: 12px; margin-top: 24px; }}
.link {{
  display: flex; align-items: center; gap: 14px; min-height: 60px;
  padding: 10px 16px; border-radius: 16px; background: var(--card);
  border: 1px solid var(--border); color: var(--text); text-decoration: none;
  font-weight: 600; font-size: 17px; text-align: left;
}}
.link:active {{ transform: scale(.98); }}
.badge {{
  flex: none; width: 40px; height: 40px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 13px; font-weight: 800;
  box-shadow: inset 0 0 0 1px var(--border);
}}
footer {{ margin-top: 40px; font-size: 13px; color: var(--muted); }}
</style>
</head>
<body>
<main>
{body}
<footer>Créé avec QR Studio</footer>
</main>
</body>
</html>
"""
