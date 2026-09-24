# QR Studio — backend

Petit serveur FastAPI qui met en ligne les CV (PDF) et les images de carte
de visite. L'application encode dans le QR Code le lien renvoyé ; la
personne qui scanne ouvre le fichier dans son navigateur.

| Méthode | Chemin            | Rôle                                              |
|---------|-------------------|---------------------------------------------------|
| POST    | `/api/v1/cvs`     | Envoi d'un PDF (champ multipart `file`)           |
| POST    | `/api/v1/cards`   | Envoi d'une image JPEG, PNG ou WebP (`file`)      |
| GET     | `/cv/{id}`        | Affiche le PDF                                    |
| GET     | `/card/{id}`      | Affiche l'image                                   |
| GET     | `/health`         | Vérification de disponibilité                     |

Réponse d'envoi : `201 {"id": "...", "url": "https://.../cv/<id>"}`.
Erreurs : `411` (Content-Length absent), `413` (> 10 MB), `415` (mauvais
format), `400` (fichier vide).

Erreur `429` au-delà de 20 envois par heure et par adresse IP, ou de 300
envois par heure pour tout le serveur (protège le quota de stockage).

Le type est vérifié sur le **contenu** du fichier (signature), pas sur son
nom. Les identifiants sont aléatoires (96 bits) : un lien ne se devine pas.

Stockage :
- **production** : Cloudflare R2 (objets `cv/<id>` et `card/<id>`, nom et
  type stockés avec l'objet, aucune base de données) ;
- **développement** : fichiers dans `data/files/`, métadonnées dans
  `data/qr_studio.sqlite3`.

## Installation

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
```

## Tests

```bash
.venv/bin/python -m pytest
```

## Lancer en local avec un téléphone

Le téléphone doit joindre le serveur, et le téléphone qui **scanne** doit
pouvoir ouvrir le lien : utilisez l'adresse IP du Mac sur le Wi-Fi.

```bash
# Adresse IP du Mac sur le Wi-Fi
ipconfig getifaddr en0          # ex. 192.168.1.10

QR_STUDIO_PUBLIC_URL=http://192.168.1.10:8000 \
  .venv/bin/uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8000
```

Puis lancez l'application avec l'adresse du serveur :

```bash
flutter run --dart-define=QR_STUDIO_API_URL=http://192.168.1.10:8000
```

Sans `QR_STUDIO_API_URL`, l'application affiche « La mise en ligne … n'est
pas encore disponible » au lieu de produire un QR Code inutilisable.

Le HTTP en clair n'est autorisé que pour le développement : builds debug sur
Android, réseau local sur iOS. En production, servez l'API en HTTPS.

## Variables d'environnement

| Variable               | Défaut                                   | Rôle                                  |
|------------------------|------------------------------------------|---------------------------------------|
| `QR_STUDIO_PUBLIC_URL` | `RENDER_EXTERNAL_URL`, sinon `http://localhost:8000` | Base des liens encodés dans les QR |
| `QR_STUDIO_DATA_DIR`   | `data`                                   | Stockage local (sans R2)              |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | — | Active le stockage R2 (les quatre ensemble) |

Sur Render (`RENDER` défini), le serveur **refuse de démarrer sans R2** :
le disque y est effacé à chaque déploiement, et les QR Codes déjà partagés
pointeraient vers des fichiers disparus.

## Déploiement sur Render + Cloudflare R2

### 1. Cloudflare R2

1. Tableau de bord Cloudflare → **R2** → activer R2 (un moyen de paiement
   peut être demandé, même pour rester dans l'offre gratuite).
2. **Create bucket** : `qr-studio`. Laissez-le **privé** : c'est l'API qui
   sert les fichiers.
3. **Manage R2 API Tokens** → **Create API token** : permission
   *Object Read & Write*, limitée au bucket `qr-studio`. Notez
   l'**Access Key ID** et le **Secret Access Key** (affiché une seule fois).
4. Notez l'**Account ID** (page d'accueil de R2).

### 2. Render

Render déploie depuis un dépôt Git (GitHub, GitLab ou Bitbucket) contenant
`render.yaml` à la racine.

1. Poussez le projet sur GitHub.
2. Render → **New** → **Blueprint** → choisissez le dépôt. Render lit
   `render.yaml` et crée le service `qr-studio-api`.
3. Saisissez les quatre variables `R2_*` quand Render les demande.
4. Une fois déployé, vérifiez `https://<service>.onrender.com/health`.

### 3. Application

```bash
flutter build apk --dart-define=QR_STUDIO_API_URL=https://<service>.onrender.com
```

### Limites de l'offre gratuite

- Le service s'**endort après 15 minutes** sans requête : le premier envoi
  ou le premier scan qui suit attend environ une minute. Les envois de
  l'application ont un délai de 2 minutes.
- Pas de suppression ni d'expiration des fichiers pour l'instant.
- Les limites d'envoi sont en mémoire : elles repartent de zéro au
  redémarrage. La limite par adresse IP peut être contournée (adresse
  transmise par le proxy) ; la limite globale ne peut pas l'être.
