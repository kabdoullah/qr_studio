import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';

import '../../../helpers/fake_file_picker_platform.dart';

void main() {
  late FakeFilePickerPlatform platform;
  const service = FilePickerService();

  setUp(() {
    platform = FakeFilePickerPlatform();
    FilePickerPlatform.instance = platform;
  });

  test('limite le sélecteur aux fichiers PDF', () async {
    await service.pickPdf();

    expect(platform.lastType, FileType.custom);
    expect(platform.lastExtensions, ['pdf']);
  });

  test("renvoie null si l'utilisateur annule", () async {
    expect(await service.pickPdf(), isNull);
  });

  test('décrit le fichier sans le charger en mémoire', () async {
    final file = FakePlatformFile(
      name: 'CV.pdf',
      knownSize: 1887437,
      path: '/cache/CV.pdf',
    );
    platform.pickedFile = file;

    final cv = await service.pickPdf();

    expect(cv?.name, 'CV.pdf');
    expect(cv?.size, 1887437);
    expect(cv?.localPath, '/cache/CV.pdf');
    expect(cv?.remoteUrl, isNull);
    expect(file.readCount, 0);
  });

  test("lit la taille si le sélecteur ne l'a pas fournie", () async {
    platform.pickedFile = FakePlatformFile(name: 'CV.pdf', readSize: 2048);

    expect((await service.pickPdf())?.size, 2048);
  });

  test('échoue si la taille est inconnue', () async {
    platform.pickedFile = FakePlatformFile(name: 'CV.pdf');

    expect(service.pickPdf(), throwsStateError);
  });

  group('pickImage', () {
    test(
      'ouvre la galerie en demandant un format compatible sur iOS',
      () async {
        await service.pickImage();

        expect(platform.lastType, FileType.image);
        expect(
          platform.lastDarwinOptions?.assetRepresentationMode,
          DarwinAssetRepresentationMode.compatible,
        );
      },
    );

    test("décrit l'image sans la charger en mémoire", () async {
      final file = FakePlatformFile(
        name: 'carte.jpg',
        knownSize: 850000,
        path: '/cache/carte.jpg',
      );
      platform.pickedFile = file;

      final image = await service.pickImage();

      expect(image?.name, 'carte.jpg');
      expect(image?.size, 850000);
      expect(image?.localPath, '/cache/carte.jpg');
      expect(file.readCount, 0);
    });
  });
}
