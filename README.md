# QR Studio

Application Flutter (Android, et PWA pour les utilisateurs iOS) pour créer,
enregistrer et partager des QR Codes, avec un compte utilisateur. Le backend
FastAPI est dans [`backend/`](backend/README.md).

## Fonctionnalités

- **Six types de QR Code** : carte de visite (vCard ou image de la carte),
  CV en PDF, texte libre, réseaux sociaux (page publique listant plusieurs
  liens), site web et Wi-Fi.
- **QR Codes dynamiques** (CV, réseaux sociaux, site web, carte en image) :
  le QR Code encode `https://…/q/{slug}`. Le contenu reste modifiable sans
  réimprimer le QR Code, car le slug ne change jamais.
- **QR Codes statiques** (texte, Wi-Fi, carte en coordonnées) : le contenu
  est encodé directement, lisible hors ligne par le téléphone qui scanne.
  Ils sont tout de même enregistrés sur le compte.
- **Comptes** : email et mot de passe, ou Google. Facebook est codé mais
  pas encore configuré. La session reste ouverte entre deux lancements
  (jeton d'accès de 15 min, jeton de renouvellement de 30 jours).
- **Mes QR Codes** : ouvrir, modifier, partager ou supprimer. La dernière
  liste connue s'affiche aussitôt depuis un cache chiffré sur l'appareil,
  puis est actualisée.
- Partage et téléchargement du QR Code en PNG, aperçu en direct pendant la
  saisie.

Les paiements, abonnements, quotas et statistiques de scan ne sont pas
implémentés : l'application prépare seulement une future offre SaaS.

## Architecture

```text
Flutter (Android, PWA)  ──HTTPS──▶  FastAPI (Render)  ──▶  PostgreSQL (Neon)
   Dio + AuthInterceptor              JWT + refresh tokens      comptes, QR Codes,
   Riverpod (générateur)              Google/Facebook vérifiés  fichiers (bytea)
   Hive CE chiffré (cache)            côté serveur
```

- **Flutter** : MVVM par fonctionnalité (`lib/features/auth`,
  `qr_generator`, `qr_history`), sans couches `domain/` ni `data/`. Les vues
  affichent, les ViewModels (notifiers Riverpod générés par
  `riverpod_generator`) portent l'état et la validation, les services font
  les appels techniques.
- **Réseau** : un seul `ApiClient` (Dio). Son `AuthInterceptor` ajoute le
  jeton, le renouvelle une seule fois sur un `401`, puis rejoue la requête.
- **Sécurité** : jetons dans `flutter_secure_storage`, cache de l'historique
  chiffré en AES-256 (il contient des mots de passe Wi-Fi). Les
  identifiants Google/Facebook sont toujours vérifiés par le serveur.

Les règles détaillées (conventions, choix de conception, tests) sont dans
[`CLAUDE.md`](CLAUDE.md) ; l'API, ses variables d'environnement et le
déploiement dans [`backend/README.md`](backend/README.md).

## Démarrage

Prérequis : Flutter 3.44 (Dart 3.12), Python 3.9+ pour le backend.

```bash
flutter pub get
dart run build_runner build   # providers Riverpod générés (*.g.dart)
```

L'application se configure au lancement par `--dart-define` :

| Variable              | Rôle                                                        |
|-----------------------|-------------------------------------------------------------|
| `QR_STUDIO_API_URL`   | Adresse du backend. Sans elle, comptes et QR Codes enregistrés sont indisponibles |
| `GOOGLE_CLIENT_ID`    | Client OAuth « Application Web » ; sans lui, pas de bouton Google |
| `FACEBOOK_APP_ID`, `FACEBOOK_CLIENT_TOKEN` | Application Meta ; sans eux, pas de bouton Facebook |

Aucun secret n'est embarqué dans l'application : les clés secrètes Google
et Facebook restent sur le serveur.

### Avec le backend en production

```bash
flutter run --dart-define=QR_STUDIO_API_URL=https://qr-studio-api-q71x.onrender.com \
  --dart-define=GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com
```

### Avec le backend en local

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/alembic upgrade head
QR_STUDIO_PUBLIC_URL=http://<ip-du-mac>:8000 \
QR_STUDIO_CORS_ORIGINS=http://localhost:8080 \
GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com \
  .venv/bin/uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8000
```

Puis, depuis la racine :

```bash
# Web (port fixe : il doit être autorisé par le CORS et par le client Google)
flutter run -d chrome --web-port 8080 --dart-define=QR_STUDIO_API_URL=http://localhost:8000 \
  --dart-define=GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com

# Téléphone Android sur le même Wi-Fi (debug : seul mode qui autorise le http)
flutter run --dart-define=QR_STUDIO_API_URL=http://<ip-du-mac>:8000 \
  --dart-define=GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com
```

La connexion Google sur Android exige que l'APK soit signé par une clé dont
le SHA-1 est déclaré dans le client OAuth Android (package
`com.qrstudio.app`). Voir « Connexion Google et Facebook » dans
[`backend/README.md`](backend/README.md).

## Tests

```bash
flutter analyze                      # doit rester propre
flutter test                         # tests unitaires et de widgets
cd backend && .venv/bin/python -m pytest   # SQLite et PostgreSQL embarqué
```

## Build et déploiement

```bash
# APK Android (signé pour l'instant avec la clé de debug, installé directement)
flutter build apk --release --dart-define=QR_STUDIO_API_URL=https://qr-studio-api-q71x.onrender.com \
  --dart-define=GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com

# PWA
flutter build web --release --dart-define=QR_STUDIO_API_URL=https://qr-studio-api-q71x.onrender.com \
  --dart-define=GOOGLE_CLIENT_ID=788583080594-grau0tdej4k2bpokotf94dkg8c7donm7.apps.googleusercontent.com
```

Le backend et la PWA sont déployés sur Render par [`render.yaml`](render.yaml),
qui migre la base (`alembic upgrade head`) à chaque démarrage. Sur iOS, la
PWA s'installe depuis Safari › Partager › « Sur l'écran d'accueil ».
