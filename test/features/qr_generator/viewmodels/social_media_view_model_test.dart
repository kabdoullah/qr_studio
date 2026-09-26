import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';
import 'package:qr_studio/features/qr_generator/models/social_page_data.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/qr_generator/services/qr_code_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeQrCodeService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);
  SocialPageData page() => state().socialPage;

  ProviderContainer createContainer(QrCodeService? qrCodes) {
    final c = ProviderContainer(
      overrides: [qrCodeServiceProvider.overrideWithValue(qrCodes)],
    );
    c
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.socialMedia);
    return c;
  }

  void fillValidPage() {
    viewModel()
      ..updateSocialPage((p) => p.copyWith(title: 'Awa'))
      ..addSocialLink(SocialNetwork.instagram);
    viewModel().updateSocialLink(page().links.single.id, '@awa');
  }

  setUp(() {
    service = FakeQrCodeService();
    container = createContainer(service);
  });
  tearDown(() => container.dispose());

  group('liens', () {
    test('ajoute, modifie et retire des liens', () {
      viewModel()
        ..addSocialLink(SocialNetwork.instagram)
        ..addSocialLink(SocialNetwork.website);
      final [instagram, website] = page().links;

      viewModel().updateSocialLink(website.id, 'awa.design');
      viewModel().removeSocialLink(instagram.id);

      expect(page().links.single.network, SocialNetwork.website);
      expect(page().links.single.value, 'awa.design');
    });

    test('attribue des identifiants distincts', () {
      viewModel()
        ..addSocialLink(SocialNetwork.twitter)
        ..addSocialLink(SocialNetwork.twitter);
      viewModel().removeSocialLink(page().links.first.id);
      viewModel().addSocialLink(SocialNetwork.twitter);

      final ids = page().links.map((l) => l.id).toSet();
      expect(ids, hasLength(2));
    });

    test('limite le nombre de liens', () {
      for (var i = 0; i < SocialPageData.maxLinks + 2; i++) {
        viewModel().addSocialLink(SocialNetwork.website);
      }

      expect(page().links, hasLength(SocialPageData.maxLinks));
    });
  });

  group('validation', () {
    test('exige un titre et au moins un lien valide', () {
      expect(state().isSocialPageValid, isFalse);

      viewModel().updateSocialPage((p) => p.copyWith(title: 'Awa'));
      expect(state().isSocialPageValid, isFalse);

      viewModel().addSocialLink(SocialNetwork.instagram);
      expect(state().isSocialPageValid, isFalse);

      viewModel().updateSocialLink(page().links.single.id, 'https://evil.com');
      expect(state().isSocialPageValid, isFalse);

      viewModel().updateSocialLink(page().links.single.id, '@awa');
      expect(state().isSocialPageValid, isTrue);
    });

    test('messages d’erreur', () {
      expect(
        QrContentState.validateSocialTitle('  '),
        'Veuillez saisir un titre.',
      );
      expect(
        QrContentState.validateSocialLinks(const []),
        'Ajoutez au moins un réseau.',
      );
      expect(
        QrContentState.validateSocialLink(SocialNetwork.whatsapp, 'abc'),
        'Numéro WhatsApp invalide.',
      );
      expect(
        QrContentState.validateSocialLink(SocialNetwork.instagram, ''),
        'Veuillez compléter ce lien.',
      );
    });
  });

  group('generateQr', () {
    test("enregistre le profil et encode l'adresse publique", () async {
      fillValidPage();

      final result = await viewModel().generateQr();

      // Le QR Code contient l'adresse QR Studio, jamais les liens.
      expect(result?.payload, FakeQrCodeService.publicUrl(1));
      expect(result?.type, QrType.socialMedia);
      expect(result?.isOnlineLink, isTrue);
      final created = service.created.single;
      expect(created.type, QrType.socialMedia);
      expect(created.title, 'Awa');
      expect(created.content, {
        'description': '',
        'links': [
          {'platform': 'instagram', 'url': 'https://www.instagram.com/awa'},
        ],
      });
      expect(state().saving.errorMessage, isNull);
    });

    test('modifier met à jour le même QR Code', () async {
      fillValidPage();
      await viewModel().generateQr();

      viewModel().addSocialLink(SocialNetwork.github);
      viewModel().updateSocialLink(page().links.last.id, 'awa');
      final result = await viewModel().generateQr();

      expect(service.created, hasLength(1));
      expect(service.updated, ['qr1']);
      expect(result?.payload, FakeQrCodeService.publicUrl(1));
    });

    test('ne publie pas une page invalide et affiche ses erreurs', () async {
      viewModel().updateSocialPage((p) => p.copyWith(title: 'Awa'));

      final result = await viewModel().generateQr();

      expect(result, isNull);
      expect(service.created, isEmpty);
      expect(state().showErrorsFor, contains(QrType.socialMedia));
    });

    test(
      "indique l'enregistrement en cours et ignore un second appel",
      () async {
        fillValidPage();
        service.gate = Completer<void>();

        final pending = viewModel().generateQr();
        await Future<void>.delayed(Duration.zero);
        expect(state().saving.isSaving, isTrue);
        expect(await viewModel().generateQr(), isNull);

        service.gate!.complete();
        expect(await pending, isNotNull);
        expect(state().saving.isSaving, isFalse);
        expect(service.created, hasLength(1));
      },
    );

    test('message clair en cas d’échec inattendu', () async {
      fillValidPage();
      service.error = Exception('timeout');

      expect(await viewModel().generateQr(), isNull);
      expect(state().saving.errorMessage, QrContentViewModel.saveFailedMessage);
    });

    test('affiche le message du serveur (hors ligne, limite…)', () async {
      fillValidPage();
      service.error = const ApiException(ApiErrorKind.offline);

      await viewModel().generateQr();

      expect(
        state().saving.errorMessage,
        const ApiException(ApiErrorKind.offline).message,
      );
      expect(state().saving.type, QrType.socialMedia);
    });

    test(
      "sans serveur, indique que l'enregistrement est indisponible",
      () async {
        container.dispose();
        container = createContainer(null);
        fillValidPage();

        expect(await viewModel().generateQr(), isNull);
        expect(
          state().saving.errorMessage,
          QrContentViewModel.saveUnavailableMessage,
        );
      },
    );
  });

  test('startOver efface la page', () {
    fillValidPage();

    viewModel().startOver();

    expect(page().title, isEmpty);
    expect(page().links, isEmpty);
  });

  test('pas d’aperçu en direct avant enregistrement', () {
    fillValidPage();

    expect(container.read(livePreviewProvider), isNull);
  });

  test('un titre de 100 caractères est enregistré tel quel', () async {
    fillValidPage();
    viewModel().updateSocialPage((p) => p.copyWith(title: 'T' * 100));

    await viewModel().generateQr();

    expect(service.created.single.title, 'T' * 100);
  });
}
