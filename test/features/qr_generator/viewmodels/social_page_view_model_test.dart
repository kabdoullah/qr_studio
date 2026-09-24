import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';
import 'package:qr_studio/features/qr_generator/models/social_page_data.dart';
import 'package:qr_studio/features/qr_generator/services/social_page_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeSocialPageService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);
  SocialPageData page() => state().socialPage;

  ProviderContainer createContainer(SocialPageService? pageService) {
    final c = ProviderContainer(
      overrides: [socialPageServiceProvider.overrideWithValue(pageService)],
    );
    c
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.socialPage);
    return c;
  }

  void fillValidPage() {
    viewModel()
      ..updateSocialPage((p) => p.copyWith(title: 'Awa'))
      ..addSocialLink(SocialNetwork.instagram);
    viewModel().updateSocialLink(page().links.single.id, '@awa');
  }

  setUp(() {
    service = FakeSocialPageService();
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
        ..addSocialLink(SocialNetwork.x)
        ..addSocialLink(SocialNetwork.x);
      viewModel().removeSocialLink(page().links.first.id);
      viewModel().addSocialLink(SocialNetwork.x);

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
    test('publie la page et encode son URL', () async {
      fillValidPage();

      final result = await viewModel().generateQr();

      expect(result?.payload, service.url);
      expect(result?.type, QrType.socialPage);
      expect(result?.isOnlineLink, isTrue);
      expect(service.published.single.title, 'Awa');
      expect(state().socialPagePublish.errorMessage, isNull);
    });

    test('ne publie pas une page invalide et affiche ses erreurs', () async {
      viewModel().updateSocialPage((p) => p.copyWith(title: 'Awa'));

      final result = await viewModel().generateQr();

      expect(result, isNull);
      expect(service.published, isEmpty);
      expect(state().showErrorsFor, contains(QrType.socialPage));
    });

    test('indique la publication en cours et ignore un second appel', () async {
      fillValidPage();
      service.gate = Completer<void>();

      final pending = viewModel().generateQr();
      expect(state().socialPagePublish.isPublishing, isTrue);
      expect(await viewModel().generateQr(), isNull);

      service.gate!.complete();
      expect(await pending, isNotNull);
      expect(state().socialPagePublish.isPublishing, isFalse);
      expect(service.published, hasLength(1));
    });

    test('message clair en cas d’échec réseau', () async {
      fillValidPage();
      service.error = Exception('timeout');

      expect(await viewModel().generateQr(), isNull);
      expect(
        state().socialPagePublish.errorMessage,
        QrContentViewModel.publishFailedMessage,
      );
    });

    test('message dédié quand le serveur limite les envois', () async {
      fillValidPage();
      service.error = const SocialPageException('429', statusCode: 429);

      await viewModel().generateQr();

      expect(
        state().socialPagePublish.errorMessage,
        QrContentViewModel.publishTooManyMessage,
      );
    });

    test('sans serveur, indique que la publication est indisponible', () async {
      container.dispose();
      container = createContainer(null);
      fillValidPage();

      expect(await viewModel().generateQr(), isNull);
      expect(
        state().socialPagePublish.errorMessage,
        QrContentViewModel.publishUnavailableMessage,
      );
    });
  });

  test('startOver efface la page', () {
    fillValidPage();

    viewModel().startOver();

    expect(page().title, isEmpty);
    expect(page().links, isEmpty);
  });

  test('pas d’aperçu en direct avant publication', () {
    fillValidPage();

    expect(container.read(livePreviewProvider), isNull);
  });
}
