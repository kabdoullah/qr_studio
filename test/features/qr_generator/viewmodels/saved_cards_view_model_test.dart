import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/qr_generator/models/business_card_data.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/saved_cards_view_model.dart';

import '../../../helpers/fake_services.dart';

void main() {
  late ProviderContainer container;
  late FakeBusinessCardDirectory directory;

  setUp(() {
    directory = FakeBusinessCardDirectory([jeanCard, awaCard]);
    container = ProviderContainer(
      overrides: [businessCardDirectoryProvider.overrideWithValue(directory)],
    );
  });
  tearDown(() => container.dispose());

  // Garde le provider (autoDispose) actif pendant le test.
  ProviderSubscription<AsyncValue<List<SavedBusinessCard>>> listen() =>
      container.listen(savedCardsViewModelProvider, (_, _) {});

  group('liste des cartes', () {
    test('charge toutes les cartes à l’ouverture', () async {
      listen();

      final cards = await container.read(savedCardsViewModelProvider.future);

      expect(cards, [jeanCard, awaCard]);
      expect(directory.queries, ['']);
    });

    test('la recherche attend la fin de la frappe', () async {
      listen();
      await container.read(savedCardsViewModelProvider.future);
      final viewModel = container.read(savedCardsViewModelProvider.notifier);

      viewModel
        ..updateQuery('a')
        ..updateQuery('aw')
        ..updateQuery('awa');
      await Future<void>.delayed(
        SavedCardsViewModel.searchDelay + const Duration(milliseconds: 50),
      );

      expect(directory.queries, ['', 'awa']);
      expect(container.read(savedCardsViewModelProvider).value, [awaCard]);
    });

    test('une erreur est affichée sans nouvel essai automatique', () async {
      directory.error = Exception('hors ligne');
      listen();

      await expectLater(
        container.read(savedCardsViewModelProvider.future),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(savedCardsViewModelProvider).hasError, isTrue);
      expect(directory.queries, hasLength(1));
    });

    test('réessayer recharge la liste', () async {
      directory.error = Exception('hors ligne');
      listen();
      await container
          .read(savedCardsViewModelProvider.future)
          .catchError((_) => <SavedBusinessCard>[]);

      directory.error = null;
      await container.read(savedCardsViewModelProvider.notifier).retry();

      expect(container.read(savedCardsViewModelProvider).value, hasLength(2));
    });

    test('une réponse périmée ne remplace pas la plus récente', () async {
      listen();
      await container.read(savedCardsViewModelProvider.future);
      final viewModel = container.read(savedCardsViewModelProvider.notifier);

      // La recherche « jean » répond après la recherche « awa ».
      directory.gate = Completer<void>();
      viewModel.updateQuery('jean');
      await Future<void>.delayed(
        SavedCardsViewModel.searchDelay + const Duration(milliseconds: 20),
      );
      directory.gate = null;
      viewModel.updateQuery('awa');
      await Future<void>.delayed(
        SavedCardsViewModel.searchDelay + const Duration(milliseconds: 20),
      );
      expect(container.read(savedCardsViewModelProvider).value, [awaCard]);

      // Libère l'ancienne requête : son résultat est ignoré.
      final stale = directory.gate;
      stale?.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(savedCardsViewModelProvider).value, [awaCard]);
    });
  });

  group('publication', () {
    CardPublishViewModel publisher() =>
        container.read(cardPublishViewModelProvider.notifier);

    test('publie une carte valide', () async {
      final message = await publisher().publish(awaCard.data);

      expect(message, CardPublishViewModel.publishedMessage);
      expect(directory.published.single.firstName, 'Awa');
      expect(container.read(cardPublishViewModelProvider), isFalse);
    });

    test('refuse une carte sans prénom ni nom', () async {
      final message = await publisher().publish(
        const BusinessCardData(company: 'Studio'),
      );

      expect(message, CardPublishViewModel.invalidMessage);
      expect(directory.published, isEmpty);
    });

    test('explique la limite d’envois', () async {
      directory.error = const ApiException(
        ApiErrorKind.tooManyRequests,
        statusCode: 429,
      );

      expect(
        await publisher().publish(awaCard.data),
        CardPublishViewModel.tooManyMessage,
      );
    });

    test('traduit une erreur réseau en message clair', () async {
      directory.error = Exception('SocketException');

      expect(
        await publisher().publish(awaCard.data),
        CardPublishViewModel.failedMessage,
      );
    });

    test('une seule publication à la fois', () async {
      directory.gate = Completer<void>();

      final pending = publisher().publish(awaCard.data);
      expect(container.read(cardPublishViewModelProvider), isTrue);
      expect(await publisher().publish(awaCard.data), isNull);

      directory.gate!.complete();
      await pending;
      expect(directory.published, hasLength(1));
    });
  });

  test('charger une carte remplace la saisie et efface les erreurs', () async {
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.businessCard);
    final content = container.read(qrContentViewModelProvider.notifier);
    content
      ..setBusinessCardMode(BusinessCardMode.image)
      ..updateBusinessCard((c) => c.copyWith(company: 'Ancienne'));
    content.setBusinessCardMode(BusinessCardMode.details);
    await content.generateQr(); // échec : erreurs affichées

    content.loadBusinessCard(awaCard.data);

    final state = container.read(qrContentViewModelProvider);
    expect(state.businessCard.company, 'Studio Lagune');
    expect(state.businessCardMode, BusinessCardMode.details);
    expect(state.businessCardRevision, 1);
    expect(state.showErrorsFor, isNot(contains(QrType.businessCard)));
  });
}
