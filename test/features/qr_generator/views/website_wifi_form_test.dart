import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/views/qr_result_view.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_live_preview.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late FakeQrCodeService service;

  Future<void> open(WidgetTester tester, QrType type) async {
    service = FakeQrCodeService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedIn(qrCodes: service),
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(type.title));
    await tester.tap(find.text(type.title));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> generate(WidgetTester tester) async {
    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();
  }

  group('validation champ par champ', () {
    testWidgets('saisir le réseau ne signale pas le mot de passe vide', (
      tester,
    ) async {
      await open(tester, QrType.wifi);

      await tester.enterText(field('Nom du réseau (SSID) *'), 'Maison');
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir le mot de passe.'), findsNothing);
    });

    testWidgets('saisir le titre ne signale pas l’URL vide', (tester) async {
      await open(tester, QrType.website);

      await tester.enterText(field('Titre'), 'Mon portfolio');
      await tester.pumpAndSettle();

      expect(find.textContaining('Veuillez'), findsNothing);
    });

    testWidgets('Générer signale tous les champs, puis chacun se corrige', (
      tester,
    ) async {
      await open(tester, QrType.wifi);

      await generate(tester);
      expect(find.text('Veuillez saisir le mot de passe.'), findsOneWidget);

      await tester.enterText(field('Mot de passe *'), 'motdepasse');
      await tester.pumpAndSettle();
      expect(find.text('Veuillez saisir le mot de passe.'), findsNothing);
    });
  });

  group('Site Web', () {
    testWidgets('URL invalide signalée en ligne', (tester) async {
      await open(tester, QrType.website);

      await tester.enterText(field('URL du site *'), 'pas une url');
      await tester.pumpAndSettle();

      expect(
        find.text('Adresse du site invalide (ex. https://exemple.com).'),
        findsOneWidget,
      );
    });

    testWidgets('génère le QR Code vers l’adresse publique', (tester) async {
      await open(tester, QrType.website);

      await tester.enterText(field('Titre'), 'Mon portfolio');
      await tester.enterText(field('URL du site *'), 'example.com');
      await generate(tester);

      expect(find.byType(QrResultView), findsOneWidget);
      expect(find.text(FakeQrCodeService.publicUrl(1)), findsOneWidget);
      expect(service.created.single.content, {'url': 'https://example.com'});
    });
  });

  group('Wi-Fi', () {
    testWidgets('mot de passe désactivé pour un réseau ouvert', (tester) async {
      await open(tester, QrType.wifi);

      TextField password() => tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Mot de passe *'),
          matching: find.byType(TextField),
        ),
      );
      expect(password().enabled, isTrue);
      expect(password().obscureText, isTrue);

      await tester.tap(find.text('WPA2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucune (réseau ouvert)').last);
      await tester.pumpAndSettle();

      final disabled = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(
            TextFormField,
            'Mot de passe (réseau ouvert)',
          ),
          matching: find.byType(TextField),
        ),
      );
      expect(disabled.enabled, isFalse);
    });

    testWidgets('aperçu en direct puis QR Code Wi-Fi', (tester) async {
      await open(tester, QrType.wifi);

      await tester.enterText(field('Nom du réseau (SSID) *'), 'Maison');
      await tester.enterText(field('Mot de passe *'), 'secret-wifi');
      await tester.ensureVisible(find.text('Réseau masqué'));
      await tester.tap(find.text('Réseau masqué'));
      await tester.pumpAndSettle();

      expect(find.byType(QrLivePreview), findsOneWidget);
      await generate(tester);

      expect(find.text('Votre QR Code Wi-Fi est prêt'), findsOneWidget);
      expect(service.created.single.content['hidden'], isTrue);
      // Le mot de passe n'est jamais affiché sur l'écran résultat.
      expect(find.textContaining('secret-wifi'), findsNothing);
    });
  });

  for (final type in [QrType.website, QrType.wifi]) {
    testWidgets('${type.title} : pas de débordement avec texte agrandi', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await open(tester, type);

      expect(tester.takeException(), isNull);
    });
  }
}
