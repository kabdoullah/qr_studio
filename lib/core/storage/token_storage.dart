import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/session_token.dart';

part 'token_storage.g.dart';

// Conservation des jetons de session entre deux lancements.
abstract interface class TokenStorage {
  // `null` sans jeton de renouvellement : aucune session à restaurer.
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> delete();
}

// Stockage chiffré du système (Keystore Android, Keychain iOS ; sur le
// web, chiffré par WebCrypto dans le stockage du navigateur). Jamais
// SharedPreferences, qui n'est pas chiffré.
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const String _accessKey = 'qr_studio_access_token';
  static const String _refreshKey = 'qr_studio_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final refresh = await _storage.read(key: _refreshKey);
    // Une ancienne version ne gardait que le jeton d'accès : sans jeton de
    // renouvellement, l'utilisateur se reconnecte.
    if (refresh == null || refresh.isEmpty) return null;
    final access = await _storage.read(key: _accessKey);
    return AuthTokens(accessToken: access ?? '', refreshToken: refresh);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(key: _accessKey, value: tokens.accessToken);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _accessKey);
  }
}

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => const SecureTokenStorage();
