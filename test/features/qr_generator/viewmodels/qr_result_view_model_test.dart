import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_code_data.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_result_view_model.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeQrExportService exporter;
  late FakeQrShareService sharer;

  const text = QrCodeData(type: QrType.text, payload: 'Bonjour');
  final cv = QrCodeData(
    type: QrType.cv,
    payload: 'https://qrstudio.app/cv/a82f91d3',
    file: validCv.withRemote(
      const RemoteFile(id: 'a82f91d3', url: 'https://qrstudio.app/cv/a82f91d3'),
    ),
  );

  QrResultViewModel viewModel() =>
      container.read(qrResultViewModelProvider.notifier);

  setUp(() {
    exporter = FakeQrExportService();
    sharer = FakeQrShareService();
    container = ProviderContainer(
      overrides: [
        ...signedIn(),
        qrExportServiceProvider.overrideWithValue(exporter),
        qrShareServiceProvider.overrideWithValue(sharer),
      ],
    );
  });
  tearDown(() => container.dispose());

  group('download', () {
    test('enregistre le PNG avec un nom explicite', () async {
      final message = await viewModel().download(text);

      expect(message, QrResultViewModel.savedMessage);
      expect(exporter.exported.single, same(text));
      expect(sharer.saves, ['qr-code-texte.png']);
    });

    test("ne dit rien si l'utilisateur annule", () async {
      sharer.saveAccepted = false;

      expect(await viewModel().download(text), isNull);
    });

    test('traduit une erreur en message compréhensible', () async {
      exporter.error = StateError('boom');

      expect(
        await viewModel().download(text),
        QrResultViewModel.saveFailedMessage,
      );
      expect(container.read(qrResultViewModelProvider), isNull);
    });
  });

  group('share', () {
    test("partage l'image et la position du bouton", () async {
      const origin = Rect.fromLTWH(10, 20, 100, 40);

      final message = await viewModel().share(text, origin: origin);

      expect(message, isNull);
      expect(sharer.shares.single.fileName, 'qr-code-texte.png');
      expect(sharer.shares.single.text, isNull);
      expect(sharer.shares.single.origin, origin);
    });

    test('joint le lien pour un CV', () async {
      await viewModel().share(cv);

      expect(sharer.shares.single.text, 'https://qrstudio.app/cv/a82f91d3');
      expect(sharer.shares.single.fileName, 'qr-code-cv.png');
    });

    test('traduit une erreur en message compréhensible', () async {
      sharer.error = Exception('PlatformException');

      expect(
        await viewModel().share(text),
        QrResultViewModel.shareFailedMessage,
      );
    });
  });

  test('une seule action à la fois', () async {
    final gate = Completer<void>();
    final slowExporter = _SlowExporter(gate.future);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        ...signedIn(),
        qrExportServiceProvider.overrideWithValue(slowExporter),
        qrShareServiceProvider.overrideWithValue(sharer),
      ],
    );

    final pending = viewModel().share(text);
    expect(container.read(qrResultViewModelProvider), QrResultAction.share);

    expect(await viewModel().download(text), isNull);
    expect(sharer.saves, isEmpty);

    gate.complete();
    await pending;
    expect(container.read(qrResultViewModelProvider), isNull);
    expect(sharer.shares, hasLength(1));
  });
}

class _SlowExporter extends FakeQrExportService {
  _SlowExporter(this.gate);

  final Future<void> gate;

  @override
  Future<Uint8List> exportPng(
    QrCodeData data, {
    int size = QrExportService.defaultSize,
  }) async {
    await gate;
    return super.exportPng(data, size: size);
  }
}
