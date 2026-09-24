import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

const cardImage = SharedFile(
  name: 'carte.jpg',
  size: 850000,
  localPath: '/cache/carte.jpg',
);

void main() {
  late ProviderContainer container;
  late FakeFilePickerService picker;
  late FakeFileStorageService storage;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  setUp(() {
    picker = FakeFilePickerService();
    storage = FakeFileStorageService(url: 'https://qrstudio.app/card/b7c1');
    container = ProviderContainer(
      overrides: [
        filePickerServiceProvider.overrideWithValue(picker),
        fileStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.businessCard);
  });
  tearDown(() => container.dispose());

  test('les coordonnées sont le mode par défaut', () {
    expect(state().businessCardMode, BusinessCardMode.details);
  });

  test('changer de mode conserve les coordonnées saisies', () {
    viewModel().updateBusinessCard((c) => c.copyWith(firstName: 'Awa'));

    viewModel().setBusinessCardMode(BusinessCardMode.image);
    viewModel().setBusinessCardMode(BusinessCardMode.details);

    expect(state().businessCard.firstName, 'Awa');
  });

  group('pickCardImage', () {
    test('retient une image JPG ou PNG', () async {
      for (final name in ['carte.jpg', 'CARTE.JPEG', 'carte.png']) {
        picker.next = SharedFile(name: name, size: 1000);
        await viewModel().pickCardImage();
        expect(state().cardImage.file?.name, name);
      }
      expect(state().cardImage.status, FileStatus.fileSelected);
    });

    test("refuse un format qu'un navigateur ne sait pas afficher", () async {
      picker.next = const SharedFile(name: 'carte.heic', size: 1000);

      await viewModel().pickCardImage();

      expect(state().cardImage.file, isNull);
      expect(
        state().cardImage.errorMessage,
        'Veuillez sélectionner une image JPG ou PNG.',
      );
    });

    test('refuse une image trop volumineuse', () async {
      picker.next = const SharedFile(
        name: 'carte.png',
        size: SharedFileKind.maxSizeBytes + 1,
      );

      await viewModel().pickCardImage();

      expect(state().cardImage.errorMessage, contains('trop volumineux'));
    });

    test("n'affecte pas le CV", () async {
      picker.next = cardImage;

      await viewModel().pickCardImage();

      expect(state().cv.file, isNull);
    });
  });

  group('generateQr en mode image', () {
    setUp(() => viewModel().setBusinessCardMode(BusinessCardMode.image));

    test('sans image, demande de la sélectionner', () async {
      expect(await viewModel().generateQr(), isNull);
      expect(
        state().cardImage.errorMessage,
        SharedFileKind.businessCardImage.missingMessage,
      );
      expect(storage.uploads, 0);
    });

    test("met l'image en ligne et encode son lien", () async {
      picker.next = cardImage;
      await viewModel().pickCardImage();

      final result = await viewModel().generateQr();

      expect(result?.type, QrType.businessCard);
      expect(result?.payload, 'https://qrstudio.app/card/b7c1');
      expect(result?.file?.name, 'carte.jpg');
      expect(storage.kinds, [SharedFileKind.businessCardImage]);
      expect(state().cardImage.status, FileStatus.uploaded);
    });

    test('ignore les coordonnées incomplètes', () async {
      picker.next = cardImage;
      await viewModel().pickCardImage();

      // Prénom et nom vides : sans importance en mode image.
      expect(await viewModel().generateQr(), isNotNull);
    });

    test('sans backend, aucun QR Code n’est produit', () async {
      storage.error = const FileStorageUnavailableException();
      picker.next = cardImage;
      await viewModel().pickCardImage();

      expect(await viewModel().generateQr(), isNull);
      expect(
        state().cardImage.errorMessage,
        "La mise en ligne des images n'est pas encore disponible.\n"
        'Votre QR Code pourra être créé dès son ouverture.',
      );
      expect(state().result, isNull);
    });

    test("pas d'aperçu en direct avant la mise en ligne", () {
      expect(container.read(livePreviewProvider), isNull);
    });
  });

  test('revenir aux coordonnées génère de nouveau une vCard', () async {
    picker.next = cardImage;
    viewModel().setBusinessCardMode(BusinessCardMode.image);
    await viewModel().pickCardImage();
    viewModel()
      ..setBusinessCardMode(BusinessCardMode.details)
      ..updateBusinessCard(
        (c) => c.copyWith(firstName: 'Awa', lastName: 'Traoré'),
      );

    final result = await viewModel().generateQr();

    expect(result?.payload, startsWith('BEGIN:VCARD'));
    expect(result?.file, isNull);
    expect(storage.uploads, 0);
  });
}
