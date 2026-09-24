import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

void main() {
  late ProviderContainer container;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  setUp(() {
    container = ProviderContainer();
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.businessCard);
  });
  tearDown(() => container.dispose());

  group('validation de la carte de visite', () {
    test('prénom et nom sont obligatoires', () {
      expect(state().isBusinessCardValid, isFalse);

      viewModel().updateBusinessCard(
        (c) => c.copyWith(firstName: 'Awa', lastName: 'Traoré'),
      );

      expect(state().isBusinessCardValid, isTrue);
    });

    test('un prénom composé uniquement d’espaces est refusé', () {
      expect(QrContentState.validateFirstName('   '), isNotNull);
    });

    test("l'email est facultatif mais doit être valide", () {
      expect(QrContentState.validateEmail(''), isNull);
      expect(QrContentState.validateEmail('awa@example.com'), isNull);
      expect(
        QrContentState.validateEmail('awa@'),
        'Veuillez saisir une adresse email valide.',
      );
    });
  });

  group('generateQr', () {
    test('refuse un contenu invalide et affiche toutes les erreurs', () async {
      expect(state().showErrorsFor, isEmpty);

      expect(await viewModel().generateQr(), isNull);
      expect(state().showErrorsFor, {QrType.businessCard});
      expect(state().result, isNull);
    });

    test('produit une vCard pour une carte de visite valide', () async {
      viewModel().updateBusinessCard(
        (c) => c.copyWith(firstName: 'Awa', lastName: 'Traoré'),
      );

      final result = await viewModel().generateQr();

      expect(result, isNotNull);
      expect(result!.type, QrType.businessCard);
      expect(result.payload, startsWith('BEGIN:VCARD'));
      expect(result.payload, contains('FN:Awa Traoré'));
      expect(state().result, same(result));
    });
  });

  group('aperçu de la carte de visite', () {
    test('attend le prénom et le nom', () {
      final preview = container.read(livePreviewProvider);

      expect(preview?.payload, isNull);
      expect(preview?.message, contains('prénom et votre nom'));
    });

    test('affiche la vCard dès que la carte est valide', () {
      viewModel().updateBusinessCard(
        (c) => c.copyWith(firstName: 'Awa', lastName: 'Traoré'),
      );

      expect(
        container.read(livePreviewProvider)?.payload,
        contains('FN:Awa Traoré'),
      );
    });

    test('signale une carte trop longue et refuse de la générer', () async {
      final long = 'é' * 200;
      viewModel().updateBusinessCard(
        (c) => c.copyWith(
          firstName: 'Awa',
          lastName: 'Traoré',
          jobTitle: long,
          company: long,
          address: long,
          city: long,
          country: long,
          website: long,
          linkedin: long,
        ),
      );

      final preview = container.read(livePreviewProvider);
      expect(preview?.payload, isNull);
      expect(preview?.message, contains('trop longues'));
      expect(await viewModel().generateQr(), isNull);
    });
  });

  test("le CV n'a pas d'aperçu en direct", () {
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.cv);

    expect(container.read(livePreviewProvider), isNull);
  });

  test('reset efface la saisie', () async {
    viewModel().updateBusinessCard((c) => c.copyWith(firstName: 'Awa'));
    await viewModel().generateQr();

    viewModel().reset();

    expect(state().businessCard.firstName, isEmpty);
    expect(state().showErrorsFor, isEmpty);
    expect(state().result, isNull);
  });

  group('texte', () {
    setUp(() {
      container
          .read(qrGeneratorViewModelProvider.notifier)
          .selectQrType(QrType.text);
    });

    test('updateText met à jour le texte', () {
      viewModel().updateText('Bonjour');

      expect(state().text.text, 'Bonjour');
      expect(state().isTextValid, isTrue);
    });

    test('un texte vide ou trop long est invalide', () {
      expect(QrContentState.validateText('  '), 'Veuillez saisir un texte.');
      expect(QrContentState.validateText('😊' * 1000), isNotNull);
    });

    test("l'aperçu en direct suit la saisie", () {
      LivePreview? preview() => container.read(livePreviewProvider);
      expect(preview()?.payload, isNull);
      expect(preview()?.message, isNotNull);

      viewModel().updateText('Bonjour');
      expect(preview()?.payload, 'Bonjour');

      viewModel().updateText('');
      expect(preview()?.payload, isNull);
    });

    test("l'aperçu explique pourquoi un texte trop long n'est pas affiché", () {
      viewModel().updateText('😊' * 1000);

      final preview = container.read(livePreviewProvider);
      expect(preview?.payload, isNull);
      expect(preview?.message, QrContentState.validateText('😊' * 1000));
    });

    test('generateQr encode le texte', () async {
      viewModel().updateText('Bonjour');

      final result = await viewModel().generateQr();

      expect(result?.type, QrType.text);
      expect(result?.payload, 'Bonjour');
    });

    test('generateQr refuse un texte vide', () async {
      expect(await viewModel().generateQr(), isNull);
      // Seules les erreurs du texte deviennent visibles.
      expect(state().showErrorsFor, {QrType.text});
    });
  });
}
