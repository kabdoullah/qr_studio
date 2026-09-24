# QR Studio — backend

Petit serveur FastAPI qui met en ligne les CV (PDF), les images de carte
de visite et les pages de réseaux sociaux. L'application encode dans le QR
Code le lien renvoyé ; la personne qui scanne l'ouvre dans son navigateur.

| Méthode | Chemin            | Rôle                                              |
|---------|-------------------|---------------------------------------------------|
| POST    | `/api/v1/cvs`     | Envoi d'un PDF (champ multipart `file`)           |
| POST    | `/api/v1/cards`   | Envoi d'une image JPEG, PNG ou WebP (`file`)      |
| GET     | `/cv/{id}`        | Affiche le PDF                                    |
| GET     | `/card/{id}`      | Affiche l'image                                   |
| POST    | `/api/v1/business-cards` | Publie les coordonnées d'une carte (JSON)  |
| GET     | `/api/v1/business-cards?q=&limit=` | Liste/recherche, plus récentes d'abord (50 par défaut, 100 max) |
| POST    | `/api/v1/social-pages` | Publie une page de réseaux sociaux (JSON)    |
| GET     | `/s/{id}`         | Affiche la page de réseaux sociaux (HTML)         |
| GET     | `/health`         | Vérification de disponibilité                     |

Réponse d'envoi : `201 {"id": "...", "url": "https://.../cv/<id>"}`.

**Cartes partagées** : les coordonnées publiées sont **visibles par tous
les utilisateurs** (annuaire public, sans compte). Champs `first_name`,
`last_name` (obligatoires), `job_title`, `company`, `phone`, `email`,
`website`, `address`, `city`, `country`, `linkedin`, `instagram`,
`whatsapp` (200 caractères maximum chacun). Une carte identique (casse et
espaces ignorés) n'est pas enregistrée deux fois. La recherche porte sur le
nom, la fonction, l'entreprise et la ville. Il n'existe pas de
suppression : retirer une carte se fait directement dans la base
(`DELETE FROM business_cards WHERE id = '…'`).
**Pages de réseaux sociaux** : `{"title", "bio", "links": [{"network",
"url"}]}` → `201 {"id", "url": "https://.../s/<id>"}`. Titre obligatoire
(80 caractères maximum), description facultative (300), 1 à 10 liens.
Réseaux : `instagram`, `tiktok`, `facebook`, `x`, `linkedin`, `youtube`,
`snapchat`, `whatsapp`, `telegram`, `website`. Chaque adresse doit être en
`https` (300 caractères maximum) et, sauf pour `website`, sur le domaine du
réseau (un bouton « Instagram » ne mène qu'à Instagram) ; sinon `422`. La
page n'est listée nulle part (lien seul, `noindex`), ne change jamais et
n'a pas de suppression (`DELETE FROM social_pages WHERE id = '…'`). Un
contenu identique renvoie la même page. Le HTML est généré par le serveur,
sans JavaScript, avec une CSP stricte.

Erreurs : `411` (Content-Length absent), `413` (> 10 MB), `415` (mauvais
format), `400` (fichier vide).

Erreur `429` au-delà de 20 envois par heure et par adresse IP, ou de 300
envois par heure pour tout le serveur. Erreur `507` quand l'espace total
atteint la limite (400 MB par défaut, sous le quota gratuit de Neon).

Le type est vérifié sur le **contenu** du fichier (signature), pas sur son
nom. Les identifiants sont aléatoires (96 bits) : un lien ne se devine pas.

Stockage :
- **production** : PostgreSQL (Neon), tables `files`, `business_cards` et
  `social_pages` (créées automatiquement) ;
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

Les tests PostgreSQL démarrent un vrai serveur embarqué (`pgserver`) : ni
Docker ni installation de PostgreSQL ne sont nécessaires.

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

| Variable                   | Défaut                                   | Rôle                                  |
|----------------------------|------------------------------------------|---------------------------------------|
| `DATABASE_URL`             | —                                        | Chaîne de connexion PostgreSQL (Neon) ; sans elle, stockage local |
| `QR_STUDIO_PUBLIC_URL`     | `RENDER_EXTERNAL_URL`, sinon `http://localhost:8000` | Base des liens encodés dans les QR |
| `QR_STUDIO_MAX_STORAGE_MB` | `400`                                    | Espace total autorisé pour les fichiers |
| `QR_STUDIO_DATA_DIR`       | `data`                                   | Stockage local (sans base)            |
| `QR_STUDIO_CORS_ORIGINS`   | vide                                     | Origines web autorisées (PWA), séparées par des virgules |

Sur Render (`RENDER` défini), le serveur **refuse de démarrer sans
`DATABASE_URL`** : le disque y est effacé à chaque déploiement, et les QR
Codes déjà partagés pointeraient vers des fichiers disparus.

## Déploiement sur Render + Neon

### 1. Neon (PostgreSQL gratuit, sans carte bancaire)

1. Créez un compte sur [neon.tech](https://neon.tech) (connexion GitHub
   possible).
2. **Create project** : nom `qr-studio`, région **AWS Europe Central 1
   (Frankfurt)**, la même que le service Render.
3. Sur le tableau de bord du projet, cliquez sur **Connect** et copiez la
   chaîne de connexion (avec *Connection pooling* activé). Elle ressemble à
   `postgresql://neondb_owner:…@ep-…-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require`.

La table `files` est créée automatiquement au premier démarrage.

### 2. Render

Render déploie depuis le dépôt GitHub, qui contient `render.yaml` à la
racine.

1. Render → **New** → **Blueprint** → choisissez le dépôt.
2. Collez la chaîne Neon dans `DATABASE_URL` quand Render la demande.
3. Une fois déployé, vérifiez `https://<service>.onrender.com/health`.

### 3. Application

```bash
flutter build apk --dart-define=QR_STUDIO_API_URL=https://<service>.onrender.com
```

### Limites des offres gratuites

- **Neon** : environ 0,5 GB. Les fichiers sont limités à 400 MB au total
  (quelques centaines de CV et d'images) ; au-delà, les envois sont refusés
  (`507`). Pas de suppression ni d'expiration des fichiers pour l'instant.
- **Render** : le service s'**endort après 15 minutes** sans requête ; le
  premier envoi ou le premier scan qui suit attend environ une minute. Les
  envois de l'application ont un délai de 2 minutes.
- Les limites d'envoi sont en mémoire : elles repartent de zéro au
  redémarrage. La limite par adresse IP peut être contournée (adresse
  transmise par le proxy) ; la limite globale ne peut pas l'être.
