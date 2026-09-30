import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/features/auth/services/auth_service.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late AuthService service;

  const anonymousSession = {
    'user': {
      'id': 'u1',
      'email': null,
      'first_name': null,
      'last_name': null,
      'avatar_url': null,
      'email_verified': false,
      'is_anonymous': true,
    },
    'access_token': 'access',
    'refresh_token': 'refresh',
    'token_type': 'bearer',
  };

  setUp(() {
    adapter = FakeHttpAdapter((_) async => jsonResponse(200, anonymousSession));
    service = AuthService(
      ApiClient(
        'https://api.test',
        readTokens: () =>
            const AuthTokens(accessToken: 'jeton-anonyme', refreshToken: 'r'),
        onTokensRefreshed: (_) {},
        onUnauthorized: () {},
        adapter: adapter,
      ),
    );
  });

  String? bearer() => adapter.requests.single.header('Authorization');

  test('session anonyme : identifiant d’installation, sans jeton', () async {
    final session = await service.anonymous('installation-1');

    expect(adapter.requests.single.uri.path, '/api/v1/auth/anonymous');
    expect(jsonDecode(adapter.requests.single.body), {
      'installation_id': 'installation-1',
    });
    expect(bearer(), isNull);
    expect(session.user.isAnonymous, isTrue);
    expect(session.user.firstName, isNull);
    expect(session.user.email, isNull);
  });

  test('inscription : envoyée avec la session, pour convertir '
      'l’utilisateur anonyme', () async {
    await service.register(
      firstName: 'Awa',
      lastName: 'Traoré',
      email: 'awa@example.com',
      password: 'motdepasse',
    );

    expect(bearer(), 'Bearer jeton-anonyme');
  });

  test('suppression du compte : DELETE auth/me avec la session', () async {
    await service.deleteAccount();

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.uri.path, '/api/v1/auth/me');
    expect(bearer(), 'Bearer jeton-anonyme');
  });

  test('Google et Facebook : envoyés avec la session', () async {
    await service.loginWithGoogle('id-token');
    expect(bearer(), 'Bearer jeton-anonyme');

    adapter.requests.clear();
    await service.loginWithFacebook('fb-token');
    expect(bearer(), 'Bearer jeton-anonyme');
  });

  test('connexion par email : sans session (autre compte)', () async {
    await service.login(email: 'awa@example.com', password: 'motdepasse');

    expect(bearer(), isNull);
  });
}
