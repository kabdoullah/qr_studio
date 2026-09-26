import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/saved_cards_view_model.dart';
import 'package:qr_studio/features/qr_generator/views/saved_cards_view.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late FakeBusinessCardDirectory directory;
  late ProviderContainer container;

  Future<void> openBusinessCard(
    WidgetTester tester, {
    bool withServer = true,
  }) async {
    directory = FakeBusinessCardDirectory([jeanCard, awaCard]);
    container = ProviderContainer(
      overrides: [
        ...signedIn(),
        if (withServer)
          businessCardDirectoryProvider.overrideWithValue(directory),
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
    await tester.tap(find.text(QrType.businessCard.title));
    await tester.pumpAndSettle();
  }

  Future<void> openSavedCards(WidgetTester tester) async {
    await openBusinessCard(tester);
    await tester.tap(find.text('Choisir une carte enregistrée'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('sans serveur, les cartes partagées sont masquées', (
    tester,
  ) async {
    await openBusinessCard(tester, withServer: false);

    expect(find.text('Choisir une carte enregistrée'), findsNothing);
    expect(find.text('Enregistrer dans les cartes partagées'), findsNothing);
  });

  testWidgets('affiche les cartes enregistrées', (tester) async {
    await openSavedCards(tester);

    expect(find.byType(SavedCardsView), findsOneWidget);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('Designer · Studio Lagune · Abidjan'), findsOneWidget);
    expect(find.text('Jean Kouassi'), findsOneWidget);
    expect(find.text('Orange CI'), findsOneWidget);
  });

  testWidgets('la recherche filtre la liste', (tester) async {
    await openSavedCards(tester);

    await tester.enterText(find.byType(TextField), 'lagune');
    await tester.pump(SavedCardsViewModel.searchDelay);
    await tester.pumpAndSettle();

    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('Jean Kouassi'), findsNothing);

    await tester.enterText(find.byType(TextField), 'inconnu');
    await tester.pump(SavedCardsViewModel.searchDelay);
    await tester.pumpAndSettle();
    expect(
      find.text('Aucune carte ne correspond à « inconnu ».'),
      findsOneWidget,
    );

    // Effacer la recherche affiche de nouveau toutes les cartes.
    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump(SavedCardsViewModel.searchDelay);
    await tester.pumpAndSettle();
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('Jean Kouassi'), findsOneWidget);
    expect(find.byTooltip('Effacer la recherche'), findsNothing);
  });

  testWidgets('choisir une carte remplit le formulaire et l’aperçu', (
    tester,
  ) async {
    await openBusinessCard(tester);
    await tester.enterText(field('Prénom *'), 'Ancien');
    await tester.tap(find.text('Choisir une carte enregistrée'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Awa Traoré'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedCardsView), findsNothing);
    String value(String label) =>
        tester.widget<TextFormField>(field(label)).controller?.text ??
        tester
            .widget<EditableText>(
              find.descendant(
                of: field(label),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text;
    expect(value('Prénom *'), 'Awa');
    expect(value('Nom *'), 'Traoré');
    expect(value('Entreprise'), 'Studio Lagune');
    expect(value('Email'), 'awa@example.com');

    await tester.ensureVisible(find.byType(QrPreview));
    expect(
      tester.widget<QrPreview>(find.byType(QrPreview)).data,
      contains('FN:Awa Traoré'),
    );
  });

  testWidgets('une erreur de chargement propose de réessayer', (tester) async {
    await openBusinessCard(tester);
    directory.error = Exception('hors ligne');
    await tester.tap(find.text('Choisir une carte enregistrée'));
    await tester.pumpAndSettle();

    expect(find.text(SavedCardsViewModel.loadFailedMessage), findsOneWidget);

    directory.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Awa Traoré'), findsOneWidget);
  });

  Future<void> tapPublish(WidgetTester tester) async {
    await tester.ensureVisible(
      find.text('Enregistrer dans les cartes partagées'),
    );
    await tester.tap(find.text('Enregistrer dans les cartes partagées'));
    await tester.pumpAndSettle();
  }

  testWidgets('publier demande une confirmation puis enregistre la carte', (
    tester,
  ) async {
    await openBusinessCard(tester);
    await tester.enterText(field('Prénom *'), 'Awa');
    await tester.enterText(field('Nom *'), 'Traoré');

    await tapPublish(tester);
    expect(find.text('Rendre cette carte publique ?'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(directory.published.single.lastName, 'Traoré');
    expect(find.text(CardPublishViewModel.publishedMessage), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne publie rien', (tester) async {
    await openBusinessCard(tester);
    await tester.enterText(field('Prénom *'), 'Awa');
    await tester.enterText(field('Nom *'), 'Traoré');

    await tapPublish(tester);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(directory.published, isEmpty);
  });

  testWidgets('publier une carte incomplète explique quoi remplir', (
    tester,
  ) async {
    await openBusinessCard(tester);

    await tapPublish(tester);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(find.text(CardPublishViewModel.invalidMessage), findsOneWidget);
    expect(directory.published, isEmpty);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    directory = FakeBusinessCardDirectory([jeanCard, awaCard]);
    container = ProviderContainer(
      overrides: [
        ...signedIn(),
        businessCardDirectoryProvider.overrideWithValue(directory),
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
    await tester.ensureVisible(find.text(QrType.businessCard.title));
    await tester.tap(find.text(QrType.businessCard.title));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Choisir une carte enregistrée'));
    await tester.tap(find.text('Choisir une carte enregistrée'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(qrContentViewModelProvider).businessCardRevision, 0);
  });
}
