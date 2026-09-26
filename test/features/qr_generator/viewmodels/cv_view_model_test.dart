import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeFilePickerService picker;
  late FakeFileStorageService storage;
  late FakeQrCodeService qrCodes;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  FileState cv() => container.read(qrContentViewModelProvider).cv;

  setUp(() {
    picker = FakeFilePickerService();
    storage = FakeFileStorageService();
    qrCodes = FakeQrCodeService();
    container = ProviderContainer(
      overrides: [
        ...signedIn(qrCodes: qrCodes),
        filePickerServiceProvider.overrideWithValue(picker),
        fileStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.cv);
  });
  tearDown(() => container.dispose());

  group('pickCv', () {
    test('retient un PDF valide', () async {
      picker.next = validCv;

      await viewModel().pickCv();

      expect(cv().status, FileStatus.fileSelected);
      expect(cv().file, same(validCv));
      expect(cv().errorMessage, isNull);
    });

    test('passe par l’état « selecting » pendant la sélection', () async {
      picker
        ..next = validCv
        ..gate = Completer<void>();

      final pending = viewModel().pickCv();
      expect(cv().status, FileStatus.selecting);
      expect(cv().isBusy, isTrue);

      // Un second appel pendant la sélection est ignoré.
      await viewModel().pickCv();
      expect(picker.calls, 1);

      picker.gate!.complete();
      await pending;
      expect(cv().status, FileStatus.fileSelected);
    });

    test('refuse un fichier trop volumineux', () async {
      picker.next = const SharedFile(
        name: 'cv.pdf',
        size: SharedFileKind.maxSizeBytes + 1,
      );

      await viewModel().pickCv();

      expect(cv().file, isNull);
      expect(cv().status, FileStatus.noFile);
      expect(
        cv().errorMessage,
        'Votre fichier est trop volumineux.\n'
        'La taille maximale est de 10 MB.',
      );
    });

    test('accepte exactement 10 MB', () async {
      picker.next = const SharedFile(
        name: 'cv.pdf',
        size: SharedFileKind.maxSizeBytes,
      );

      await viewModel().pickCv();

      expect(cv().status, FileStatus.fileSelected);
    });

    test('refuse un fichier qui n’est pas un PDF', () async {
      picker.next = const SharedFile(name: 'cv.docx', size: 1000);

      await viewModel().pickCv();

      expect(cv().file, isNull);
      expect(cv().errorMessage, 'Veuillez sélectionner un fichier PDF.');
    });

    test('un fichier refusé conserve le CV déjà sélectionné', () async {
      picker.next = validCv;
      await viewModel().pickCv();

      picker.next = const SharedFile(name: 'vide.pdf', size: 0);
      await viewModel().pickCv();

      expect(cv().file, same(validCv));
      expect(cv().status, FileStatus.fileSelected);
      expect(cv().errorMessage, 'Ce fichier est vide.');
    });

    test('une annulation conserve le CV et efface l’erreur', () async {
      picker.next = validCv;
      await viewModel().pickCv();
      picker.next = const SharedFile(name: 'cv.txt', size: 10);
      await viewModel().pickCv();

      picker.next = null;
      await viewModel().pickCv();

      expect(cv().file, same(validCv));
      expect(cv().errorMessage, isNull);
    });

    test('une erreur technique affiche un message compréhensible', () async {
      picker.error = PlatformException(code: 'unknown_path');

      await viewModel().pickCv();

      expect(
        cv().errorMessage,
        'Impossible de sélectionner le fichier.\nVeuillez réessayer.',
      );
      expect(cv().errorMessage, isNot(contains('PlatformException')));
    });
  });

  group('generateQr pour un CV', () {
    test('sans fichier, demande de sélectionner un CV', () async {
      expect(await viewModel().generateQr(), isNull);
      expect(cv().errorMessage, SharedFileKind.cv.missingMessage);
      expect(storage.uploads, 0);
    });

    test("met le CV en ligne et encode l'adresse publique", () async {
      picker.next = validCv;
      await viewModel().pickCv();

      final result = await viewModel().generateQr();

      expect(result?.type, QrType.cv);
      expect(result?.payload, FakeQrCodeService.publicUrl(1));
      expect(cv().status, FileStatus.uploaded);
      expect(cv().file?.remoteUrl, 'https://qrstudio.app/cv/a82f91d3');
    });

    test("ne renvoie pas un CV déjà en ligne", () async {
      picker.next = validCv;
      await viewModel().pickCv();
      await viewModel().generateQr();

      await viewModel().generateQr();

      expect(storage.uploads, 1);
    });

    test('sans backend, aucun QR Code n’est produit', () async {
      storage.error = const FileStorageUnavailableException();
      picker.next = validCv;
      await viewModel().pickCv();

      expect(await viewModel().generateQr(), isNull);
      expect(cv().status, FileStatus.fileSelected);
      expect(cv().file?.remoteUrl, isNull);
      expect(cv().errorMessage, SharedFileKind.cv.unavailableMessage);
      expect(container.read(qrContentViewModelProvider).result, isNull);
    });

    test("un échec d'envoi affiche un message compréhensible", () async {
      storage.error = Exception('SocketException');
      picker.next = validCv;
      await viewModel().pickCv();

      expect(await viewModel().generateQr(), isNull);
      expect(cv().errorMessage, SharedFileKind.cv.uploadFailedMessage);
    });
  });

  test("l'implémentation par défaut exige un backend", () async {
    const service = BackendRequiredFileStorageService();

    expect(
      () => service.upload(validCv, SharedFileKind.cv),
      throwsA(isA<FileStorageUnavailableException>()),
    );
  });

  test('reset efface le CV', () async {
    picker.next = validCv;
    await viewModel().pickCv();

    viewModel().reset();

    expect(cv().file, isNull);
    expect(cv().status, FileStatus.noFile);
  });

  test('enregistre le CV sous son nom, limité à 100 caractères', () async {
    picker.next = SharedFile(
      name: '${'CV très détaillé ' * 10}.pdf',
      size: 1000,
      localPath: '/tmp/cv.pdf',
    );
    await viewModel().pickCv();

    await viewModel().generateQr();

    final created = qrCodes.created.single;
    expect(created.title.length, 100);
    expect(created.title, endsWith('…'));
    expect(created.content, {'file_id': FakeFileStorageService.fileId});
  });
}
