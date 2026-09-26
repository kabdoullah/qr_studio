# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QR Studio: a Flutter app (Android, plus a web PWA for iOS users) with user accounts, where each QR code is saved to the signed-in user's account. Six content types (`QrType`): **business card** (vCard from a form, *or* an uploaded image of the card), **CV as a PDF file**, **free text**, **social media** (a public page listing several social links), **website**, and **Wi-Fi**. The app is being prepared for a future SaaS offer (Free/Pro/Business), but payments, subscriptions, quotas, analytics, and scan statistics are explicitly **not** to be implemented yet.

Toolchain: Flutter 3.44 / Dart 3.12 (`sdk: ^3.12.0`), lints from `flutter_lints`. Dependencies: `flutter_riverpod` (3), `go_router`, `pretty_qr_code`, `file_picker`, `share_plus`, `http` (no Dio), `web`, `flutter_secure_storage`. Add a dependency only when it has a real job.

Backend: FastAPI in `backend/`, deployed on Render at `https://qr-studio-api-q71x.onrender.com` with Neon Postgres. `backend/README.md` documents every endpoint and its validation rules. Never use MinIO/S3: files live in Postgres through the existing `FileStore`.

## Commands

```bash
flutter pub get
flutter run                                   # pick a device with -d <id>
flutter analyze                               # must be clean before finishing a step
flutter test                                  # all tests
flutter test test/path/to/file_test.dart      # a single file
flutter test --plain-name "test description"  # a single test by name
dart format .
flutter build web --release --dart-define=QR_STUDIO_API_URL=https://qr-studio-api-q71x.onrender.com
flutter run -d chrome --web-port 8080         # local web: pin the port so CORS can allow http://localhost:8080
dart run flutter_launcher_icons              # after editing flutter_launcher_icons.yaml or assets/branding/
dart run flutter_native_splash:create        # after editing flutter_native_splash.yaml

# Backend (FastAPI), Python 3.9+ locally (Render runs 3.12)
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/alembic upgrade head                              # create/upgrade the SQLAlchemy schema
.venv/bin/alembic revision --autogenerate -m "…"           # after changing models; review the file
.venv/bin/python -m pytest                                  # Postgres tests use a real embedded server (pgserver)
.venv/bin/python -m pytest tests/test_qr_codes.py -k <name> # a single test
QR_STUDIO_PUBLIC_URL=http://<mac-lan-ip>:8000 .venv/bin/uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8000
flutter run --dart-define=QR_STUDIO_API_URL=http://<mac-lan-ip>:8000
```

Run native builds one at a time: an earlier parallel build filled the disk. Work incrementally and run `flutter analyze` plus the relevant tests after each step.

## Static vs dynamic QR codes (key design decision)

- **Dynamic** (`QrType.isDynamic`: CV, social media, website; plus business card in image mode): the QR encodes `{public_url}/q/{slug}`. The slug is random, never changes on edit (a printed QR stays valid), and the backend page `/q/{slug}` renders the current content.
- **Static** (text, Wi-Fi, business card details): the QR encodes the content itself (text, `WIFI:T:…;S:…;P:…;;`, vCard 3.0), because the scanning phone must act on it offline. They are still saved to the account (history, edit), and `/q/{slug}` exists for them too, but the Wi-Fi password is never exposed publicly.
- `QrService` builds every payload (`generateBusinessCardPayload`, `generateTextPayload`, `generateWifiPayload` with `\ ; , : "` escaping and WPA/WPA2/WPA3 → `T:WPA`, `generateWebsitePayload`/`generateSocialMediaPayload`/`generateLinkPayload` for URLs, `generateSavedPayload` for a `SavedQrCode`). `QrService.fitsInQrCode` checks size in bytes (level M holds 2331 bytes; emojis take 4). The QR is always rendered locally with `pretty_qr_code`.

## Flutter architecture: MVVM + feature-based (no heavy Clean Architecture)

