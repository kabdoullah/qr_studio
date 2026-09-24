import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/app/router/app_router.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';
import 'package:qr_studio/features/qr_generator/views/qr_content_view.dart';
import 'package:qr_studio/features/qr_generator/views/qr_generator_view.dart';
import 'package:qr_studio/features/qr_generator/views/qr_result_view.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_result_view_model.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeQrShareService sharer;

  Future<void> pumpApp(WidgetTester tester) async {
    sharer = FakeQrShareService();
    container = ProviderContainer(
      overrides: [
        qrExportServiceProvider.overrideWithValue(FakeQrExportService()),
        qrShareServiceProvider.overrideWithValue(sharer),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Parcours complet jusqu'au résultat d'un QR Code texte.
  Future<void> generateText(WidgetTester tester, String text) async {
    await pumpApp(tester);
    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), text);
    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();
  }

  testWidgets('générer affiche le résultat', (tester) async {
    await generateText(tester, 'Bonjour');

    expect(find.byType(QrResultView), findsOneWidget);
    expect(find.text('Votre QR Code est prêt 🎉'), findsOneWidget);
    expect(find.text(QrType.text.title), findsOneWidget);
    expect(tester.widget<QrPreview>(find.byType(QrPreview)).data, 'Bonjour');
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Créer un nouveau QR Code'), findsOneWidget);
  });

  testWidgets('une saisie invalide ne mène pas au résultat', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.byType(QrResultView), findsNothing);
    expect(find.byType(QrContentView), findsOneWidget);
  });

  testWidgets('« Modifier » revient au formulaire avec les données', (
    tester,
  ) async {
    await generateText(tester, 'Bonjour');

    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(QrContentView), findsOneWidget);
    expect(find.text('Bonjour'), findsWidgets);
  });

  testWidgets('le bouton retour revient au formulaire', (tester) async {
    await generateText(tester, 'Bonjour');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(QrContentView), findsOneWidget);
  });

  testWidgets('« Créer un nouveau QR Code » repart de zéro', (tester) async {
    await generateText(tester, 'Bonjour');

    await tester.ensureVisible(find.text('Créer un nouveau QR Code'));
    await tester.tap(find.text('Créer un nouveau QR Code'));
    await tester.pumpAndSettle();

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.byType(QrResultView), findsNothing);
    expect(container.read(qrGeneratorViewModelProvider), isNull);
    expect(container.read(qrContentViewModelProvider).result, isNull);
    expect(container.read(qrContentViewModelProvider).text.text, isEmpty);

    // L'accueil n'a plus d'écran précédent.
    final router = container.read(appRouterProvider);
    expect(router.canPop(), isFalse);
  });

  testWidgets('la carte de visite mène au résultat', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(QrType.businessCard.title));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prénom *'),
      'Awa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom *'),
      'Traoré',
    );

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Votre QR Code est prêt 🎉'), findsOneWidget);
    expect(find.text(QrType.businessCard.title), findsOneWidget);
  });

  testWidgets('un accès direct sans QR Code redirige vers l’accueil', (
    tester,
  ) async {
    await pumpApp(tester);

    container.read(appRouterProvider).go(AppRoutes.result);
    await tester.pumpAndSettle();
    expect(find.byType(QrGeneratorView), findsOneWidget);

    container.read(appRouterProvider).go(AppRoutes.content);
    await tester.pumpAndSettle();
    expect(find.byType(QrGeneratorView), findsOneWidget);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    await tester.ensureVisible(find.text(QrType.text.title));
    await tester.tap(find.text(QrType.text.title));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Bonjour');
    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.byType(QrResultView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Partager » ouvre le partage de l’image', (tester) async {
    await generateText(tester, 'Bonjour');

    await tester.ensureVisible(find.text('Partager'));
    await tester.tap(find.text('Partager'));
    await tester.pumpAndSettle();

    expect(sharer.shares.single.fileName, 'qr-code-texte.png');
    expect(sharer.shares.single.origin, isNotNull);
  });

  testWidgets('« Télécharger » confirme l’enregistrement', (tester) async {
    await generateText(tester, 'Bonjour');

    await tester.ensureVisible(find.text('Télécharger'));
    await tester.tap(find.text('Télécharger'));
    await tester.pumpAndSettle();

    expect(sharer.saves, ['qr-code-texte.png']);
    expect(find.text(QrResultViewModel.savedMessage), findsOneWidget);
  });

  testWidgets('un échec de partage affiche un message clair', (tester) async {
    await generateText(tester, 'Bonjour');
    sharer.error = Exception('PlatformException');

    await tester.ensureVisible(find.text('Partager'));
    await tester.tap(find.text('Partager'));
    await tester.pumpAndSettle();

    expect(find.text(QrResultViewModel.shareFailedMessage), findsOneWidget);
  });
}
