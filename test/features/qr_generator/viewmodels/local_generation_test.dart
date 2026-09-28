import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

// Générer un QR Code ne demande jamais de compte : l'utilisateur anonyme
// génère et enregistre, et les types statiques (texte, Wi-Fi, coordonnées,
// site web) sont produits sur l'appareil même sans serveur.
void main() {
  late ProviderContainer container;
  late FakeQrCodeService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  // Installation neuve (aucun jeton) ; `offline` : le serveur est injoignable.
  void start({bool offline = false}) {
    service = FakeQrCodeService();
    final auth = FakeAuthService();
    if (offline) {
      auth.anonymousError = const ApiException(ApiErrorKind.offline);
    }
    container = ProviderContainer(
      overrides: signedIn(
        auth: auth,
        storage: FakeTokenStorage(),
        qrCodes: service,
      ),
    );
    container.listen(authViewModelProvider, (_, _) {});
  }

  void select(QrType type) =>
      container.read(qrGeneratorViewModelProvider.notifier).selectQrType(type);

  void fill(QrType type) {
    final vm = viewModel();
    switch (type) {
      case QrType.text:
        vm.updateText('Hello QR Studio');
      case QrType.wifi:
        vm.updateWifi(
          (w) => w.copyWith(ssid: 'Maison', password: 'secret-wifi'),
        );
      case QrType.businessCard:
        vm.updateBusinessCard(
          (c) => c.copyWith(firstName: 'Awa', lastName: 'Diallo'),
        );
      case QrType.website:
        vm.updateWebsite((w) => w.copyWith(url: 'https://example.com'));
      case QrType.socialMedia:
        vm
          ..updateSocialPage((p) => p.copyWith(title: 'Awa'))
          ..addSocialLink(SocialNetwork.instagram);
        vm.updateSocialLink(state().socialPage.links.single.id, '@awa');
      case QrType.cv:
        throw UnimplementedError();
    }
  }

  tearDown(() => container.dispose());

  test('utilisateur anonyme : génère et enregistre sans compte', () async {
    start();
    for (final type in [
      QrType.text,
      QrType.wifi,
      QrType.businessCard,
      QrType.website,
    ]) {
      select(type);
      fill(type);
      expect(await viewModel().generateQr(), isNotNull, reason: type.name);
      expect(state().saving.errorMessage, isNull, reason: type.name);
    }

    expect(container.read(authViewModelProvider).isAnonymous, isTrue);
    expect(service.created.map((c) => c.type), [
      QrType.text,
      QrType.wifi,
      QrType.businessCard,
      QrType.website,
    ]);
  });

  group('serveur injoignable', () {
    for (final type in [
      QrType.text,
      QrType.wifi,
      QrType.businessCard,
      QrType.website,
    ]) {
      test('${type.name} : le QR Code est généré sur l’appareil', () async {
        start(offline: true);
        select(type);
        fill(type);

        final result = await viewModel().generateQr();

        expect(result, isNotNull);
        expect(state().result, same(result));
        // Seul avertissement : il n'est pas dans « Mes QR Codes ».
        expect(state().saving.errorMessage, QrContentViewModel.notSavedMessage);
        expect(state().saving.type, type);
        expect(service.created, isEmpty);
      });
    }

    test('réseaux sociaux : la dépendance au serveur est signalée', () async {
      start(offline: true);
      select(QrType.socialMedia);
      fill(QrType.socialMedia);

      expect(await viewModel().generateQr(), isNull);
      expect(state().saving.errorMessage, AuthViewModel.restoreFailedMessage);
    });
  });

  test('enregistrement refusé : le QR Code statique reste généré, puis '
      'une nouvelle génération met à jour le même QR Code', () async {
    start();
    select(QrType.text);
    fill(QrType.text);
    await viewModel().generateQr();
    final saved = state().editing;

    service.error = const ApiException(ApiErrorKind.offline);
    viewModel().updateText('Texte modifié');
    final result = await viewModel().generateQr();

    expect(result?.payload, 'Texte modifié');
    expect(state().editing, same(saved));
    expect(state().saving.errorMessage, QrContentViewModel.notSavedMessage);

    service.error = null;
    await viewModel().generateQr();
    expect(service.updated, [saved!.id]);
    expect(service.created, hasLength(1));
    expect(state().saving.errorMessage, isNull);
  });
}
