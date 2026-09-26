# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QR Studio: a Flutter app (Android, plus a web PWA for iOS users) with user accounts, where each QR code is saved to the signed-in user's account. Six content types (`QrType`): **business card** (vCard from a form, *or* an uploaded image of the card), **CV as a PDF file**, **free text**, **social media** (a public page listing several social links), **website**, and **Wi-Fi**. The app is being prepared for a future SaaS offer (Free/Pro/Business), but payments, subscriptions, quotas, analytics, and scan statistics are explicitly **not** to be implemented yet.

Toolchain: Flutter 3.44 / Dart 3.12 (`sdk: ^3.12.0`), lints from `flutter_lints`. Dependencies: `flutter_riverpod` (3) + `riverpod_annotation` (dev: `riverpod_generator`, `build_runner`), `go_router`, `pretty_qr_code`, `file_picker`, `share_plus`, `dio` (the only HTTP client; `http` is only transitive), `web`, `flutter_secure_storage` (pinned to ^10.3.1: every `flutter_facebook_auth` 7.x requires ≤ 10), `google_sign_in` (7) + `google_sign_in_web` (`renderButton`), `flutter_facebook_auth` (7), `hive_ce` + `hive_ce_flutter` (encrypted history cache only). Add a dependency only when it has a real job.

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
dart run build_runner build                   # after adding/changing a @riverpod provider (generated *.g.dart are committed)
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
- `lib/core/`: `constants/api_config.dart` (`QR_STUDIO_API_URL`), `network/api_client.dart` (`ApiClient` over Dio, `ApiException` with `ApiErrorKind`), `network/auth_interceptor.dart`, `network/session_token.dart`, `utils/no_retry.dart`, `storage/token_storage.dart`, utils, widgets.
- `lib/features/auth/` (login/register/session), `lib/features/qr_generator/` (all six types, result, share), `lib/features/qr_history/` ("Mes QR Codes").
- **Views/widgets:** rendering, interaction, navigation only. **ViewModels:** Riverpod 3 notifiers owning state, validation, and error mapping (`ref.watch` for state, `ref.read(...notifier)` for actions).
- **Providers are generated** (`riverpod_generator`): `@riverpod` functions for services, `class X extends _$X` for ViewModels; never hand-write `Provider(...)`/`NotifierProvider(...)`. Generated providers auto-dispose by default: session, services and flow state use `@Riverpod(keepAlive: true)`; `savedCardsViewModelProvider` stays auto-dispose with `retry: noRetry` (the user retries). Tests still override with `xProvider.overrideWithValue(...)`. **Models:** immutable, JSON mapping allowed, no UI logic. **Services:** technical operations.
- `QrType` owns each type's `apiName`, title, description, icon, `isDynamic`; keep those strings off widgets.
- The six types share one content flow: forms are widgets (`BusinessCardContent`, `SharedFilePicker`, `TextForm`, `SocialPageForm`, `WebsiteForm`, `WifiForm`) over the single `QrContentViewModel`. Don't add per-type ViewModels or a second QR/preview/share system.

### Session and API

- Tokens: `AuthTokens { accessToken (JWT, 15 min), refreshToken (opaque, 30 days) }` live in `sessionTokenProvider` (memory) and `TokenStorage` (`flutter_secure_storage`, never SharedPreferences; `read()` is `null` without a refresh token). Never log them (`AuthTokens.toString` hides them).
- `ApiClient` (built by `apiClientProvider`, `null` without `QR_STUDIO_API_URL`) wraps one `Dio`: `get(path, {query, authenticated})`, `post`, `put`, `delete`, `postForm(path, FormData)` for uploads. It applies a 90 s **total** timeout (refresh and replay included, request cancelled on expiry) and maps `DioException`s (401/403/404/409/422/429/5xx, timeouts, connection errors, non-JSON bodies) to `ApiException.message` (friendly French; server `detail` strings are shown, 5xx details never). It never keeps response bodies (they can echo a Wi-Fi password). Every HTTP call goes through it, including the public legacy card directory (`authenticated: false`); tests inject `FakeHttpAdapter` (`test/helpers/fake_http_adapter.dart`).
- `AuthInterceptor` adds `Authorization: Bearer <access>` unless `Options.extra[authenticatedKey]` is `false`. On a 401 it refreshes once (`POST auth/refresh`, marked unauthenticated so it never triggers itself), single-flight (concurrent 401s share one `_refreshing` future), and replays the request once (`FormData.clone()` for uploads). If the tokens were already renewed by another request, it reuses them instead of presenting the old refresh token (the server treats that as reuse and revokes the session). Refresh rejected (401/403), or a replayed request still 401 → `onUnauthorized` clears `sessionTokenProvider` → `AuthViewModel` signs out with "session expirée"; offline/5xx during refresh keeps the session. Login/register/social calls pass `authenticated: false`, so a wrong password never triggers a logout.
- `AuthViewModel` (`AuthState { status: unknown|authenticated|unauthenticated, user, isSubmitting, errorMessage }`): at startup, stored refresh token → `service.refresh` → persist new pair → `GET /auth/me`. Rejected (401/403) → tokens deleted; unreachable server → tokens kept, login screen with a message. It persists tokens renewed by `ApiClient` (listens to `sessionTokenProvider`). Login, register, Google and Facebook all return `AuthSession { user, tokens }`. Logout: local sign-out first, then best-effort `POST auth/logout` and SDK `signOut()`/`logOut()` (never revokes the Google/Facebook grant); `app.dart` then calls `startOver()` so no previous user's input stays in memory.
- Social sign-in: `GoogleAuthService`/`FacebookAuthService` (interfaces, faked in tests) only return a credential (`null` = cancelled, `SocialSignInException` = failure); the backend verifies it. Configured by `--dart-define=GOOGLE_CLIENT_ID` (web client ID: `clientId` on web, `serverClientId` on Android) and `FACEBOOK_APP_ID` (+ `FACEBOOK_CLIENT_TOKEN`, copied by `android/app/build.gradle.kts` into Android resources; inert placeholders when unset because the Facebook SDK blocks plugin registration without them). Unconfigured → `SocialSignInButtons` hides them. On web, Google uses the GIS button (`google_web_button.dart`, conditional import) and ID tokens arrive through `idTokens`, which `AuthViewModel` subscribes to.
- Router: `authRedirect(status, location)` (pure, tested) sends `unknown` → `/splash`, unauthenticated → `/login` (except `/login`, `/register`), authenticated away from `/login`/`/register`/`/splash` → `/`. `refreshListenable` is a `ValueNotifier` fed by the auth status. Other redirects: `/qr/content` (no type), `/qr/result` (no result) → `/`; `/qr/cards` → `/` without backend. Routes: `/splash`, `/login`, `/register`, `/`, `/qr/content`, `/qr/result`, `/qr/cards`, `/history`.