- Do **not** add `domain/`, `data/`, `repositories/`, `usecases/`, or `datasources/` layers. Only create a file when it has a real job.
- `lib/app/`: `app.dart`, `router/app_router.dart`, `theme/` (`AppColors`, `AppTheme`, `AppTypography`, Material 3). All colors live in `AppColors`; no `Colors.xxx` in widgets.
- `lib/core/`: `constants/api_config.dart` (`QR_STUDIO_API_URL`), `network/api_client.dart` (`ApiClient`, `ApiException` with `ApiErrorKind`), `network/session_token.dart`, `storage/token_storage.dart`, utils, widgets.
- `lib/features/auth/` (login/register/session), `lib/features/qr_generator/` (all six types, result, share), `lib/features/qr_history/` ("Mes QR Codes").
- **Views/widgets:** rendering, interaction, navigation only. **ViewModels:** Riverpod 3 `Notifier`s owning state, validation, and error mapping (`ref.watch` for state, `ref.read(...notifier)` for actions). **Models:** immutable, JSON mapping allowed, no UI logic. **Services:** technical operations.
- `QrType` owns each type's `apiName`, title, description, icon, `isDynamic`; keep those strings off widgets.
- The six types share one content flow: forms are widgets (`BusinessCardContent`, `SharedFilePicker`, `TextForm`, `SocialPageForm`, `WebsiteForm`, `WifiForm`) over the single `QrContentViewModel`. Don't add per-type ViewModels or a second QR/preview/share system.

### Session and API

- `ApiClient` (built by `apiClientProvider`, `null` without `QR_STUDIO_API_URL`) adds `Authorization: Bearer` from `sessionTokenProvider`, applies a 90 s timeout, and maps errors (401/403/404/409/422/429/5xx, timeout, offline) to `ApiException.message` (friendly French; server `detail` strings are shown, 5xx details never). It never keeps response bodies (they can echo a Wi-Fi password).
- On a 401 for an **authenticated** request, `ApiClient` clears `sessionTokenProvider`; `AuthViewModel` listens and signs out with "session expirée". Login/register calls pass `authenticated: false`, so a wrong password never triggers a logout.
- `AuthViewModel` (`AuthState { status: unknown|authenticated|unauthenticated, user, isSubmitting, errorMessage }`) restores the session at startup: token from `TokenStorage` (`flutter_secure_storage`, never SharedPreferences) → `GET /auth/me`. A rejected token is deleted; an unreachable server keeps the token but shows the login screen. Logout deletes the token; `app.dart` then calls `startOver()` so no previous user's input stays in memory.
- Router: `authRedirect(status, location)` (pure, tested) sends `unknown` → `/splash`, unauthenticated → `/login` (except `/login`, `/register`), authenticated away from `/login`/`/register`/`/splash` → `/`. `refreshListenable` is a `ValueNotifier` fed by the auth status. Other redirects: `/qr/content` (no type), `/qr/result` (no result) → `/`; `/qr/cards` → `/` without backend. Routes: `/splash`, `/login`, `/register`, `/`, `/qr/content`, `/qr/result`, `/qr/cards`, `/history`.

### Flow state and generation

