import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/qr_generator/models/business_card_data.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late List<RecordedRequest> requests;

  BusinessCardDirectoryService serviceReplying(int status, Object body) {
    final adapter = FakeHttpAdapter((_) async => jsonResponse(status, body));
    requests = adapter.requests;
    return BusinessCardDirectoryService(
      ApiClient(
        'https://api.test',
        readTokens: () => null,
        onTokensRefreshed: (_) {},
        onUnauthorized: () {},
        adapter: adapter,
      ),
    );
  }

  const awaJson = {
    'id': 'AwaAwaAwaAwaAwa1',
    'first_name': 'Awa',
    'last_name': 'Traoré',
    'job_title': 'Designer',
    'company': 'Studio Lagune',
    'phone': '',
    'email': 'awa@example.com',
    'website': '',
    'address': '',
    'city': 'Abidjan',
    'country': '',
    'linkedin': '',
    'instagram': '',
    'whatsapp': '',
  };

  test('recherche les cartes et lit tous les champs', () async {
    final service = serviceReplying(200, {
      'items': [awaJson],
    });

    final cards = await service.search('  lagune ');

    expect(
      requests.single.uri.toString(),
      'https://api.test/api/v1/business-cards?q=lagune',
    );
    final card = cards.single;
    expect(card.id, 'AwaAwaAwaAwaAwa1');
    expect(card.data.firstName, 'Awa');
    // Accents correctement décodés (UTF-8).
    expect(card.data.lastName, 'Traoré');
    expect(card.data.company, 'Studio Lagune');
    expect(card.data.city, 'Abidjan');
  });

  test('sans recherche, pas de paramètre q', () async {
    final service = serviceReplying(200, {'items': []});

    await service.search('');

    expect(requests.single.uri.hasQuery, isFalse);
  });

  test('publie la carte en JSON avec les noms de champs de l’API', () async {
    final service = serviceReplying(201, awaJson);

    final saved = await service.publish(
      const BusinessCardData(
        firstName: ' Awa ',
        lastName: 'Traoré',
        company: 'Studio Lagune',
        whatsapp: '+225 07',
      ),
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/business-cards');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body, hasLength(13));
    expect(body['first_name'], 'Awa');
    expect(body['company'], 'Studio Lagune');
    expect(body['whatsapp'], '+225 07');
    expect(saved.id, 'AwaAwaAwaAwaAwa1');
  });

  test('annuaire public : aucune session envoyée', () async {
    final service = serviceReplying(200, {'items': []});

    await service.search('');

    expect(requests.single.header('Authorization'), isNull);
  });

  test('un statut d’erreur garde sa catégorie', () async {
    final service = serviceReplying(429, {'detail': 'Trop d’envois'});

    await expectLater(
      service.publish(const BusinessCardData(firstName: 'A', lastName: 'B')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.tooManyRequests,
        ),
      ),
    );
  });

  test('une réponse invalide lève une exception', () async {
    for (final body in [
      {'pas': 'items'},
      {
        'items': [
          {'first_name': 'sans id'},
        ],
      },
    ]) {
      await expectLater(
        serviceReplying(200, body).search(''),
        throwsA(isA<ApiException>()),
      );
    }
  });

  test('sans adresse de serveur, les cartes partagées sont désactivées', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(businessCardDirectoryProvider), isNull);
  });
}