### Flow state and generation

- Flow state lives in two non-auto-dispose providers: `qrGeneratorViewModelProvider` (selected `QrType`) and `qrContentViewModelProvider` (`QrContentState`): business card data + `BusinessCardMode`, text, `website`, `wifi`, `socialPage`, one `FileState` per `SharedFileKind` (`cv`, `cardImage`), `saving` (`SaveState`, with the `type` its error belongs to), `editing` (the `SavedQrCode` being edited), `showErrorsFor`, and the last `QrCodeData` result.
- Validation rules are static methods on `QrContentState`, shared by form validators and `is…Valid` getters.
- `generateQr()`: validate → upload the file if needed (`FileStorageService.upload` → `RemoteFile { id, url }`, stored in `SharedFile.remoteId`) → `QrCodeService.create` or, when `editing` has the same type, `update` (same slug) → payload (static content, or `saved.publicUrl`). Titles are derived per type and clipped to 100 characters. Save errors show above the "Générer" button.
- `openSaved(saved)` (history "Ouvrir"/"Modifier") fills the form for that type and sets `editing` + `result`; `resultFor(saved)` builds the `QrCodeData` without touching the form (history "Partager").
- Live preview: `livePreviewProvider` (`null` for dynamic/file content) feeds `QrLivePreview`, under the form on phones and beside it at ≥ 840 dp.
- Result: "Modifier" pops back to the filled form (regenerating updates the same QR); "Créer un nouveau QR Code" does `go('/')` then `startOver()`. `QrResultViewModel` handles download/share (one action at a time). `QrExportService` renders a 1024 px PNG via `QrStyle.toDecoration(forExport: true)`. `QrShareService` writes to `systemTemp/qr_studio_share/`, cleared *before* each share. `QrCodeData.isOnlineLink` (dynamic type or file) adds the link to shares; Wi-Fi shares never include text.

### Mes QR Codes (stale-while-revalidate)

