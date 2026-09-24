import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

void main() {
  late ProviderContainer container;

  Future<void> openBusinessCard(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(QrType.businessCard.title));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('affiche le formulaire organisé en sections', (tester) async {
    await openBusinessCard(tester);

    for (final section in [
      'Informations personnelles',
      'Contact',
      'Adresse',
      'Réseaux sociaux',
    ]) {
      expect(find.textContaining(section), findsWidgets);
    }
    expect(field('Prénom *'), findsOneWidget);
    expect(find.text('Générer le QR Code'), findsOneWidget);
  });

  testWidgets("aucune erreur n'est affichée avant interaction", (tester) async {
    await openBusinessCard(tester);

    expect(find.text('Veuillez saisir votre prénom.'), findsNothing);
    expect(find.text('Veuillez saisir votre nom.'), findsNothing);
  });

  testWidgets('générer avec des champs manquants affiche les erreurs', (
    tester,
  ) async {
    await openBusinessCard(tester);

    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir votre prénom.'), findsOneWidget);
    expect(find.text('Veuillez saisir votre nom.'), findsOneWidget);
    expect(container.read(qrContentViewModelProvider).result, isNull);
  });

  testWidgets("un email invalide est signalé pendant la saisie", (
    tester,
  ) async {
    await openBusinessCard(tester);

    await tester.enterText(field('Email'), 'awa@');
    await tester.pumpAndSettle();

    expect(
      find.text('Veuillez saisir une adresse email valide.'),
      findsOneWidget,
    );
  });

  testWidgets('la saisie met à jour le ViewModel et permet de générer', (
    tester,
  ) async {
    await openBusinessCard(tester);

    await tester.enterText(field('Prénom *'), 'Awa');
    await tester.enterText(field('Nom *'), 'Traoré');
    await tester.tap(find.text('Générer le QR Code'));
    await tester.pumpAndSettle();

    final result = container.read(qrContentViewModelProvider).result;
    expect(result?.payload, contains('FN:Awa Traoré'));
  });

  testWidgets('les données saisies sont conservées au retour', (tester) async {
    await openBusinessCard(tester);
    await tester.enterText(field('Prénom *'), 'Awa');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(QrType.businessCard.title));
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

    await openBusinessCard(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets("l'aperçu apparaît quand le prénom et le nom sont saisis", (
    tester,
  ) async {
    await openBusinessCard(tester);
    expect(find.byType(QrPreview), findsNothing);

    await tester.enterText(field('Prénom *'), 'Awa');
    await tester.enterText(field('Nom *'), 'Traoré');
    await tester.pumpAndSettle();

    final preview = tester.widget<QrPreview>(find.byType(QrPreview));
    expect(preview.data, contains('FN:Awa Traoré'));
  });

  testWidgets("sur tablette, l'aperçu est affiché à côté du formulaire", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openBusinessCard(tester);
    await tester.enterText(field('Prénom *'), 'Awa');
    await tester.enterText(field('Nom *'), 'Traoré');
    await tester.pumpAndSettle();

    final formRight = tester.getTopRight(field('Prénom *')).dx;
    final previewLeft = tester.getTopLeft(find.byType(QrPreview)).dx;
    expect(previewLeft, greaterThan(formRight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque champ remplit la bonne information', (tester) async {
    await openBusinessCard(tester);
    const values = {
      'Prénom *': 'Awa',
      'Nom *': 'Traoré',
      'Fonction': 'Designer',
      'Entreprise': 'Studio',
      'Téléphone': '+225 01',
      'Email': 'awa@example.com',
      'Site web': 'awa.dev',
      'Adresse': '12 rue A',
      'Ville': 'Abidjan',
      'Pays': 'CI',
      'LinkedIn': 'awa-traore',
      'Instagram': '@awa',
      'WhatsApp': '+225 02',
    };

    for (final MapEntry(:key, :value) in values.entries) {
      await tester.ensureVisible(field(key));
      await tester.enterText(field(key), value);
    }

    final card = container.read(qrContentViewModelProvider).businessCard;
    expect([
      card.firstName,
      card.lastName,
      card.jobTitle,
      card.company,
      card.phone,
      card.email,
      card.website,
      card.address,
      card.city,
      card.country,
      card.linkedin,
      card.instagram,
      card.whatsapp,
    ], values.values.toList());
  });

  testWidgets('le clavier passe au champ suivant, sauf sur le dernier', (
    tester,
  ) async {
    await openBusinessCard(tester);

    final actions = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.textInputAction)
        .toList();

    expect(actions, hasLength(13));
    expect(actions.take(12), everyElement(TextInputAction.next));
    expect(actions.last, TextInputAction.done);
  });

  testWidgets('les claviers sont adaptés au type de champ', (tester) async {
    await openBusinessCard(tester);

    TextInputType? keyboard(String label) => tester
        .widget<TextField>(
          find.descendant(of: field(label), matching: find.byType(TextField)),
        )
        .keyboardType;

    expect(keyboard('Téléphone'), TextInputType.phone);
    expect(keyboard('Email'), TextInputType.emailAddress);
    expect(keyboard('Site web'), TextInputType.url);
    expect(keyboard('WhatsApp'), TextInputType.phone);
  });
}
