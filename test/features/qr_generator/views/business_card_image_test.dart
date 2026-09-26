import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late FakeFilePickerService picker;

  Future<void> openImageMode(
    WidgetTester tester, {
    FileStorageService storage = const BackendRequiredFileStorageService(),
  }) async {
    picker = FakeFilePickerService()
      ..next = const SharedFile(
        name: 'carte.jpg',
        size: 850 * 1024,
        localPath: '/fichier/inexistant.jpg',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          filePickerServiceProvider.overrideWithValue(picker),
          fileStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(QrType.businessCard.title));
    await tester.tap(find.text(QrType.businessCard.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Image de ma carte'));
    await tester.tap(find.text('Image de ma carte'));
    await tester.pumpAndSettle();
  }

  Future<void> pickImage(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Choisir une image'));
    await tester.tap(find.text('Choisir une image'));
    await tester.pumpAndSettle();
  }

  testWidgets('le mode image remplace le formulaire', (tester) async {
    await openImageMode(tester);

    expect(find.text("Ajoutez l'image de votre carte"), findsOneWidget);
    expect(find.text('JPG ou PNG · 10 MB maximum'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Prénom *'), findsNothing);
    // Pas d'aperçu avant la mise en ligne.
    expect(find.text('Aperçu'), findsNothing);
  });

  testWidgets("affiche l'image sélectionnée", (tester) async {
    await openImageMode(tester);

    await pickImage(tester);

    expect(find.text('carte.jpg'), findsOneWidget);
    expect(find.text('850 KB'), findsOneWidget);
    expect(find.text('Image sélectionnée'), findsOneWidget);
    // Fichier illisible : l'icône remplace la miniature, sans erreur.
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans backend, indique que la mise en ligne est indisponible', (
    tester,
  ) async {
    await openImageMode(tester);
    await pickImage(tester);

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(
      find.text(SharedFileKind.businessCardImage.unavailableMessage),
      findsOneWidget,
    );
  });

  testWidgets('avec un backend, le QR Code contient l’adresse publique', (
    tester,
  ) async {
    await openImageMode(
      tester,
      storage: FakeFileStorageService(url: 'https://qrstudio.app/card/b7c1'),
    );
    await pickImage(tester);

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Votre QR Code est prêt'), findsOneWidget);
    expect(find.text('carte.jpg'), findsOneWidget);
    expect(find.text(FakeQrCodeService.publicUrl(1)), findsOneWidget);
    expect(
      tester.widget<QrPreview>(find.byType(QrPreview)).data,
      FakeQrCodeService.publicUrl(1),
    );

    // « Modifier » revient au mode image, avec l'image marquée en ligne.
    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Image en ligne'), findsOneWidget);
  });

  testWidgets('les coordonnées saisies sont conservées en changeant de mode', (
    tester,
  ) async {
    await openImageMode(tester);
    await tester.tap(find.text('Mes coordonnées'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prénom *'),
      'Awa',
    );

    await tester.tap(find.text('Image de ma carte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes coordonnées'));
    await tester.pumpAndSettle();

    expect(find.text('Awa'), findsOneWidget);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openImageMode(tester);
    await pickImage(tester);

    expect(tester.takeException(), isNull);
  });
}
