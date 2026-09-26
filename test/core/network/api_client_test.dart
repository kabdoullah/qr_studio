import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_studio/core/network/api_client.dart';

void main() {
  late List<http.Request> requests;
  late int unauthorized;

  ApiClient client(
    Future<http.Response> Function(http.Request) handler, {
    String? token = 'jeton',
  }) {
    return ApiClient(
      'https://api.test',
      readToken: () => token,
      onUnauthorized: () => unauthorized++,
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  http.Response json(int status, Object body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status);

  setUp(() {
    requests = [];
    unauthorized = 0;
  });

  test('ajoute le jeton aux requêtes authentifiées', () async {
    final api = client((_) async => json(200, {'ok': true}));

    expect(await api.get('api/v1/qr-codes'), {'ok': true});
    expect(requests.single.headers['authorization'], 'Bearer jeton');
    expect(requests.single.url.toString(), 'https://api.test/api/v1/qr-codes');
  });

  test('la connexion part sans jeton', () async {
    final api = client((_) async => json(200, {}));

    await api.post('api/v1/auth/login', {'email': 'a'}, authenticated: false);

    expect(requests.single.headers.containsKey('authorization'), isFalse);
    expect(requests.single.headers['content-type'], 'application/json');
  });

  test('401 sur une requête authentifiée termine la session', () async {
    final api = client((_) async => json(401, {'detail': 'Session expirée'}));

    await expectLater(
      api.get('api/v1/qr-codes'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(unauthorized, 1);
  });

  test('401 à la connexion (mauvais mot de passe) ne déconnecte pas', () async {
    final api = client(
      (_) async => json(401, {'detail': 'Email ou mot de passe incorrect.'}),
    );

    await expectLater(
      api.post('api/v1/auth/login', {}, authenticated: false),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Email ou mot de passe incorrect.',
        ),
      ),
    );
    expect(unauthorized, 0);
  });

  test('traduit chaque statut en erreur typée', () async {
    for (final (status, kind) in [
      (403, ApiErrorKind.forbidden),
      (404, ApiErrorKind.notFound),
      (409, ApiErrorKind.conflict),
      (422, ApiErrorKind.validation),
      (429, ApiErrorKind.tooManyRequests),
      (500, ApiErrorKind.server),
    ]) {
      final api = client((_) async => json(status, {'detail': []}));
      await expectLater(
        api.get('x'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind)),
        reason: '$status',
      );
    }
  });

  test("n'affiche jamais le détail technique d'une erreur 500", () async {
    final api = client((_) async => json(500, {'detail': 'Traceback…'}));

    await expectLater(
      api.get('x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          isNot(contains('Traceback')),
        ),
      ),
    );
  });

  test('hors ligne', () async {
    final api = client((_) async => throw http.ClientException('no route'));

    await expectLater(
      api.get('x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.offline),
      ),
    );
  });

  test('délai dépassé', () async {
    final api = client((_) async => throw TimeoutException('lent'));

    await expectLater(
      api.get('x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
      ),
    );
  });

  test('DELETE sans contenu', () async {
    final api = client((_) async => http.Response('', 204));

    await api.delete('api/v1/qr-codes/1');

    expect(requests.single.method, 'DELETE');
  });
}
