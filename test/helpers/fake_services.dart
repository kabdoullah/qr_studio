import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/models/business_card_data.dart';
import 'package:qr_studio/features/qr_generator/models/qr_code_data.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/storage/token_storage.dart';
import 'package:qr_studio/features/auth/models/app_user.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/features/auth/models/auth_session.dart';
import 'package:qr_studio/features/auth/services/auth_service.dart';
import 'package:qr_studio/features/auth/services/facebook_auth_service.dart';
import 'package:qr_studio/features/auth/services/google_auth_service.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/saved_qr_code.dart';
import 'package:qr_studio/features/qr_generator/services/qr_code_service.dart';
import 'package:qr_studio/features/qr_history/services/qr_history_cache.dart';

// Sélecteur simulé : renvoie le résultat programmé, ou lève `error`.
class FakeFilePickerService implements FilePickerService {
  SharedFile? next;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<SharedFile?> pickPdf() => _pick();

  @override
  Future<SharedFile?> pickImage() => _pick();

  Future<SharedFile?> _pick() async {
    calls++;
    await gate?.future;
    if (error case final e?) throw e;
    return next;
  }
}

// Stockage simulé : renvoie `url`, ou lève `error`.
class FakeFileStorageService implements FileStorageService {
  FakeFileStorageService({this.url = 'https://qrstudio.app/cv/a82f91d3'});

  final String url;
  static const String fileId = 'FileFileFileFil1';
  Object? error;
  Completer<void>? gate;
  int uploads = 0;
  final List<SharedFileKind> kinds = [];

  @override
  Future<RemoteFile> upload(SharedFile file, SharedFileKind kind) async {
    uploads++;
    kinds.add(kind);
    await gate?.future;
    if (error case final e?) throw e;
    return RemoteFile(id: fileId, url: url);
  }
}

const validCv = SharedFile(
  name: 'CV_Abdoullah_Coulibaly.pdf',
  size: 1887437,
  localPath: '/tmp/CV_Abdoullah_Coulibaly.pdf',
);

// Export simulé : renvoie des octets fictifs, ou lève `error`.
class FakeQrExportService implements QrExportService {
  Object? error;
  final List<QrCodeData> exported = [];

  @override
  Future<Uint8List> exportPng(
    QrCodeData data, {
    int size = QrExportService.defaultSize,
  }) async {
    if (error case final e?) throw e;
    exported.add(data);
    return Uint8List.fromList([1, 2, 3]);
  }
}

// Partage simulé : mémorise les appels.
class FakeQrShareService implements QrShareService {
  Object? error;
  bool saveAccepted = true;
  final List<({String fileName, String? text, Rect? origin})> shares = [];
  final List<String> saves = [];

  @override
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    if (error case final e?) throw e;
    shares.add((fileName: fileName, text: text, origin: origin));
  }

  @override
  Future<bool> savePng(Uint8List png, {required String fileName}) async {
    if (error case final e?) throw e;
    saves.add(fileName);
    return saveAccepted;
  }
}

// Annuaire de cartes simulé : recherche simple sur le nom et l'entreprise.
class FakeBusinessCardDirectory implements BusinessCardDirectoryService {
  FakeBusinessCardDirectory([List<SavedBusinessCard>? cards])
    : cards = cards ?? [];

  final List<SavedBusinessCard> cards;
  final List<String> queries = [];
  final List<BusinessCardData> published = [];
  Object? error;
  Completer<void>? gate;

  @override
  Future<List<SavedBusinessCard>> search(String query) async {
    queries.add(query);
    await gate?.future;
    if (error case final e?) throw e;
    final q = query.toLowerCase();
    return cards
        .where(
          (c) => '${c.data.firstName} ${c.data.lastName} ${c.data.company}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  @override
  Future<SavedBusinessCard> publish(BusinessCardData card) async {
    await gate?.future;
    if (error case final e?) throw e;
    published.add(card);
    final saved = SavedBusinessCard(id: 'id${published.length}', data: card);
    cards.insert(0, saved);
    return saved;
  }
}

const awaCard = SavedBusinessCard(
  id: 'AwaAwaAwaAwaAwa1',
  data: BusinessCardData(
    firstName: 'Awa',
    lastName: 'Traoré',
    jobTitle: 'Designer',
    company: 'Studio Lagune',
    email: 'awa@example.com',
    city: 'Abidjan',
  ),
);

const jeanCard = SavedBusinessCard(
  id: 'JeanJeanJeanJea1',
  data: BusinessCardData(
    firstName: 'Jean',
    lastName: 'Kouassi',
    company: 'Orange CI',
  ),
);

// Stockage des jetons simulé (en mémoire). `FakeTokenStorage('refresh')`
// : une session enregistrée avec ce jeton de renouvellement.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([String? refreshToken])
    : tokens = refreshToken == null
          ? null
          : AuthTokens(accessToken: 'ancien', refreshToken: refreshToken);

  AuthTokens? tokens;

  String? get refreshToken => tokens?.refreshToken;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> delete() async => tokens = null;
}

const awaUser = AppUser(
  id: 'user-awa',
  email: 'awa@example.com',
  firstName: 'Awa',
  lastName: 'Traoré',
);

// Serveur de comptes simulé : `password` est le seul mot de passe accepté.
// Chaque session ouverte ou renouvelée reçoit des jetons numérotés
// (`access-1`/`refresh-1`, …).
class FakeAuthService implements AuthService {
  FakeAuthService({this.user = awaUser, this.password = 'motdepasse'});

  AppUser user;
  final String password;
  Object? meError;
  Object? registerError;
  Object? refreshError;
  Object? socialError;
  Completer<void>? gate;
  final List<String> registered = [];
  final List<String> refreshed = [];
  final List<String> loggedOut = [];
  final List<String> googleTokens = [];
  final List<String> facebookTokens = [];
  int logins = 0;
  int _issued = 0;

