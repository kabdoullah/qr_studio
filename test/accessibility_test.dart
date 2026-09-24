import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/services/social_page_service.dart';

import 'helpers/fake_services.dart';

// Vérifie les recommandations d'accessibilité Flutter sur chaque écran.
void main() {
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  late FakeFilePickerService picker;

  Future<void> pumpApp(WidgetTester tester, {ThemeMode? mode}) async {
    picker = FakeFilePickerService()..next = validCv;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filePickerServiceProvider.overrideWithValue(picker),
          fileStorageServiceProvider.overrideWithValue(
            FakeFileStorageService(),
          ),
          businessCardDirectoryProvider.overrideWithValue(
            FakeBusinessCardDirectory([jeanCard, awaCard]),
          ),
          socialPageServiceProvider.overrideWithValue(FakeSocialPageService()),
        ],
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, QrType type) async {
    await tester.ensureVisible(find.text(type.title));
    await tester.tap(find.text(type.title));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    group('thème ${brightness.name}', () {
      setUp(() {
        TestWidgetsFlutterBinding
                .instance
                .platformDispatcher
                .platformBrightnessTestValue =
            brightness;
      });
      tearDown(() {
        TestWidgetsFlutterBinding.instance.platformDispatcher
            .clearPlatformBrightnessTestValue();
      });

      testWidgets('accueil', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('carte de visite avec erreurs', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.businessCard);
        await tester.tap(find.text('Générer le QR Code'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('cartes enregistrées', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.businessCard);
        await expectAccessible(tester);

        await tester.tap(find.text('Choisir une carte enregistrée'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('carte de visite en mode image', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.businessCard);
        await tester.tap(find.text('Image de ma carte'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        picker.next = const SharedFile(name: 'carte.jpg', size: 1000);
        await tester.tap(find.text('Choisir une image'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('texte avec aperçu', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.text);
        await tester.enterText(find.byType(TextFormField), 'Bonjour');
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('CV sélectionné puis résultat', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.cv);
        await expectAccessible(tester);

        await tester.tap(find.text('Choisir un PDF'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.tap(find.text('Générer le QR Code'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('page de réseaux avec erreurs puis confirmation', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await open(tester, QrType.socialPage);
        await tester.tap(find.text('Générer le QR Code'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.enterText(find.byType(TextFormField).first, 'Awa');
        await tester.ensureVisible(find.text('Ajouter un réseau'));
        await tester.tap(find.text('Ajouter un réseau'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.tap(find.text('Instagram'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).last, '@awa');
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.tap(find.text('Générer le QR Code'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });
    });
  }

  testWidgets('page de réseaux sans débordement avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    await open(tester, QrType.socialPage);
    await tester.ensureVisible(find.text('Ajouter un réseau'));
    await tester.tap(find.text('Ajouter un réseau'));
    await tester.pumpAndSettle();
    // Le premier réseau de la liste : les autres sont hors écran.
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();

    expect(find.text('Retirer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
