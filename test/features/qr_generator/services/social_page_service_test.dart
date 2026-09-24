import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';
import 'package:qr_studio/features/qr_generator/models/social_page_data.dart';
import 'package:qr_studio/features/qr_generator/services/social_page_service.dart';

void main() {
  late List<http.Request> requests;

  SocialPageService serviceReplying(int status, Object body) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    });
    return SocialPageService('https://api.test', client: client);
  }

  const page = SocialPageData(
    title: ' Awa Traoré ',
    bio: ' Designer ',
    links: [
      SocialLink(id: 1, network: SocialNetwork.instagram, value: '@awa'),
      SocialLink(id: 2, network: SocialNetwork.whatsapp, value: '+225 07'),
    ],
  );

  test('publie la page et renvoie son URL', () async {
    final service = serviceReplying(201, {
      'id': 'PagePagePagePag1',
      'url': 'https://api.test/s/PagePagePagePag1',
    });

    final url = await service.publish(page);

    expect(url, 'https://api.test/s/PagePagePagePag1');
    expect(
      requests.single.url.toString(),
      'https://api.test/api/v1/social-pages',
    );
    expect(jsonDecode(requests.single.body), {
      'title': 'Awa Traoré',
      'bio': 'Designer',
      'links': [
        {'network': 'instagram', 'url': 'https://www.instagram.com/awa'},
        {'network': 'whatsapp', 'url': 'https://wa.me/22507'},
      ],
    });
  });

  test('signale le statut en cas d’erreur', () async {
    final service = serviceReplying(429, {'detail': 'Trop'});

    await expectLater(
      service.publish(page),
      throwsA(
        isA<SocialPageException>().having((e) => e.statusCode, 'statut', 429),
      ),
    );
  });

  test('refuse une réponse sans URL', () async {
    final service = serviceReplying(201, {'id': 'x'});

    await expectLater(
      service.publish(page),
      throwsA(isA<SocialPageException>()),
    );
  });
}