- Flow state lives in two non-auto-dispose providers: `qrGeneratorViewModelProvider` (selected `QrType`) and `qrContentViewModelProvider` (`QrContentState`): business card data + `BusinessCardMode`, text, `website`, `wifi`, `socialPage`, one `FileState` per `SharedFileKind` (`cv`, `cardImage`), `saving` (`SaveState`, with the `type` its error belongs to), `editing` (the `SavedQrCode` being edited), `showErrorsFor`, and the last `QrCodeData` result.
- Validation rules are static methods on `QrContentState`, shared by form validators and `is…Valid` getters.
- `generateQr()`: validate → upload the file if needed (`FileStorageService.upload` → `RemoteFile { id, url }`, stored in `SharedFile.remoteId`) → `QrCodeService.create` or, when `editing` has the same type, `update` (same slug) → payload (static content, or `saved.publicUrl`). Titles are derived per type and clipped to 100 characters. Save errors show above the "Générer" button.
- `openSaved(saved)` (history "Ouvrir"/"Modifier") fills the form for that type and sets `editing` + `result`; `resultFor(saved)` builds the `QrCodeData` without touching the form (history "Partager").
- Live preview: `livePreviewProvider` (`null` for dynamic/file content) feeds `QrLivePreview`, under the form on phones and beside it at ≥ 840 dp.
- Result: "Modifier" pops back to the filled form (regenerating updates the same QR); "Créer un nouveau QR Code" does `go('/')` then `startOver()`. `QrResultViewModel` handles download/share (one action at a time). `QrExportService` renders a 1024 px PNG via `QrStyle.toDecoration(forExport: true)`. `QrShareService` writes to `systemTemp/qr_studio_share/`, cleared *before* each share. `QrCodeData.isOnlineLink` (dynamic type or file) adds the link to shares; Wi-Fi shares never include text.

### File-backed content (CV PDF, business-card image)

- JPG/PNG/WebP only for images (no HEIC). Chain: `SharedFilePicker(kind:)` → `QrContentViewModel` (`pickCv`/`pickCardImage`) → `FilePickerService` → `SharedFileKind` validation (extensions, 10 MB) → upload (account required) → QR code saved with `file_id`. A new file-backed type means a new `SharedFileKind` value.
- `SharedFile` doesn't load content into memory except on web. Without `QR_STUDIO_API_URL`, `BackendRequiredFileStorageService` throws `FileStorageUnavailableException`; never fake a remote URL.

### Social networks

- `SocialNetwork` (Flutter enum, `name` = API `platform`) owns normalization (`normalize`, also used by the vCard) and validation (`toUrl`: https + network domain). The backend registry is `backend/app/social_networks.py` (`NETWORKS`, `PROFILE_PLATFORMS`, `check_url`). Adding a network = one enum value + one registry entry. `x` exists only for legacy `/s/` pages; new profiles use `twitter`.
- Legacy features kept for already printed QRs / older app versions: the public business card directory (`/api/v1/business-cards`, `SavedCardsView`, publish button with confirmation) and immutable social pages `/s/{id}` (`app/social_pages.py`). The app no longer creates `/s/` pages.

### Web / PWA (iOS users install via Safari › "Sur l'écran d'accueil")

- Any `dart:io` use must stay behind a `kIsWeb` branch. On web, `SharedFile.bytes` holds the content and uploads use `MultipartFile.fromBytes`. `QrShareService` shares from memory and `savePng` returns `true`.
- Web file picking does **not** use `file_picker`: `pickWebFile` (`services/web_file_input.dart`, conditional import on `dart.library.js_interop`) keeps its own `<input type="file">` until `change`/`cancel`; `click()` must run before any `await`. `web/index.html` and `web/manifest.json` are hand-tuned for iOS install.

## Backend (`backend/`)

