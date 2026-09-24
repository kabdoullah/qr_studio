import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_code_data.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';

void main() {
  testWidgets('exporte un PNG carré en haute résolution', (tester) async {
    await tester.runAsync(() async {
      const data = QrCodeData(type: QrType.text, payload: 'Bonjour');

      final png = await const QrExportService().exportPng(data);

      // Signature PNG.
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);

      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, QrExportService.defaultSize);
      expect(image.height, QrExportService.defaultSize);

      final pixels = (await image.toByteData())!;
      int red(int x, int y) => pixels.getUint8((y * image.width + x) * 4);

      // La marge (« quiet zone ») est blanche…
      expect(red(5, 5), 255);
      // … et le QR contient des modules noirs.
      final hasDark = Iterable<int>.generate(
        image.width,
      ).any((x) => red(x, image.height ~/ 2) < 50);
      expect(hasDark, isTrue);
    });
  });

  testWidgets('respecte la taille demandée', (tester) async {
    await tester.runAsync(() async {
      const data = QrCodeData(type: QrType.text, payload: 'Bonjour');

      final Uint8List png = await const QrExportService().exportPng(
        data,
        size: 512,
      );
      final codec = await ui.instantiateImageCodec(png);
      expect((await codec.getNextFrame()).image.width, 512);
    });
  });
}
