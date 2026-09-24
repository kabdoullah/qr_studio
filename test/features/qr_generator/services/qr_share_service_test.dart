import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';

import '../../../helpers/fake_file_picker_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final shared = <Map<Object?, Object?>>[];

  setUp(() {
    shared.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          shared.add(call.arguments as Map<Object?, Object?>);
          return 'dev.fluttercommunity.plus/share/success';
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('partage le PNG sous forme de fichier image', () async {
    await const QrShareService().sharePng(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'qr-code-cv.png',
      text: 'https://qrstudio.app/cv/a82f91d3',
    );

    final params = shared.single;
    final path = (params['paths']! as List).single as String;
    expect(path, endsWith('qr-code-cv.png'));
    expect(params['mimeTypes'], ['image/png']);
    expect(params['text'], 'https://qrstudio.app/cv/a82f91d3');
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });

  test('ne conserve que la dernière image partagée', () async {
    const service = QrShareService();
    await service.sharePng(Uint8List(1), fileName: 'qr-code-texte.png');
    final first = (shared.last['paths']! as List).single as String;

    await service.sharePng(Uint8List(1), fileName: 'qr-code-cv.png');
    final second = (shared.last['paths']! as List).single as String;

    expect(File(first).existsSync(), isFalse);
    expect(File(second).existsSync(), isTrue);
    expect(File(second).parent.listSync(), hasLength(1));
  });

  group('savePng', () {
    late FakeFilePickerPlatform platform;

    setUp(() {
      platform = FakeFilePickerPlatform();
      FilePickerPlatform.instance = platform;
    });

    test('ouvre « Enregistrer sous » avec un PNG nommé', () async {
      final saved = await const QrShareService().savePng(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'qr-code-texte.png',
      );

      expect(saved, isTrue);
      expect(platform.lastSave?.fileName, 'qr-code-texte.png');
      expect(platform.lastSave?.mimeType, 'image/png');
      expect(platform.lastSave?.bytes, [1, 2, 3]);
    });

    test("renvoie false si l'utilisateur annule", () async {
      platform.savedUri = null;

      expect(
        await const QrShareService().savePng(
          Uint8List(1),
          fileName: 'qr-code-texte.png',
        ),
        isFalse,
      );
    });
  });
}
