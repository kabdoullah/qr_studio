import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:qr_studio/app/theme/app_theme.dart';
import 'package:qr_studio/features/qr_generator/models/qr_style.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester,
    String data, {
    double width = 400,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: QrPreview(data: data),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('affiche le QR Code à la taille du style', (tester) async {
    await pumpPreview(tester, 'Bonjour');

    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(find.bySemanticsLabel('Aperçu du QR Code'), findsOneWidget);
    final box = tester.getSize(
      find.descendant(
        of: find.byType(QrPreview),
        matching: find.byType(Container),
      ),
    );
    expect(box.width, const QrStyle().size);
  });

  testWidgets("se réduit à la largeur disponible", (tester) async {
    await pumpPreview(tester, 'Bonjour', width: 200);

    final box = tester.getSize(
      find.descendant(
        of: find.byType(QrPreview),
        matching: find.byType(Container),
      ),
    );
    expect(box.width, 200);
  });

  testWidgets(
    'affiche un message clair si le contenu est impossible à encoder',
    (tester) async {
      await pumpPreview(tester, 'x' * 5000);

      expect(
        find.text(
          'Impossible de générer le QR Code.\n'
          'Veuillez vérifier les informations saisies.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
