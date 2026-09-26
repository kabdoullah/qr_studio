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
from typing import Any, List, Literal, Optional

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field, field_validator

from .database import Database
from .html_page import html_response, layout, social_links_html
from .social_networks import NETWORKS, check_url
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


def _strip(value: Any) -> Any:
    return value.strip() if isinstance(value, str) else value


class SocialLinkIn(BaseModel):
    network: Network
    url: str = Field(min_length=1, max_length=_MAX_URL_LENGTH)

    _strip_url = field_validator("url", mode="before")(_strip)

    @field_validator("url")
    @classmethod
    def _check_url(cls, url: str, info) -> str:
        return check_url(url, NETWORKS.get(info.data.get("network", "")))


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
            return html_response(_not_found_html(), status_code=404, cache="no-store")
        # Une page publiée ne change jamais.
        return html_response(_page_html(page), cache="public, max-age=86400, immutable")

    return router


def _initials(title: str) -> str:
    words = title.split()
    return "".join(word[0] for word in words[:2]).upper() or "?"


def _page_html(page: SocialPageIn) -> str:
    title = escape(page.title)
    bio = escape(page.bio)
    buttons = social_links_html(
        (link.network, NETWORKS[link.network].label, link.url) for link in page.links
    )
    bio_html = f'<p class="bio">{bio}</p>' if bio else ""
    return layout(
        title=title,
        description=bio,
        body=(
            f'<div class="avatar" aria-hidden="true">{escape(_initials(page.title))}</div>'
            f"<h1>{title}</h1>{bio_html}"
            f'<nav class="links">{buttons}</nav>'
        ),
    )


def _not_found_html() -> str:
    return layout(
        title="Page introuvable",
        description="",
        body=(
            "<h1>Page introuvable</h1>"
            '<p class="bio">Ce lien ne correspond à aucune page. '
            "Vérifiez le QR Code scanné.</p>"
        ),
    )


