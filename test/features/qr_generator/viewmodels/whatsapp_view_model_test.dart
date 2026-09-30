import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/saved_qr_code.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';
import 'package:qr_studio/features/qr_generator/services/qr_code_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

// Discussion WhatsApp : QR Code statique (lien wa.me) produit sur
// l'appareil, enregistré sur la session anonyme quand c'est possible.
void main() {
  const url =
      'https://wa.me/2250712345678'
      '?text=Bonjour%2C%20je%20viens%20de%20scanner%20votre%20QR%20Code.';
  late ProviderContainer container;
  late FakeQrCodeService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  // Installation neuve (aucun jeton) ; `offline` : serveur injoignable ;
  // `noBackend` : aucun serveur configuré (ni session ni enregistrement).
  Future<void> start({bool offline = false, bool noBackend = false}) async {
    service = FakeQrCodeService();
    final auth = FakeAuthService();
    if (offline) {
      auth.anonymousError = const ApiException(ApiErrorKind.offline);
    }
    container = ProviderContainer(
      overrides: noBackend
          ? [qrCodeServiceProvider.overrideWithValue(null)]
          : signedIn(auth: auth, storage: FakeTokenStorage(), qrCodes: service),
    );
    if (!noBackend) {
      container.listen(authViewModelProvider, (_, _) {});
      // Session ouverte (ou abandonnée) avant la fin du test.
      await container.read(authViewModelProvider.notifier).ensureSession();
    }
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.socialMedia);
  }

  void fillWhatsApp() {
    viewModel()
      ..setSocialMediaMode(SocialMediaMode.whatsapp)
      ..updateWhatsApp(
        (d) => d.copyWith(
          phone: '+225 07 12 34 56 78',
          message: 'Bonjour, je viens de scanner votre QR Code.',
        ),
      );
  }

  tearDown(() => container.dispose());

  test('titre par défaut : « Contactez-moi sur WhatsApp »', () async {
    await start();
    expect(state().whatsapp.title, 'Contactez-moi sur WhatsApp');
  });

  test('génère le lien wa.me et l’enregistre sur la session anonyme', () async {
    await start();
    fillWhatsApp();

    final result = await viewModel().generateQr();

    expect(result?.payload, url);
    expect(result?.whatsapp?.displayPhone, '+2250712345678');
    expect(container.read(authViewModelProvider).isAnonymous, isTrue);
    final created = service.created.single;
    expect(created.type, QrType.socialMedia);
    expect(created.title, 'Contactez-moi sur WhatsApp');
    expect(created.content, {
      'mode': 'whatsapp',
      'description': '',
      'links': [
        {'platform': 'whatsapp', 'url': 'https://wa.me/2250712345678'},
      ],
      'message': 'Bonjour, je viens de scanner votre QR Code.',
    });
    expect(state().saving.errorMessage, isNull);
  });

  test('hors ligne : généré sur l’appareil, seul un avertissement', () async {
    await start(offline: true);
    fillWhatsApp();

    final result = await viewModel().generateQr();

    expect(result?.payload, url);
    expect(state().saving.errorMessage, QrContentViewModel.notSavedMessage);
    expect(service.created, isEmpty);
  });

  test('sans serveur configuré : généré sans avertissement', () async {
    await start(noBackend: true);
    fillWhatsApp();

    expect((await viewModel().generateQr())?.payload, url);
    expect(state().saving.errorMessage, isNull);
  });

  test('numéro vide : génération refusée, erreurs visibles', () async {
    await start();
    viewModel().setSocialMediaMode(SocialMediaMode.whatsapp);

    expect(await viewModel().generateQr(), isNull);
    expect(state().showErrorsFor, contains(QrType.socialMedia));
    expect(service.created, isEmpty);
  });

  test('aperçu en direct du lien wa.me', () async {
    await start();
    expect(container.read(livePreviewProvider), isNull); // page de liens
    viewModel().setSocialMediaMode(SocialMediaMode.whatsapp);
    expect(container.read(livePreviewProvider)?.payload, isNull);
    fillWhatsApp();
    expect(container.read(livePreviewProvider)?.payload, url);
  });

  test('rouvrir depuis Mes QR Codes restitue la saisie et le QR', () async {
    await start();
    fillWhatsApp();
    viewModel().updateWhatsApp((d) => d.copyWith(title: 'Mon WhatsApp'));
    await viewModel().generateQr();
    final saved = SavedQrCode.fromJson(state().editing!.toJson())!;

    viewModel().startOver();
    final reopened = viewModel().openSaved(saved);

    expect(reopened.payload, url);
    expect(state().socialMediaMode, SocialMediaMode.whatsapp);
    expect(state().whatsapp.title, 'Mon WhatsApp');
    expect(viewModel().resultFor(saved).whatsapp?.title, 'Mon WhatsApp');

    viewModel().updateWhatsApp((d) => d.copyWith(message: ''));
    final updated = await viewModel().generateQr();
    expect(updated?.payload, 'https://wa.me/2250712345678');
    expect(service.updated, [saved.id]);
  });

  test('une page de liens modifiée en WhatsApp crée un nouveau QR Code '
      '(la page imprimée reste intacte)', () async {
    await start();
    viewModel()
      ..updateSocialPage((p) => p.copyWith(title: 'Awa'))
      ..addSocialLink(SocialNetwork.instagram);
    viewModel().updateSocialLink(state().socialPage.links.single.id, '@awa');
    await viewModel().generateQr();

    fillWhatsApp();
    await viewModel().generateQr();

    expect(service.created, hasLength(2));
    expect(service.updated, isEmpty);
  });
}
