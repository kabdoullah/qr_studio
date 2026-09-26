import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late int unauthorized;
  late AuthTokens? tokens;
  late List<AuthTokens> refreshedTokens;

  late List<RecordedRequest> requests;

  ApiClient client(Future<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    requests = adapter.requests;
    return ApiClient(
      'https://api.test',
      readTokens: () => tokens,
      onTokensRefreshed: (next) {
        refreshedTokens.add(next);
        tokens = next;
      },
      onUnauthorized: () {
        unauthorized++;
        tokens = null;
      },
      adapter: adapter,
    );
  }

  bool isRefresh(RecordedRequest r) => r.uri.path == '/api/v1/auth/refresh';
  String? bearer(RecordedRequest r) => r.header('Authorization');
  Matcher throwsKind(ApiErrorKind kind) =>
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind));

  setUp(() {
    unauthorized = 0;
    tokens = const AuthTokens(accessToken: 'jeton', refreshToken: 'refresh');
    refreshedTokens = [];
  });

  test('ajoute le jeton aux requêtes authentifiées', () async {
    final api = client((_) async => jsonResponse(200, {'ok': true}));

    expect(await api.get('api/v1/qr-codes'), {'ok': true});
    expect(bearer(requests.single), 'Bearer jeton');
    expect(requests.single.uri.toString(), 'https://api.test/api/v1/qr-codes');
  });

  test('la connexion part sans jeton, en JSON', () async {
    final api = client((_) async => jsonResponse(200, {}));

    await api.post('api/v1/auth/login', {'email': 'a'}, authenticated: false);

    expect(bearer(requests.single), isNull);
    expect(
      requests.single.header(Headers.contentTypeHeader),
      startsWith('application/json'),
    );
    expect(jsonDecode(requests.single.body), {'email': 'a'});
  });

  test('paramètres de recherche encodés dans l’adresse', () async {
    final api = client((_) async => jsonResponse(200, {}));

    await api.get('x', query: {'q': 'café lagune'});

    expect(requests.single.uri.queryParameters, {'q': 'café lagune'});
  });

  group('renouvellement de session', () {
    test(
      '401 : renouvelle les jetons puis rejoue la requête une fois',
      () async {
        final api = client((r) async {
          if (isRefresh(r)) {
            return jsonResponse(200, {
              'access_token': 'neuf',
              'refresh_token': 'r2',
            });
          }
          return bearer(r) == 'Bearer neuf'
              ? jsonResponse(200, {'ok': true})
              : jsonResponse(401, {'detail': 'Session expirée'});
        });

        expect(await api.get('api/v1/qr-codes'), {'ok': true});

        expect(requests.map((r) => r.uri.path), [
          '/api/v1/qr-codes',
          '/api/v1/auth/refresh',
          '/api/v1/qr-codes',
        ]);
        final refresh = requests[1];
        expect(bearer(refresh), isNull);
        expect(jsonDecode(refresh.body), {'refresh_token': 'refresh'});
        expect(refreshedTokens.single.refreshToken, 'r2');
        expect(unauthorized, 0);
      },
    );

    test('renouvellement refusé : session terminée, sans boucle', () async {
      final api = client(
        (_) async => jsonResponse(401, {'detail': 'Session expirée.'}),
      );

      await expectLater(
        api.get('api/v1/qr-codes'),
        throwsKind(ApiErrorKind.unauthorized),
      );
      expect(requests.where(isRefresh), hasLength(1));
      expect(requests, hasLength(2));
      expect(unauthorized, 1);
      expect(tokens, isNull);
    });

    test(
      'compte désactivé au renouvellement (403) : session terminée',
      () async {
        final api = client(
          (r) async =>
              isRefresh(r) ? jsonResponse(403, {}) : jsonResponse(401, {}),
        );

        await expectLater(api.get('x'), throwsKind(ApiErrorKind.unauthorized));
        expect(unauthorized, 1);
      },
    );

    test(
      'requête rejouée encore refusée : pas de second renouvellement',
      () async {
        final api = client((r) async {
          if (isRefresh(r)) {
            return jsonResponse(200, {
              'access_token': 'neuf',
              'refresh_token': 'r2',
            });
          }
          return jsonResponse(401, {'detail': 'Session expirée'});
        });

        await expectLater(api.get('x'), throwsKind(ApiErrorKind.unauthorized));

        expect(requests.where(isRefresh), hasLength(1));
        expect(requests, hasLength(3));
        expect(unauthorized, 1);
      },
    );

    test('401 simultanés : un seul renouvellement pour toutes', () async {
      final refreshGate = Completer<void>();
      final api = client((r) async {
        if (isRefresh(r)) {
          await refreshGate.future;
          return jsonResponse(200, {
            'access_token': 'neuf',
            'refresh_token': 'r2',
          });
        }
        return bearer(r) == 'Bearer neuf'
            ? jsonResponse(200, {'path': r.uri.path})
            : jsonResponse(401, {});
      });

      final results = Future.wait([api.get('a'), api.get('b'), api.get('c')]);
      await pumpEventQueue();
      refreshGate.complete();

      expect(await results, [
        {'path': '/a'},
        {'path': '/b'},
        {'path': '/c'},
      ]);
      expect(requests.where(isRefresh), hasLength(1));
      expect(refreshedTokens, hasLength(1));
    });

    test('jetons déjà renouvelés par une autre requête : réutilisés', () async {
      final api = client((r) async {
        if (bearer(r) == 'Bearer jeton') {
          // Pendant que cette requête échoue, une autre a renouvelé.
          tokens = const AuthTokens(accessToken: 'neuf', refreshToken: 'r2');
          return jsonResponse(401, {});
        }
        return jsonResponse(200, {'ok': true});
      });

      expect(await api.get('x'), {'ok': true});
      expect(requests.where(isRefresh), isEmpty);
    });

    test(
      'serveur injoignable pendant le renouvellement : session gardée',
      () async {
        final api = client((r) async {
          if (isRefresh(r)) throw const SocketException('no route');
          return jsonResponse(401, {});
        });

        await expectLater(api.get('x'), throwsKind(ApiErrorKind.offline));
        expect(unauthorized, 0);
        expect(tokens?.refreshToken, 'refresh');
      },
    );

    test('envoi de fichier rejoué avec un formulaire reconstruit', () async {
      final api = client((r) async {
        if (isRefresh(r)) {
          return jsonResponse(200, {
            'access_token': 'neuf',
            'refresh_token': 'r2',
          });
        }
        return bearer(r) == 'Bearer neuf'
            ? jsonResponse(201, {'id': '1'})
            : jsonResponse(401, {});
      });

      final body = await api.postForm(
        'api/v1/cvs',
        FormData.fromMap({
          'file': MultipartFile.fromString('%PDF', filename: 'cv.pdf'),
        }),
      );

      expect(body, {'id': '1'});
      final uploads = requests.where((r) => r.uri.path == '/api/v1/cvs');
      expect(uploads, hasLength(2));
      expect(uploads.last.body, contains('%PDF'));
    });

    test('401 sans session en mémoire : pas de renouvellement', () async {
      tokens = null;
      final api = client(
        (_) async => jsonResponse(401, {'detail': 'Session expirée'}),
      );

      await expectLater(api.get('x'), throwsKind(ApiErrorKind.unauthorized));
      expect(unauthorized, 1);
      expect(requests.where(isRefresh), isEmpty);
    });
  });

  test('401 à la connexion (mauvais mot de passe) ne déconnecte pas', () async {
    final api = client(
      (_) async =>
          jsonResponse(401, {'detail': 'Email ou mot de passe incorrect.'}),
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
    expect(requests.where(isRefresh), isEmpty);
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
      final api = client((_) async => jsonResponse(status, {'detail': []}));
      await expectLater(api.get('x'), throwsKind(kind), reason: '$status');
    }
  });

  test("n'affiche jamais le détail technique d'une erreur 500", () async {
    final api = client(
      (_) async => jsonResponse(500, {'detail': 'Traceback…'}),
    );

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

  test('réponse qui n’est pas du JSON', () async {
    final api = client(
      (_) async => ResponseBody.fromString(
        '<html>proxy</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );

    await expectLater(api.get('x'), throwsKind(ApiErrorKind.invalidResponse));
  });

  test('hors ligne', () async {
    final api = client((_) async => throw const SocketException('no route'));

    await expectLater(api.get('x'), throwsKind(ApiErrorKind.offline));
  });

  test('délai dépassé', () async {
    final api = client(
      (r) async => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 90),
        requestOptions: r.options,
      ),
    );

    await expectLater(api.get('x'), throwsKind(ApiErrorKind.timeout));
  });

  test('DELETE sans contenu', () async {
    final api = client((_) async => ResponseBody.fromString('', 204));

    await api.delete('api/v1/qr-codes/1');

    expect(requests.single.method, 'DELETE');
  });
}
