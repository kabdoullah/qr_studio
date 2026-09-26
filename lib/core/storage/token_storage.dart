import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Conservation du jeton de session entre deux lancements.
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

// Stockage chiffré du système (Keystore Android, Keychain iOS ; sur le
// web, chiffré par WebCrypto dans le stockage du navigateur). Jamais
// SharedPreferences, qui n'est pas chiffré.
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const String _key = 'qr_studio_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureTokenStorage(),
);
