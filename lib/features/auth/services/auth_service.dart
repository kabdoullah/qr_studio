import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_token.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';

part 'auth_service.g.dart';

// Comptes et sessions (`/api/v1/auth/…`). Inscription, connexion
// (email, Google, Facebook) renvoient `{ user, access_token, refresh_token }`.
// Les credentials Google/Facebook sont vérifiés par le serveur, qui en tire
// lui-même l'identité.
class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => _session(
    await _api.post('api/v1/auth/register', {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'password': password,
    }, authenticated: false),
  );

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _session(
    await _api.post('api/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    }, authenticated: false),
  );

  Future<AuthSession> loginWithGoogle(String idToken) async => _session(
    await _api.post('api/v1/auth/social/google', {
      'id_token': idToken,
    }, authenticated: false),
  );

  Future<AuthSession> loginWithFacebook(String accessToken) async => _session(
    await _api.post('api/v1/auth/social/facebook', {
      'access_token': accessToken,
    }, authenticated: false),
  );

  // Nouvelle paire de jetons ; l'ancien jeton de renouvellement est révoqué.
  Future<AuthTokens> refresh(String refreshToken) async {
    final tokens = AuthTokens.fromJson(
      await _api.post(ApiClient.refreshPath, {
        'refresh_token': refreshToken,
      }, authenticated: false),
    );
    if (tokens == null) throw const ApiException(ApiErrorKind.invalidResponse);
    return tokens;
  }

  // Termine la session (cet appareil) côté serveur.
  Future<void> logout(String refreshToken) async {
    await _api.post('api/v1/auth/logout', {
      'refresh_token': refreshToken,
    }, authenticated: false);
  }

  // Compte de la session en cours (vérifié par le serveur).
  Future<AppUser> me() async {
    final user = AppUser.fromJson(await _api.get('api/v1/auth/me'));
    if (user == null) throw const ApiException(ApiErrorKind.invalidResponse);
    return user;
  }

  static AuthSession _session(Object? body) =>
      AuthSession.fromJson(body) ??
      (throw const ApiException(ApiErrorKind.invalidResponse));
}

// `null` sans adresse de serveur : la connexion est alors indisponible.
@Riverpod(keepAlive: true)
AuthService? authService(Ref ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : AuthService(api);
}
