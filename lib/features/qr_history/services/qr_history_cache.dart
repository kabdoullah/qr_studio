import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../qr_generator/models/saved_qr_code.dart';

part 'qr_history_cache.g.dart';

// Dernière liste « Mes QR Codes » connue, par compte, affichée au prochain
// lancement avant la réponse du serveur. Jamais bloquant : une erreur de
// cache se lit comme un cache vide.
abstract interface class QrHistoryCache {
  Future<List<SavedQrCode>?> read(String userId);
  Future<void> write(String userId, List<SavedQrCode> items);
  // Efface tout (déconnexion).
  Future<void> clear();
}

// Box Hive chiffrée (AES-256). La réponse contient des mots de passe Wi-Fi :
// elle n'est jamais écrite en clair. La clé, générée au premier usage, est
// gardée dans le stockage sécurisé du système (comme les jetons de
// session) ; jamais SharedPreferences.
class HiveQrHistoryCache implements QrHistoryCache {
  HiveQrHistoryCache({
    this._keyStorage = const FlutterSecureStorage(),
    Future<void> Function()? initHive,
  }) : _initHive = initHive ?? Hive.initFlutter;

  static const String boxName = 'qr_history_cache';
  static const String keyName = 'qr_studio_cache_key';
  // Format des entrées : un autre numéro (ancienne version) est ignoré.
  static const int formatVersion = 1;

  final FlutterSecureStorage _keyStorage;
  final Future<void> Function() _initHive;
  Future<Box<String>>? _box;

  // Ouverte une fois ; un échec sera retenté à l'appel suivant.
  Future<Box<String>> _open() async {
    try {
      return await (_box ??= _openBox());
    } catch (_) {
      _box = null;
      rethrow;
    }
  }

  Future<Box<String>> _openBox() async {
    await _initHive();
    final cipher = HiveAesCipher(await _encryptionKey());
    try {
      return await Hive.openBox<String>(boxName, encryptionCipher: cipher);
    } catch (error, stackTrace) {
      // Box illisible (clé perdue après une réinstallation, fichier
      // abîmé) : ce n'est qu'un cache, il repart de zéro.
      _log("Cache illisible, réinitialisé", error, stackTrace);
      await Hive.deleteBoxFromDisk(boxName);
      return Hive.openBox<String>(boxName, encryptionCipher: cipher);
    }
  }

  Future<List<int>> _encryptionKey() async {
    final stored = await _keyStorage.read(key: keyName);
    if (stored != null) {
      final key = base64Url.decode(stored);
      if (key.length == 32) return key;
    }
    final key = Hive.generateSecureKey();
    await _keyStorage.write(key: keyName, value: base64Url.encode(key));
    return key;
  }

  @override
  Future<List<SavedQrCode>?> read(String userId) async {
    try {
      final raw = (await _open()).get(userId);
      if (raw == null) return null;
      if (jsonDecode(raw) case {
        'version': formatVersion,
        'items': final List<Object?> items,
      }) {
        return items.map(SavedQrCode.fromJson).nonNulls.toList();
      }
      return null;
    } catch (error, stackTrace) {
      _log('Lecture du cache impossible', error, stackTrace);
      return null;
    }
  }

  @override
  Future<void> write(String userId, List<SavedQrCode> items) async {
    try {
      await (await _open()).put(
        userId,
        jsonEncode({
          'version': formatVersion,
          'items': [for (final item in items) item.toJson()],
        }),
      );
    } catch (error, stackTrace) {
      _log('Écriture du cache impossible', error, stackTrace);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await _open()).clear();
    } catch (error, stackTrace) {
      _log('Effacement du cache impossible', error, stackTrace);
    }
  }

  // Jamais le contenu (mots de passe Wi-Fi) dans les logs.
  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'QrHistoryCache',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }
}

@Riverpod(keepAlive: true)
QrHistoryCache qrHistoryCache(Ref ref) => HiveQrHistoryCache();
