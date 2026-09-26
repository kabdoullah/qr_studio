import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/core/network/api_client.dart';
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

  setUp(() => service = FakeQrCodeService()..items.addAll([website, wifi]));

  group('QrHistoryViewModel', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: signedIn(qrCodes: service));
      container.listen(qrHistoryViewModelProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    test('charge les QR Codes du compte', () async {
      final items = await container.read(qrHistoryViewModelProvider.future);

      expect(items.map((q) => q.title), ['Mon portfolio', 'Wi-Fi Maison']);
    });

    test('supprime un QR Code', () async {
      await container.read(qrHistoryViewModelProvider.future);

      final message = await container
          .read(qrHistoryViewModelProvider.notifier)
          .delete(website);

      expect(message, QrHistoryViewModel.deletedMessage);
      expect(service.deleted, ['site']);
      expect(
        container.read(qrHistoryViewModelProvider).value?.map((q) => q.id),
        ['wifi'],
      );
    });

    test('échec de suppression : message et liste inchangée', () async {
      await container.read(qrHistoryViewModelProvider.future);
      service.error = const ApiException(ApiErrorKind.offline);

      final message = await container
          .read(qrHistoryViewModelProvider.notifier)
          .delete(website);

      expect(message, QrHistoryViewModel.deleteFailedMessage);
      expect(container.read(qrHistoryViewModelProvider).value, hasLength(2));
    });

    test('échec de chargement : message pour l’utilisateur', () async {
      service.error = const ApiException(ApiErrorKind.offline);
      container.invalidate(qrHistoryViewModelProvider);

      await expectLater(
        container.read(qrHistoryViewModelProvider.future),
        throwsA(isA<QrHistoryException>()),
      );
    });
  });

  group('écran Mes QR Codes', () {
    late FakeQrShareService sharer;

    Future<void> openHistory(WidgetTester tester) async {
      sharer = FakeQrShareService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedIn(qrCodes: service),
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
