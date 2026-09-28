import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/storage/installation_storage.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('premier appel : UUID v4 créé et enregistré', () async {
    final storage = SecureInstallationStorage();
    expect(await storage.getInstallationId(), isNull);

    final id = await storage.getOrCreateInstallationId();

    expect(id, matches(uuidV4));
    expect(await storage.getInstallationId(), id);
  });

  test('appels suivants : toujours le même identifiant, même après un '
      'redémarrage', () async {
    final first = await SecureInstallationStorage().getOrCreateInstallationId();

    final again = SecureInstallationStorage();

    expect(await again.getOrCreateInstallationId(), first);
    expect(await again.getOrCreateInstallationId(), first);
  });

  test(
    'appels simultanés au premier lancement : un seul identifiant',
    () async {
      final storage = SecureInstallationStorage();

      final ids = await Future.wait([
        storage.getOrCreateInstallationId(),
        storage.getOrCreateInstallationId(),
      ]);

      expect(ids[0], ids[1]);
    },
  );

  test('identifiant effacé : un nouveau est créé', () async {
    final storage = SecureInstallationStorage();
    final first = await storage.getOrCreateInstallationId();

    await storage.clearInstallationId();

    expect(await storage.getInstallationId(), isNull);
    expect(await storage.getOrCreateInstallationId(), isNot(first));
  });

  test('format UUID v4 (version et variante)', () {
    final random = Random(1);
    for (var i = 0; i < 200; i++) {
      expect(generateUuidV4(random), matches(uuidV4));
    }
  });
}
