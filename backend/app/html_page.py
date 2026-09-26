"""Pages HTML publiques, autonomes et sans JavaScript (pages `/s/` et `/q/`)."""

from html import escape
from typing import Iterable, Tuple

from fastapi.responses import HTMLResponse

from .social_networks import NETWORKS


def html_response(
    body: str, cache: str, status_code: int = 200, images: bool = False
) -> HTMLResponse:
    return HTMLResponse(
        body,
        status_code=status_code,
        headers={
            # Aucun script, aucune ressource externe : seul le style en ligne
            # est autorisé (et les images du serveur, pour une carte de
            # visite).
            "Content-Security-Policy": (
                "default-src 'none'; style-src 'unsafe-inline'; "
                + ("img-src 'self'; " if images else "")
                + "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
            ),
            "X-Content-Type-Options": "nosniff",
            "Referrer-Policy": "no-referrer",
            "Cache-Control": cache,
        },
    )




def social_links_html(links: Iterable[Tuple[str, str, str]]) -> str:
    """Boutons des réseaux : (clé du réseau, libellé, adresse vérifiée)."""
    return "\n".join(
        '<a class="link" href="{url}" rel="noopener noreferrer">'
        '<span class="badge" style="background:{background};color:{color}">'
        "{mark}</span><span>{label}</span></a>".format(
            url=escape(url),
            label=escape(label),
            background=NETWORKS[network].background,
            color=NETWORKS[network].foreground,
            mark=escape(NETWORKS[network].mark),
        )
        for network, label, url in links
    )


# Les valeurs passées ici sont déjà échappées.
def layout(title: str, description: str, body: str) -> str:
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
.content {{
  margin: 24px 0 0; padding: 20px; border-radius: 16px; background: var(--card);
  border: 1px solid var(--border); text-align: left; white-space: pre-wrap;
  word-wrap: break-word;
}}
.rows {{ margin: 24px 0 0; padding: 0; list-style: none; text-align: left; }}
.rows li {{
  padding: 14px 16px; background: var(--card); border: 1px solid var(--border);
  border-radius: 14px; margin-bottom: 10px; word-wrap: break-word;
}}
.rows .name {{ display: block; font-size: 13px; color: var(--muted); }}
.rows a {{ color: var(--accent); }}
.button {{
  display: block; margin-top: 24px; padding: 16px; border-radius: 16px;
  background: var(--accent); color: #fff; font-weight: 700; font-size: 17px;
  text-decoration: none;
}}
.card-image {{ width: 100%; margin-top: 24px; border-radius: 16px; }}
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
