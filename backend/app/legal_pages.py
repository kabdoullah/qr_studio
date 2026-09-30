"""Politique de confidentialité et suppression de compte (pages publiques
exigées par Google Play pour une application avec des comptes)."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from .html_page import html_response, layout

# Valeurs publiques, déjà sûres en HTML.
_PUBLISHER = "Kemogoha Abdoulaye Coulibaly"
_CONTACT = "abdoullahcoulibaly2@gmail.com"
_UPDATED = "28 septembre 2026"

_CACHE = "public, max-age=3600"

_CONTACT_LINK = f'<a href="mailto:{_CONTACT}">{_CONTACT}</a>'

_PRIVACY = f"""
<article class="legal">
<h1>Politique de confidentialité</h1>
<p>Dernière mise à jour : {_UPDATED}</p>
<p>QR Studio est une application de création de QR Codes éditée par
<strong>{_PUBLISHER}</strong>, responsable du traitement des données.
Contact : {_CONTACT_LINK}.</p>

<h2>Données collectées</h2>
<ul>
<li><strong>Compte anonyme</strong> : à la première ouverture, un compte sans
email ni nom est créé automatiquement. Seule une empreinte (SHA-256) d'un
identifiant aléatoire propre à l'installation est conservée.</li>
<li><strong>Compte enregistré</strong> (facultatif) : adresse email, prénom,
nom et mot de passe (conservé uniquement sous forme chiffrée par Argon2). Avec
Google ou Facebook : l'identifiant du compte chez ce fournisseur, l'email, le
nom et l'adresse de la photo de profil qu'il transmet.</li>
<li><strong>Contenu de vos QR Codes</strong> : textes, adresses de sites,
réseaux Wi-Fi (mot de passe compris), cartes de visite, liens de réseaux
sociaux, ainsi que les CV (PDF) et images de cartes de visite que vous
envoyez.</li>
<li><strong>Sessions</strong> : pour chaque appareil connecté, l'adresse IP
et le type d'appareil (user agent) au moment de la connexion, afin de
sécuriser le compte.</li>
</ul>

<h2>Utilisation</h2>
<p>Ces données servent uniquement à faire fonctionner l'application :
enregistrer vos QR Codes, les retrouver sur vos appareils et afficher les
pages publiques des QR Codes dynamiques. Aucune publicité, aucune mesure
d'audience, aucune revente ni aucun partage à des fins commerciales.</p>

<h2>Ce qui est public</h2>
<p>Le contenu d'un QR Code dynamique (CV, page de réseaux sociaux, image de
carte de visite) est visible par toute personne qui scanne le QR Code ou
connaît son adresse, par nature. Ces adresses sont aléatoires et ne sont pas
référencées par les moteurs de recherche. Le mot de passe d'un réseau Wi-Fi
n'est jamais affiché publiquement : il est seulement inscrit dans le QR Code
lui-même.</p>
<p>Si vous publiez une carte de visite dans l'annuaire public de
l'application, elle est consultable par tous les utilisateurs. Ces cartes ne
sont pas rattachées à un compte : pour en retirer une, écrivez à
{_CONTACT_LINK}.</p>

<h2>Hébergement et sous-traitants</h2>
<p>Le serveur est hébergé par Render et la base de données par Neon. La
connexion avec Google ou Facebook passe par ces services, selon leurs propres
politiques de confidentialité. Les échanges sont chiffrés (HTTPS).</p>

<h2>Sur votre appareil</h2>
<p>L'application garde vos jetons de session dans le stockage sécurisé du
système et une copie chiffrée (AES-256) de la liste de vos QR Codes, effacée à
la déconnexion.</p>

<h2>Durée de conservation</h2>
<p>Vos données sont conservées tant que votre compte existe. Les sessions
expirent au bout de 30 jours sans utilisation. À la suppression du compte,
tout est effacé immédiatement ; des copies peuvent subsister pour une durée
limitée dans les sauvegardes techniques de l'hébergeur de la base de données,
jusqu'à leur remplacement automatique.</p>

<h2>Vos droits</h2>
<p>Vous pouvez consulter, modifier et supprimer vos QR Codes dans
l'application, et <a href="/account/delete">supprimer votre compte</a> à tout
moment. Pour exercer vos droits d'accès, de rectification, d'effacement ou
d'opposition, écrivez à {_CONTACT_LINK}. Vous pouvez aussi saisir l'autorité
de protection des données de votre pays (en France, la CNIL).</p>

<h2>Enfants</h2>
<p>QR Studio ne s'adresse pas spécifiquement aux enfants et ne collecte pas
sciemment de données les concernant.</p>

<h2>Modifications</h2>
<p>Cette politique peut évoluer ; la date de mise à jour ci-dessus change
alors.</p>
</article>
"""

_DELETE_ACCOUNT = f"""
<article class="legal">
<h1>Supprimer votre compte QR Studio</h1>
<p>QR Studio est édité par <strong>{_PUBLISHER}</strong>.</p>

<h2>Depuis l'application</h2>
<ol>
<li>Ouvrez QR Studio.</li>
<li>Touchez <strong>Paramètres</strong> (icône en haut de l'écran
d'accueil).</li>
<li>Choisissez <strong>Supprimer mon compte</strong>, puis confirmez.</li>
</ol>

<h2>Sans l'application</h2>
<p>Écrivez à {_CONTACT_LINK} depuis l'adresse email de votre compte, avec pour
objet « Suppression de compte ». La suppression est faite sous 30 jours et
vous est confirmée par email.</p>

<h2>Données supprimées</h2>
<ul>
<li>votre compte (email, nom, mot de passe, comptes Google/Facebook
liés) ;</li>
<li>tous vos QR Codes et leur contenu : leurs pages publiques deviennent
indisponibles (les QR Codes Wi-Fi, texte, site web ou carte de visite déjà
imprimés contiennent leur contenu et continuent de fonctionner) ;</li>
<li>les CV et images de cartes de visite que vous avez envoyés ;</li>
<li>vos sessions sur tous vos appareils.</li>
</ul>
<p>Les cartes publiées dans l'annuaire public ne sont pas rattachées à un
compte : pour en retirer une, écrivez à {_CONTACT_LINK}.</p>
<p>La suppression est immédiate et définitive. Des copies peuvent subsister
pour une durée limitée dans les sauvegardes techniques de l'hébergeur, avant
leur remplacement automatique. Voir la
<a href="/privacy">politique de confidentialité</a>.</p>
</article>
"""


def create_legal_router() -> APIRouter:
    router = APIRouter(tags=["legal"])

    @router.get("/privacy", response_class=HTMLResponse)
    def privacy() -> HTMLResponse:
        return html_response(
            layout("Politique de confidentialité — QR Studio", "", _PRIVACY),
            cache=_CACHE,
        )

    @router.get("/account/delete", response_class=HTMLResponse)
    def delete_account() -> HTMLResponse:
        return html_response(
            layout("Supprimer votre compte — QR Studio", "", _DELETE_ACCOUNT),
            cache=_CACHE,
        )

    return router
