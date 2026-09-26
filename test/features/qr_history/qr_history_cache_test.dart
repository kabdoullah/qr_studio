import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/saved_qr_code.dart';
import 'package:qr_studio/features/qr_history/services/qr_history_cache.dart';

void main() {
  late Directory dir;

  const wifi = SavedQrCode(
    id: 'wifi',
    type: QrType.wifi,
    title: 'Wi-Fi Maison',
    publicUrl: 'https://qr.test/q/wifi',
    content: {
      'ssid': 'Maison',
      'security': 'WPA2',
      'password': 'secret-wifi-123',
      'hidden': false,
    },
  );

  HiveQrHistoryCache cache() =>
      HiveQrHistoryCache(initHive: () async => Hive.init(dir.path));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('qr_history_cache_');
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('relit la liste enregistrée, champ par champ', () async {
    await cache().write('user-1', [wifi]);
    await Hive.close();

    // Nouvelle instance : comme au prochain lancement.
    final items = await cache().read('user-1');

    final item = items!.single;
    expect(item.id, 'wifi');
    expect(item.type, QrType.wifi);
    expect(item.title, 'Wi-Fi Maison');
    expect(item.publicUrl, 'https://qr.test/q/wifi');
    expect(item.content['password'], 'secret-wifi-123');
  });

  test('une entrée par compte', () async {
    final store = cache();
    await store.write('user-1', [wifi]);

    expect(await store.read('user-2'), isNull);
  });

  test('chiffré sur le disque : aucun mot de passe lisible', () async {
    await cache().write('user-1', [wifi]);
    await Hive.close();

    final files = dir.listSync().whereType<File>().toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      final raw = latin1.decode(file.readAsBytesSync());
      expect(raw, isNot(contains('secret-wifi-123')));
      expect(raw, isNot(contains('Maison')));
    }
  });

  test('clé perdue (réinstallation) : cache vide, sans erreur', () async {
    await cache().write('user-1', [wifi]);
    await Hive.close();
    FlutterSecureStorage.setMockInitialValues({});

    final store = cache();

    expect(await store.read('user-1'), isNull);
    await store.write('user-1', [wifi]);
    expect(await store.read('user-1'), hasLength(1));
  });

  test('ancien format : ignoré', () async {
    final store = cache();
    await store.write('user-1', [wifi]);
    final box = Hive.box<String>(HiveQrHistoryCache.boxName);
    await box.put('user-1', jsonEncode({'version': 0, 'items': []}));

    expect(await store.read('user-1'), isNull);
  });

  test('effacer supprime tous les comptes', () async {
    final store = cache();
    await store.write('user-1', [wifi]);
    await store.write('user-2', [wifi]);

    await store.clear();

    expect(await store.read('user-1'), isNull);
    expect(await store.read('user-2'), isNull);
  });

  test('stockage indisponible : lecture vide, écriture sans erreur', () async {
    final store = HiveQrHistoryCache(
      initHive: () async => throw const FileSystemException('lecture seule'),
    );

    expect(await store.read('user-1'), isNull);
    await store.write('user-1', [wifi]);
    await store.clear();
  });
}
