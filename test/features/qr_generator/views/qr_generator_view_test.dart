import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/views/qr_content_view.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_type_card.dart';

import '../../../helpers/fake_services.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: signedIn(), child: const QrStudioApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("L'accueil affiche une carte par type de QR Code", (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.text('Créez votre QR Code\nsimplement et rapidement.'),
      findsOneWidget,
    );
    expect(find.byType(QrTypeCard), findsNWidgets(QrType.values.length));
    for (final type in QrType.values) {
      expect(find.text(type.title), findsOneWidget);
      expect(find.text(type.description), findsOneWidget);
    }
  });

  testWidgets('Choisir un type ouvre la saisie du contenu', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();

    expect(find.byType(QrContentView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(QrType.text.title),
      ),
      findsOneWidget,
    );

    // Le bouton retour ramène à l'accueil.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(QrTypeCard), findsNWidgets(QrType.values.length));
  });

  testWidgets('Pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
  });
}