- `QrHistoryViewModel` (keepAlive, sync `QrHistoryState { items?, isRevalidating, errorMessage? }`, not an `AsyncValue`: Riverpod 3 can't keep stale data next to an error publicly). `QrHistoryView` calls `revalidate()` on every opening; the last known list shows immediately with a thin progress bar, pull-to-refresh also revalidates. A failed revalidation keeps the list and shows the message above it; only a first load failure shows the full-screen error + "Réessayer".
- Concurrent `revalidate()` calls share one request. Local mutations (`delete`, `upsert` called by `QrContentViewModel` after create/update when the provider `exists`) bump `_version`, so a response that left before them is discarded.
- Persistent cache: `QrHistoryCache` (`features/qr_history/services/`), an **encrypted** Hive CE box (`HiveAesCipher`, AES-256) storing the API JSON per user id with a `version` (another version is ignored). The 32-byte key is generated once and kept in `flutter_secure_storage` (`qr_studio_cache_key`); a lost key or unreadable box resets the cache. It never throws (errors read as an empty cache) and never logs content. It holds Wi-Fi passwords: never store it unencrypted, never in SharedPreferences.
- The first `revalidate()` of the session shows the cached list before the server answers; every successful load, `upsert` and `delete` rewrites it, but only while the same account is signed in. The in-memory state is per account (`build()` watches the user id); on sign-out `app.dart` calls `qrHistoryCacheProvider.clear()`. Tests use `FakeQrHistoryCache` (injected by `signedIn`); the Hive implementation is tested with `Hive.init(tempDir)` and `FlutterSecureStorage.setMockInitialValues`.

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

- `create_app(settings, store=None, …)` is a factory (no module-level app). `app/config.py` `Settings.from_env()`: `APP_ENV` (default `production` on Render), `JWT_SECRET_KEY` (required outside development), `JWT_ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES` (15), `REFRESH_TOKEN_EXPIRE_DAYS` (30), `GOOGLE_CLIENT_ID` (comma-separated audiences), `FACEBOOK_APP_ID`/`FACEBOOK_APP_SECRET`, `PUBLIC_BASE_URL` (> `QR_STUDIO_PUBLIC_URL` > `RENDER_EXTERNAL_URL`), `DATABASE_URL` (either `postgresql://` or `postgresql+asyncpg://`; `psycopg_url()`/`async_database_url()` convert), `QR_STUDIO_CORS_ORIGINS`. On Render it refuses to start without `DATABASE_URL`. See `backend/.env.example`.
- **Two SQL stacks in one database, on purpose:** new code uses SQLAlchemy 2 async (`app/core/database.py`: `Base`, `UtcDateTime`, engine with asyncpg options for Neon's pooler, SQLite+aiosqlite locally) with Alembic migrations (`migrations/`, `alembic.ini`; env ignores the unmanaged tables). Legacy code keeps raw psycopg/sqlite SQL with tables created at startup: `files` (`app/storage.py`, `FileStore` → `PostgresFileStore` bytea / `LocalFileStore`, now with `owner_id` and `delete`), `business_cards` (`app/cards.py`), `social_pages` (`app/social_pages.py`).
- Modules: `app/modules/auth/` (`User` with nullable `email`/`password_hash`, `AuthIdentity` (external accounts only, `UNIQUE(provider, provider_user_id)`), `RefreshToken` (SHA-256 hash only, `session_id` per login/device, rotation with `replaced_by_token_id`; a revoked token presented again revokes its whole session; the conditional `UPDATE … WHERE revoked_at IS NULL` makes rotation atomic). `social.py`: `GoogleAuthProvider` (PyJWT RS256 against Google JWKS, iss/aud/exp) and `FacebookAuthProvider` (`debug_token` + `/me` with `appsecret_proof`) → `SocialUser`; providers are injectable via `create_app(social_providers=…)`. Linking by email only when both sides are verified, otherwise 409 and `…/social/{provider}/link` while signed in. Argon2 via pwdlib, run in a threadpool; constant-time-ish login with a dummy hash) and `app/modules/qr_codes/` (`QrCode` + one content table per type; `contents.py` maps each type's apply/private/public/files; `service.py` owns ownership, slug, file checks; `router.py` private CRUD + public JSON/HTML; `public_page.py` renders `/q/{slug}`). Flow: router → service → repository → SQLAlchemy. Keep business logic out of routers. `app/core/dependencies.py`: `get_current_user`, `get_current_active_user`, settings/store accessors via `app.state`.
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

- Flutter fakes live in `test/helpers/fake_services.dart` (services) and `test/helpers/fake_http_adapter.dart` (Dio transport: `FakeHttpAdapter`, `jsonResponse`). `signedIn({auth, storage, qrCodes, google, facebook})` returns the overrides for an open session (`FakeTokenStorage('refresh-token')`, `FakeAuthService` issuing `access-n`/`refresh-n`, `FakeQrCodeService`; `FakeGoogleAuthService`/`FakeFacebookAuthService` only when passed, otherwise the real services stay unconfigured and hidden); any test that pumps `QrStudioApp` needs it, otherwise the app sits on `/splash` or `/login`. Don't override the same provider twice (use the named parameters instead). `FakeQrCodeService.publicUrl(n)` is the `/q/` URL of the n-th created QR.
- The native `file_picker` platform is faked with `FilePickerPlatform.instance = FakeFilePickerPlatform()`, and `share_plus` by mocking its `dev.fluttercommunity.plus/share` method channel. Home cards and result buttons can sit below the fold: call `tester.ensureVisible` before `tap`. `jsonResponse` encodes bodies as UTF-8 (accents are safe).
- Backend: `tests/helpers.py` `running_app(settings, authenticated=True, **app_options)` starts the app with its lifespan (schema created via `auto_create_schema`) and a registered user; `register(client)` returns auth headers for another user. `test_social_auth.py` signs real RS256 ID tokens with a test key and mocks the Graph API with `httpx.MockTransport`; nothing calls Google or Facebook. Most suites run on both SQLite and a real embedded Postgres (`pgserver`, fixtures in `tests/conftest.py`); `test_migrations.py` checks Alembic against the models on both.
