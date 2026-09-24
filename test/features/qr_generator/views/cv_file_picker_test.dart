import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late FakeFilePickerService picker;

  Future<void> openCv(
    WidgetTester tester, {
    FileStorageService storage = const BackendRequiredFileStorageService(),
  }) async {
    picker = FakeFilePickerService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filePickerServiceProvider.overrideWithValue(picker),
          fileStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(QrType.cv.title));
    await tester.tap(find.text(QrType.cv.title));
    await tester.pumpAndSettle();
  }

  testWidgets('invite à choisir un PDF', (tester) async {
    await openCv(tester);

    expect(find.text('Partagez votre CV'), findsOneWidget);
    expect(find.text('Choisir un PDF'), findsOneWidget);
    expect(find.text('PDF uniquement · 10 MB maximum'), findsOneWidget);
  });

  testWidgets('affiche le fichier sélectionné', (tester) async {
    await openCv(tester);
    picker.next = validCv;

    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    expect(find.text('CV_Abdoullah_Coulibaly.pdf'), findsOneWidget);
    expect(find.text('1.8 MB'), findsOneWidget);
    expect(find.text('PDF sélectionné'), findsOneWidget);
    expect(find.text('Remplacer'), findsOneWidget);
  });

  testWidgets('signale un fichier trop volumineux', (tester) async {
    await openCv(tester);
    picker.next = const SharedFile(name: 'cv.pdf', size: 12 * 1024 * 1024);

    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Votre fichier est trop volumineux.\n'
        'La taille maximale est de 10 MB.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choisir un PDF'), findsOneWidget);
  });

  testWidgets('sans backend, indique que la mise en ligne est indisponible', (
    tester,
  ) async {
    await openCv(tester);
    picker.next = validCv;
    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text(SharedFileKind.cv.unavailableMessage), findsOneWidget);
    expect(find.text('PDF sélectionné'), findsOneWidget);
  });

  testWidgets('avec un backend, le CV est mis en ligne puis affiché', (
    tester,
  ) async {
    await openCv(tester, storage: FakeFileStorageService());
    picker.next = validCv;
    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Votre CV est prêt 🎉'), findsOneWidget);
    expect(find.text('CV_Abdoullah_Coulibaly.pdf'), findsOneWidget);
    expect(find.text('https://qrstudio.app/cv/a82f91d3'), findsOneWidget);

    // Au retour, le CV est indiqué comme déjà en ligne.
    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('CV en ligne'), findsOneWidget);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openCv(tester);
    picker.next = validCv;
    await tester.ensureVisible(find.text('Choisir un PDF'));
    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets("pendant l'envoi, la progression est visible et les boutons "
      'désactivés', (tester) async {
    final storage = FakeFileStorageService()..gate = Completer<void>();
    await openCv(tester, storage: storage);
    picker.next = validCv;
    await tester.tap(find.text('Choisir un PDF'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pump();

    expect(find.text('Envoi en cours…'), findsOneWidget);
    // Le bouton explique pourquoi il est indisponible.
    expect(find.text('Générer le QR Code'), findsNothing);
    FilledButton generate() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Envoi du fichier…'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    ButtonStyleButton replace() => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Remplacer'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(generate().onPressed, isNull);
    expect(replace().onPressed, isNull);

    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Votre CV est prêt 🎉'), findsOneWidget);
  });
}
