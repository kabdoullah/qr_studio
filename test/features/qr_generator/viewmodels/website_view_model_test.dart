import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/qr_code_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

// Site web : saisie, validation, enregistrement et modification.
void main() {
  late ProviderContainer container;
  late FakeQrCodeService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  setUp(() {
    service = FakeQrCodeService();
    container = ProviderContainer(
      overrides: [qrCodeServiceProvider.overrideWithValue(service)],
    );
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.website);
  });
  tearDown(() => container.dispose());

  group('validation', () {
    test('URL obligatoire et valide', () {
      expect(
        QrContentState.validateWebsiteUrl(''),
        "Veuillez saisir l'adresse du site.",
      );
      for (final invalid in [
        'exemple',
        'ftp://exemple.com',
        'javascript:alert(1)',
        'https://user:pw@exemple.com',
        'https://exemple.com/${'a' * 500}',
      ]) {
        expect(QrContentState.validateWebsiteUrl(invalid), isNotNull);
      }
      for (final valid in [
        'https://www.mon-site.com',
        'mon-site.com/page',
        'http://localhost.dev:8080',
      ]) {
        expect(QrContentState.validateWebsiteUrl(valid), isNull, reason: valid);
      }
    });

    test('titre limité à 100 caractères', () {
      expect(QrContentState.validateWebsiteTitle('x' * 101), isNotNull);
      expect(QrContentState.validateWebsiteTitle(''), isNull);
    });
  });

  test('enregistre le site et encode l’adresse publique', () async {
    viewModel().updateWebsite(
      (s) => s.copyWith(title: 'Mon portfolio', url: 'mon-site.com'),
    );

    final result = await viewModel().generateQr();

    // Le QR Code contient l'adresse QR Studio, pas celle du site.
    expect(result?.payload, FakeQrCodeService.publicUrl(1));
    expect(result?.isOnlineLink, isTrue);
    expect(service.created.single.title, 'Mon portfolio');
    expect(service.created.single.content, {'url': 'https://mon-site.com'});
  });

  test('sans titre, le nom du site sert de titre', () async {
    viewModel().updateWebsite((s) => s.copyWith(url: 'https://www.awa.design'));

    await viewModel().generateQr();

    expect(service.created.single.title, 'www.awa.design');
  });

  test('une URL invalide n’est pas enregistrée', () async {
    viewModel().updateWebsite((s) => s.copyWith(url: 'pas une url'));

    expect(await viewModel().generateQr(), isNull);
    expect(service.created, isEmpty);
    expect(state().showErrorsFor, contains(QrType.website));
  });

  test('modifier l’URL garde la même adresse publique', () async {
    viewModel().updateWebsite((s) => s.copyWith(url: 'https://ancien.com'));
    await viewModel().generateQr();

    viewModel().updateWebsite((s) => s.copyWith(url: 'https://nouveau.com'));
    final result = await viewModel().generateQr();

    expect(service.updated, ['qr1']);
    expect(service.items.single.content, {'url': 'https://nouveau.com'});
    expect(result?.payload, FakeQrCodeService.publicUrl(1));
  });

  test('pas d’aperçu avant enregistrement', () {
    viewModel().updateWebsite((s) => s.copyWith(url: 'https://site.com'));

    expect(container.read(livePreviewProvider), isNull);
  });
}
