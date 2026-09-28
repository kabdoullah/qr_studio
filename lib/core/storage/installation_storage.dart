import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'installation_storage.g.dart';

// Identifiant de cette installation de l'application (UUID v4), créé au
// premier lancement. Il sert uniquement à ouvrir la session de
// l'utilisateur anonyme (`POST auth/anonymous`) ; les requêtes sont ensuite
// authentifiées par les jetons, jamais par cet identifiant. Il ne doit
// être ni affiché ni écrit dans les logs.
abstract interface class InstallationStorage {
  // `null` si aucun identifiant n'a encore été créé.
  Future<String?> getInstallationId();

  // L'identifiant existant, ou un nouveau, enregistré avant d'être renvoyé.
  Future<String> getOrCreateInstallationId();

  Future<void> clearInstallationId();
}

// Stockage chiffré du système, comme les jetons (`SecureTokenStorage`).
class SecureInstallationStorage implements InstallationStorage {
  SecureInstallationStorage([this._storage = const FlutterSecureStorage()]);

  static const String _key = 'installation_id';

  final FlutterSecureStorage _storage;

  // Création en cours : deux appels simultanés au premier lancement
  // obtiennent le même identifiant.
  Future<String>? _creating;

  @override
  Future<String?> getInstallationId() async {
    final id = await _storage.read(key: _key);
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<String> getOrCreateInstallationId() =>
      _creating ??= _getOrCreate().whenComplete(() => _creating = null);

  Future<String> _getOrCreate() async {
    if (await getInstallationId() case final id?) return id;
    final id = generateUuidV4();
    await _storage.write(key: _key, value: id);
    return id;
  }

  @override
  Future<void> clearInstallationId() => _storage.delete(key: _key);
}

// UUID version 4 (RFC 9562) tiré d'un générateur cryptographique.
String generateUuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

@Riverpod(keepAlive: true)
InstallationStorage installationStorage(Ref ref) => SecureInstallationStorage();
