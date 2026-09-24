import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_studio/features/qr_generator/models/business_card_data.dart';
import 'package:qr_studio/features/qr_generator/services/business_card_directory_service.dart';

void main() {
  late List<http.Request> requests;

  BusinessCardDirectoryService serviceReplying(int status, Object body) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
    return BusinessCardDirectoryService('https://api.test', client: client);
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
      requests.single.url.toString(),
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

    expect(requests.single.url.hasQuery, isFalse);
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
    expect(request.url.path, '/api/v1/business-cards');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body, hasLength(13));
    expect(body['first_name'], 'Awa');
    expect(body['company'], 'Studio Lagune');
    expect(body['whatsapp'], '+225 07');
    expect(saved.id, 'AwaAwaAwaAwaAwa1');
  });

  test('un statut d’erreur conserve le code HTTP', () async {
    final service = serviceReplying(429, {'detail': 'Trop d’envois'});

    await expectLater(
      service.publish(const BusinessCardData(firstName: 'A', lastName: 'B')),
      throwsA(
        isA<BusinessCardDirectoryException>().having(
          (e) => e.statusCode,
          'statusCode',
          429,
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
        throwsA(isA<BusinessCardDirectoryException>()),
      );
    }
  });

  test('sans adresse de serveur, les cartes partagées sont désactivées', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(businessCardDirectoryProvider), isNull);
  });
}
