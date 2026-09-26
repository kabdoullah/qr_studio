import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/saved_qr_code.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';
import 'package:qr_studio/features/qr_generator/views/qr_content_view.dart';
import 'package:qr_studio/features/qr_generator/views/qr_result_view.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_preview.dart';
import 'package:qr_studio/features/qr_history/viewmodels/qr_history_view_model.dart';
import 'package:qr_studio/features/qr_history/views/qr_history_view.dart';

import '../../helpers/fake_services.dart';

void main() {
  const website = SavedQrCode(
    id: 'site',
    type: QrType.website,
    title: 'Mon portfolio',
    publicUrl: 'https://qr.test/q/site',
    content: {'url': 'https://example.com'},
  );
  const wifi = SavedQrCode(
    id: 'wifi',
    type: QrType.wifi,
    title: 'Wi-Fi Maison',
    publicUrl: 'https://qr.test/q/wifi',
    content: {
      'ssid': 'Maison',
      'security': 'WPA2',
      'password': 'secret-wifi',
      'hidden': false,
    },
  );

  late FakeQrCodeService service;
  late FakeQrHistoryCache cache;

  setUp(() {
    service = FakeQrCodeService()..items.addAll([website, wifi]);
    cache = FakeQrHistoryCache();
  });

  group('QrHistoryViewModel (stale-while-revalidate)', () {
    late ProviderContainer container;

    QrHistoryState state() => container.read(qrHistoryViewModelProvider);
    QrHistoryViewModel viewModel() =>
        container.read(qrHistoryViewModelProvider.notifier);
    List<String>? ids() => state().items?.map((q) => q.id).toList();

    setUp(() async {
      container = ProviderContainer(
        overrides: signedIn(qrCodes: service, historyCache: cache),
      );
      container.listen(qrHistoryViewModelProvider, (_, _) {});
      // Session ouverte (compte connu du cache).
      container.listen(authViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });
    tearDown(() => container.dispose());

    test('premier chargement : rien d’affiché, puis la liste', () async {
      expect(state().hasItems, isFalse);

      final loading = viewModel().revalidate();
      expect(state().isRevalidating, isTrue);
      await loading;

      expect(ids(), ['site', 'wifi']);
      expect(state().isRevalidating, isFalse);
    });

    test('réouverture : la liste connue reste affichée pendant le '
        'rechargement', () async {
      await viewModel().revalidate();
      service.items.removeAt(1);
      service.gate = Completer<void>();

      final loading = viewModel().revalidate();

      expect(ids(), ['site', 'wifi']);
      expect(state().isRevalidating, isTrue);
      service.gate!.complete();
      await loading;
      expect(ids(), ['site']);
      expect(state().isRevalidating, isFalse);
    });

    test('échec du rechargement : liste connue gardée, message', () async {
      await viewModel().revalidate();
      service.error = const ApiException(ApiErrorKind.offline);

      await viewModel().revalidate();

      expect(ids(), ['site', 'wifi']);
      expect(
        state().errorMessage,
        const ApiException(ApiErrorKind.offline).message,
      );
      expect(state().isRevalidating, isFalse);
    });

    test('échec du premier chargement : message, aucune liste', () async {
      service.error = const ApiException(ApiErrorKind.server);

      await viewModel().revalidate();

      expect(state().hasItems, isFalse);
      expect(state().errorMessage, QrHistoryViewModel.loadFailedMessage);
    });

    test('un rechargement réussi efface le message d’échec', () async {
      service.error = const ApiException(ApiErrorKind.offline);
      await viewModel().revalidate();
      service.error = null;

      await viewModel().revalidate();

      expect(state().errorMessage, isNull);
      expect(ids(), ['site', 'wifi']);
    });

    test('rechargements simultanés : une seule requête', () async {
      await Future.wait([
        viewModel().revalidate(),
        viewModel().revalidate(),
        viewModel().revalidate(),
      ]);

      expect(service.lists, 1);
    });

    test('supprime un QR Code', () async {
      await viewModel().revalidate();

      final message = await viewModel().delete(website);

      expect(message, QrHistoryViewModel.deletedMessage);
      expect(service.deleted, ['site']);
      expect(ids(), ['wifi']);
    });

    test('échec de suppression : message et liste inchangée', () async {
      await viewModel().revalidate();
      service.error = const ApiException(ApiErrorKind.offline);

      final message = await viewModel().delete(website);

      expect(message, QrHistoryViewModel.deleteFailedMessage);
      expect(ids(), hasLength(2));
    });

    test('réponse partie avant une suppression : ignorée', () async {
      await viewModel().revalidate();
      final pendingList = Completer<void>();
      service.gate = pendingList;
      final loading = viewModel().revalidate();

      // Supprimé pendant le rechargement, dont la réponse contient encore
      // le QR Code supprimé.
      service.gate = null;
      await viewModel().delete(website);
      service.items.insert(0, website);
      pendingList.complete();
      await loading;

      expect(ids(), ['wifi']);
      expect(state().isRevalidating, isFalse);
    });

    test('QR Code créé ou modifié : la liste connue suit', () async {
      await viewModel().revalidate();
      const renamed = SavedQrCode(
        id: 'site',
        type: QrType.website,
        title: 'Portfolio 2026',
        publicUrl: 'https://qr.test/q/site',
        content: {'url': 'https://example.com/2026'},
      );
      const text = SavedQrCode(
        id: 'texte',
        type: QrType.text,
        title: 'Bonjour',
        publicUrl: 'https://qr.test/q/texte',
        content: {'text': 'Bonjour'},
      );

      viewModel().upsert(renamed);
      viewModel().upsert(text);

      expect(ids(), ['texte', 'site', 'wifi']);
      expect(state().items![1].title, 'Portfolio 2026');
    });

    group('cache sur l’appareil', () {
      final userId = awaUser.id;

      test('nouveau lancement : la liste enregistrée s’affiche avant le '
          'serveur', () async {
        cache.entries[userId] = [wifi];
        service.gate = Completer<void>();

        final loading = viewModel().revalidate();
        await pumpEventQueue();

        expect(ids(), ['wifi']);
        expect(state().isRevalidating, isTrue);
        service.gate!.complete();
        await loading;
        expect(ids(), ['site', 'wifi']);
      });

      test('la réponse du serveur est enregistrée', () async {
        await viewModel().revalidate();

        expect(cache.entries[userId]?.map((q) => q.id), ['site', 'wifi']);
      });

      test('suppressions et modifications enregistrées', () async {
        await viewModel().revalidate();

        await viewModel().delete(website);
        viewModel().upsert(
          const SavedQrCode(
            id: 'wifi',
            type: QrType.wifi,
            title: 'Wi-Fi Bureau',
            publicUrl: 'https://qr.test/q/wifi',
            content: {'ssid': 'Bureau', 'security': 'WPA2'},
          ),
        );

        expect(cache.entries[userId]?.map((q) => q.title), ['Wi-Fi Bureau']);
      });

      test(
        'serveur injoignable : la liste enregistrée reste affichée',
        () async {
          cache.entries[userId] = [wifi];
          service.error = const ApiException(ApiErrorKind.offline);

          await viewModel().revalidate();

          expect(ids(), ['wifi']);
          expect(state().errorMessage, isNotNull);
          // Un échec n'efface pas le cache.
          expect(cache.entries[userId], hasLength(1));
        },
      );

      test('le cache d’un autre compte n’est jamais affiché', () async {
        cache.entries['autre-compte'] = [wifi];
        service.gate = Completer<void>();

        final loading = viewModel().revalidate();
        await pumpEventQueue();

        expect(state().hasItems, isFalse);
        service.gate!.complete();
        await loading;
      });

      test(
        'réponse arrivée après la déconnexion : jamais enregistrée',
        () async {
          service.gate = Completer<void>();
          final loading = viewModel().revalidate();
          await pumpEventQueue();

          await container.read(authViewModelProvider.notifier).logout();
          service.gate!.complete();
          await loading;

          expect(cache.entries, isEmpty);
        },
      );
    });

    test('déconnexion : le cache du compte est vidé', () async {
      await viewModel().revalidate();

      await container.read(authViewModelProvider.notifier).logout();

      expect(state().hasItems, isFalse);
    });
  });

  group('écran Mes QR Codes', () {
    late FakeQrShareService sharer;

    Future<void> openHistory(WidgetTester tester) async {
      sharer = FakeQrShareService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedIn(qrCodes: service, historyCache: cache),
            qrShareServiceProvider.overrideWithValue(sharer),
            qrExportServiceProvider.overrideWithValue(FakeQrExportService()),
          ],
          child: const QrStudioApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes QR Codes'));
      await tester.pumpAndSettle();
    }

    Future<void> tapAction(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.bySemanticsLabel(label));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    testWidgets('liste les QR Codes depuis le menu du compte', (tester) async {
      await openHistory(tester);

      expect(find.byType(QrHistoryView), findsOneWidget);
      expect(find.text('Mon portfolio'), findsOneWidget);
      expect(find.text('Wi-Fi Maison'), findsOneWidget);
    });

    testWidgets('Ouvrir affiche le QR Code enregistré', (tester) async {
      await openHistory(tester);

      await tapAction(tester, 'Ouvrir Mon portfolio');

      expect(find.byType(QrResultView), findsOneWidget);
      expect(
        tester.widget<QrPreview>(find.byType(QrPreview)).data,
        'https://qr.test/q/site',
      );
    });

    testWidgets('Modifier ouvre le formulaire rempli et met à jour', (
      tester,
    ) async {
      await openHistory(tester);

      await tapAction(tester, 'Modifier Mon portfolio');
      expect(find.byType(QrContentView), findsOneWidget);
      final url = find.widgetWithText(TextFormField, 'URL du site *');
      expect(
        tester.widget<TextFormField>(url).initialValue,
        'https://example.com',
      );

      await tester.enterText(url, 'https://nouveau.example');
      await tester.tap(find.text('Générer le QR Code'));
      await tester.pumpAndSettle();

      expect(service.updated, ['site']);
      expect(service.created, isEmpty);
    });

    testWidgets('Partager partage le QR Code sans le mot de passe', (
      tester,
    ) async {
      await openHistory(tester);

      await tapAction(tester, 'Partager Wi-Fi Maison');

      expect(sharer.shares.single.fileName, QrType.wifi.fileName);
      expect(sharer.shares.single.text, isNull);
    });

    testWidgets('Supprimer demande confirmation', (tester) async {
      await openHistory(tester);

      await tapAction(tester, 'Supprimer Mon portfolio');
      expect(find.text('Supprimer ce QR Code ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(service.deleted, ['site']);
      expect(find.text('Mon portfolio'), findsNothing);
      expect(find.text(QrHistoryViewModel.deletedMessage), findsOneWidget);
    });

    testWidgets('réouverture : liste connue affichée tout de suite, puis '
        'actualisée', (tester) async {
      await openHistory(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      service.items.removeAt(0);
      service.gate = Completer<void>();
      await tester.tap(find.text('Mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes QR Codes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Données en cache, pas d'écran de chargement.
      expect(find.text('Mon portfolio'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mon portfolio'), findsNothing);
      expect(find.text('Wi-Fi Maison'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('actualisation impossible : liste gardée et message', (
      tester,
    ) async {
      await openHistory(tester);
      service.error = const ApiException(ApiErrorKind.offline);

      await tester.fling(
        find.text('Mon portfolio'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Mon portfolio'), findsOneWidget);
      expect(
        find.text(const ApiException(ApiErrorKind.offline).message),
        findsOneWidget,
      );
    });

    testWidgets('premier chargement impossible : message et Réessayer', (
      tester,
    ) async {
      service.error = const ApiException(ApiErrorKind.server);
      await openHistory(tester);

      expect(find.text(QrHistoryViewModel.loadFailedMessage), findsOneWidget);
      service.error = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Mon portfolio'), findsOneWidget);
    });

    testWidgets('se déconnecter efface l’historique enregistré', (
      tester,
    ) async {
      await openHistory(tester);
      expect(cache.entries, isNotEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(cache.clears, 1);
      expect(cache.entries, isEmpty);
    });

    testWidgets('liste vide', (tester) async {
      service.items.clear();
      await openHistory(tester);

      expect(
        find.textContaining('Aucun QR Code pour le moment.'),
        findsOneWidget,
      );
    });
  });
}
