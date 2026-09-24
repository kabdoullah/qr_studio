import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/social_page_service.dart';
import 'package:qr_studio/features/qr_generator/views/qr_result_view.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late FakeSocialPageService service;

  Future<void> openForm(WidgetTester tester) async {
    service = FakeSocialPageService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [socialPageServiceProvider.overrideWithValue(service)],
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(QrType.socialPage.title));
    await tester.tap(find.text(QrType.socialPage.title));
    await tester.pumpAndSettle();
  }

  Future<void> addNetwork(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text('Ajouter un réseau'));
    await tester.tap(find.text('Ajouter un réseau'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, label));
    await tester.pumpAndSettle();
  }

  Future<void> tapGenerate(WidgetTester tester) async {
    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();
  }

  Future<void> fillValidPage(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Titre *'),
      'Awa Traoré',
    );
    await addNetwork(tester, 'Instagram');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram'),
      '@awa',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la carte de l’accueil ouvre le formulaire', (tester) async {
    await openForm(tester);

    expect(find.text('Votre page'), findsOneWidget);
    expect(find.text('Vos réseaux  ·  0 / 10'), findsOneWidget);
  });

  testWidgets('ajoute puis retire un réseau', (tester) async {
    await openForm(tester);

    await addNetwork(tester, 'WhatsApp');
    expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsOneWidget);

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsNothing);
  });

  testWidgets('générer un formulaire vide affiche les erreurs sans confirmer', (
    tester,
  ) async {
    await openForm(tester);

    await tapGenerate(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Veuillez saisir un titre.'), findsOneWidget);
    expect(find.text('Ajoutez au moins un réseau.'), findsOneWidget);
    expect(service.published, isEmpty);
  });

  testWidgets('signale un lien invalide', (tester) async {
    await openForm(tester);
    await addNetwork(tester, 'Instagram');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram'),
      'https://evil.com/awa',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lien Instagram invalide.'), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne publie rien', (tester) async {
    await openForm(tester);
    await fillValidPage(tester);

    await tapGenerate(tester);
    expect(find.text('Publier votre page ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(service.published, isEmpty);
    expect(find.byType(QrResultView), findsNothing);
  });

  testWidgets('publier affiche le QR Code et le lien de la page', (
    tester,
  ) async {
    await openForm(tester);
    await fillValidPage(tester);

    await tapGenerate(tester);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(service.published.single.title, 'Awa Traoré');
    expect(find.byType(QrResultView), findsOneWidget);
    expect(find.text('Votre page est en ligne 🎉'), findsOneWidget);
    expect(find.text(service.url), findsOneWidget);
  });

  testWidgets('Modifier retrouve la saisie', (tester) async {
    await openForm(tester);
    await fillValidPage(tester);
    await tapGenerate(tester);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('@awa'), findsOneWidget);
  });

  testWidgets('affiche l’échec de la publication', (tester) async {
    await openForm(tester);
    await fillValidPage(tester);
    service.error = Exception('hors ligne');

    await tapGenerate(tester);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(find.byType(QrResultView), findsNothing);
    expect(
      find.text(
        'Impossible de publier la page.\n'
        'Vérifiez votre connexion et réessayez.',
      ),
      findsOneWidget,
    );
  });
}