  AuthTokens _nextTokens() {
    _issued++;
    return AuthTokens(
      accessToken: 'access-$_issued',
      refreshToken: 'refresh-$_issued',
    );
  }

  AuthSession _session() => AuthSession(user: user, tokens: _nextTokens());

  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await gate?.future;
    if (registerError case final e?) throw e;
    registered.add(email);
    user = AppUser(
      id: 'user-new',
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
    return _session();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    logins++;
    await gate?.future;
    if (password != this.password) {
      throw const ApiException(
        ApiErrorKind.unauthorized,
        statusCode: 401,
        serverMessage: 'Email ou mot de passe incorrect.',
      );
    }
    return _session();
  }

  @override
  Future<AuthSession> loginWithGoogle(String idToken) async {
    googleTokens.add(idToken);
    await gate?.future;
    if (socialError case final e?) throw e;
    return _session();
  }

  @override
  Future<AuthSession> loginWithFacebook(String accessToken) async {
    facebookTokens.add(accessToken);
    await gate?.future;
    if (socialError case final e?) throw e;
    return _session();
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshed.add(refreshToken);
    if (refreshError case final e?) throw e;
    return _nextTokens();
  }

  @override
  Future<void> logout(String refreshToken) async => loggedOut.add(refreshToken);

  @override
  Future<AppUser> me() async {
    if (meError case final e?) throw e;
    return user;
  }
}

// Connexions Google/Facebook simulées : `next` est le credential renvoyé
// (`null` : annulation), ou `error` est levée.
class FakeGoogleAuthService implements GoogleAuthService {
  FakeGoogleAuthService({this.usesGoogleButton = false});

  @override
  final bool usesGoogleButton;
  String? next = 'google-id-token';
  Object? error;
  int signOuts = 0;
  final StreamController<String> webTokens = StreamController.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Future<void> get ready async {}

  @override
  Future<String?> signIn() async {
    if (error case final e?) throw e;
    return next;
  }

  @override
  Stream<String> get idTokens => webTokens.stream;

  @override
  Future<void> signOut() async => signOuts++;
}

class FakeFacebookAuthService implements FacebookAuthService {
  String? next = 'facebook-access-token';
  Object? error;
  int signOuts = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<String?> signIn() async {
    if (error case final e?) throw e;
    return next;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

// QR Codes du compte simulés (en mémoire).
class FakeQrCodeService implements QrCodeService {
  final List<SavedQrCode> items = [];
  final List<({QrType type, String title, Map<String, Object?> content})>
  created = [];
  final List<String> updated = [];
  final List<String> deleted = [];
  Object? error;
  Completer<void>? gate;
  int _next = 0;

  static String publicUrl(int n) => 'https://qr.test/q/slug$n';

  int lists = 0;

  @override
  Future<List<SavedQrCode>> list() async {
    lists++;
    await gate?.future;
    if (error case final e?) throw e;
    return List.of(items);
  }

  @override
  Future<SavedQrCode> create(
    QrType type, {
    required String title,
    required Map<String, Object?> content,
  }) async {
    await gate?.future;
    if (error case final e?) throw e;
    created.add((type: type, title: title, content: content));
    _next++;
    final saved = SavedQrCode(
      id: 'qr$_next',
      type: type,
      title: title,
      publicUrl: publicUrl(_next),
      content: content,
    );
    items.insert(0, saved);
    return saved;
  }

  @override
  Future<SavedQrCode> update(
    String id,
    QrType type, {
    required String title,
    required Map<String, Object?> content,
  }) async {
    await gate?.future;
    if (error case final e?) throw e;
    updated.add(id);
    final index = items.indexWhere((q) => q.id == id);
    final saved = SavedQrCode(
      id: id,
      type: type,
      title: title,
      publicUrl: items[index].publicUrl,
      content: content,
    );
    items[index] = saved;
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    await gate?.future;
    if (error case final e?) throw e;
    deleted.add(id);
    items.removeWhere((q) => q.id == id);
  }
}

// Session ouverte (jeton enregistré, reconnu par le serveur simulé) et
// QR Codes enregistrés en mémoire : l'application démarre sur l'accueil.
// Cache de « Mes QR Codes » simulé (en mémoire), avec un délai de lecture
// optionnel (`readGate`).
class FakeQrHistoryCache implements QrHistoryCache {
  final Map<String, List<SavedQrCode>> entries = {};
  Completer<void>? readGate;
  int clears = 0;

  @override
  Future<List<SavedQrCode>?> read(String userId) async {
    await readGate?.future;
    return entries[userId];
  }

  @override
  Future<void> write(String userId, List<SavedQrCode> items) async =>
      entries[userId] = List.of(items);

  @override
  Future<void> clear() async {
    clears++;
    entries.clear();
  }
}

List<Override> signedIn({
  FakeAuthService? auth,
  FakeTokenStorage? storage,
  FakeQrCodeService? qrCodes,
  FakeGoogleAuthService? google,
  FakeFacebookAuthService? facebook,
  FakeQrHistoryCache? historyCache,
}) => [
  qrHistoryCacheProvider.overrideWithValue(
    historyCache ?? FakeQrHistoryCache(),
  ),
  if (google != null) googleAuthServiceProvider.overrideWithValue(google),
  if (facebook != null) facebookAuthServiceProvider.overrideWithValue(facebook),
  tokenStorageProvider.overrideWithValue(
    storage ?? FakeTokenStorage('refresh-token'),
  ),
  authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
  qrCodeServiceProvider.overrideWithValue(qrCodes ?? FakeQrCodeService()),
];