- `create_app(settings, store=None, …)` is a factory (no module-level app). `app/config.py` `Settings.from_env()`: `APP_ENV` (default `production` on Render), `JWT_SECRET_KEY` (required outside development), `JWT_ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES`, `PUBLIC_BASE_URL` (> `QR_STUDIO_PUBLIC_URL` > `RENDER_EXTERNAL_URL`), `DATABASE_URL` (either `postgresql://` or `postgresql+asyncpg://`; `psycopg_url()`/`async_database_url()` convert), `QR_STUDIO_CORS_ORIGINS`. On Render it refuses to start without `DATABASE_URL`. See `backend/.env.example`.
- **Two SQL stacks in one database, on purpose:** new code uses SQLAlchemy 2 async (`app/core/database.py`: `Base`, `UtcDateTime`, engine with asyncpg options for Neon's pooler, SQLite+aiosqlite locally) with Alembic migrations (`migrations/`, `alembic.ini`; env ignores the unmanaged tables). Legacy code keeps raw psycopg/sqlite SQL with tables created at startup: `files` (`app/storage.py`, `FileStore` → `PostgresFileStore` bytea / `LocalFileStore`, now with `owner_id` and `delete`), `business_cards` (`app/cards.py`), `social_pages` (`app/social_pages.py`).
- Modules: `app/modules/auth/` (User, register/login/me; Argon2 via pwdlib, run in a threadpool; constant-time-ish login with a dummy hash) and `app/modules/qr_codes/` (`QrCode` + one content table per type; `contents.py` maps each type's apply/private/public/files; `service.py` owns ownership, slug, file checks; `router.py` private CRUD + public JSON/HTML; `public_page.py` renders `/q/{slug}`). Flow: router → service → repository → SQLAlchemy. Keep business logic out of routers. `app/core/dependencies.py`: `get_current_user`, `get_current_active_user`, settings/store accessors via `app.state`.
- Ownership: repositories filter by `user_id`, so another user's QR is a `404`. A file can back only one QR code, must belong to the user, and is deleted with its QR (or when replaced). Deletion is real; `/q/{slug}` then shows "QR Code indisponible".
- Validation errors (422) are returned without the submitted `input` (a custom `RequestValidationError` handler), so passwords are never echoed.
- Limits: 10 MB per file (checked on `Content-Length` then while streaming), `QR_STUDIO_MAX_STORAGE_MB` total (507), in-memory rate limits for uploads/legacy publishing and for login/register (429). `GET /q/{slug}` and `/s/{id}` pages are self-contained HTML: escaped values, no JavaScript, strict CSP, `noindex`.
- Deployment: `render.yaml` runs `alembic upgrade head && uvicorn …`, generates `JWT_SECRET_KEY`, and defines the static PWA site (`qr-studio-web`, Flutter `$FLUTTER_VERSION` kept in sync with the project).
- Cleartext HTTP is dev-only: `usesCleartextTraffic` in the Android **debug** manifest, `NSAllowsLocalNetworking` on iOS.

## Conventions

- Code identifiers in English. **Code comments in French.** **User-facing strings in French**, errors as friendly French messages; never show raw exceptions, log technical details in dev only (`developer.log`), never log or `debugPrint` passwords, tokens, or Wi-Fi content (`WifiQrData.toString` omits the password).
- `const` wherever possible, small widgets, never compute the QR or do heavy work in `build()`.
- Large tap targets, every important action has a text label (never an icon alone; e.g. "Afficher"/"Masquer" for passwords), support large text sizes. Responsive from small phones to tablets (`LayoutBuilder`, `ConstrainedBox`, `Wrap`, `isExpanded` dropdowns).
- Out of scope until explicitly requested: payments/Stripe, subscriptions, quotas, billing, analytics, scan statistics, PDF generator, Redis/queues, MinIO/S3.

## Tests

- Flutter fakes live in `test/helpers/fake_services.dart`. `signedIn({auth, storage, qrCodes})` returns the overrides for an open session (`FakeTokenStorage('token')`, `FakeAuthService`, `FakeQrCodeService`); any test that pumps `QrStudioApp` needs it, otherwise the app sits on `/splash` or `/login`. Don't override the same provider twice (use the named parameters instead). `FakeQrCodeService.publicUrl(n)` is the `/q/` URL of the n-th created QR.
- The native `file_picker` platform is faked with `FilePickerPlatform.instance = FakeFilePickerPlatform()`, and `share_plus` by mocking its `dev.fluttercommunity.plus/share` method channel. Home cards and result buttons can sit below the fold: call `tester.ensureVisible` before `tap`. Use `http.Response.bytes(utf8.encode(...))` in `MockClient` responses with accents.
- Backend: `tests/helpers.py` `running_app(settings, authenticated=True, **app_options)` starts the app with its lifespan (schema created via `auto_create_schema`) and a registered user; `register(client)` returns auth headers for another user. Most suites run on both SQLite and a real embedded Postgres (`pgserver`, fixtures in `tests/conftest.py`); `test_migrations.py` checks Alembic against the models on both.
