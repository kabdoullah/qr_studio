# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QR Studio: a Flutter mobile app (Android/iOS) that creates QR codes from three content types only: **business card** (vCard from a form, *or* a link to an uploaded image of the card), **CV as a PDF file**, and **free text**. V1 aims to be small, polished, and fast, not feature-rich. Toolchain: Flutter 3.44 / Dart 3.12 (`sdk: ^3.12.0`), lints from `flutter_lints`.

State as of 2026-09-24: steps 2–10 are done, step 11 (audit) is partly done, and the business-card image mode was added after it (144 Flutter tests, 31 backend tests). The user has tested the app on Android, and the app label is now "QR Studio". A minimal FastAPI backend lives in `backend/` (see below). Run native builds one at a time: an earlier parallel build filled the disk. Flow state lives in two non-auto-dispose providers: `qrGeneratorViewModelProvider` (selected `QrType`) and `qrContentViewModelProvider` (`QrContentState`: business card data + `BusinessCardMode` (`details`/`image`), text, one `FileState` per `SharedFileKind` (`cv`, `cardImage`), `showErrorsFor` (the set of types whose generation failed, so errors never leak onto another type's form), and the last `QrCodeData` result). Validation rules are static methods on `QrContentState`, shared by the form validators and the `is…Valid` getters. Payload size is checked in bytes by `QrService.fitsInQrCode` (the default error correction level, M, holds at most 2331 bytes, and emojis take 4 bytes each). Live preview: `livePreviewProvider` (a derived `Provider<LivePreview?>`, `null` for file-backed content) feeds `QrLivePreview`. `QrContentView` places it under the form on phones and beside it at 840 dp and wider. Forms don't render the preview themselves. `generateQr()` is async because file-backed content is uploaded first. On success the view pushes `/qr/result`. "Modifier" pops back to the form, and "Créer un nouveau QR Code" does `go('/')` then `startOver()`, which resets both view models. Result actions live in `QrResultViewModel` (one action at a time, returns a user message for a SnackBar). `QrExportService` renders a 1024 px PNG through `QrStyle.toDecoration(forExport: true)`, the same rendering as the preview plus background and quiet zone. `QrShareService` shares through `share_plus`, writing to `systemTemp/qr_studio_share/`, which it clears *before* each share because the receiving app may read the file after the share sheet returns. It saves through `FilePicker.saveFile`, the system "Save as" dialog. Router redirects send `/qr/content` (no type selected) and `/qr/result` (no result) back to `/`. `fileStorageServiceProvider` returns `HttpFileStorageService` when the app is started with `--dart-define=QR_STUDIO_API_URL=…`, and otherwise `BackendRequiredFileStorageService`, which always throws `FileStorageUnavailableException`, so file flows stop with an honest "not available yet" message. Test fakes live in `test/helpers/`. App services are faked by overriding their providers (`fake_services.dart`). The native `file_picker` platform is faked with `FilePickerPlatform.instance = FakeFilePickerPlatform()`, and `share_plus` by mocking its `dev.fluttercommunity.plus/share` method channel. Home cards and result buttons can sit below the fold on the test screen, so call `tester.ensureVisible` before `tap`. Much of what follows is the target design, so check what is actually present before you assume a file or dependency exists.

## Commands

```bash
flutter pub get
flutter run                                   # pick a device with -d <id>
flutter analyze                               # must be clean before finishing a step
flutter test                                  # all tests
flutter test test/path/to/file_test.dart      # a single file
flutter test --plain-name "test description"  # a single test by name
dart format .

# Backend (FastAPI), see backend/README.md
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest
QR_STUDIO_PUBLIC_URL=http://<mac-lan-ip>:8000 .venv/bin/uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8000
flutter run --dart-define=QR_STUDIO_API_URL=http://<mac-lan-ip>:8000
```

Workflow rule: build incrementally. After each step (foundation → home → business card → text → CV → preview → result → share → tests), run `flutter analyze` and the relevant tests before moving on.

## Target architecture: MVVM + feature-based (no heavy Clean Architecture)

- Do **not** add `domain/`, `data/`, `repositories/`, `usecases/`, or `datasources/` layers. Only create a file when it has a real job.
- `lib/app/`: `app.dart`, `router/app_router.dart` (GoRouter), and `theme/` (`AppColors`, `AppTheme`, `AppTypography`, Material 3). All colors live in `AppColors`, so don't put `Colors.xxx` in widgets.
- `lib/core/`: shared constants, extensions, utils, and widgets.
- `lib/features/qr_generator/`: `models/`, `services/`, `viewmodels/`, `views/`, `widgets/`.
- Layer responsibilities:
  - **Views/widgets:** rendering, user interaction, and navigation only. No business logic.
  - **ViewModels:** Riverpod `Notifier`s (Riverpod 3 APIs) that own state, validation, and error mapping, and orchestrate services. Views use `ref.watch(provider)` for state and `ref.read(provider.notifier)` for actions. Don't mix in Bloc, GetX, or Provider.
  - **Models:** immutable data classes with no UI logic.
  - **Services:** technical operations.
- Planned dependencies (add only when you need them): `flutter_riverpod`, `go_router`, `pretty_qr_code`, `file_picker`, `share_plus`.

### Routing and state

- Routes: `/` (type selection), `/qr/content`, and `/qr/result`. Don't pass large objects through route params. Flow state lives in providers, so that "Modifier" on the result screen returns to a form that still holds the user's data. The system back button must behave naturally.

### Key models and services

- `QrType` enum (`businessCard`, `cv`, `text`) provides each type's title, description, and icon. Keep these strings off the widgets.
- `QrCodeData { type, payload, style }` is the final result. `QrStyle` (foreground, background, size) is the extension point for future customization (shapes, logo, gradient, error correction), but V1 doesn't need it.
- `QrService`:
  - `generateBusinessCardPayload`: vCard 3.0 with correctly escaped special characters (`\`, `;`, `,`, newlines).
  - `generateTextPayload`: text is limited to 1000 characters, with a live counter and a live QR preview.
  - `generateLinkPayload(remoteUrl)`: for a file-backed QR (CV, card image), the payload is just the URL.
  - PNG export must be good enough quality for WhatsApp, email, and print. Clean up temporary share files afterward.
- `QrPreview(data:, style:)` is type-agnostic.
- Business card: only first name and last name are required. Validate email, and show errors only after the user has interacted with a field. The form uses sections in a scroll view, `TextInputAction.next`, and a keyboard that never hides the active field.

### File-backed flows: CV and business-card image (important)

- A CV is a **PDF file**, not a form. The business card can alternatively be an **image** (JPG/PNG/WebP, not HEIC, because browsers can't display it). In both cases the QR code contains a **URL** to the file, never the file itself.
- The flow is: pick → validate (`SharedFileKind`: extensions, max 10 MB, messages) → show the file → `FileStorageService.upload(file, kind)` → `remoteUrl` → `QrCodeData(file: …)` → QR code. Adding another file-backed type means adding a `SharedFileKind` value, not new plumbing.
- `FilePickerService.pickPdf()` / `pickImage()` return a `SharedFile { name, size, localPath?, remoteUrl? }` without loading the content into memory. `pickImage` asks iOS for a compatible (JPEG) representation.
- `FileStorageService` is an `abstract interface class`. Never fake a remote URL: without a configured server, the flow must fail honestly.
- Backend (`backend/`, Python 3.9+, FastAPI): `POST /api/v1/cvs` and `POST /api/v1/cards` (multipart field `file`) return `201 { "id", "url" }`. `GET /cv/{id}` and `GET /card/{id}` serve the file inline. The file type is sniffed from its content (magic bytes), IDs are 96-bit random, and the 10 MB limit is checked on `Content-Length` before reading, then again while streaming. Storage (`app/storage.py`, `FileStore` protocol): `PostgresFileStore` (Neon, files stored as `bytea` in the auto-created `files` table, one connection per operation with `prepare_threshold=None` for Neon's pooler) when `DATABASE_URL` is set, otherwise `LocalFileStore` (disk + SQLite, for dev and tests). On Render (`RENDER` set), `Settings.from_env()` refuses to start without `DATABASE_URL`, because the disk is ephemeral. Total storage is capped (`QR_STUDIO_MAX_STORAGE_MB`, default 400, under Neon's 0.5 GB free tier), returning 507 when full. The public URL defaults to `RENDER_EXTERNAL_URL`. Uploads are rate-limited in memory (per IP and globally, returning 429). `create_app(settings, store=None)` is a factory (no module-level app). Postgres tests run against a real embedded server (`pgserver`, fixtures in `tests/conftest.py`). Deployment: `render.yaml` at the repo root (free web service, Frankfurt region to match Neon, `rootDir: backend`, Python 3.12). There is no auth or file expiry yet.
- Cleartext HTTP is allowed only for development: `usesCleartextTraffic` in the Android **debug** manifest and `NSAllowsLocalNetworking` on iOS. The main Android manifest declares `INTERNET` (release builds need it for uploads).
- Keep the picker, upload, and QR generation out of the View. The chain is `SharedFilePicker(kind:)` widget → `QrContentViewModel` (`pickCv`/`pickCardImage`) → `FilePickerService` → `FileStorageService` → `QrService` → `QrPreview`.

## Conventions

- Code identifiers are in English. **Code comments are in French.** **User-facing strings are in French.**
- User-facing errors are friendly French messages (for example "Impossible de sélectionner le fichier. Veuillez réessayer."). Never show raw exceptions to users. Log technical details in dev only.
- Use `const` wherever possible, keep widgets small, and never compute the QR code or do heavy work inside `build()`.
- Keep tap targets large, give every important action a text label (never an icon alone), and support large text sizes.
- Layouts must be responsive from small phones up to tablets (`LayoutBuilder`, `ConstrainedBox`, `MediaQuery`).
- Out of scope for V1 (don't add): auth or accounts, cloud history, analytics, payments, scan statistics, dynamic QR codes, or a PDF generator. The backend stays minimal (file upload and serving only). Don't start V2 work without an explicit request.

## Tests

- Unit tests: `QrService` (valid vCard, escaping, CV URL, text preserved) and the ViewModels (`selectQrType`, `updateText`, `pickCv`, `reset`, validation). Fake the services by overriding their providers.
- Widget tests: the home screen, business card, CV, and text screens.
