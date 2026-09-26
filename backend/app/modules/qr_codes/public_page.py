"""Page `/q/{slug}` ouverte par la personne qui scanne un QR Code.

Rendue côté serveur, sans JavaScript ; toutes les valeurs sont échappées.
"""

import re
from html import escape
from typing import Any, Callable, Dict

from fastapi.responses import HTMLResponse

from ...html_page import html_response, layout, social_links_html

# Le contenu peut être modifié à tout moment : pas de cache durable.
_CACHE = "no-cache"
_SECURITY_LABELS = {"none": "Aucune (réseau ouvert)"}
_CARD_ROWS = (
    ("job_title", "Fonction"),
    ("company", "Entreprise"),
    ("phone", "Téléphone"),
    ("email", "Email"),
    ("website", "Site web"),
    ("address", "Adresse"),
    ("city", "Ville"),
    ("country", "Pays"),
    ("linkedin", "LinkedIn"),
    ("instagram", "Instagram"),
    ("whatsapp", "WhatsApp"),
)


def _initials(title: str) -> str:
    return "".join(word[0] for word in title.split()[:2]).upper() or "?"


def _heading(title: str) -> str:
    return (
        f'<div class="avatar" aria-hidden="true">{escape(_initials(title))}</div>'
        f"<h1>{escape(title)}</h1>"
    )


def _button(url: str, label: str) -> str:
    return (
        f'<a class="button" href="{escape(url)}" rel="noopener noreferrer">'
        f"{escape(label)}</a>"
    )


def _row(name: str, value: str) -> str:
    return f'<li><span class="name">{escape(name)}</span>{value}</li>'


def _website(qr: Dict[str, Any]) -> str:
    return (
        f"{_heading(qr['title'])}"
        f'<p class="bio">{escape(qr["url"])}</p>'
        f"{_button(qr['url'], 'Visiter le site')}"
    )


def _social_media(qr: Dict[str, Any]) -> str:
    description = qr["description"]
    links = social_links_html(
        (link["platform"], link["label"], link["url"]) for link in qr["links"]
    )
    return (
        f"{_heading(qr['title'])}"
        + (f'<p class="bio">{escape(description)}</p>' if description else "")
        + f'<nav class="links">{links}</nav>'
    )


def _cv(qr: Dict[str, Any]) -> str:
    return (
        f"{_heading(qr['title'])}"
        f'<p class="bio">{escape(qr["filename"])}</p>'
        f"{_button(qr['url'], 'Télécharger le CV')}"
    )


def _text(qr: Dict[str, Any]) -> str:
    return f"<h1>{escape(qr['title'])}</h1><div class=\"content\">{escape(qr['text'])}</div>"


def _wifi(qr: Dict[str, Any]) -> str:
    security = _SECURITY_LABELS.get(qr["security"], qr["security"])
    return (
        f"<h1>{escape(qr['title'])}</h1>"
        '<ul class="rows">'
        f"{_row('Réseau', escape(qr['ssid']))}"
        f"{_row('Sécurité', escape(security))}"
        "</ul>"
        '<p class="bio">Scannez le QR Code Wi-Fi pour vous connecter, ou '
        "saisissez ces informations dans les réglages Wi-Fi.</p>"
    )


def _business_card(qr: Dict[str, Any]) -> str:
    if qr["mode"] == "image":
        return (
            f"<h1>{escape(qr['title'])}</h1>"
            f'<img class="card-image" src="{escape(qr["image_url"])}" '
            f'alt="Carte de visite">'
        )
    card = qr["details"]
    name = f"{card['first_name']} {card['last_name']}"
    rows = []
    for field, label in _CARD_ROWS:
        value = card[field]
        if not value:
            continue
        # Seuls l'email et le téléphone deviennent des liens, sur un format
        # sûr ; les autres valeurs (saisie libre) restent du texte.
        if field == "email":
            html = f'<a href="mailto:{escape(value)}">{escape(value)}</a>'
        elif field == "phone" and re.fullmatch(r"\+?[0-9 ().-]{3,30}", value):
            number = re.sub(r"[^0-9+]", "", value)
            html = f'<a href="tel:{number}">{escape(value)}</a>'
        else:
            html = escape(value)
        rows.append(_row(label, html))
    return f"{_heading(name)}<ul class=\"rows\">{''.join(rows)}</ul>"


_RENDERERS: Dict[str, Callable[[Dict[str, Any]], str]] = {
    "website": _website,
    "social_media": _social_media,
    "cv": _cv,
    "text": _text,
    "wifi": _wifi,
    "business_card": _business_card,
}


def public_html(qr: Dict[str, Any]) -> HTMLResponse:
    body = _RENDERERS[qr["type"]](qr)
    return html_response(
        layout(title=escape(qr["title"]), description="", body=body),
        cache=_CACHE,
        images=qr["type"] == "business_card",
    )


def not_found_html() -> HTMLResponse:
    body = (
        "<h1>QR Code indisponible</h1>"
        '<p class="bio">Ce QR Code a été supprimé ou n\'existe pas.</p>'
    )
    return html_response(
        layout(title="QR Code indisponible", description="", body=body),
        cache="no-store",
        status_code=404,
    )
