import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

void main() {
  late ProviderContainer container;

  Future<void> openText(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(QrType.text.title));
    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();
  }

  Finder textField() => find.byType(TextFormField);

  testWidgets('affiche le champ, le compteur et un aperçu vide', (
    tester,
  ) async {
    await openText(tester);

    expect(find.text('Votre texte'), findsOneWidget);
    expect(find.text('0 / 1000'), findsOneWidget);
    expect(find.byType(QrPreview), findsNothing);
    expect(
      find.text('Votre QR Code apparaîtra ici pendant la saisie.'),
      findsOneWidget,
    );
  });

  testWidgets('le compteur et le QR se mettent à jour pendant la saisie', (
    tester,
  ) async {
    await openText(tester);

    await tester.enterText(textField(), 'Bonjour');
    await tester.pumpAndSettle();

    expect(find.text('7 / 1000'), findsOneWidget);
    final preview = tester.widget<QrPreview>(find.byType(QrPreview));
    expect(preview.data, 'Bonjour');
  });

  testWidgets('la saisie est limitée à 1000 caractères', (tester) async {
    await openText(tester);

    await tester.enterText(textField(), 'a' * 1200);
    await tester.pump();

    expect(container.read(qrContentViewModelProvider).text.text.length, 1000);
    expect(find.text('1000 / 1000'), findsOneWidget);
  });

  testWidgets('générer sans texte affiche une erreur', (tester) async {
    await openText(tester);

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir un texte.'), findsOneWidget);
  });

  testWidgets('le texte est conservé au retour', (tester) async {
    await openText(tester);
    await tester.enterText(textField(), 'Bonjour');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour'), findsOneWidget);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openText(tester);
    await tester.enterText(textField(), 'Bonjour');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
